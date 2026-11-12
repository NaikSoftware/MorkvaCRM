import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rxdart/rxdart.dart';

import '../../../core/automation/runner_api.dart';
import '../../../core/domain/automation/automation.dart';
import '../widgets/reason_copy.dart';
import 'automation_runs_cubit.dart';
import 'modules_cubit.dart';

/// The journal keeps an applied run undoable this long (`journal.dart:15`).
const Duration kUndoWindow = Duration(minutes: 10);

/// How a run doc reads in this session (design spec, Run queue & lifecycle).
enum RunDisplay {
  /// As stored.
  plain,

  /// Awaiting review, and this session holds its plan: **Review**.
  reviewHere,

  /// Awaiting review in another window or an earlier start: Run again.
  reviewNotHere,

  /// Applying in this session right now.
  applyingHere,

  /// Left applying by another window, or interrupted: no Run again.
  outcomeUnknown,
}

/// The trailing action of a run row.
enum RunRowAction { none, review, runAgain, reviewPermissions, editAutomation }

/// Undo of an applied run (run detail's Outcome).
enum UndoState {
  /// Nothing was applied.
  none,

  /// "Undo · 9 min left".
  available,

  /// "Undo expired".
  expired,

  /// "Undo isn't available after a reload".
  afterReload,

  /// "Reverted · 12:09".
  undone,
}

/// One run row / run detail, mapped for this session.
final class RunRow extends Equatable {
  const RunRow({
    required this.run,
    required this.display,
    required this.copy,
    required this.action,
    required this.undo,
    this.undoUntil,
  });

  final RunRecord run;
  final RunDisplay display;
  final RunCopy copy;
  final RunRowAction action;
  final UndoState undo;

  /// When Undo stops working (the countdown).
  final DateTime? undoUntil;

  @override
  List<Object?> get props => [run, display, action, undo, undoUntil];
}

/// Maps a run doc for this session: who holds a review, an outcome nobody
/// can know, Run again eligibility and the undo window.
RunRow runRowOf(
  RunRecord run, {
  required String sessionId,
  required bool hasReviewPlan,
  required bool live,
  required bool canUndo,
  required DateTime now,
  required AutomationStatus? automation,
}) {
  final ownSession = run.sessionId == sessionId;
  final applying =
      run.status == RunStatus.applying ||
      (run.status == RunStatus.awaitingReview && run.applyStartedAt != null);
  final display = applying
      ? (ownSession && live
            ? RunDisplay.applyingHere
            : RunDisplay.outcomeUnknown)
      : run.status == RunStatus.awaitingReview
      ? (ownSession && hasReviewPlan
            ? RunDisplay.reviewHere
            : RunDisplay.reviewNotHere)
      : run.reason == RunReason.interrupted
      ? RunDisplay.outcomeUnknown
      : RunDisplay.plain;

  final copy = switch (display) {
    RunDisplay.reviewNotHere => kReviewNotHereCopy,
    RunDisplay.outcomeUnknown when run.reason != RunReason.interrupted =>
      kOutcomeUnknownCopy,
    RunDisplay.applyingHere => runCopy(RunStatus.applying, null),
    _ => runCopy(
      run.status,
      run.reason,
      error: run.error,
      timeoutSeconds: ((run.durationMs ?? 20000) / 1000).round(),
    ),
  };

  // Run again re-runs the stored trigger: never when the card is gone, or
  // when changes may already be in (it could apply twice).
  final rerunnable =
      (display == RunDisplay.reviewNotHere ||
          (display == RunDisplay.plain &&
              const {
                RunStatus.failed,
                RunStatus.timedOut,
                RunStatus.skipped,
                RunStatus.expired,
              }.contains(run.status))) &&
      run.automationId != null &&
      automation != null &&
      run.trigger.kind != TriggerKind.cardDeleted &&
      (run.receipt?.unconfirmed ?? 0) == 0;
  final action = display == RunDisplay.reviewHere
      ? RunRowAction.review
      : !rerunnable
      ? RunRowAction.none
      : switch (automation) {
          AutomationStatus.needsConsent => RunRowAction.reviewPermissions,
          AutomationStatus.broken => RunRowAction.editAutomation,
          _ => RunRowAction.runAgain,
        };

  final undoUntil = run.journalId == null
      ? null
      : (run.endedAt ?? run.startedAt).add(kUndoWindow);
  final undo = run.status != RunStatus.succeeded || undoUntil == null
      ? UndoState.none
      : run.undoneAt != null
      ? UndoState.undone
      : canUndo
      ? UndoState.available
      : now.isBefore(undoUntil)
      ? UndoState.afterReload
      : UndoState.expired;

  return RunRow(
    run: run,
    display: display,
    copy: copy,
    action: action,
    undo: undo,
    undoUntil: undo == UndoState.available ? undoUntil : null,
  );
}

/// The Runs tab's filter chips (+ the automation picker, the card chip and
/// module details' "All runs").
enum RunFilterKind { all, review, failed }

final class RunFilter extends Equatable {
  const RunFilter({
    this.kind = RunFilterKind.all,
    this.automationId,
    this.moduleId,
    this.cardId,
  });

  final RunFilterKind kind;
  final String? automationId;
  final String? moduleId;
  final String? cardId;

  bool accepts(RunRecord run) =>
      switch (kind) {
        RunFilterKind.all => true,
        RunFilterKind.review => run.status == RunStatus.awaitingReview,
        RunFilterKind.failed => runFailed(run) || runDidntRun(run),
      } &&
      (automationId == null || run.automationId == automationId) &&
      (moduleId == null || run.moduleId == moduleId) &&
      (cardId == null ||
          run.trigger.cardId == cardId ||
          run.touchedCardIds.contains(cardId));

  @override
  List<Object?> get props => [kind, automationId, moduleId, cardId];
}

/// A row of the list: one run, or more than 3 consecutive skips that share
/// a reason ("12 skipped — show").
sealed class RunEntry extends Equatable {
  const RunEntry();
}

final class RunEntryRow extends RunEntry {
  const RunEntryRow(this.row);

  final RunRow row;

  @override
  List<Object?> get props => [row];
}

final class RunEntryGroup extends RunEntry {
  const RunEntryGroup(this.rows);

  final List<RunRow> rows;

  /// The key [RunLogCubit.expand] takes.
  String get key => rows.first.run.id;

  @override
  List<Object?> get props => [rows];
}

/// Folds runs of more than 3 consecutive skips with one reason into a group,
/// unless [expanded] holds its key.
List<RunEntry> groupRuns(List<RunRow> rows, Set<String> expanded) {
  final out = <RunEntry>[];
  var i = 0;
  while (i < rows.length) {
    final run = rows[i].run;
    var j = i + 1;
    if (run.status == RunStatus.skipped) {
      while (j < rows.length &&
          rows[j].run.status == RunStatus.skipped &&
          rows[j].run.reason == run.reason) {
        j++;
      }
    }
    if (j - i > 3 && !expanded.contains(run.id)) {
      out.add(RunEntryGroup(rows.sublist(i, j)));
    } else {
      out.addAll([for (final r in rows.sublist(i, j)) RunEntryRow(r)]);
    }
    i = j;
  }
  return out;
}

final class RunLogState extends Equatable {
  const RunLogState({
    this.loading = true,
    this.filter = const RunFilter(),
    this.rows = const [],
    this.expanded = const {},
    this.live = const [],
    this.error,
  });

  final bool loading;
  final RunFilter filter;

  /// Every run doc (≤ 200), mapped, newest first, unfiltered.
  final List<RunRow> rows;
  final Set<String> expanded;

  /// "Running now": this session's queued, running and applying runs.
  final List<RunView> live;
  final String? error;

  /// The list under the filter chips.
  List<RunEntry> get entries => groupRuns([
    for (final r in rows)
      if (filter.accepts(r.run)) r,
  ], expanded);

  /// The "Needs review" chip count: reviews this session can open.
  int get needsReview =>
      rows.where((r) => r.display == RunDisplay.reviewHere).length;

  /// The run detail's row ([RunLogCubit.load] fetches one outside the
  /// window).
  RunRow? row(String runId) => rows.where((r) => r.run.id == runId).firstOrNull;

  /// The live view of [runId] (progress, queued position), if running.
  RunView? liveRun(String runId) =>
      live.where((r) => r.runId == runId).firstOrNull;

  RunLogState copyWith({
    bool? loading,
    RunFilter? filter,
    List<RunRow>? rows,
    Set<String>? expanded,
    List<RunView>? live,
    String? Function()? error,
  }) => RunLogState(
    loading: loading ?? this.loading,
    filter: filter ?? this.filter,
    rows: rows ?? this.rows,
    expanded: expanded ?? this.expanded,
    live: live ?? this.live,
    error: error == null ? this.error : error(),
  );

  @override
  List<Object?> get props => [loading, filter, rows, expanded, live, error];
}

/// The Runs tab and the run detail page: run docs mapped for this session
/// (review here or elsewhere, outcome unknown, Run again, undo window), the
/// live runs, and Stop / Run again / Undo / Retry failed.
class RunLogCubit extends Cubit<RunLogState> {
  RunLogCubit(
    this._runner,
    this._stores, {
    required String uid,
    RunFilter filter = const RunFilter(),
    DateTime Function() now = DateTime.now,
  }) : _now = now,
       super(RunLogState(filter: filter)) {
    _sub =
        Rx.combineLatest5(
          _stores.runs.watchRecent(),
          _stores.modules.watch(),
          _stores.automations.watch(),
          _stores.grants.watch(uid),
          _runner.activityChanges.startWith(_runner.activity),
          (runs, m, a, g, activity) => (
            runs: runs,
            automations: joinEntries(m, a, g, uid: uid).automations,
            activity: activity,
          ),
        ).listen(
          (s) {
            _last = s;
            _emitRows();
          },
          onError: (Object e) =>
              emit(state.copyWith(loading: false, error: () => '$e')),
        );
  }

  final AutomationRunnerApi _runner;
  final AutomationStores _stores;
  final DateTime Function() _now;
  late final StreamSubscription<Object?> _sub;
  ({
    List<RunRecord> runs,
    List<AutomationEntry> automations,
    RunActivity activity,
  })?
  _last;

  /// Runs fetched by id outside the 200-run window (an old run detail link).
  final _extra = <String, RunRecord>{};

  void _emitRows() {
    final s = _last;
    if (s == null || isClosed) return;
    final status = {for (final a in s.automations) a.automation.id: a.status};
    final live = {for (final r in s.activity.runs) r.runId};
    final ids = {for (final r in s.runs) r.id};
    emit(
      state.copyWith(
        loading: false,
        live: [
          for (final r in s.activity.runs)
            if (r.status != RunStatus.awaitingReview) r,
        ],
        rows: [
          for (final run in [
            ...s.runs,
            for (final r in _extra.values)
              if (!ids.contains(r.id)) r,
          ])
            runRowOf(
              run,
              sessionId: _runner.sessionId,
              hasReviewPlan: _runner.reviewPlan(run.id) != null,
              live: live.contains(run.id),
              canUndo: _runner.canUndo(run.id),
              now: _now(),
              automation: status[run.automationId],
            ),
        ],
      ),
    );
  }

  /// Makes sure [runId] has a row (the run detail of an older run).
  Future<void> load(String runId) async {
    if (state.row(runId) != null) return;
    final run = await _stores.runs.get(runId);
    if (run == null) return;
    _extra[runId] = run;
    _emitRows();
  }

  /// Re-maps the rows (the undo countdown passing its deadline).
  void refresh() => _emitRows();

  void setFilter(RunFilter filter) => emit(state.copyWith(filter: filter));

  /// "12 skipped — show".
  void expand(String groupKey) =>
      emit(state.copyWith(expanded: {...state.expanded, groupKey}));

  void stop(String runId) => _runner.stop(runId);

  /// Returns the new run's id, or null when refused.
  Future<String?> runAgain(String runId) async {
    String? id;
    await _guard(() async => id = await _runner.runAgain(runId));
    return id;
  }

  Future<bool> undo(String runId) => _guard(() => _runner.undo(runId));

  Future<bool> retryFailed(String runId) =>
      _guard(() => _runner.retryFailed(runId));

  /// Resume from a "Stopped after a crash" / "Paused" outcome.
  Future<bool> resume(String automationId) =>
      _guard(() => _runner.resume(automationId));

  void clearError() => emit(state.copyWith(error: () => null));

  Future<bool> _guard(Future<void> Function() action) async {
    emit(state.copyWith(error: () => null));
    try {
      await action();
      _emitRows(); // canUndo / reviewPlan changed underneath
      return true;
    } on AutomationRefused catch (e) {
      if (!isClosed) emit(state.copyWith(error: () => e.message));
      return false;
    }
  }

  @override
  Future<void> close() async {
    await _sub.cancel();
    return super.close();
  }
}
