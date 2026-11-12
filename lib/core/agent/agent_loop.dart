import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import '../domain/collection.dart';
import '../harness/harness.dart';
import '../harness/input/screen_line.dart';
import 'agent_event.dart';
import 'grounding.dart';
import 'history_compactor.dart';
import 'llm_client.dart';
import 'rate_limiter.dart';
import 'tool_projection.dart';

/// The workspace a loop grounds its turns in, read fresh for every request
/// (the host implements it over `WorkspaceCache` and `WorkspaceDigest`).
abstract interface class AgentWorkspace {
  /// The workspace harness calls run against.
  String get workspaceId;

  /// The current schema, for the `[Screen: …]` line and step labels.
  List<Collection> get collections;

  /// The workspace digest for the context message (the `<workspace-data>`
  /// block or its body).
  String digest();
}

/// The model settings of a loop: the bloc maps `AssistantConfig` onto them
/// (`lib/core/agent` cannot import `lib/api`).
final class AgentSettings {
  const AgentSettings({
    this.model = defaultModel,
    this.fallbackModel,
    this.maxRounds = 6,
    this.thinking = LlmThinking.off,
    this.rpm = 12,
    this.tpm,
  }) : assert(maxRounds >= 1);

  /// The only model the owner chose; `AssistantConfig.defaultModel` mirrors it.
  static const String defaultModel = 'gemini-3.5-flash-lite';

  final String model;

  /// Used only after quota errors, and only when set (the default is none).
  final String? fallbackModel;

  /// Model rounds per user turn; the last one must answer in text.
  final int maxRounds;
  final LlmThinking thinking;

  /// Client requests-per-minute bucket.
  final int rpm;

  /// Client tokens-per-minute bucket; null means none.
  final int? tpm;
}

/// One user turn at a time, as a streaming tool loop over an [LlmClient]
/// and the [Harness] (spec "Agent loop"):
/// - every harness call runs as `agent:assistant` with the loop's grants;
///   commit ops are never declared to the model, and the loop has no way to
///   call them;
/// - read and UI calls of a round run in parallel (at most 4 in flight);
///   plan calls run in call order under the turn's id, are sealed into one
///   plan, and the turn suspends at the gate until the host calls
///   [deliverOutcome];
/// - call ids are local (`r<round>.<n>`); the provider's id is echoed in the
///   function response only when the call carried one;
/// - model requests are paced by a [RateLimiter] and retried on rate
///   limits and dropped connections; writes are never retried.
final class AgentLoop {
  AgentLoop({
    required LlmClient llm,
    required Harness harness,
    required AgentWorkspace workspace,
    required Grants grants,
    AgentSettings settings = const AgentSettings(),
    HistoryCompactor compactor = const HistoryCompactor(),
    String locale = 'en',
    this.timeZoneName = '',
    DateTime Function()? now,
  }) : _llm = llm,
       _harness = harness,
       _workspace = workspace,
       _settings = settings,
       _grants = grants,
       _compactor = compactor,
       _now = now ?? DateTime.now,
       _model = settings.model,
       _system = systemInstruction(locale: locale) {
    _limiter = RateLimiter(rpm: settings.rpm, tpm: settings.tpm, now: _now);
  }

  /// Text deltas are coalesced over this long.
  static const Duration textCoalesce = Duration(milliseconds: 50);

  /// A local pacing wait shorter than this shows as "Thinking…" only; a
  /// longer one is announced with [RetryWaiting].
  static const Duration quietWait = Duration(seconds: 3);

  /// Read and UI calls in flight at once.
  static const int maxParallelReads = 4;

  /// The step summary of a harness error whose message means nothing to
  /// the user; neutral because the model may retry or give up.
  static const String stepFailed = "didn't go through";

  /// The step summary of a plan call that would change nothing.
  static const String stepNoChange = 'Already up to date';

  /// Harness errors whose message says something to the user.
  static const Set<ErrorCode> _userFacing = {
    ErrorCode.notPermitted,
    ErrorCode.offline,
    ErrorCode.conflict,
    ErrorCode.limitExceeded,
    ErrorCode.unsupported,
    ErrorCode.planExpired,
    ErrorCode.stalePreview,
    ErrorCode.internal,
  };

  static const String nudgeMalformed =
      'Your last tool call was invalid; call it again with valid arguments.';
  static const String nudgeAnswer =
      'Answer in text now, without calling tools.';
  static const String nudgeTooMany =
      'That was too many tool calls at once; make fewer calls per response, '
      'or answer in text now.';

  final LlmClient _llm;
  final Harness _harness;
  final AgentWorkspace _workspace;
  final Grants _grants;
  final HistoryCompactor _compactor;
  final DateTime Function() _now;
  final String _system;

  /// Display text for the context message (`Europe/Kyiv`).
  String timeZoneName;

  AgentSettings _settings;
  late final RateLimiter _limiter;
  String _model;
  final List<HistoryTurn> _turns = [];
  String? _summary;
  int? _lastPromptTokens;
  _Turn? _active;

  AgentSettings get settings => _settings;

  /// Applies new settings (a config change). A thread already switched to
  /// the fallback model stays on it.
  set settings(AgentSettings value) {
    if (_model == _settings.model) _model = value.model;
    _settings = value;
    _limiter.configure(rpm: value.rpm, tpm: value.tpm);
  }

  /// The model the next request uses (the fallback after a switch).
  String get model => _model;

  /// Whether a turn is running (or suspended at the gate).
  bool get busy => _active != null;

  /// The id of the plan the running turn waits on, if any.
  String? get pendingPlanId => _active?.gatePlanId;

  /// The thread's turns, oldest first; the running or last turn is last.
  /// The host persists each turn's [HistoryTurn.contents] through
  /// [LlmClient.encodeContent].
  List<HistoryTurn> get history => List.unmodifiable(_turns);

  /// The local summary older turns were folded into, if any.
  String? get summary => _summary;

  /// Replaces the thread (a thread switch or a restore): [turns] hold
  /// restored contents. Also drops a fallback-model switch.
  void restore(List<HistoryTurn> turns, {String? summary}) {
    if (busy) throw StateError('A turn is running');
    _turns
      ..clear()
      ..addAll(turns);
    _summary = summary;
    _lastPromptTokens = null;
    _model = _settings.model;
  }

  /// Starts an empty thread.
  void resetThread() => restore(const []);

  /// Runs one user turn for [text], sent while the user saw [screen] (null
  /// when they removed the context chip). The stream ends with [TurnDone],
  /// [TurnStopped] or [TurnFailed]; cancelling it stops the turn. Throws
  /// [StateError] while another turn runs.
  Stream<AgentEvent> run(String text, {ScreenContext? screen}) {
    if (busy) throw StateError('A turn is already running');
    final now = _now();
    final turnId = _harness.openTurn(Actor.assistant);
    final controller = StreamController<AgentEvent>();
    final turn = _Turn(
      turnId: turnId,
      controller: controller,
      screen: screen,
      ctx: HarnessContext(
        workspaceId: _workspace.workspaceId,
        actor: Actor.assistant,
        grants: _grants,
        now: now,
        today: now,
        timeZoneName: timeZoneName,
        focus: screen,
        turnId: turnId,
      ),
      record: HistoryTurn(userText: text),
    );
    _active = turn;
    _turns.add(turn.record);
    turn.record.add(
      LlmUserText(
        userMessage(text, screen: screen, collections: _workspace.collections),
      ),
    );
    controller
      ..onListen = (() => unawaited(_drive(turn)))
      // The done event also cancels; by then a later turn may be running.
      ..onCancel = () {
        if (identical(_active, turn)) stop();
      };
    return controller.stream;
  }

  /// Hands the gate the user's decision on [planId]. Returns false when the
  /// running turn does not wait on that plan (a late or foreign delivery).
  bool deliverOutcome(String planId, PlanOutcome outcome) {
    final gate = _active?.gate;
    if (gate == null || gate.isCompleted || _active!.gatePlanId != planId) {
      return false;
    }
    gate.complete(outcome);
    return true;
  }

  /// Stops the running turn: cancels the model stream or a wait, and ends a
  /// pending gate as `stopped` (the host rejects the plan itself). Partial
  /// text is kept.
  void stop() {
    final turn = _active;
    if (turn == null || turn.stopped) return;
    turn.stopped = true;
    if (turn.wake case final wake? when !wake.isCompleted) wake.complete();
    if (turn.gate case final gate? when !gate.isCompleted) {
      gate.complete(const Rejection(RejectReason.stopped));
    }
    unawaited(turn.cancelStream?.call());
  }

  /// Ends a retry wait early ("Retry now").
  void retryNow() {
    final wake = _active?.wake;
    if (wake != null && !wake.isCompleted) wake.complete();
  }

  // -------------------------------------------------------------- the turn

  Future<void> _drive(_Turn t) async {
    try {
      _emit(t, TurnStarted(t.turnId));
      await _rounds(t);
    } on _TurnEnd {
      // Already reported.
    } catch (e) {
      _emit(t, TurnFailed(LlmUnknownFailure('$e'), nothingChanged: !t.changed));
    } finally {
      if (t.pendingCalls case final calls?) {
        t.record.add(_stoppedResponses(calls));
      }
      _harness.closeTurn(t.turnId);
      _active = null;
      t.flush();
      await t.controller.close();
    }
  }

  Future<void> _rounds(_Turn t) async {
    var maxRounds = _settings.maxRounds;
    for (var round = 1; round <= maxRounds; round++) {
      final last = round == maxRounds;
      final mode = last || t.answerOnly ? LlmToolMode.none : LlmToolMode.auto;
      final r = await _request(t, round, mode);
      t.usage += TokenUsage(
        promptTokens: r.promptTokens,
        outputTokens: r.outputTokens,
      );
      t.record.answer += r.text;

      if (r.finish == FinishKind.maxTokens) {
        _emit(t, const TextCutShort());
        // Cut-off calls may hold half their args: drop them with the content.
        if (r.content case final content? when r.calls.isEmpty) {
          t.record.add(content);
        }
        break;
      }
      final nudge = switch (r.finish) {
        FinishKind.malformedCall => nudgeMalformed,
        FinishKind.unexpectedToolCall => nudgeAnswer,
        FinishKind.tooManyToolCalls => nudgeTooMany,
        _ when mode == LlmToolMode.none && r.calls.isNotEmpty => nudgeAnswer,
        _ => null,
      };
      if (nudge != null) {
        if (last) {
          // A nudge on the forced last round gets one more text-only round;
          // when that one misses too, the turn fails visibly instead of
          // ending without an answer (and the unsent nudge stays out).
          if (maxRounds > _settings.maxRounds) {
            _end(
              t,
              TurnFailed(
                const LlmUnknownFailure('no text answer within the step limit'),
                nothingChanged: !t.changed,
              ),
            );
          }
          maxRounds++;
        }
        t.record.add(LlmUserText(nudge));
        continue;
      }
      if (r.content case final content?) t.record.add(content);
      if (r.calls.isEmpty) break;

      final ended = await _runCalls(t, round, r.calls);
      if (ended != null) _end(t, ended);
      if (t.stopped) _end(t, const TurnStopped());
    }
    _end(t, TurnDone(t.usage));
  }

  /// One model request with its retries. Returns the collected response, or
  /// ends the turn ([_TurnEnd]) on Stop or a failure it cannot retry.
  Future<_Response> _request(_Turn t, int round, LlmToolMode mode) async {
    var rateTries = 0;
    var transientTries = 0;
    var signatureRetried = false;
    var announced = false;
    while (true) {
      if (t.stopped) _end(t, const TurnStopped());
      final tools = t.tools ??= ToolSet.project(_harness.descriptors, _grants);
      final context = contextMessage(
        today: _now(),
        timeZoneName: timeZoneName,
        digest: _workspace.digest(),
      );
      final overheadTokens =
          (_system.length + tools.chars + context.length) ~/ 4;
      _foldIfOverCap(overheadTokens);
      final contents = [
        LlmUserText(context),
        ..._compactor.contentsFor(_turns, summary: _summary),
      ];
      final estimate = overheadTokens + _estimateTokens(contents.skip(1));

      if (_limiter.acquire(tokens: estimate) case final wait?) {
        final reason = wait.scope == RateLimitScope.tpm
            ? RetryReason.tpm
            : RetryReason.rpm;
        await _wait(
          t,
          wait.until,
          reason,
          announce: wait.until.difference(_now()) >= quietWait,
        );
      }
      if (!announced) {
        _emit(t, RoundStarted(round, _model));
        announced = true;
      }
      final request = LlmRequest(
        model: _model,
        systemInstruction: _system,
        contents: contents,
        tools: tools.tools,
        toolMode: mode,
        thinking: _settings.thinking,
      );
      final response = _Response();
      try {
        await _collect(t, request, response);
        if (response.finish == FinishKind.missingThoughtSignature) {
          throw const LlmMissingSignature();
        }
        if (response.blocked case final reason?) {
          throw LlmBlockedFailure(reason);
        }
        _lastPromptTokens = response.promptTokens;
        if (response.promptTokens > 0) {
          _limiter.recordUsage(
            estimated: estimate,
            actual: response.promptTokens,
          );
        }
        return response;
      } on LlmFailure catch (failure) {
        if (t.stopped || failure is LlmStopped) _end(t, const TurnStopped());
        Never fail() =>
            _end(t, TurnFailed(failure, nothingChanged: !t.changed));
        // Text already on screen cannot be taken back by a retry.
        if (response.text.isNotEmpty) fail();
        switch (failure) {
          case LlmRateLimited(:final retryAfter, :final scope):
            if (rateTries++ < 2) {
              await _wait(
                t,
                _now().add(retryAfter ?? RateLimiter.defaultRetryAfter),
                scope == RateLimitScope.tpm ? RetryReason.tpm : RetryReason.rpm,
              );
            } else if (_switchToFallback(t)) {
              rateTries = 0;
            } else {
              fail();
            }
          case LlmDailyQuota():
            if (!_switchToFallback(t)) fail();
          case LlmTransient():
            if (transientTries < RateLimiter.transientBackoff.length) {
              await _wait(
                t,
                _now().add(RateLimiter.transientBackoff[transientTries++]),
                RetryReason.transient,
              );
            } else {
              fail();
            }
          case LlmMissingSignature() when !signatureRetried:
            signatureRetried = true;
            _foldPastTurns();
          default:
            fail();
        }
      }
    }
  }

  /// Streams [request] into [into]; text goes out as coalesced deltas.
  Future<void> _collect(_Turn t, LlmRequest request, _Response into) {
    final done = Completer<void>();
    late final StreamSubscription<LlmChunk> sub;
    sub = _llm
        .generate(request)
        .listen(
          (chunk) {
            switch (chunk) {
              case LlmText(:final text):
                into.text += text;
                t.addText(text);
              case LlmCalls(:final calls):
                into.calls.addAll(calls);
              case LlmModelContent():
                into.content = chunk;
              case LlmUsage(:final promptTokens, :final outputTokens):
                into
                  ..promptTokens = promptTokens
                  ..outputTokens = outputTokens;
              case LlmFinish(:final kind):
                into.finish = kind;
              case LlmBlocked(:final reason):
                into.blocked = reason;
            }
          },
          onError: (Object e) {
            if (!done.isCompleted) {
              done.completeError(e is LlmFailure ? e : LlmUnknownFailure('$e'));
            }
          },
          onDone: () {
            if (!done.isCompleted) done.complete();
          },
          cancelOnError: true,
        );
    t.cancelStream = () async {
      if (!done.isCompleted) done.completeError(const LlmStopped());
      await sub.cancel();
    };
    return done.future.whenComplete(() => t.cancelStream = null);
  }

  /// Runs one round's [calls] and appends their responses. Returns the event
  /// that ends the turn when the gate ended it (skipped or stopped).
  Future<AgentEvent?> _runCalls(_Turn t, int round, List<LlmCall> calls) async {
    final ids = [for (var i = 0; i < calls.length; i++) 'r$round.${i + 1}'];
    final ops = [for (final c in calls) t.tools!.opFor(c.name)];
    final responses = List<Map<String, Object?>?>.filled(calls.length, null);
    t.pendingCalls = calls;

    for (var i = 0; i < calls.length; i++) {
      _emit(
        t,
        StepStarted(
          callId: ids[i],
          op: ops[i]?.id ?? calls[i].name,
          label: _stepLabel(t, ops[i]?.id, calls[i]),
        ),
      );
    }

    // Reads and UI intents: in parallel, reported in call order.
    final reads = [
      for (var i = 0; i < calls.length; i++)
        if (ops[i] case final op? when op.kind != OpKind.plan) i,
    ];
    final readResults = <int, HarnessResponse>{};
    var next = 0;
    Future<void> worker() async {
      while (next < reads.length) {
        final i = reads[next++];
        readResults[i] = await _call(t, ops[i]!.id, calls[i].args, ids[i]);
      }
    }

    await Future.wait([
      for (var w = 0; w < math.min(maxParallelReads, reads.length); w++)
        worker(),
    ]);

    for (var i = 0; i < calls.length; i++) {
      final op = ops[i];
      if (op == null) {
        responses[i] = _unknownTool(t, calls[i].name);
        _finishStep(t, ids[i], HarnessFailure(_unknownToolError(t, calls[i])));
        continue;
      }
      final result = readResults[i];
      if (result == null) continue;
      responses[i] = moduleTextOps.contains(op.id)
          ? moduleDataResponse(op.id, calls[i].args, result)
          : _responseJson(result);
      _finishStep(t, ids[i], result, op: op.id);
      if (result is HarnessOk) _present(t, ids[i], op, calls[i], result);
    }

    // Plan calls: in order under the turn, sealed into one plan.
    final plans = [
      for (var i = 0; i < calls.length; i++)
        if (ops[i]?.kind == OpKind.plan) i,
    ];
    AgentEvent? ended;
    if (plans.isNotEmpty) {
      ended = await _plan(t, ids, ops, calls, plans, responses);
    }

    t.record.add(
      LlmFunctionResponses([
        for (var i = 0; i < calls.length; i++)
          LlmFunctionResponse(
            name: calls[i].name,
            response: responses[i] ?? _stoppedResponse,
            geminiId: calls[i].geminiId,
          ),
      ]),
    );
    t.pendingCalls = null;
    return ended;
  }

  Future<AgentEvent?> _plan(
    _Turn t,
    List<String> ids,
    List<OperationDescriptor?> ops,
    List<LlmCall> calls,
    List<int> plans,
    List<Map<String, Object?>?> responses,
  ) async {
    final errors = <String, Map<String, Object?>>{};
    // `no_change` calls keep that answer; the rest are proposed together.
    final proposed = <int>[];
    for (final i in plans) {
      final result = await _call(t, ops[i]!.id, calls[i].args, ids[i]);
      _finishStep(t, ids[i], result);
      if (result case HarnessFailure(:final error)) {
        if (error.code == ErrorCode.noChange) {
          responses[i] = _responseJson(result);
          continue;
        }
        errors[ids[i]] = _responseJson(result);
      }
      proposed.add(i);
    }
    // Every call changed nothing: the overlay stays empty (no_change is
    // never recorded), so there is nothing to seal or discard.
    final seal = proposed.isEmpty
        ? null
        : await _call(t, 'plans.seal', {
            'turnId': t.turnId,
          }, '${ids.first.split('.').first}.seal');

    if (t.stopped) {
      final stopped = const Rejection(RejectReason.stopped).toModelJson();
      for (final i in plans) {
        responses[i] = stopped;
      }
      return const TurnStopped();
    }

    if (seal == null) return null;

    CompactPlan? plan;
    switch (seal) {
      case HarnessFailure():
        // The merged plan is refused as a whole (e.g. over 500 items).
        for (final i in proposed) {
          errors.putIfAbsent(ids[i], () => _responseJson(seal));
        }
      case HarnessOk(:final result):
        for (final e in result['errors'] as List? ?? const []) {
          if (e case {'callId': final String id, 'error': final Map error}) {
            errors.putIfAbsent(id, () => {'error': error});
          }
        }
        if (errors.isEmpty) {
          try {
            plan = CompactPlan.fromJson(result);
          } on FormatException {
            plan = null;
          }
        }
    }

    if (plan == null) {
      for (final i in proposed) {
        responses[i] =
            errors[ids[i]] ??
            (errors.isEmpty
                ? {
                    'error': {
                      'code': ErrorCode.internal.wire,
                      'message': 'The change could not be prepared.',
                    },
                  }
                : const {
                    'status': 'not_proposed',
                    'reason':
                        'another change in this turn failed; resend them '
                        'together',
                  });
      }
      return null;
    }

    final gate = Completer<PlanOutcome>();
    t
      ..gate = gate
      ..gatePlanId = plan.planId;
    _emit(t, PlanProposed(plan));
    final outcome = await gate.future;
    t
      ..gate = null
      ..gatePlanId = null
      ..answerOnly = true;
    if (outcome case Receipt(
      :final applied,
      :final queued,
    ) when applied.isNotEmpty || queued.isNotEmpty) {
      t.changed = true;
    }
    final json = outcome.toModelJson();
    for (final i in proposed) {
      responses[i] = json;
    }
    return switch (outcome) {
      Rejection(reason: RejectReason.stopped) => const TurnStopped(),
      Rejection(reason: RejectReason.skipped) => TurnDone(t.usage),
      _ => null,
    };
  }

  Future<HarnessResponse> _call(
    _Turn t,
    String op,
    Map<String, Object?> args,
    String callId,
  ) => _harness.call(
    HarnessRequest(op: op, args: args, callId: callId, turnId: t.turnId),
    t.ctx,
  );

  void _finishStep(
    _Turn t,
    String callId,
    HarnessResponse result, {
    String? op,
  }) {
    switch (result) {
      case HarnessFailure(:final error) when error.code == ErrorCode.noChange:
        // Information, never shown as a failure.
        t.record.addStep(stepNoChange);
        _emit(t, StepFinished(callId: callId, summary: stepNoChange, ok: true));
      case HarnessOk(:final result):
        // A module-written summary never becomes a step line.
        final summary = moduleTextOps.contains(op)
            ? _moduleStepLine(op!, result)
            : result['summary'] as String? ?? 'Done';
        t.record.addStep(summary);
        _emit(
          t,
          StepFinished(
            callId: callId,
            summary: summary,
            ok: true,
            handle: result['handle'] as String?,
          ),
        );
      case HarnessFailure(:final error):
        _emit(
          t,
          StepFinished(
            callId: callId,
            // The full error goes to the model; the user sees plain copy
            // for internal slips (unknown tool or field, bad args), and the
            // message only where it is news.
            summary: _userFacing.contains(error.code)
                ? sanitizeName(error.message, max: 160)
                : stepFailed,
            ok: false,
            errorCode: error.code.wire,
          ),
        );
    }
  }

  /// `present` and `ui.open` results become chat items.
  void _present(
    _Turn t,
    String callId,
    OperationDescriptor op,
    LlmCall call,
    HarnessOk ok,
  ) {
    final result = ok.result;
    if (op.id == 'modules.testRun') {
      _emit(
        t,
        TestRunShown(
          title:
              'Test run · ${sanitizeName('${call.args['moduleId']}', max: 40)}',
          result: result,
        ),
      );
      return;
    }
    if (op.kind == OpKind.ui) {
      // shortcut: reads ids from the result and falls back to the args
      // (names) until ui.open (T5b) settles its result shape.
      final collectionId =
          result['collectionId'] as String? ?? _str(call.args['collection']);
      if (collectionId == null) return;
      _emit(
        t,
        ObjectChipShown(
          collectionId: collectionId,
          cardId: result['cardId'] as String? ?? _str(call.args['card']),
          viewId: result['viewId'] as String? ?? _str(call.args['view']),
          label: result['label'] as String? ?? _collectionName(collectionId),
        ),
      );
      return;
    }
    final kind = PresentKind.values.asNameMap()[call.args['present']];
    final handle = result['handle'];
    if (kind == null || handle is! String) return;
    final summary = result['summary'] as String?;
    _emit(
      t,
      ResultPresented(
        callId: callId,
        handle: handle,
        kind: kind,
        title:
            result['title'] as String? ??
            summary ??
            _collectionName(_str(call.args['collection']) ?? ''),
        spec: (result['spec'] as Map?)?.cast<String, Object?>(),
        summary: summary,
      ),
    );
  }

  Map<String, Object?> _unknownTool(_Turn t, String name) => {
    'error': _unknownToolError(t, LlmCall(name: name, args: const {})).toJson(),
  };

  HarnessError _unknownToolError(_Turn t, LlmCall call) => HarnessError(
    code: ErrorCode.unknownOp,
    message: 'There is no tool "${sanitizeName(call.name)}".',
    candidates: [for (final tool in t.tools!.tools) tool.name],
  );

  /// Read ops whose results carry module-written text (code, logs,
  /// errors, summaries, manifest names): the model gets them inside the
  /// workspace-data block, tagged with where they came from.
  static const Set<String> moduleTextOps = {
    'modules.list',
    'modules.get',
    'modules.testRun',
    'runs.list',
    'runs.get',
  };

  /// [result] of module op [op] as the model sees it: a host-authored
  /// summary, the `source` (`module:<id>` when the call names one module)
  /// and the result as JSON inside the data block. `<` is escaped, so text
  /// in it can never close the block; the JSON decodes unchanged.
  static Map<String, Object?> moduleDataResponse(
    String op,
    Map<String, Object?> args,
    HarnessResponse result,
  ) {
    if (result is! HarnessOk) return _responseJson(result);
    final json = result.result;
    final moduleId = switch (op) {
      'modules.get' => json['id'],
      'modules.testRun' => args['moduleId'],
      'runs.get' => json['moduleId'],
      _ => null,
    };
    final data = jsonEncode(json).replaceAll('<', r'\u003c');
    return {
      'summary': _moduleStepLine(op, json),
      'source': moduleId is String ? 'module:$moduleId' : 'modules',
      'data': '$kWorkspaceDataOpen$data$kWorkspaceDataClose',
    };
  }

  static String _moduleStepLine(String op, Map<String, Object?> result) =>
      switch (op) {
        'modules.list' => 'Read the modules',
        'modules.get' => 'Read the module',
        'modules.testRun' => switch (result['status']) {
          'succeeded' => 'Test run finished',
          'skipped' => 'Test run skipped',
          'timed_out' => 'Test run timed out',
          _ => 'Test run failed',
        },
        'runs.list' => 'Read the runs',
        _ => 'Read the run',
      };

  static Map<String, Object?> _responseJson(HarnessResponse r) => switch (r) {
    HarnessOk(:final result) => result,
    HarnessFailure(:final error) => {'error': error.toJson()},
  };

  static const Map<String, Object?> _stoppedResponse = {
    'status': 'stopped',
    'reason': 'the user stopped this turn; nothing was run',
  };

  static LlmFunctionResponses _stoppedResponses(List<LlmCall> calls) =>
      LlmFunctionResponses([
        for (final c in calls)
          LlmFunctionResponse(
            name: c.name,
            response: _stoppedResponse,
            geminiId: c.geminiId,
          ),
      ]);

  // ------------------------------------------------------------- helpers

  bool _switchToFallback(_Turn t) {
    final fallback = _settings.fallbackModel;
    if (fallback == null || fallback == _model) return false;
    _emit(t, ModelSwitched(_model, fallback));
    _model = fallback;
    return true;
  }

  /// Folds the oldest turns into the summary once history passes the cap,
  /// keeping the current turn and the one before it.
  void _foldIfOverCap(int overheadTokens) {
    final prompt = _lastPromptTokens;
    if (prompt == null || !_compactor.overCap(prompt - overheadTokens)) return;
    final past = _turns.length - 1;
    if (past < 2) return;
    final folded = _turns.sublist(0, past - 1);
    _summary = _compactor.summarize(_summary, folded);
    _turns.removeRange(0, past - 1);
    _lastPromptTokens = null;
  }

  /// Rebuilds history as text only (every past turn into the summary), for
  /// a resumed thread whose thought signatures were lost.
  void _foldPastTurns() {
    final past = _turns.length - 1;
    if (past < 1) return;
    _summary = _compactor.summarize(_summary, _turns.sublist(0, past));
    _turns.removeRange(0, past);
    _lastPromptTokens = null;
  }

  int _estimateTokens(Iterable<LlmContent> contents) {
    var chars = 0;
    for (final c in contents) {
      chars += _llm.encodeContent(c).toString().length;
    }
    return chars ~/ 4;
  }

  /// Waits until [until] (cut short by Stop or "Retry now"), announcing it
  /// with [RetryWaiting] when [announce].
  Future<void> _wait(
    _Turn t,
    DateTime until,
    RetryReason reason, {
    bool announce = true,
  }) async {
    final delay = until.difference(_now());
    if (delay <= Duration.zero) return;
    if (announce) _emit(t, RetryWaiting(until, reason));
    final wake = Completer<void>();
    t.wake = wake;
    final timer = Timer(delay, () {
      if (!wake.isCompleted) wake.complete();
    });
    await wake.future;
    timer.cancel();
    t.wake = null;
    if (t.stopped) _end(t, const TurnStopped());
  }

  String _stepLabel(_Turn t, String? op, LlmCall call) {
    final args = call.args;
    final collection = switch (args['from']) {
      '@screen' => _collectionName(t.screen?.collectionId ?? ''),
      _ => _collectionName(_str(args['collection']) ?? ''),
    };
    final text = switch (op) {
      // A made-up tool name is the model's slip, not something to show.
      null => 'Choosing a step',
      'workspace.describe' => 'Reading the workspace',
      'collections.get' => 'Reading $collection',
      'cards.query' || 'cards.page' => 'Looking at $collection',
      'cards.get' => 'Opening $collection cards',
      'cards.find' => 'Searching for ${quoteName('${args['text'] ?? ''}')}',
      'cards.aggregate' => 'Calculating over $collection',
      'cards.distinct' => 'Listing values in $collection',
      'ui.open' => 'Opening $collection',
      'modules.list' || 'modules.get' => 'Reading modules',
      'modules.save' => 'Writing module',
      'modules.testRun' =>
        'Testing ${sanitizeName('${args['moduleId'] ?? ''}', max: 40)}',
      'automations.list' => 'Reading automations',
      'automations.save' => 'Setting up automation',
      'automations.delete' => 'Removing automation',
      'runs.list' || 'runs.get' => 'Reading runs',
      final id when t.tools!.opFor(call.name)?.kind == OpKind.plan =>
        collection.isEmpty
            ? 'Preparing changes ($id)'
            : 'Preparing changes to $collection',
      final id => 'Running $id',
    };
    return '$text…';
  }

  /// A model-sent arg as a string, or null when it is anything else (the
  /// harness reports the wrong type; labels must not throw first).
  static String? _str(Object? arg) => arg is String ? arg : null;

  /// A collection's name for labels: [ref] is an id or a name the model
  /// sent; sanitized either way.
  String _collectionName(String ref) {
    for (final c in _workspace.collections) {
      if (c.id == ref) return sanitizeName(c.name, max: 40);
    }
    return sanitizeName(ref, max: 40);
  }

  void _emit(_Turn t, AgentEvent event) {
    t.flush();
    if (!t.controller.isClosed) t.controller.add(event);
  }

  /// Reports [event] and unwinds the turn.
  Never _end(_Turn t, AgentEvent event) {
    _emit(t, event);
    throw const _TurnEnd();
  }
}

/// Unwinds a turn after its last event was reported.
final class _TurnEnd implements Exception {
  const _TurnEnd();
}

/// One model response, collected.
final class _Response {
  String text = '';
  final List<LlmCall> calls = [];
  LlmModelContent? content;
  int promptTokens = 0;
  int outputTokens = 0;
  FinishKind finish = FinishKind.stop;
  String? blocked;
}

/// The state of the running turn.
final class _Turn {
  _Turn({
    required this.turnId,
    required this.controller,
    required this.screen,
    required this.ctx,
    required this.record,
  });

  final String turnId;
  final StreamController<AgentEvent> controller;
  final ScreenContext? screen;
  final HarnessContext ctx;
  final HistoryTurn record;

  ToolSet? tools;
  TokenUsage usage = TokenUsage.zero;
  bool stopped = false;

  /// A plan of this turn was (at least partly) written.
  bool changed = false;

  /// Set once the user answered this turn's preview: one preview per turn,
  /// so the rounds after it may only answer in text (a rejected change must
  /// not come straight back as a new preview).
  bool answerOnly = false;

  /// Calls whose responses are not in the history yet.
  List<LlmCall>? pendingCalls;

  Completer<PlanOutcome>? gate;
  String? gatePlanId;
  Completer<void>? wake;
  Future<void> Function()? cancelStream;

  final StringBuffer _text = StringBuffer();
  Timer? _textTimer;

  void addText(String text) {
    if (text.isEmpty) return;
    _text.write(text);
    _textTimer ??= Timer(AgentLoop.textCoalesce, flush);
  }

  /// Sends the buffered text as one [TextDelta].
  void flush() {
    _textTimer?.cancel();
    _textTimer = null;
    if (_text.isEmpty) return;
    final text = _text.toString();
    _text.clear();
    if (!controller.isClosed) controller.add(TextDelta(text));
  }
}
