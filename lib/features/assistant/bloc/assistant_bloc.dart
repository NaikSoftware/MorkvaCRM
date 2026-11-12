import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../api/assistant/assistant_config.dart';
import '../../../api/assistant/assistant_config_repository.dart';
import '../../../api/assistant/message_size_guard.dart';
import '../../../api/assistant/thread_repository.dart';
import '../../../api/data/data_repository.dart' show WriteKind, WriteOrigin;
import '../../../core/agent/agent_event.dart';
import '../../../core/agent/agent_loop.dart';
import '../../../core/agent/history_compactor.dart';
import '../../../core/agent/llm_client.dart';
import '../../../core/harness/harness.dart';
import '../host/result_reader.dart';
import 'assistant_focus.dart';
import 'assistant_state.dart';
import 'chat_item.dart';
import 'chat_item_codec.dart';

part 'assistant_event.dart';

/// The Ask Morkva chat: runs user turns through the [AgentLoop], renders its
/// events as [ChatItem]s, and is the **only** code that builds a user-actor
/// `HarnessContext`: approve, reject, retry-failed, undo and journal restore
/// all go through the harness's commit ops here, and the outcome is handed
/// back to the loop with `deliverOutcome`.
///
/// Events are handled one at a time, in order (a streaming turn, a decision
/// arriving mid-turn and Stop must not interleave); commit progress is
/// emitted from inside the approve handler while it awaits the commit.
///
/// Persistence: one turn doc per user turn, checkpointed at the plan
/// proposal (`pending`), when it is approved (`committing`), once the
/// receipt is the plan calls' response (`committed`, with the journal
/// mirror) and at the turn's end (`done`). Restoring a thread
/// maps in-flight states to settled ones (see `chat_item_codec.dart`),
/// re-validates undo journals through `journal.restore`, drops the plan
/// gate's unanswered calls and replays the last [replayTurns] turns.
class AssistantBloc extends Bloc<AssistantEvent, AssistantState> {
  AssistantBloc({
    required AgentLoop agentLoop,
    required Harness harness,
    required ThreadRepository threads,
    required AssistantConfigRepository config,
    required LlmClient llm,
    required ResultReader results,
    List<String> Function()? collectionNames,
    Stream<bool>? online,
    bool initiallyOnline = true,
    void Function(AssistantConfig config)? onConfig,
    Stream<String>? runsStarted,
    DateTime Function()? now,
  }) : _loop = agentLoop,
       _harness = harness,
       _threads = threads,
       _configRepo = config,
       _llm = llm,
       _results = results,
       _collectionNames = collectionNames ?? (() => const []),
       _onConfig = onConfig,
       _now = now ?? DateTime.now,
       _online = initiallyOnline,
       super(const AssistantState()) {
    on<AssistantEvent>(
      _handle,
      transformer: (events, mapper) {
        return events.asyncExpand(mapper);
      },
    );
    _onlineSub = online?.distinct().listen((o) => add(_SyncChanged(o)));
    _runsSub = runsStarted?.listen((commitId) => add(_RunStarted(commitId)));
  }

  /// Turns of a restored thread replayed into the model.
  static const int replayTurns = 6;

  /// A thread's title: the first sentence of its first message, at most
  /// this many characters.
  static const int titleLength = 40;

  final AgentLoop _loop;
  final Harness _harness;
  final ThreadRepository _threads;
  final AssistantConfigRepository _configRepo;
  final LlmClient _llm;
  final ResultReader _results;
  final List<String> Function() _collectionNames;
  final void Function(AssistantConfig config)? _onConfig;
  final DateTime Function() _now;

  StreamSubscription<bool>? _onlineSub;
  StreamSubscription<String>? _runsSub;
  StreamSubscription<AssistantConfig>? _configSub;

  String? _workspaceId;
  String? _uid;
  AssistantConfig? _config;
  bool _online;
  bool _consentGranted = false;
  bool _notSetUp = false;
  String? _unavailable;
  DateTime? _quotaUntil;

  /// The latest published focus, and whether the user removed the chip.
  AssistantFocus? _focus;
  bool _focusCleared = false;

  /// The running turn, until its agent stream closes.
  _Turn? _turn;
  String? _queuedPrompt;
  _Switch? _pendingSwitch;

  // Per thread.
  int _nextSeq = 0;

  /// The open thread was read from the local cache only, so it may miss
  /// turns (and [_nextSeq] would overwrite them).
  bool _fromCache = false;
  DateTime? _threadCreatedAt;
  final Map<int, _Doc> _docs = {};
  final Map<String, int> _seqOf = {};

  /// Journals committed in this session and not undone: their undo works
  /// without a mirror (until the window closes).
  final Set<String> _liveJournals = {};

  /// Journal mirrors of threads left before their undo window closed, by
  /// (thread, seq): dropped when the window closes.
  final Map<(String, int), DateTime> _mirrorsLeft = {};
  int _hostCalls = 0;
  Timer? _tick;

  /// Ends the session: back to Idle with no thread (sign-out, a workspace
  /// switch). [AssistantStarted] starts it again.
  void reset() {
    // At once: a handler still running (a commit awaiting its ack) must not
    // write once the repositories are re-bound to the next member.
    _uid = null;
    _workspaceId = null;
    add(const _SessionReset());
  }

  // ---------------------------------------------------------------------------

  Future<void> _handle(AssistantEvent event, Emitter<AssistantState> emit) =>
      switch (event) {
        AssistantStarted() => _onStarted(event, emit),
        PromptSubmitted(:final text) ||
        SuggestionTapped(:final text) => _onPrompt(text, emit),
        StopRequested() => _onStop(emit),
        PlanSelectionChanged() => _sync(() => _onSelection(event, emit)),
        PlanApproved(:final planId) => _onApprove(planId, emit),
        PlanRejected(:final planId) => _onReject(planId, emit),
        UndoRequested(:final journalId) => _onUndo(journalId, emit),
        RetryFailedRequested(:final planId) => _onRetryFailed(planId, emit),
        RetryRequested() => _onRetry(emit),
        RetryNowRequested() => _sync(() {
          _loop.retryNow();
          emit(state.copyWith(clearBanner: true));
        }),
        FocusChanged(:final focus) => _sync(() => _onFocus(focus, emit)),
        FocusCleared() => _sync(() {
          _focusCleared = true;
          emit(state.copyWith(clearFocus: true));
        }),
        ThreadSelected(:final threadId) => _requestSwitch(
          _Switch.open(threadId),
          emit,
        ),
        NewThreadRequested() => _requestSwitch(const _Switch.fresh(), emit),
        ThreadDeleted(:final threadId) => _onDelete(threadId, emit),
        ConsentGranted() => _sync(() => _onConsent(emit)),
        _AgentEventReceived(:final turn, :final event) => _onAgent(
          turn,
          event,
          emit,
        ),
        _TurnClosed(:final turn) => _onTurnClosed(turn, emit),
        _ConfigChanged(:final config) => _sync(
          () => _onConfigChanged(config, emit),
        ),
        _SyncChanged(:final online) => _sync(() {
          _online = online;
          if (online) _clearOfflineNotes(emit);
          _emitAvailability(emit);
        }),
        _UndoTick() => _sync(() => _onTick(emit)),
        _SaveFailed() => _sync(() => emit(state.copyWith(saveFailed: true))),
        _RunStarted(:final commitId) => _sync(
          () => _onRunStarted(commitId, emit),
        ),
        _SessionReset() => _sync(() => _onReset(emit)),
      };

  static Future<void> _sync(void Function() body) {
    body();
    return Future.value();
  }

  // ------------------------------------------------------------- lifecycle

  Future<void> _onStarted(
    AssistantStarted e,
    Emitter<AssistantState> emit,
  ) async {
    _workspaceId = e.workspaceId;
    _uid = e.uid;
    _clearThread();
    if (!_loop.busy) _loop.resetThread();
    await _configSub?.cancel();
    _configSub = _configRepo.watch().listen((c) => add(_ConfigChanged(c)));
    emit(
      AssistantState(
        availability: _availability(),
        focus: _focusCleared ? null : _focus,
        userFirstName: e.userFirstName,
        collectionNames: _collectionNames(),
      ),
    );
  }

  void _onReset(Emitter<AssistantState> emit) {
    unawaited(_configSub?.cancel());
    _configSub = null;
    _workspaceId = null;
    _uid = null;
    _config = null;
    _consentGranted = false;
    _notSetUp = false;
    _unavailable = null;
    _quotaUntil = null;
    _queuedPrompt = null;
    _pendingSwitch = null;
    if (_turn case final turn?) {
      turn.dead = true;
      _turn = null;
      _loop.stop();
    } else if (!_loop.busy) {
      _loop.resetThread();
    }
    _clearThread();
    _liveJournals.clear();
    _mirrorsLeft.clear();
    emit(AssistantState(focus: _focusCleared ? null : _focus));
  }

  void _onConfigChanged(AssistantConfig config, Emitter<AssistantState> emit) {
    _config = config;
    if (config.consented) _consentGranted = false;
    _loop.settings = AgentSettings(
      model: config.model,
      fallbackModel: config.fallbackModel,
      maxRounds: config.maxRounds,
      thinking: LlmThinking.values.byName(config.thinking.name),
      rpm: config.rpm,
      tpm: config.tpm,
    );
    _onConfig?.call(config);
    _emitAvailability(emit, names: true);
  }

  void _onConsent(Emitter<AssistantState> emit) {
    if (_uid == null || (_config?.consented ?? false)) return;
    _consentGranted = true;
    _emitAvailability(emit);
    _configRepo.grantConsent().then<void>(
      (_) {},
      onError: (Object error) {
        _log('Saving the consent failed', error);
        add(const _SaveFailed());
      },
    );
  }

  void _onFocus(AssistantFocus? focus, Emitter<AssistantState> emit) {
    if (focus != _focus) _focusCleared = false;
    _focus = focus;
    final shown = _focusCleared ? null : focus;
    emit(
      state.copyWith(
        focus: shown,
        clearFocus: shown == null,
        collectionNames: _collectionNames(),
      ),
    );
  }

  Availability _availability() {
    final config = _config;
    if (config == null) return const AvailabilityChecking();
    if (!config.enabled) return const AvailabilityDisabledByFlag();
    if (_notSetUp) return const AvailabilityNotSetUp();
    if (_unavailable case final message?) {
      return AvailabilityUnavailable(message);
    }
    if (!config.consented && !_consentGranted) {
      return AvailabilityNeedsConsent(
        freeTier: config.dataUse == AssistantDataUse.free,
      );
    }
    if (!_online) return const AvailabilityOffline();
    if (_quotaUntil case final until? when _now().isBefore(until)) {
      return AvailabilityQuotaExhausted(until);
    }
    return const AvailabilityEnabled();
  }

  void _emitAvailability(Emitter<AssistantState> emit, {bool names = false}) {
    emit(
      state.copyWith(
        availability: _availability(),
        collectionNames: names ? _collectionNames() : null,
      ),
    );
    _scheduleTick();
  }

  // ------------------------------------------------------------------ turns

  Future<void> _onPrompt(String raw, Emitter<AssistantState> emit) async {
    final text = raw.trim();
    if (text.isEmpty || _uid == null) return;
    if (state.phase case AwaitingApprovalPhase(:final planId)) {
      // The new message skips the plan; it starts once the turn has ended.
      _queuedPrompt = text;
      await _skip(planId, emit);
      return;
    }
    if (state.phase.active || !state.availability.canSend) return;
    if (_turn != null || _loop.busy) {
      // The last turn's stream is still closing.
      _queuedPrompt = text;
      return;
    }
    if (_fromCache && state.threadId != null) {
      // Its next seq is only known from a server read.
      await _load(state.threadId!, emit);
      if (_uid == null) return; // signed out during the re-read
      if (_fromCache || state.threadId == null) {
        if (state.threadId != null) {
          emit(
            state.copyWith(
              items: [
                ...state.items,
                const ErrorItem(
                  id: 'load',
                  kind: ChatErrorKind.connection,
                  message:
                      'Couldn’t load this whole conversation, so the '
                      'message wasn’t sent. Try again in a moment.',
                  retryable: false,
                ),
              ],
            ),
          );
        }
        return;
      }
    }
    _startTurn(text, emit);
  }

  void _startTurn(String text, Emitter<AssistantState> emit) {
    final isNew = state.threadId == null;
    final threadId = state.threadId ?? _threads.newThreadId();
    if (isNew) _threadCreatedAt = _now();
    final turn = _Turn(threadId: threadId, seq: _nextSeq++, text: text);
    _docs[turn.seq] = _Doc(createdAt: _now());
    final user = UserItem(id: turn.mint(), text: text);
    _seqOf[user.id] = turn.seq;
    _turn = turn;
    final screen = _screen();
    emit(
      state.copyWith(
        threadId: threadId,
        threadTitle: isNew ? _title(text) : null,
        items: [...state.items, user],
        phase: const ThinkingPhase(),
        clearBanner: true,
        saveFailed: isNew ? false : null,
      ),
    );
    turn.sub = _loop
        .run(text, screen: screen)
        .listen(
          (event) => add(_AgentEventReceived(turn, event)),
          onDone: () => add(_TurnClosed(turn)),
        );
  }

  /// The turn's screen snapshot; null when the chip was removed.
  ScreenContext? _screen() {
    final focus = _focusCleared ? null : state.focus;
    if (focus == null) return null;
    try {
      return ScreenContext.fromJson(focus.toScreenContextJson());
    } on FormatException {
      return null;
    }
  }

  Future<void> _onAgent(
    _Turn turn,
    AgentEvent event,
    Emitter<AssistantState> emit,
  ) async {
    if (turn.dead || !identical(turn, _turn)) return;
    switch (event) {
      case TurnStarted() || ModelSwitched():
        break;
      case RoundStarted():
        if (!state.phase.active || state.phase is RunningToolsPhase) {
          emit(state.copyWith(phase: const ThinkingPhase()));
        }
      case TextDelta(:final text):
        _onText(turn, text, emit);
      case TextCutShort():
        _closeText(turn, emit, cutShort: true);
      case StepStarted(:final callId, :final label):
        _onStepStarted(turn, callId, label, emit);
      case StepFinished():
        _onStepFinished(turn, event, emit);
      case ResultPresented():
        await _onResult(turn, event, emit);
      case TestRunShown(:final title, :final result):
        _closeText(turn, emit);
        try {
          final run = testRunResultFromJson(result);
          _append(
            turn,
            TestRunItem(id: turn.mint(), title: title, result: run),
            emit,
          );
        } on FormatException catch (error) {
          _log('Test-run result not shown', error);
        }
      case ObjectChipShown():
        _closeText(turn, emit);
        _append(
          turn,
          ObjectChipItem(
            id: turn.mint(),
            collectionId: event.collectionId,
            cardId: event.cardId,
            viewId: event.viewId,
            label: event.label,
          ),
          emit,
        );
      case PlanProposed(:final plan):
        await _onPlan(turn, plan, emit);
      case RetryWaiting(:final until, :final reason):
        emit(
          state.copyWith(
            banner: RetryBanner(until, reason),
            phase: const ThinkingPhase(),
          ),
        );
      case TurnFailed(:final failure, :final nothingChanged):
        _closeText(turn, emit);
        _onFailed(turn, failure, nothingChanged, emit);
        _endTurn(turn, emit);
      case TurnStopped():
        _closeText(turn, emit, stopped: true);
        emit(state.copyWith(phase: const IdlePhase()));
        _endTurn(turn, emit);
      case TurnDone(:final usage):
        _closeText(turn, emit);
        turn.usage = usage;
        emit(
          state.copyWith(phase: const IdlePhase(), usage: state.usage + usage),
        );
        _endTurn(turn, emit);
    }
  }

  void _onText(_Turn turn, String text, Emitter<AssistantState> emit) {
    if (turn.live case final live?) {
      live.value += text;
      if (state.phase is! StreamingPhase || state.banner != null) {
        emit(state.copyWith(phase: const StreamingPhase(), clearBanner: true));
      }
      return;
    }
    final live = ValueNotifier(text);
    final item = AssistantTextItem(
      id: turn.mint(),
      text: '',
      streaming: true,
      live: live,
    );
    turn
      ..live = live
      ..textItemId = item.id;
    _append(turn, item, emit, phase: const StreamingPhase());
  }

  /// Settles the streaming text item, if any.
  void _closeText(
    _Turn turn,
    Emitter<AssistantState> emit, {
    bool stopped = false,
    bool cutShort = false,
  }) {
    final id = turn.textItemId;
    final live = turn.live;
    turn
      ..textItemId = null
      ..live = null;
    if (id == null) return;
    final item = _find<AssistantTextItem>(id);
    if (item == null) return;
    final text = live?.value ?? item.text;
    if (text.trim().isEmpty && !stopped && !cutShort) {
      // Whitespace between calls: no empty bubble before the next card.
      _seqOf.remove(id);
      emit(state.copyWith(items: [...state.items.where((i) => i.id != id)]));
      return;
    }
    _replace(
      item.copyWith(
        text: text,
        streaming: false,
        stopped: stopped,
        cutShort: cutShort,
        clearLive: true,
      ),
      emit,
    );
  }

  void _onStepStarted(
    _Turn turn,
    String callId,
    String label,
    Emitter<AssistantState> emit,
  ) {
    _closeText(turn, emit);
    final step = StepView(callId: callId, label: label);
    final last = state.items.lastOrNull;
    if (last is StepsItem && last.id == turn.stepsItemId) {
      _replace(
        StepsItem(id: last.id, steps: [...last.steps, step]),
        emit,
        phase: RunningToolsPhase(label),
        clearBanner: true,
      );
    } else {
      final item = StepsItem(id: turn.mint(), steps: [step]);
      turn.stepsItemId = item.id;
      _append(turn, item, emit, phase: RunningToolsPhase(label));
    }
  }

  void _onStepFinished(
    _Turn turn,
    StepFinished e,
    Emitter<AssistantState> emit,
  ) {
    final handle = e.handle;
    // A read's line comes from its stored spec ("Looked at Orders · grouped
    // by Status"); the model's summary is the fallback.
    final summary = e.ok && handle != null
        ? _results.stepLine(handle, thread: turn.threadId) ?? e.summary
        : e.summary;
    for (final item in state.items.reversed) {
      if (item is! StepsItem) continue;
      final i = item.steps.indexWhere((s) => s.callId == e.callId);
      if (i < 0) continue;
      final steps = [...item.steps];
      steps[i] = steps[i].finish(ok: e.ok, summary: summary, code: e.errorCode);
      final running = steps.where((s) => s.status == StepStatus.running);
      _replace(
        StepsItem(id: item.id, steps: steps),
        emit,
        phase: state.phase is RunningToolsPhase
            ? (running.isEmpty
                  ? const ThinkingPhase()
                  : RunningToolsPhase(running.first.label))
            : null,
      );
      return;
    }
  }

  Future<void> _onResult(
    _Turn turn,
    ResultPresented e,
    Emitter<AssistantState> emit,
  ) async {
    _closeText(turn, emit);
    final spec = e.spec ?? _results.specOf(e.handle, thread: turn.threadId);
    final title =
        _results.titleOf(handle: e.handle, spec: spec, thread: turn.threadId) ??
        e.title;
    final ChatItem item = e.kind == PresentKind.table
        ? TableItem(
            id: turn.mint(),
            title: title,
            handle: e.handle,
            spec: spec,
            summary: e.summary,
          )
        : ChartItem(
            id: turn.mint(),
            title: title,
            kind: e.kind,
            handle: e.handle,
            spec: spec,
            summary: e.summary,
          );
    _append(turn, item, emit);
    await _materialize(item, turn.threadId, emit);
  }

  /// Fills a table or chart card's read-model from its handle (or spec).
  Future<void> _materialize(
    ChatItem item,
    String threadId,
    Emitter<AssistantState> emit,
  ) async {
    if (_uid == null) return;
    switch (item) {
      case TableItem(:final handle, :final spec):
        final table = await _results.table(
          handle: handle,
          spec: spec,
          ctx: _userContext(),
          thread: threadId,
        );
        final current = _find<TableItem>(item.id);
        if (table == null || current == null || emit.isDone) return;
        _replace(
          TableItem(
            id: current.id,
            title:
                _results.titleOf(
                  handle: handle,
                  spec: spec,
                  total: table.totalCount,
                  thread: threadId,
                ) ??
                current.title,
            handle: current.handle,
            spec: current.spec,
            summary: current.summary,
            table: table,
          ),
          emit,
        );
      case ChartItem(:final handle, :final spec):
        final chart = await _results.chart(
          handle: handle,
          spec: spec,
          ctx: _userContext(),
          thread: threadId,
        );
        final current = _find<ChartItem>(item.id);
        if (chart == null || current == null || emit.isDone) return;
        _replace(
          ChartItem(
            id: current.id,
            title:
                _results.titleOf(
                  handle: handle,
                  spec: spec,
                  thread: threadId,
                ) ??
                current.title,
            kind: current.kind,
            handle: current.handle,
            spec: current.spec,
            summary: current.summary,
            chart: chart,
          ),
          emit,
        );
      default:
        break;
    }
  }

  Future<void> _onPlan(
    _Turn turn,
    CompactPlan compact,
    Emitter<AssistantState> emit,
  ) async {
    _closeText(turn, emit);
    var plan = _planView(compact.json);
    final full = await _host('plans.get', {'planId': compact.planId});
    if (full case HarnessOk(:final result)) plan = _planView(result) ?? plan;
    if (plan == null) {
      // A plan the card cannot show is never approvable.
      await _host('plans.reject', {'planId': compact.planId});
      _loop.deliverOutcome(
        compact.planId,
        const Rejection(RejectReason.skipped),
      );
      return;
    }
    final item = PlanItem.proposed(id: turn.mint(), plan: plan);
    turn
      ..planId = plan.planId
      ..planItemId = item.id;
    _seqOf[item.id] = turn.seq;
    // Checkpoint before the card shows: a reload now restores it expired.
    _save(turn.seq, status: 'pending', items: [...state.items, item]);
    _append(
      turn,
      item,
      emit,
      phase: AwaitingApprovalPhase(plan.planId),
      clearBanner: true,
    );
  }

  static PlanView? _planView(Map<String, Object?> json) {
    try {
      return PlanView.fromJson(json);
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  void _onFailed(
    _Turn turn,
    LlmFailure failure,
    bool nothingChanged,
    Emitter<AssistantState> emit,
  ) {
    final after = nothingChanged
        ? ' Nothing was changed.'
        : ' The changes you approved were applied.';
    void error(ChatErrorKind kind, String message, {bool retryable = true}) {
      _append(
        turn,
        ErrorItem(
          id: turn.mint(),
          kind: kind,
          message: '$message$after',
          nothingChanged: nothingChanged,
          retryable: retryable,
        ),
        emit,
        phase: FailedPhase(kind, '$message$after', retryable: retryable),
        clearBanner: true,
      );
    }

    switch (failure) {
      case LlmNotSetUp():
        _notSetUp = true;
        emit(state.copyWith(phase: const IdlePhase(), clearBanner: true));
        _emitAvailability(emit);
      case LlmUnavailable(:final message):
        _unavailable = message;
        emit(state.copyWith(phase: const IdlePhase(), clearBanner: true));
        _emitAvailability(emit);
      case LlmBlockedFailure():
        _append(
          turn,
          AssistantTextItem(
            id: turn.mint(),
            text: 'I can\'t help with that request.',
          ),
          emit,
          phase: const IdlePhase(),
          clearBanner: true,
        );
      case LlmDailyQuota():
        _quotaUntil = nextPacificMidnight(_now());
        error(
          ChatErrorKind.dailyQuota,
          'Today\'s AI limit is used up.',
          retryable: false,
        );
        _emitAvailability(emit);
      case LlmRateLimited():
        error(ChatErrorKind.rateLimited, 'Gemini is busy right now.');
      case LlmTransient():
        error(
          ChatErrorKind.connection,
          'I couldn\'t finish — the connection dropped.',
        );
      case LlmStopped() || LlmMissingSignature() || LlmUnknownFailure():
        _log('A turn failed: ${failure.message}');
        error(
          ChatErrorKind.unknown,
          'Something went wrong and I couldn\'t '
          'finish.',
        );
    }
  }

  /// The turn's last event: write its doc for the last time.
  void _endTurn(_Turn turn, Emitter<AssistantState> emit) {
    turn.ended = true;
    _save(turn.seq, status: 'done');
    emit(
      state.copyWith(clearBanner: true, collectionNames: _collectionNames()),
    );
  }

  Future<void> _onTurnClosed(_Turn turn, Emitter<AssistantState> emit) async {
    if (turn.dead) {
      if (!_loop.busy && _turn == null) _loop.resetThread();
    } else if (identical(turn, _turn)) {
      _turn = null;
      if (state.phase.active || state.phase is AwaitingApprovalPhase) {
        emit(state.copyWith(phase: const IdlePhase()));
      }
    } else {
      return;
    }
    if (_turn != null || _loop.busy) return;
    if (_pendingSwitch case final target?) {
      _pendingSwitch = null;
      _queuedPrompt = null;
      await _switchTo(target, emit);
    } else if (_queuedPrompt case final text?) {
      _queuedPrompt = null;
      if (state.availability.canSend && _uid != null) _startTurn(text, emit);
    }
  }

  Future<void> _onStop(Emitter<AssistantState> emit) async {
    _queuedPrompt = null;
    switch (state.phase) {
      case ApplyingPhase():
        return; // A commit cannot be taken back mid-way.
      case AwaitingApprovalPhase(:final planId):
        // Same as Reject; the loop ends the gate as stopped.
        await _host('plans.reject', {'planId': planId, 'reason': 'user'});
        _setPlan(planId, PlanStatus.rejected, emit);
        _loop.stop();
      default:
        if (_turn != null) _loop.stop();
    }
  }

  // ------------------------------------------------------------------ plans

  void _onSelection(PlanSelectionChanged e, Emitter<AssistantState> emit) {
    final item = _planItem(e.planId);
    if (item == null || item.status != PlanStatus.pending) return;
    final valid = {for (final r in item.plan.rows) r.itemId};
    _replace(
      item.copyWith(selected: e.itemIds.where(valid.contains).toSet()),
      emit,
    );
  }

  Future<void> _onApprove(String planId, Emitter<AssistantState> emit) async {
    final turn = _turn;
    final item = _planItem(planId);
    if (turn == null ||
        turn.planId != planId ||
        item == null ||
        item.status != PlanStatus.pending ||
        item.selected.isEmpty) {
      return;
    }
    if (!_online) {
      _replace(item.copyWith(message: _needsConnection), emit);
      return;
    }
    final selected = [...item.selected];
    _replace(
      item.copyWith(status: PlanStatus.committing, clearMessage: true),
      emit,
      phase: ApplyingPhase(0, selected.length),
    );
    // A reload mid-commit restores "may have been partly applied", not
    // "Rebuild": chunks acked before it stay written.
    _save(turn.seq, status: 'committing');
    final sink = _EventSink((event) {
      if (event is ProgressEvent && !emit.isDone) {
        emit(state.copyWith(phase: ApplyingPhase(event.done, event.total)));
      }
    });
    final response = await _host('plans.commit', {
      'planId': planId,
      'itemIds': selected,
    }, events: sink);
    final current = _planItem(planId) ?? item;

    Receipt? receipt;
    String? failure;
    var expired = false;
    switch (response) {
      case HarnessOk(:final result):
        try {
          receipt = Receipt.fromJson(result);
        } on FormatException catch (e) {
          failure = 'Couldn’t read the result (${e.message})';
        }
        turn.journal = (result['journal'] as Map?)?.cast<String, Object?>();
      case HarnessFailure(:final error):
        expired = error.code == ErrorCode.planExpired;
        failure = error.code == ErrorCode.offline
            ? _needsConnection
            : error.message;
    }

    if (receipt == null) {
      _replace(
        current.copyWith(
          status: expired ? PlanStatus.expired : PlanStatus.failed,
          message: failure,
        ),
        emit,
        phase: const ThinkingPhase(),
      );
      _save(turn.seq);
      // Nothing was written: the turn ends without a follow-up.
      _loop.deliverOutcome(planId, const Rejection(RejectReason.skipped));
      return;
    }

    final wrote = receipt.applied.isNotEmpty || receipt.queued.isNotEmpty;
    final status = wrote
        ? PlanStatus.applied
        : receipt.failed.isEmpty && receipt.stale.isNotEmpty
        ? PlanStatus.stale
        : PlanStatus.failed;
    final items = [...state.items];
    final index = items.indexWhere((i) => i.id == current.id);
    final message = switch (status) {
      PlanStatus.failed => receipt.failed.firstOrNull?.message,
      _ => null,
    };
    items[index] = current.copyWith(
      status: status,
      message: message,
      clearMessage: message == null,
    );
    if (wrote) {
      final journalId = receipt.journalId;
      if (journalId != null) _liveJournals.add(journalId);
      _docs[turn.seq]?.journal = turn.journal;
      final applied = AppliedItem(
        id: turn.mint(),
        plan: current.plan,
        receipt: receipt,
        undoUntil: receipt.undoUntil,
        undoSessionOnly: journalId != null && turn.journal == null,
      );
      _seqOf[applied.id] = turn.seq;
      items.insert(index + 1, applied);
    }
    emit(state.copyWith(items: items, phase: const ThinkingPhase()));
    _scheduleTick();
    _loop.deliverOutcome(planId, receipt);
    // The loop appends the receipt as the plan calls' responses a few
    // microtasks later. Saving after that (and before the model's reply)
    // keeps the change in the replayed history after a reload.
    await Future<void>.delayed(Duration.zero);
    _save(turn.seq, status: wrote ? 'committed' : null, emit: emit);
  }

  Future<void> _onReject(String planId, Emitter<AssistantState> emit) async {
    final turn = _turn;
    final item = _planItem(planId);
    if (turn?.planId != planId || item?.status != PlanStatus.pending) return;
    await _host('plans.reject', {'planId': planId, 'reason': 'user'});
    _setPlan(planId, PlanStatus.rejected, emit, phase: const ThinkingPhase());
    _loop.deliverOutcome(planId, const Rejection(RejectReason.user));
  }

  /// A new message or a thread switch skips the pending plan [planId].
  Future<void> _skip(String planId, Emitter<AssistantState> emit) async {
    await _host('plans.reject', {'planId': planId, 'reason': 'skipped'});
    _setPlan(planId, PlanStatus.skipped, emit, phase: const ThinkingPhase());
    _loop.deliverOutcome(planId, const Rejection(RejectReason.skipped));
  }

  void _setPlan(
    String planId,
    PlanStatus status,
    Emitter<AssistantState> emit, {
    TurnPhase? phase,
  }) {
    final item = _planItem(planId);
    if (item == null) return;
    _replace(item.copyWith(status: status), emit, phase: phase);
  }

  PlanItem? _planItem(String planId) {
    for (final item in state.items.reversed) {
      if (item is PlanItem && item.plan.planId == planId) return item;
    }
    return null;
  }

  Future<void> _onRetryFailed(
    String planId,
    Emitter<AssistantState> emit,
  ) async {
    final applied = _appliedWhere((a) => a.receipt.planId == planId);
    if (applied == null || applied.receipt.failed.isEmpty || !_online) return;
    final idle = _turn == null && !state.phase.active;
    if (idle) {
      emit(
        state.copyWith(phase: ApplyingPhase(0, applied.receipt.failed.length)),
      );
    }
    final sink = _EventSink((event) {
      if (idle && event is ProgressEvent && !emit.isDone) {
        emit(state.copyWith(phase: ApplyingPhase(event.done, event.total)));
      }
    });
    final response = await _host('plans.retryFailed', {
      'planId': planId,
    }, events: sink);
    final current = _find<AppliedItem>(applied.id) ?? applied;
    var next = current;
    switch (response) {
      case HarnessOk(:final result):
        try {
          final receipt = Receipt.fromJson(result);
          final mirror = (result['journal'] as Map?)?.cast<String, Object?>();
          if (receipt.journalId case final id?) _liveJournals.add(id);
          final seq = _seqOf[current.id];
          if (seq != null && mirror != null) _docs[seq]?.journal = mirror;
          next = _withUndo(
            current,
            receipt: receipt,
            undoUntil: receipt.undoUntil ?? current.undoUntil,
            undoState: receipt.journalId == null
                ? current.undoState
                : UndoState.available,
          );
        } on FormatException catch (e) {
          next = current.copyWith(undoNote: 'Couldn’t retry (${e.message})');
        }
      case HarnessFailure(:final error):
        next = current.copyWith(
          undoNote: error.code == ErrorCode.offline
              ? _needsConnection
              : error.message,
        );
    }
    _replace(next, emit, phase: idle ? const IdlePhase() : null);
    if (_seqOf[next.id] case final seq?) _save(seq, emit: emit);
    _scheduleTick();
  }

  /// "Try again" / "Rebuild": sends the last user message again.
  Future<void> _onRetry(Emitter<AssistantState> emit) async {
    final last = state.items.whereType<UserItem>().lastOrNull;
    if (last != null) await _onPrompt(last.text, emit);
  }

  // ------------------------------------------------------------------- undo

  Future<void> _onUndo(String journalId, Emitter<AssistantState> emit) async {
    final applied = _appliedWhere(
      (a) =>
          a.receipt.journalId == journalId &&
          a.undoState == UndoState.available,
    );
    if (applied == null) return;
    if (!_online) {
      _replace(applied.copyWith(undoNote: _needsConnectionToUndo), emit);
      return;
    }
    _replace(
      applied.copyWith(undoState: UndoState.undoing, clearUndoNote: true),
      emit,
    );
    final response = await _host('journal.undo', {
      'journalId': journalId,
    }, origin: _undoOrigin);
    final current = _find<AppliedItem>(applied.id) ?? applied;
    final AppliedItem next;
    var settled = true;
    switch (response) {
      case HarnessOk(:final result):
        final failed = (result['failed'] as List?) ?? const [];
        final summary = result['summary'] as String?;
        settled = failed.isEmpty;
        next = current.copyWith(
          undoState: settled ? UndoState.undone : UndoState.available,
          undoNote: summary,
          clearUndoNote: summary == null,
        );
      case HarnessFailure(:final error):
        settled = error.code != ErrorCode.offline;
        next = current.copyWith(
          undoState: switch (error.code) {
            ErrorCode.planExpired => UndoState.expired,
            ErrorCode.offline => UndoState.available,
            _ => UndoState.failed,
          },
          undoNote: error.code == ErrorCode.offline
              ? _needsConnectionToUndo
              : error.message,
        );
    }
    _replace(next, emit);
    if (settled) _liveJournals.remove(journalId);
    final seq = _seqOf[next.id];
    if (seq == null) return;
    if (settled) _docs[seq]?.journal = null;
    _save(seq, emit: emit);
  }

  static const _needsConnection = 'Needs a connection';
  static const _needsConnectionToUndo = 'Needs a connection to undo';

  /// Back online: drop the "Needs a connection" notes the offline taps left
  /// on pending plans and applied cards.
  void _clearOfflineNotes(Emitter<AssistantState> emit) {
    final seqs = <int>{};
    var changed = false;
    final items = <ChatItem>[];
    for (final item in state.items) {
      final cleared = switch (item) {
        PlanItem(status: PlanStatus.pending, message: _needsConnection) =>
          item.copyWith(clearMessage: true),
        AppliedItem(undoNote: _needsConnection || _needsConnectionToUndo) =>
          item.copyWith(clearUndoNote: true),
        _ => null,
      };
      if (cleared != null) {
        changed = true;
        if (_seqOf[item.id] case final seq?) seqs.add(seq);
      }
      items.add(cleared ?? item);
    }
    if (!changed) return;
    emit(state.copyWith(items: items));
    // The notes are saved with their turn: drop them there too.
    for (final seq in seqs) {
      _save(seq, emit: emit);
    }
  }

  AppliedItem? _appliedWhere(bool Function(AppliedItem) test) {
    for (final item in state.items.reversed) {
      if (item is AppliedItem && test(item)) return item;
    }
    return null;
  }

  /// Closes undo windows that passed (dropping their mirrors from the turn
  /// docs) and lifts an expired daily limit.
  void _onTick(Emitter<AssistantState> emit) {
    final now = _now();
    final threadId = state.threadId;
    var changed = false;
    final items = [
      for (final item in state.items)
        if (item is AppliedItem &&
            item.undoState == UndoState.available &&
            item.undoUntil != null &&
            !now.isBefore(item.undoUntil!))
          () {
            changed = true;
            _liveJournals.remove(item.receipt.journalId);
            final seq = _seqOf[item.id];
            if (seq != null && _docs[seq]?.journal != null) {
              _docs[seq]!.journal = null;
              if (threadId != null) {
                _observe(
                  () => _threads.dropJournal(threadId, seq),
                  'Dropping undo',
                );
              }
            }
            return item.copyWith(undoState: UndoState.expired);
          }()
        else
          item,
    ];
    if (_quotaUntil case final until? when !now.isBefore(until)) {
      _quotaUntil = null;
    }
    _mirrorsLeft.removeWhere((key, until) {
      if (now.isBefore(until)) return false;
      final (thread, seq) = key;
      _observe(() => _threads.dropJournal(thread, seq), 'Dropping undo');
      return true;
    });
    emit(
      state.copyWith(
        items: changed ? items : null,
        availability: _availability(),
      ),
    );
    _scheduleTick();
  }

  void _scheduleTick() {
    _tick?.cancel();
    _tick = null;
    final now = _now();
    DateTime? next = _quotaUntil;
    for (final until in _mirrorsLeft.values) {
      if (next == null || until.isBefore(next)) next = until;
    }
    for (final item in state.items) {
      if (item is! AppliedItem || item.undoState != UndoState.available) {
        continue;
      }
      final until = item.undoUntil;
      if (until != null && (next == null || until.isBefore(next))) {
        next = until;
      }
    }
    if (next == null || isClosed) return;
    final delay = next.difference(now);
    _tick = Timer(delay.isNegative ? Duration.zero : delay, () {
      if (!isClosed) add(const _UndoTick());
    });
  }

  // ---------------------------------------------------------------- threads

  Future<void> _requestSwitch(_Switch target, Emitter<AssistantState> emit) {
    if (_uid == null) return Future.value();
    if (!target.fresh && target.threadId == state.threadId) {
      return Future.value();
    }
    switch (state.phase) {
      case ApplyingPhase():
        // Blocked until the receipt is written.
        return Future.value();
      case AwaitingApprovalPhase(:final planId):
        _pendingSwitch = target;
        return _skip(planId, emit);
      default:
        if (_turn != null || _loop.busy) {
          // Switched once the turn's stream has closed (`_TurnClosed`).
          _pendingSwitch = target;
          _loop.stop();
          return Future.value();
        }
        return _switchTo(target, emit);
    }
  }

  Future<void> _onDelete(String threadId, Emitter<AssistantState> emit) async {
    if (_uid == null) return;
    if (threadId != state.threadId) {
      _mirrorsLeft.removeWhere((key, _) => key.$1 == threadId);
      _observe(
        () => _threads.deleteThread(threadId),
        'Deleting a conversation',
      );
      return;
    }
    await _requestSwitch(_Switch.fresh(delete: threadId), emit);
  }

  Future<void> _switchTo(_Switch target, Emitter<AssistantState> emit) async {
    final old = state.threadId;
    if (old != null) {
      _results.queries.results.dropThread(old);
      if (old != target.delete) _leaveMirrors(old);
    }
    if (target.delete case final id?) {
      _mirrorsLeft.removeWhere((key, _) => key.$1 == id);
      _observe(() => _threads.deleteThread(id), 'Deleting a conversation');
    }
    _clearThread();
    _loop.resetThread();
    final open = target.threadId;
    if (open == null) {
      emit(state.cleared());
      // The daily limit and left mirrors still need their tick.
      _scheduleTick();
      return;
    }
    await _load(open, emit);
  }

  /// Hands the journal mirrors of [threadId]'s docs to [_mirrorsLeft] (or
  /// drops them when their window already closed), so none outlives it.
  void _leaveMirrors(String threadId) {
    final now = _now();
    for (final MapEntry(key: seq, value: doc) in _docs.entries) {
      final journal = doc.journal;
      if (journal == null) continue;
      final until = DateTime.tryParse('${journal['expiresAt']}');
      if (until != null && now.isBefore(until)) {
        _mirrorsLeft[(threadId, seq)] = until;
      } else {
        _observe(() => _threads.dropJournal(threadId, seq), 'Dropping undo');
      }
    }
  }

  void _clearThread() {
    _tick?.cancel();
    _tick = null;
    _nextSeq = 0;
    _fromCache = false;
    _threadCreatedAt = null;
    _docs.clear();
    _seqOf.clear();
  }

  Future<void> _load(String threadId, Emitter<AssistantState> emit) async {
    _clearThread();
    // The open thread's own tick drops these mirrors from here on.
    _mirrorsLeft.removeWhere((key, _) => key.$1 == threadId);
    emit(state.cleared().copyWith(threadId: threadId));
    final List<AssistantRecord> records;
    try {
      final loaded = await _threads.loadMessages(threadId);
      records = loaded.records;
      _fromCache = loaded.fromCache;
    } catch (error) {
      _log('Loading a conversation failed', error);
      if (_uid == null || state.threadId != threadId) return;
      // Not bound to the thread: a message sent now starts a new one
      // rather than overwriting this one's turn docs from seq 0.
      emit(
        state.cleared().copyWith(
          items: [
            const ErrorItem(
              id: 'load',
              kind: ChatErrorKind.saveFailed,
              message: 'Couldn’t open this conversation.',
              retryable: false,
            ),
          ],
        ),
      );
      // _clearThread cancelled the daily-limit and left-mirror tick.
      _scheduleTick();
      return;
    }
    if (state.threadId != threadId || _uid == null) return;

    final items = <ChatItem>[];
    final turns = <HistoryTurn>[];
    var usage = TokenUsage.zero;
    for (final record in records) {
      final seq = record['seq'];
      if (seq is! int) continue;
      final doc = _Doc(
        createdAt:
            DateTime.tryParse('${record['createdAt']}')?.toLocal() ?? _now(),
        status: record['status'] as String? ?? 'done',
        llm: record['llm'] as String?,
        journal: (record['journal'] as Map?)?.cast<String, Object?>(),
        usage: switch (record['usage']) {
          final Map u => TokenUsage.fromJson(u.cast<String, Object?>()),
          _ => TokenUsage.zero,
        },
      );
      _docs[seq] = doc;
      usage += doc.usage;
      if (seq >= _nextSeq) _nextSeq = seq + 1;
      final decoded = decodeChatItems((record['ui'] as List?) ?? const []);
      for (final item in decoded) {
        _seqOf[item.id] = seq;
      }
      items.addAll(decoded);
      if (_historyTurn(doc, decoded) case final turn?) turns.add(turn);
    }
    _threadCreatedAt = _docs.isEmpty
        ? null
        : _docs[_docs.keys.first]?.createdAt;

    // Undo after a reload: only what `journal.restore` re-validates.
    for (final (i, item) in items.indexed) {
      if (item is! AppliedItem || item.undoState != UndoState.available) {
        continue;
      }
      items[i] = await _restoreUndo(item, threadId);
    }

    final userText = items.whereType<UserItem>().firstOrNull?.text;
    emit(
      state.copyWith(
        threadId: threadId,
        threadTitle: userText == null ? null : _title(userText),
        items: items,
        phase: const IdlePhase(),
        usage: usage,
      ),
    );
    _loop.restore(
      turns.length > replayTurns
          ? turns.sublist(turns.length - replayTurns)
          : turns,
    );
    _scheduleTick();
    for (final item in items) {
      if (item is TableItem || item is ChartItem) {
        await _materialize(item, threadId, emit);
      }
    }
  }

  Future<AppliedItem> _restoreUndo(AppliedItem item, String threadId) async {
    final journalId = item.receipt.journalId;
    final until = item.undoUntil;
    final seq = _seqOf[item.id];
    final doc = seq == null ? null : _docs[seq];
    final mirror = doc?.journal;
    AppliedItem expired() {
      if (mirror != null && seq != null) {
        doc!.journal = null;
        _observe(() => _threads.dropJournal(threadId, seq), 'Dropping undo');
      }
      return item.copyWith(undoState: UndoState.expired);
    }

    if (journalId == null || until == null || !_now().isBefore(until)) {
      return expired();
    }
    if (_liveJournals.contains(journalId)) return item;
    if (mirror == null || mirror['journalId'] != journalId) return expired();
    final response = await _host('journal.restore', {
      'entry': mirror,
    }, origin: _undoOrigin);
    if (response case HarnessOk(:final result)) {
      _liveJournals.add(journalId);
      final restoredUntil = DateTime.tryParse('${result['expiresAt']}');
      return _withUndo(item, undoUntil: restoredUntil ?? until);
    }
    return expired();
  }

  /// The model turn a persisted doc holds: its raw contents without the plan
  /// gate's unanswered calls (a reload while a plan waited, or between the
  /// commit and the model's reply).
  static HistoryTurn? _historyTurn(_Doc doc, List<ChatItem> ui) {
    final llm = doc.llm;
    if (llm == null) return null;
    final List<LlmContent> contents;
    try {
      final decoded = jsonDecode(llm);
      if (decoded is! List) return null;
      contents = [
        for (final c in decoded)
          if (c is Map) LlmRawContent(c.cast<String, Object?>()),
      ];
    } on FormatException {
      return null;
    }
    while (contents.isNotEmpty && _unansweredCalls(contents.last)) {
      contents.removeLast();
    }
    if (contents.isEmpty) return null;
    return HistoryTurn(
      userText: ui.whereType<UserItem>().firstOrNull?.text ?? '',
      contents: contents,
      answer: ui.whereType<AssistantTextItem>().map((t) => t.text).join('\n'),
      steps: [
        for (final s in ui.whereType<StepsItem>())
          for (final step in s.steps) step.text,
      ],
    );
  }

  static bool _unansweredCalls(LlmContent content) {
    if (content is! LlmRawContent || content.json['role'] != 'model') {
      return false;
    }
    final parts = content.json['parts'];
    return parts is List &&
        parts.any((p) => p is Map && p.containsKey('functionCall'));
  }

  // ------------------------------------------------------------ persistence

  /// Writes turn [seq]'s doc (and the thread meta). [items] overrides the
  /// state's items (a checkpoint taken before an emit). When the doc is over
  /// budget without its journal mirror, the applied card says "Undo
  /// available until you close Morkva" ([emit] updates it).
  void _save(
    int seq, {
    String? status,
    List<ChatItem>? items,
    Emitter<AssistantState>? emit,
  }) {
    final threadId = state.threadId;
    final doc = _docs[seq];
    if (threadId == null || doc == null || _uid == null) return;
    if (status != null) doc.status = status;
    final turn = _turn;
    if (turn != null && turn.seq == seq && _loop.history.isNotEmpty) {
      doc.llm = _encodeTurn(_loop.history.last, threadId);
      if (turn.ended) doc.usage = turn.usage;
    }
    var all = items ?? state.items;
    AssistantRecord record() => {
      'createdAt': doc.createdAt.toUtc().toIso8601String(),
      'status': doc.status,
      'llm': doc.llm ?? '[]',
      'ui': encodeChatItems(all.where((i) => _seqOf[i.id] == seq)),
      'journal': ?doc.journal,
      if (doc.usage != TokenUsage.zero) 'usage': doc.usage.toJson(),
    };
    var fit = fitMessageToBudget(record());
    if (fit.journalDropped) {
      doc.journal = null;
      all = [
        for (final i in all)
          i is AppliedItem && _seqOf[i.id] == seq
              ? i.copyWith(undoSessionOnly: true)
              : i,
      ];
      fit = fitMessageToBudget(record());
      if (emit != null && !emit.isDone && items == null) {
        emit(state.copyWith(items: all));
      }
    }
    if (!fit.fits) _log('Turn $seq is over the doc budget (${fit.bytes} B)');
    _observe(
      () => _threads.checkpoint(
        threadId,
        seq: seq,
        message: fit.record,
        thread: _threadMeta(all),
      ),
      'Saving the conversation',
    );
  }

  AssistantRecord _threadMeta(List<ChatItem> items) {
    final now = _now().toUtc().toIso8601String();
    return {
      'title': state.threadTitle ?? '',
      'createdAt': (_threadCreatedAt ?? _now()).toUtc().toIso8601String(),
      'updatedAt': now,
      'model': _loop.model,
      'lastSnippet': _snippet(items),
      'tokens': state.usage.toJson(),
      'schema': 1,
    };
  }

  static String _snippet(List<ChatItem> items) {
    for (final item in items.reversed) {
      switch (item) {
        case AppliedItem(:final receipt):
          return receipt.summary;
        case ChartItem():
          return 'chart';
        case TableItem():
          return 'table';
        case AssistantTextItem():
          final text = item.currentText.trim().replaceAll(RegExp(r'\s+'), ' ');
          if (text.isNotEmpty) {
            return text.length > 80 ? '${text.substring(0, 79)}…' : text;
          }
        default:
          break;
      }
    }
    return '';
  }

  /// [turn]'s contents as one JSON string, every function response cut to
  /// `{summary, spec}` (no row values: deleting a card leaves no copy of it
  /// in the chat history).
  String _encodeTurn(HistoryTurn turn, String threadId) => jsonEncode([
    for (final content in turn.contents)
      _compactContent(_llm.encodeContent(content), threadId),
  ]);

  Map<String, Object?> _compactContent(
    Map<String, Object?> content,
    String threadId,
  ) {
    final parts = content['parts'];
    if (parts is! List) return content;
    return {
      ...content,
      'parts': [
        for (final part in parts)
          if (part is Map && part['functionResponse'] is Map)
            {
              ...part.cast<String, Object?>(),
              'functionResponse': {
                ...(part['functionResponse'] as Map).cast<String, Object?>(),
                'response': _compactResponse(
                  (part['functionResponse'] as Map)['response'],
                  threadId,
                ),
              },
            }
          else
            part,
      ],
    };
  }

  Object? _compactResponse(Object? response, String threadId) {
    if (response is! Map) return response;
    if (response['elided'] == true) return response;
    if (response['error'] case final Map error) {
      return {
        'error': {'code': error['code'], 'message': error['message']},
      };
    }
    // Plan outcomes, `not_proposed`, `stopped`: small, and the model needs
    // them as they were.
    if (response['status'] is String) return response;
    final handle = response['handle'];
    final spec = handle is String
        ? _results.specOf(handle, thread: threadId)
        : null;
    return {
      'summary': response['summary'] ?? response['title'],
      if (response['total'] case final num total) 'total': total,
      'spec': ?spec,
    };
  }

  /// Starts [write] unless the session was reset (the repository may be
  /// bound to the next member already), and reports a failure.
  void _observe(Future<void> Function() write, String what) {
    if (_uid == null) return;
    write().then<void>(
      (_) {},
      onError: (Object error) {
        _log('$what failed', error);
        if (!isClosed) add(const _SaveFailed());
      },
    );
  }

  /// An automation run started from the writes of plan [commitId]: the
  /// thread's applied card for it counts one more.
  // shortcut: never checkpoints, so a count arriving after the turn's last
  // save is lost on reload; save the turn here once the runner reports runs.
  void _onRunStarted(String commitId, Emitter<AssistantState> emit) {
    for (final item in state.items.reversed) {
      if (item is AppliedItem && item.receipt.planId == commitId) {
        _replace(item.copyWith(startedRuns: item.startedRuns + 1), emit);
        return;
      }
    }
  }

  // ---------------------------------------------------------------- helpers

  /// Calls host op [op] as the signed-in user: the only user-actor context
  /// in the app.
  Future<HarnessResponse> _host(
    String op,
    Map<String, Object?> args, {
    Sink<HarnessEvent>? events,
    WriteOrigin origin = _planOrigin,
  }) {
    if (_uid == null) {
      return Future.value(
        HarnessFailure(
          HarnessError(
            code: ErrorCode.notPermitted,
            message: 'Nobody is signed in.',
          ),
        ),
      );
    }
    return _harness.call(
      HarnessRequest(op: op, args: args, callId: 'h.${++_hostCalls}'),
      _userContext(events: events, origin: origin),
    );
  }

  /// What the assistant's commits (and retries) write as; the committer
  /// keys them by the plan id.
  static const WriteOrigin _planOrigin = WriteOrigin(
    kind: WriteKind.plan,
    actor: 'agent:assistant',
  );
  static const WriteOrigin _undoOrigin = WriteOrigin(kind: WriteKind.undo);

  HarnessContext _userContext({
    Sink<HarnessEvent>? events,
    WriteOrigin origin = _planOrigin,
  }) {
    final now = _now();
    return HarnessContext(
      workspaceId: _workspaceId ?? '',
      actor: Actor.user(_uid ?? ''),
      grants: Grants.all(),
      now: now,
      today: now,
      timeZoneName: _loop.timeZoneName,
      events: events,
      origin: origin,
    );
  }

  void _append(
    _Turn turn,
    ChatItem item,
    Emitter<AssistantState> emit, {
    TurnPhase? phase,
    bool clearBanner = false,
  }) {
    _seqOf[item.id] = turn.seq;
    emit(
      state.copyWith(
        items: [...state.items, item],
        phase: phase,
        clearBanner: clearBanner,
      ),
    );
  }

  void _replace(
    ChatItem item,
    Emitter<AssistantState> emit, {
    TurnPhase? phase,
    bool clearBanner = false,
  }) {
    final items = [for (final i in state.items) i.id == item.id ? item : i];
    emit(state.copyWith(items: items, phase: phase, clearBanner: clearBanner));
  }

  T? _find<T extends ChatItem>(String id) {
    for (final item in state.items) {
      if (item.id == id) return item is T ? item : null;
    }
    return null;
  }

  static AppliedItem _withUndo(
    AppliedItem item, {
    Receipt? receipt,
    DateTime? undoUntil,
    UndoState? undoState,
  }) => AppliedItem(
    id: item.id,
    plan: item.plan,
    receipt: receipt ?? item.receipt,
    undoUntil: undoUntil ?? item.undoUntil,
    undoState: undoState ?? item.undoState,
    undoNote: item.undoNote,
    undoSessionOnly: item.undoSessionOnly,
    startedRuns: item.startedRuns,
  );

  /// [text]'s first sentence, cut at a word to [titleLength] with "…".
  static String _title(String text) {
    var line = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    final end = RegExp(r'[.!?;:](?= |$)').firstMatch(line);
    if (end != null && end.start > 0) {
      // A question keeps its mark; other sentence ends are dropped.
      final mark = line[end.start];
      line = line.substring(
        0,
        mark == '?' || mark == '!' ? end.end : end.start,
      );
    }
    if (line.length <= titleLength) return line;
    // A word ending at the limit stays whole; the "…" takes the space.
    final space = line.substring(0, titleLength).lastIndexOf(' ');
    final cut = line.substring(
      0,
      space > titleLength ~/ 2 ? space : titleLength - 1,
    );
    return '${cut.replaceAll(RegExp(r'[\s,;:.\-–—]+$'), '')}…';
  }

  static void _log(String message, [Object? error]) =>
      developer.log(message, name: 'assistant', error: error);

  @override
  Future<void> close() async {
    _tick?.cancel();
    await _onlineSub?.cancel();
    await _runsSub?.cancel();
    await _configSub?.cancel();
    if (_turn case final turn?) {
      turn.dead = true;
      _loop.stop();
    }
    return super.close();
  }
}

/// When Gemini's daily quota resets after [now]: the next midnight in
/// Pacific time.
///
/// shortcut: a fixed UTC−8 offset (PST), so in daylight-saving months the
/// reset reads an hour late; switch to a tz database if it ever matters.
DateTime nextPacificMidnight(DateTime now) {
  const offset = Duration(hours: 8);
  final pacific = now.toUtc().subtract(offset);
  final midnight = DateTime.utc(pacific.year, pacific.month, pacific.day + 1);
  return midnight.add(offset).toLocal();
}

/// The running user turn: which thread and doc it writes, and what it is
/// rendering.
final class _Turn {
  _Turn({required this.threadId, required this.seq, required this.text});

  final String threadId;
  final int seq;
  final String text;
  StreamSubscription<AgentEvent>? sub;

  int _items = 0;
  String? textItemId;
  ValueNotifier<String>? live;
  String? stepsItemId;
  String? planId;
  String? planItemId;

  /// The journal mirror of this turn's commit.
  Map<String, Object?>? journal;
  TokenUsage usage = TokenUsage.zero;

  /// Its last event was handled.
  bool ended = false;

  /// The session was reset: its events are ignored.
  bool dead = false;

  /// A chat item id unique in the thread.
  String mint() => 't$seq.${_items++}';
}

/// One turn doc of the open thread, as last written or loaded.
final class _Doc {
  _Doc({
    required this.createdAt,
    this.status = 'done',
    this.llm,
    this.journal,
    this.usage = TokenUsage.zero,
  });

  final DateTime createdAt;
  String status;
  String? llm;
  Map<String, Object?>? journal;
  TokenUsage usage;
}

/// Where a thread switch goes once the running turn has ended.
final class _Switch {
  const _Switch.open(String this.threadId) : delete = null;

  const _Switch.fresh({this.delete}) : threadId = null;

  /// The thread to open; null for a new one.
  final String? threadId;

  /// A thread deleted on the way (the open one).
  final String? delete;

  bool get fresh => threadId == null;
}

final class _EventSink implements Sink<HarnessEvent> {
  _EventSink(this._onEvent);

  final void Function(HarnessEvent event) _onEvent;

  @override
  void add(HarnessEvent data) => _onEvent(data);

  @override
  void close() {}
}
