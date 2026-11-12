// The host half of a module run (design spec, Bridge rules): boots a fresh
// sandbox, answers its calls through the Harness under the host-set
// identity, enforces the caps, and seals the one plan of the run or
// discards it.
import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import '../domain/automation/automation.dart';
import '../domain/automation/codec.dart' show cutText;
import '../harness/api/capability.dart';
import '../harness/api/envelope.dart';
import '../harness/api/harness.dart';
import '../harness/api/harness_context.dart';
import '../harness/api/operation.dart';
import '../harness/cache/result_store.dart';
import '../harness/plan/plan.dart';
import '../harness/plan/plan_store.dart';
import 'engine/protocol.dart';
import 'engine/script_engine.dart';
import 'engine/sdk_core.dart';
import 'run_log_builder.dart';
import 'runner_api.dart' show RunProgress;

/// Op namespaces a module may never call: the runtime seals and applies.
const Set<String> kDeniedNamespaces = {
  'plans',
  'journal',
  'modules',
  'automations',
  'runs',
};

/// Reads queued in the bridge beyond [kMaxHeavyReadsInFlight].
const Set<String> kHeavyReads = {'cards.query', 'cards.aggregate'};

/// One message for "no such collection" and "not yours", so a module cannot
/// probe which collections exist.
const String kCollectionNotAvailable =
    'Collection not available to this module';

/// What one run hands the bridge. [context] is the action context the
/// runner built (cards already shaped, see `CardShaper`).
final class BridgeRequest {
  const BridgeRequest({
    required this.moduleId,
    required this.code,
    required this.actionId,
    required this.input,
    required this.context,
    required this.grants,
    required this.workspaceId,
    required this.today,
    this.timeZoneName = '',
    this.timeout = const Duration(seconds: 20),
    this.onProgress,
    this.log,
  });

  final String moduleId;

  /// The exact in-memory code whose hash the consent pinned.
  final String code;
  final String actionId;
  final Object? input;
  final Map<String, Object?> context;

  /// The effective grants (manifest ∩ grantable ∩ consent ∩ automation).
  final Grants grants;
  final String workspaceId;
  final DateTime today;
  final String timeZoneName;

  /// The manifest's `timeoutMs`, from invoke.
  final Duration timeout;

  /// Module progress, throttled to [kMaxProgressPerSecond].
  final void Function(RunProgress progress)? onProgress;

  /// The run's log, when the runner fills its own lines (`triggerEval`,
  /// `policy`) and builds it again after the outcome; else a new one.
  final RunLogBuilder? log;
}

/// How the run's script phase ended.
///
/// - [RunStatus.sealing]: [plan] is sealed (15-min TTL); the runner decides
///   auto or review.
/// - [RunStatus.succeeded]: nothing was planned ("No changes").
/// - [RunStatus.failed]: [reason] is `engine_unavailable` when the engine
///   could not start a sandbox (the runner skips), else a failure code;
///   nothing is left in the plan store.
/// - [RunStatus.timedOut]: the run timer fired.
final class BridgeOutcome {
  const BridgeOutcome._(
    this.status,
    this.log, {
    this.reason,
    this.error,
    this.plan,
    this.summary,
  });

  final RunStatus status;
  final RunReason? reason;
  final RunError? error;
  final Plan? plan;

  /// What the action returned as its summary (≤ 200 chars); "No changes"
  /// when it planned nothing and said nothing.
  final String? summary;

  /// Calls, console, plan rows and `ui.open` links (`log.ui`).
  final RunLog log;
}

/// Runs modules in sandboxes of [engine] against [harness].
final class ScriptBridge {
  ScriptBridge({
    required this.harness,
    required this.plans,
    required this.results,
    required this.engine,
    DateTime Function()? now,
    this.bootBudget = kBootBudget,
    this.drainBudget = const Duration(seconds: 2),
    this.sdkCore = kSdkCoreJs,
  }) : now = now ?? DateTime.now;

  final Harness harness;
  final PlanStore plans;
  final ResultStore results;
  final ScriptEngine engine;

  /// The runner's clock: contexts, log times and the harness-time cap.
  final DateTime Function() now;

  /// From start to `ready`.
  final Duration bootBudget;

  /// How long in-flight harness calls are awaited after the sandbox ends.
  final Duration drainBudget;
  final String sdkCore;

  /// Starts [request] in a fresh sandbox.
  BridgeRun start(BridgeRequest request) => BridgeRun._(this, request);
}

/// One running module action.
final class BridgeRun {
  BridgeRun._(this._bridge, this.request)
    : actor = Actor.plugin(request.moduleId),
      _log = request.log ?? RunLogBuilder(now: _bridge.now) {
    turnId = _bridge.harness.openTurn(actor);
    _kinds = {for (final d in _bridge.harness.descriptors) d.id: d.kind};
    unawaited(_run());
  }

  final ScriptBridge _bridge;
  final BridgeRequest request;
  final Actor actor;

  /// The run's own turn: its plan calls merge into one plan.
  late final String turnId;

  final RunLogBuilder _log;
  late final Map<String, OpKind> _kinds;
  final _outcome = Completer<BridgeOutcome>();

  ScriptSession? _session;
  StreamSubscription<ModuleMessage>? _messages;

  /// False once the sandbox ended: by a kill ([_end] says why) or the
  /// action's `done`.
  var _live = true;
  String? _end;

  /// Module call id → (op, args) awaiting an answer.
  final _pending = <int, (String, Map<String, Object?>?)>{};
  final _inFlight = <Future<void>>{};
  final _planFailures = <String, HarnessErrorJson>{};
  var _planned = 0;
  var _calls = 0;
  var _argsBytes = 0;
  var _harnessTime = Duration.zero;
  var _heavy = 0;
  final _heavyWaiting = Queue<Completer<void>>();
  final _frames = Queue<DateTime>();
  final _progress = Queue<DateTime>();

  Future<BridgeOutcome> get outcome => _outcome.future;

  /// The user's Stop: `failed: cancelled`. No-op once the action returned.
  void stop() => _kill('cancelled');

  Future<void> _run() async {
    BridgeOutcome outcome;
    try {
      outcome = await _execute();
    } catch (e, stack) {
      _kill('internal');
      await _discard();
      outcome = _failed(RunReason.internal, '$e', stack: '$stack');
    } finally {
      _bridge.harness.closeTurn(turnId);
      _bridge.results.dropThread('run:$turnId');
    }
    _outcome.complete(outcome);
  }

  Future<BridgeOutcome> _execute() async {
    final ScriptSession session;
    try {
      session = await _bridge.engine.start(
        ScriptLoad(
          moduleId: request.moduleId,
          code: request.code,
          sdkCore: _bridge.sdkCore,
          memoryLimitBytes: kScriptMemoryLimitBytes,
          budget: request.timeout,
        ),
      );
    } catch (e) {
      final failure = e is ScriptFailure ? e : null;
      return _failed(
        failure?.code == 'engine_unavailable'
            ? RunReason.engineUnavailable
            : RunReason.bootError,
        failure?.message ?? '$e',
      );
    }
    _session = session;
    if (_end case final reason?) session.kill(reason); // stopped while starting
    _messages = session.messages.listen(_onMessage);
    final boot = Timer(_bridge.bootBudget, () => _kill('load_timeout'));
    Timer? timer;
    try {
      final actions = await session.ready;
      boot.cancel();
      if (!actions.contains(request.actionId)) {
        _kill('load_error');
        await _discard();
        return _failed(
          RunReason.loadError,
          'The module does not register the action "${request.actionId}".',
        );
      }
      timer = Timer(request.timeout, () => _kill('timeout'));
      final value = await session.invoke(
        request.actionId,
        request.input,
        request.context,
      );
      timer.cancel();
      // A sandbox is never reused; calls the action did not await still
      // land in the turn before it is sealed.
      _live = false;
      session.kill('finished');
      if (!await _drain()) {
        await _discard();
        return _failed(
          RunReason.internal,
          'A call was still running when the action finished.',
        );
      }
      _log.returned(value);
      return await _seal();
    } on ScriptFailure catch (e) {
      _kill(e.code);
      await _discard();
      final reason = _end ?? e.code;
      if (reason == 'timeout') {
        return BridgeOutcome._(RunStatus.timedOut, _log.build());
      }
      return _failed(
        RunReason.fromWire(reason) ?? RunReason.internal,
        switch (reason) {
          'load_error' || 'boot_error' || 'module_error' => e.message,
          _ => _killMessage(reason),
        },
        stack: e.stack,
      );
    } finally {
      boot.cancel();
      timer?.cancel();
      unawaited(_messages?.cancel());
    }
  }

  // --- module messages ---------------------------------------------------

  void _onMessage(ModuleMessage message) {
    if (!_live) return;
    if (!_admit(_frames, kMaxFramesPerSecond)) return _kill('abuse');
    switch (message) {
      case LogFrame(:final level, :final args):
        _log.console(level, args);
      case ProgressFrame(:final done, :final total, :final label):
        if (!_admit(_progress, kMaxProgressPerSecond)) return;
        request.onProgress?.call(
          RunProgress(
            done: _count(done),
            total: _count(total),
            label: label == null
                ? null
                : cutText(label, kMaxProgressLabelChars),
          ),
        );
      case CallFrame(:final id, :final op, :final args):
        _call(id, op, args);
      case InvalidCallFrame(:final id?, :final reason):
        if (_overCallCap(id, '?', null)) return;
        _answer(id, '?', null, error: _error(ErrorCode.invalidArgs, reason));
      case InvalidCallFrame():
        break; // no id: nothing to answer
    }
  }

  /// Counts one event in [window] (a sliding second); false over [max].
  bool _admit(Queue<DateTime> window, int max) {
    final now = _bridge.now();
    while (window.isNotEmpty &&
        now.difference(window.first) >= const Duration(seconds: 1)) {
      window.removeFirst();
    }
    if (window.length >= max) return false;
    window.addLast(now);
    return true;
  }

  /// Counts a call; the one past [kMaxCallsPerRun] is refused and ends
  /// the run.
  bool _overCallCap(int id, String op, Map<String, Object?>? args) {
    if (++_calls <= kMaxCallsPerRun) return false;
    _answer(
      id,
      op,
      args,
      error: _error(
        ErrorCode.limitExceeded,
        'A run makes at most $kMaxCallsPerRun calls.',
      ),
    );
    _kill('limit_exceeded');
    return true;
  }

  void _call(int id, String op, Map<String, Object?>? args) {
    if (_overCallCap(id, op, args)) return;
    final bytes = args == null ? 0 : utf8.encode(jsonEncode(args)).length;
    _argsBytes += bytes;
    if (_argsBytes > kMaxRunArgsBytes) {
      _answer(
        id,
        op,
        args,
        error: _error(
          ErrorCode.limitExceeded,
          'A run sends at most 2 MB of call arguments.',
        ),
      );
      return _kill('limit_exceeded');
    }
    final refusal = switch (op) {
      _ when bytes > kMaxCallArgsBytes => _error(
        ErrorCode.limitExceeded,
        'The arguments of one call are at most 256 KB.',
      ),
      _ when _pending.length >= kMaxCallsInFlight => _error(
        ErrorCode.limitExceeded,
        'At most $kMaxCallsInFlight calls may wait for an answer at once.',
      ),
      _ when kDeniedNamespaces.contains(op.split('.').first) => _error(
        ErrorCode.notPermitted,
        'The runtime seals and applies the plan.',
      ),
      _ => null,
    };
    if (refusal != null) return _answer(id, op, args, error: refusal);
    _pending[id] = (op, args);
    late final Future<void> call;
    call = _harnessCall(
      id,
      op,
      args,
      'm.$_calls',
    ).whenComplete(() => _inFlight.remove(call));
    _inFlight.add(call);
  }

  Future<void> _harnessCall(
    int id,
    String op,
    Map<String, Object?>? args,
    String callId,
  ) async {
    final heavy = kHeavyReads.contains(op);
    if (heavy) await _heavySlot();
    try {
      if (!_pending.containsKey(id)) return; // killed while queued
      final started = _bridge.now();
      final response = await _bridge.harness.call(
        HarnessRequest(
          op: op,
          args: args ?? const {},
          callId: callId,
          turnId: turnId,
        ),
        _context(),
      );
      final took = _bridge.now().difference(started);
      _harnessTime += took;
      // Killed meanwhile: the module already got `dead`.
      if (_pending.remove(id) == null) return;
      switch (response) {
        case HarnessOk(:final result):
          if (_kinds[op] == OpKind.plan) _planned++;
          _answer(id, op, args, result: result, ms: took.inMilliseconds);
        case HarnessFailure(:final error):
          _answer(
            id,
            op,
            args,
            error: _rewrite(error),
            logged: error.code == ErrorCode.internal ? error.toJson() : null,
            ms: took.inMilliseconds,
          );
      }
      if (_harnessTime > kMaxHarnessTimePerRun) _kill('limit_exceeded');
    } finally {
      if (heavy) _releaseHeavy();
    }
  }

  /// Every answer goes through here: a failed plan-kind call (but
  /// `no_change`) is recorded, whether the harness or the bridge refused
  /// it, and fails the run at seal time.
  void _answer(
    int id,
    String op,
    Map<String, Object?>? args, {
    Map<String, Object?>? result,
    HarnessErrorJson? error,
    HarnessErrorJson? logged,
    int ms = 0,
  }) {
    final kind = _kinds[op];
    if (error != null &&
        kind == OpKind.plan &&
        error['code'] != ErrorCode.noChange.wire) {
      _planFailures['$op#$id'] = error;
    }
    _log.call(
      op: op,
      kind: kind?.name ?? 'unknown',
      args: args,
      result: result,
      error: logged ?? error,
      ms: ms,
    );
    _session?.reply(id, value: result, error: error);
  }

  HarnessContext _context() => HarnessContext(
    workspaceId: request.workspaceId,
    actor: actor,
    grants: request.grants,
    now: _bridge.now(),
    today: request.today,
    timeZoneName: request.timeZoneName,
    turnId: turnId,
  );

  Future<void> _heavySlot() async {
    if (_heavy < kMaxHeavyReadsInFlight) {
      _heavy++;
      return;
    }
    final turn = Completer<void>();
    _heavyWaiting.add(turn);
    await turn.future; // the slot is handed over, [_heavy] unchanged
  }

  void _releaseHeavy() =>
      _heavyWaiting.isEmpty ? _heavy-- : _heavyWaiting.removeFirst().complete();

  // --- ending ------------------------------------------------------------

  /// Ends the sandbox with [reason] (the first reason wins) and answers
  /// every pending call `dead`; their harness results are dropped.
  void _kill(String reason) {
    if (!_live) return;
    _live = false;
    _end = reason;
    _session?.kill(reason);
    final pending = [..._pending.entries];
    _pending.clear();
    for (final MapEntry(key: id, value: (op, args)) in pending) {
      _answer(
        id,
        op,
        args,
        error: {
          'code': 'dead',
          'message': 'The run ended.',
          'retryable': false,
        },
      );
    }
    while (_heavyWaiting.isNotEmpty) {
      _heavyWaiting.removeFirst().complete();
    }
  }

  /// Waits for the in-flight harness calls, at most [drainBudget]; false
  /// when some are still running.
  Future<bool> _drain() async {
    final deadline = _bridge.now().add(_bridge.drainBudget);
    while (_inFlight.isNotEmpty) {
      final left = deadline.difference(_bridge.now());
      if (left <= Duration.zero) return false;
      try {
        await Future.wait([..._inFlight]).timeout(left);
      } on TimeoutException {
        return false;
      }
    }
    return true;
  }

  /// Bridge rule 8: close the turn first (no new plan call passes the turn
  /// check), wait for calls already past it, then drop the overlay they
  /// may have re-created; again when stragglers finish.
  Future<void> _discard() async {
    _bridge.harness.closeTurn(turnId);
    final drained = await _drain();
    _bridge.plans.discard(actor, turnId);
    if (!drained) {
      Future.wait([
        ..._inFlight,
      ]).whenComplete(() => _bridge.plans.discard(actor, turnId)).ignore();
    }
  }

  /// Bridge rule 7, after `done ok` with every call answered.
  Future<BridgeOutcome> _seal() async {
    if (_planFailures.isNotEmpty) {
      _bridge.plans.discard(actor, turnId);
      final MapEntry(:key, :value) = _planFailures.entries.first;
      final more = _planFailures.length - 1;
      return _failed(
        RunReason.planRefused,
        '${key.split('#').first} was refused: ${value['code']} — '
        '${value['message']}${more > 0 ? ' (and $more more)' : ''}',
      );
    }
    if (_planned == 0) {
      _bridge.plans.discard(actor, turnId);
      return BridgeOutcome._(
        RunStatus.succeeded,
        _log.build(),
        summary: _log.summary ?? 'No changes',
      );
    }
    final sealed = await _bridge.harness.call(
      HarnessRequest(
        op: 'plans.seal',
        args: {'turnId': turnId},
        callId: 'm.seal',
        turnId: turnId,
      ),
      _context(),
    );
    _bridge.plans.discard(actor, turnId);
    switch (sealed) {
      case HarnessFailure(:final error):
        return _failed(
          error.code == ErrorCode.limitExceeded
              ? RunReason.limitExceeded
              : RunReason.planRefused,
          error.message,
        );
      case HarnessOk(:final result) when result['errors'] != null:
        return _failed(
          RunReason.planRefused,
          'The planned changes were refused.',
        );
      case HarnessOk(:final result):
        final plan = _bridge.plans.get('${result['planId']}');
        if (plan == null) {
          return _failed(RunReason.internal, 'The sealed plan is missing.');
        }
        _log.plan(plan);
        return BridgeOutcome._(
          RunStatus.sealing,
          _log.build(),
          plan: plan,
          summary: _log.summary,
        );
    }
  }

  BridgeOutcome _failed(RunReason reason, String message, {String? stack}) =>
      BridgeOutcome._(
        RunStatus.failed,
        _log.build(),
        reason: reason,
        error: RunError(code: reason.wire, message: message, stack: stack),
        summary: _log.summary,
      );

  // JSON can carry 1e999 (Infinity) through decodeFrame.
  static int _count(num n) => n.isFinite && n > 0 ? n.toInt() : 0;

  static String _killMessage(String reason) => switch (reason) {
    'cancelled' => 'Stopped by you.',
    'abuse' => 'The module broke the runtime protocol or its limits.',
    'limit_exceeded' => 'The run went over a limit (calls, arguments or time).',
    'load_timeout' => 'The module did not start within 5 s.',
    _ => 'The run ended ($reason).',
  };

  static HarnessErrorJson _error(ErrorCode code, String message) => {
    'code': code.wire,
    'message': message,
    'retryable': false,
  };

  /// Bridge rule 4: collection refusals become one message, whatever the
  /// code, so `unknown` and `not yours` look the same; `internal` text stays
  /// in the run log.
  static HarnessErrorJson _rewrite(HarnessError e) {
    if (e.code == ErrorCode.internal) {
      return _error(ErrorCode.internal, 'Internal error');
    }
    if (_hidesCollection(e.code, e.path)) return _notAvailable(e.path);
    final json = e.toJson();
    if (e.details case final details?) {
      json['details'] = [
        for (final d in details)
          _hidesCollection(d.code, d.path) ? _notAvailable(d.path) : d.toJson(),
      ];
    }
    return json;
  }

  // A collection-ref refusal carries the ref's path; the capability check
  // carries none and the turn check `turnId`.
  static bool _hidesCollection(ErrorCode code, String? path) =>
      code == ErrorCode.unknownCollection ||
      code == ErrorCode.notPermitted && path != null && path != 'turnId';

  static HarnessErrorJson _notAvailable(String? path) => {
    ..._error(ErrorCode.notPermitted, kCollectionNotAvailable),
    'path': ?path,
  };
}
