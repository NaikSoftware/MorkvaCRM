import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/automation/runner_api.dart';
import '../../../core/domain/automation/automation.dart';

/// The actionable skips the indicator calls "didn't run" (UX §5).
const Set<RunReason> kDidntRunReasons = {
  RunReason.notSettled,
  RunReason.needsConsent,
  RunReason.broken,
  RunReason.crashed,
  RunReason.fanOut,
  RunReason.queueFull,
  RunReason.depthLimit,
  RunReason.reviewBacklog,
  RunReason.notPermitted,
};

/// Whether [run] counts as "failed" for the indicator and the Failed filter;
/// the user's own Stop (`failed(cancelled)`) doesn't.
bool runFailed(RunRecord run) =>
    (run.status == RunStatus.failed && run.reason != RunReason.cancelled) ||
    run.status == RunStatus.timedOut;

/// Whether [run] is an actionable skip ("didn't run").
bool runDidntRun(RunRecord run) =>
    run.status == RunStatus.skipped && kDidntRunReasons.contains(run.reason);

/// The run indicator's primary state, highest priority first (UX §5).
enum IndicatorState {
  running,
  needsReview,
  attention,
  reviewsExpired,
  engineUnavailable,
  idle,
}

/// Where a finished run's message goes (UX §4–§5).
enum NoticeSurface {
  /// A button run waiting for review: the review sheet, if the pressed
  /// button's surface is still the top route (else the snackbar).
  reviewSheet,

  /// The card editor is open: its in-editor banner, never a shell snackbar
  /// under its scrim.
  banner,

  /// The finish snackbar.
  snackbar,
}

/// A run that just finished, with where to tell the user.
final class RunNotice extends Equatable {
  const RunNotice(this.run, this.surface);

  final RunView run;
  final NoticeSurface surface;

  @override
  List<Object?> get props => [run, surface];
}

final class AutomationRunsState extends Equatable {
  const AutomationRunsState({
    required this.seenAt,
    required this.expiredSince,
    this.activity = RunActivity.idle,
    this.recent = const [],
    this.anyEnabled = false,
    this.editorOpen = false,
    this.notice,
    this.error,
  });

  final RunActivity activity;

  /// The latest run docs (≤ 200), newest first.
  final List<RunRecord> recent;

  /// Failures and skips after this are unseen (until the Runs tab opens).
  final DateTime seenAt;

  /// Own-session reviews expired after this are unseen: the session start
  /// (the runner expires them in `initialize`, before this cubit exists),
  /// then the last Runs tab visit. The web session id survives reloads, so
  /// older expiries must stay out.
  final DateTime expiredSince;

  /// At least one automation is enabled (the engine warning shows only
  /// then).
  final bool anyEnabled;

  /// A card editor dialog is up.
  final bool editorOpen;

  /// The latest finish to announce.
  final RunNotice? notice;

  /// The last refused press / Stop / Undo / Run again, shown as is.
  final String? error;

  /// "Running · N": queued + running.
  int get running => activity.active;

  /// Only from this session's runner: a review of another window can't be
  /// approved here, so it never counts.
  int get needsReview => activity.needsReview;

  Iterable<RunRecord> _since(DateTime t) =>
      recent.where((r) => !(r.endedAt ?? r.startedAt).isBefore(t));

  Iterable<RunRecord> get _unseen => _since(seenAt);

  /// "1 failed".
  int get failed => _unseen.where(runFailed).length;

  /// "1 automation didn't run".
  int get didntRun => _unseen.where(runDidntRun).length;

  /// "2 reviews expired · View": this session's reviews that expired (on
  /// start-up, after a reload); superseded ones were replaced by the user.
  int expired(String sessionId) => _since(expiredSince)
      .where(
        (r) =>
            r.status == RunStatus.expired &&
            r.reason == null &&
            r.sessionId == sessionId,
      )
      .length;

  bool get engineWarning => activity.engineUnavailable && anyEnabled;

  IndicatorState primary(String sessionId) {
    if (running > 0) return IndicatorState.running;
    if (needsReview > 0) return IndicatorState.needsReview;
    if (failed + didntRun > 0) return IndicatorState.attention;
    if (expired(sessionId) > 0) return IndicatorState.reviewsExpired;
    if (engineWarning) return IndicatorState.engineUnavailable;
    return IndicatorState.idle;
  }

  AutomationRunsState copyWith({
    RunActivity? activity,
    List<RunRecord>? recent,
    DateTime? seenAt,
    DateTime? expiredSince,
    bool? anyEnabled,
    bool? editorOpen,
    RunNotice? Function()? notice,
    String? Function()? error,
  }) => AutomationRunsState(
    activity: activity ?? this.activity,
    recent: recent ?? this.recent,
    seenAt: seenAt ?? this.seenAt,
    expiredSince: expiredSince ?? this.expiredSince,
    anyEnabled: anyEnabled ?? this.anyEnabled,
    editorOpen: editorOpen ?? this.editorOpen,
    notice: notice == null ? this.notice : notice(),
    error: error == null ? this.error : error(),
  );

  @override
  List<Object?> get props => [
    activity,
    recent,
    seenAt,
    expiredSince,
    anyEnabled,
    editorOpen,
    notice,
    error,
  ];
}

/// App level (next to `SyncStatusCubit`): live runs, the indicator counts
/// and where each finished run is announced.
///
/// Construction contract (T16): build it after sign-in (it subscribes to the
/// stores once), and pass as [since] the time captured just before
/// `runner.initialize`, so the reviews that start-up expires count as
/// "N reviews expired" until the Runs tab opens.
class AutomationRunsCubit extends Cubit<AutomationRunsState> {
  AutomationRunsCubit(
    this._runner,
    AutomationStores stores, {
    DateTime? since,
    DateTime Function() now = DateTime.now,
  }) : _now = now,
       // activityChanges doesn't replay, so start from the current activity.
       super(
         AutomationRunsState(
           seenAt: now(),
           expiredSince: since ?? now(),
           activity: _runner.activity,
         ),
       ) {
    _subs = [
      _runner.activityChanges.listen((a) => emit(state.copyWith(activity: a))),
      _runner.finished.listen(_finished),
      stores.runs.watchRecent().listen(
        (runs) => emit(state.copyWith(recent: runs)),
      ),
      stores.automations.watch().listen(
        (all) => emit(state.copyWith(anyEnabled: all.any((a) => a.enabled))),
      ),
    ];
  }

  final AutomationRunnerApi _runner;
  final DateTime Function() _now;
  late final List<StreamSubscription<Object?>> _subs;

  /// Runs started by hand (a press, Run again): button-like, so a review
  /// opens the sheet even for an event automation's run.
  final _manual = <String>{};

  String get sessionId => _runner.sessionId;

  IndicatorState get primary => state.primary(_runner.sessionId);

  /// The Runs tab opened: attention is seen.
  void markRunsSeen() {
    final now = _now();
    emit(state.copyWith(seenAt: now, expiredSince: now));
  }

  /// Run again started elsewhere (the run log, the review sheet): treat
  /// [runId] as button-like when it finishes.
  void startedManually(String runId) => _manual.add(runId);

  /// The card editor dialog opened / closed (it calls these).
  void editorOpened() => emit(state.copyWith(editorOpen: true));

  void editorClosed() => emit(state.copyWith(editorOpen: false));

  /// The notice was shown.
  void noticeShown() => emit(state.copyWith(notice: () => null));

  /// A card button: while a run of this automation on [cardId] is queued,
  /// running or waiting for review, a press focuses it instead of starting
  /// a second one. Returns the run's id, or null when refused.
  Future<String?> pressCard(String automationId, {required String cardId}) =>
      _press(
        automationId,
        cardId,
        () => _runner.pressCard(automationId, cardId: cardId),
      );

  /// A collection button over the view's shown cards.
  Future<String?> pressCollection(
    String automationId, {
    required List<String> cardIds,
    String? viewId,
  }) => _press(
    automationId,
    null,
    () =>
        _runner.pressCollection(automationId, cardIds: cardIds, viewId: viewId),
  );

  Future<String?> _press(
    String automationId,
    String? cardId,
    Future<String> Function() press,
  ) async {
    final live = state.activity.runOf(automationId, cardId: cardId);
    if (live != null) return live.runId;
    return _manually(press);
  }

  /// Stop on a button, the indicator or a running row.
  void stop(String runId) => _runner.stop(runId);

  /// The banner's / snackbar's Undo.
  Future<bool> undo(String runId) async =>
      await _guard(() async {
        await _runner.undo(runId);
        return runId;
      }) !=
      null;

  /// The snackbar's Run again; the new run's id, or null when refused.
  Future<String?> runAgain(String runId) =>
      _manually(() => _runner.runAgain(runId));

  Future<String?> _manually(Future<String> Function() start) async {
    final id = await _guard(start);
    if (id != null) _manual.add(id);
    return id;
  }

  void clearError() => emit(state.copyWith(error: () => null));

  Future<String?> _guard(Future<String> Function() action) async {
    emit(state.copyWith(error: () => null));
    try {
      return await action();
    } on AutomationRefused catch (e) {
      if (!isClosed) emit(state.copyWith(error: () => e.message));
      return null;
    }
  }

  void _finished(RunView run) {
    final manual = run.status == RunStatus.awaitingReview
        ? _manual.contains(run.runId)
        : _manual.remove(run.runId);
    final surface =
        (run.isButton || manual) && run.status == RunStatus.awaitingReview
        ? NoticeSurface.reviewSheet
        : state.editorOpen
        ? NoticeSurface.banner
        : NoticeSurface.snackbar;
    emit(state.copyWith(notice: () => RunNotice(run, surface)));
  }

  @override
  Future<void> close() async {
    for (final s in _subs) {
      await s.cancel();
    }
    return super.close();
  }
}
