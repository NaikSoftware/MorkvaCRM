import 'package:equatable/equatable.dart';

import '../domain/automation/automation.dart';

/// What the app (cubits and widgets) asks of the automation runner. The
/// runner implements it together with [RunnerHooks]; the UI never reaches
/// the harness or the engine directly, and reads records from the stores.
///
/// Every `runId` here is one of this session's runs ([RunActivity.runs]) or
/// a run doc's id; calls on an unknown or finished run are no-ops.
abstract interface class AutomationRunnerApi implements RunnerHooks {
  /// This session's live runs and device state, now.
  RunActivity get activity;

  /// [activity] after every change.
  Stream<RunActivity> get activityChanges;

  /// A run of this session that reached `awaiting_review` or a terminal
  /// status: the finish snackbar / in-editor banner.
  Stream<RunView> get finished;

  // ------------------------------------------------------------------- runs

  /// Presses a card button; returns the new run's id (it may be skipped at
  /// once, with the reason on its [RunView]).
  Future<String> pressCard(String automationId, {required String cardId});

  /// Presses a collection button over the current view's shown cards
  /// (≤ 500, display order).
  Future<String> pressCollection(
    String automationId, {
    required List<String> cardIds,
    String? viewId,
  });

  /// A manual re-run of [runId]'s automation on its stored trigger snapshot;
  /// returns the new run's id.
  Future<String> runAgain(String runId);

  /// Stops a queued or running run.
  void stop(String runId);

  /// Applies a run waiting for review ([itemIds]: the selected plan items,
  /// null = all), after a live consent and code-hash re-check.
  Future<void> approve(String runId, {Set<String>? itemIds});

  Future<void> reject(String runId);

  /// Undoes an applied run while this session's journal still holds it.
  Future<void> undo(String runId);

  Future<void> retryFailed(String runId);

  /// Whether [undo] can still work for [runId] (same session, journal TTL).
  bool canUndo(String runId);

  /// The sealed plan of a run waiting for review, as plan JSON for the
  /// PlanCard; null once it is gone (applied, rejected, expired, reload).
  Map<String, Object?>? reviewPlan(String runId);

  // ---------------------------------------------------------------- modules

  /// Installs an imported bundle (new, or replacing the installed version)
  /// and records the consent to exactly this bundle.
  Future<void> install(
    ModuleBundle bundle, {
    required List<String>? collections,
  });

  /// Consents to an installed module as [displayed] in the consent sheet
  /// (first consent or re-consent after a change). The hash is of
  /// [displayed], never of a re-read; auto-apply starts off.
  Future<void> allow(
    ModuleBundle displayed, {
    required List<String>? collections,
  });

  /// Changes the consent's collections (null = all); caps stay.
  Future<void> changeAccess(
    String moduleId, {
    required List<String>? collections,
  });

  /// The module-details switch, the only writer of `autoApply: true`.
  Future<void> setAutoApply(String moduleId, {required bool on});

  /// Deletes the consent: queued runs are skipped, pending reviews rejected.
  Future<void> revoke(String moduleId);

  /// Deletes the module, its automations and its consent; queued runs are
  /// skipped and pending reviews rejected. Run history stays.
  Future<void> uninstall(String moduleId);

  // ------------------------------------------------------------ automations

  /// The save-time checks of [draft] (the editor's, the planner's and the
  /// runner's, shared): empty when it may be saved.
  Future<List<AutomationProblem>> validate(AutomationRecord draft);

  /// Validates, then saves; throws [ManifestProblems] with the problems.
  Future<void> saveAutomation(AutomationRecord automation);

  Future<void> deleteAutomation(String automationId);

  /// Clears a `loop_suspected` / `crashed` pause.
  Future<void> resume(String automationId);
}

/// This session's live runs and the device-wide state for the indicator.
final class RunActivity extends Equatable {
  const RunActivity({
    this.runs = const [],
    this.engineUnavailable = false,
    this.autoPausedUntil,
  });

  static const RunActivity idle = RunActivity();

  /// Queued, running, sealing, applying and awaiting-review runs, in queue
  /// order (reviews last).
  final List<RunView> runs;

  /// The sandbox can't start on this device: runs are skipped and logged.
  final bool engineUnavailable;

  /// The workspace auto-apply budget is spent until then ("Auto-apply
  /// paused for 10 min").
  final DateTime? autoPausedUntil;

  /// "Running · N": queued + running (incl. sealing and applying).
  int get active =>
      runs.where((r) => r.status != RunStatus.awaitingReview).length;

  int get needsReview =>
      runs.where((r) => r.status == RunStatus.awaitingReview).length;

  /// The live run of [automationId] on [cardId] (a pressed button's
  /// spinner), if any.
  RunView? runOf(String automationId, {String? cardId}) {
    for (final r in runs) {
      if (r.automationId == automationId &&
          (cardId == null || r.trigger.cardId == cardId)) {
        return r;
      }
    }
    return null;
  }

  @override
  List<Object?> get props => [runs, engineUnavailable, autoPausedUntil];
}

/// One run as the UI sees it, live or just finished.
final class RunView extends Equatable {
  const RunView({
    required this.runId,
    required this.moduleId,
    required this.actionId,
    required this.label,
    required this.status,
    required this.trigger,
    required this.startedAt,
    this.automationId,
    this.reason,
    this.queuedAhead,
    this.progress,
    this.summary,
    this.planId,
    this.error,
    this.links = const [],
  });

  final String runId;
  final String? automationId;
  final String moduleId;
  final String actionId;

  /// The button label or the action label.
  final String label;
  final RunStatus status;
  final RunReason? reason;
  final RunTrigger trigger;
  final DateTime startedAt;

  /// `queued` only: runs ahead of it ("Queued · 3 ahead").
  final int? queuedAhead;

  /// `running` (module progress) or `applying` (commit progress).
  final RunProgress? progress;
  final String? summary;
  final String? planId;
  final RunError? error;

  /// `ui.open` chips (one becomes "Open #1042" on the snackbar).
  final List<UiLink> links;

  bool get isButton => trigger.kind == TriggerKind.button;

  @override
  List<Object?> get props => [
    runId,
    automationId,
    moduleId,
    actionId,
    label,
    status,
    reason,
    trigger,
    startedAt,
    queuedAhead,
    progress,
    summary,
    planId,
    error,
    links,
  ];
}

/// `done` of `total`, with an optional label (≤ 60 chars).
final class RunProgress extends Equatable {
  const RunProgress({required this.done, required this.total, this.label});

  final int done;
  final int total;
  final String? label;

  @override
  List<Object?> get props => [done, total, label];
}
