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

/// Whether [run] counts as "failed" for the indicator and the Failed filter.
bool runFailed(RunRecord run) =>
    run.status == RunStatus.failed || run.status == RunStatus.timedOut;

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
    this.activity = RunActivity.idle,
    this.recent = const [],
    this.anyEnabled = false,
    this.editorOpen = false,
    this.notice,
  });

  final RunActivity activity;

  /// The latest run docs (≤ 200), newest first.
  final List<RunRecord> recent;

  /// Failures and skips after this are unseen (until the Runs tab opens).
  final DateTime seenAt;

  /// At least one automation is enabled (the engine warning shows only
  /// then).
  final bool anyEnabled;

  /// A card editor dialog is up.
  final bool editorOpen;

  /// The latest finish to announce.
  final RunNotice? notice;

  /// "Running · N": queued + running.
  int get running => activity.active;

  /// Only from this session's runner: a review of another window can't be
  /// approved here, so it never counts.
  int get needsReview => activity.needsReview;

  Iterable<RunRecord> get _unseen =>
      recent.where((r) => !(r.endedAt ?? r.startedAt).isBefore(seenAt));

  /// "1 failed".
  int get failed => _unseen.where(runFailed).length;

  /// "1 automation didn't run".
  int get didntRun => _unseen.where(runDidntRun).length;

  /// "2 reviews expired · View": this session's reviews that expired (on
  /// start-up, after a reload); superseded ones were replaced by the user.
  int expired(String sessionId) => _unseen
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
    bool? anyEnabled,
    bool? editorOpen,
    RunNotice? Function()? notice,
  }) => AutomationRunsState(
    activity: activity ?? this.activity,
    recent: recent ?? this.recent,
    seenAt: seenAt ?? this.seenAt,
    anyEnabled: anyEnabled ?? this.anyEnabled,
    editorOpen: editorOpen ?? this.editorOpen,
    notice: notice == null ? this.notice : notice(),
  );

  @override
  List<Object?> get props => [
    activity,
    recent,
    seenAt,
    anyEnabled,
    editorOpen,
    notice,
  ];
}

/// App level (next to `SyncStatusCubit`): live runs, the indicator counts
/// and where each finished run is announced.
class AutomationRunsCubit extends Cubit<AutomationRunsState> {
  AutomationRunsCubit(
    this._runner,
    AutomationStores stores, {
    DateTime Function() now = DateTime.now,
  }) : _now = now,
       // activityChanges doesn't replay, so start from the current activity.
       super(AutomationRunsState(seenAt: now(), activity: _runner.activity)) {
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

  String get sessionId => _runner.sessionId;

  IndicatorState get primary => state.primary(_runner.sessionId);

  /// The Runs tab opened: attention is seen.
  void markRunsSeen() => emit(state.copyWith(seenAt: _now()));

  /// The card editor dialog opened / closed (it calls these).
  void editorOpened() => emit(state.copyWith(editorOpen: true));

  void editorClosed() => emit(state.copyWith(editorOpen: false));

  /// The notice was shown.
  void noticeShown() => emit(state.copyWith(notice: () => null));

  void _finished(RunView run) {
    final surface = run.isButton && run.status == RunStatus.awaitingReview
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
