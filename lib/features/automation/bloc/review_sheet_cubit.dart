import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/automation/runner_api.dart';
import '../../../core/domain/automation/automation.dart';

/// Where the review sheet is (UX §6).
enum ReviewPhase {
  /// The PlanCard with Approve / Reject.
  review,

  /// Approve is in flight (the PlanCard's progress bar).
  applying,

  /// Approved or rejected; [ReviewSheetState.next] offers the next review,
  /// else the sheet closes.
  done,

  /// The plan is gone (a reload, the TTL): "This review expired." + Run
  /// again.
  expired,
}

/// Approve refused: the runner's sentence, and whether Run again helps.
typedef ReviewRefusal = ({String code, String message, bool runAgain});

final class ReviewSheetState extends Equatable {
  const ReviewSheetState({
    required this.runId,
    required this.phase,
    this.run,
    this.record,
    this.plan,
    this.selection,
    this.refusal,
    this.reviewsLeft = const [],
  });

  final String runId;
  final ReviewPhase phase;

  /// The live run (this session).
  final RunView? run;

  /// The run doc (module name, automation name, receipt after approve).
  final RunRecord? record;

  /// The sealed plan JSON for the PlanCard.
  final Map<String, Object?>? plan;

  /// The ticked item ids (null = all).
  final Set<String>? selection;
  final ReviewRefusal? refusal;

  /// Other runs waiting for review here, oldest first.
  final List<String> reviewsLeft;

  /// "Next review (49 left)" after a decision.
  String? get next =>
      phase == ReviewPhase.done ? reviewsLeft.firstOrNull : null;

  /// The header line: "Module · Stamp shipped date (stamp-shipped-date) ·
  /// Stamp when shipped".
  String? get provenance {
    final m = module;
    if (m == null) return null;
    return ['Module · ${m.name} (${m.id})', ?automationName].join(' · ');
  }

  /// The module, for `PlanCard(provenance:)`.
  ({String id, String name})? get module {
    final id = record?.moduleId ?? run?.moduleId;
    return id == null ? null : (id: id, name: record?.moduleName ?? id);
  }

  String? get automationName => record?.automationName ?? run?.label;

  /// Applied with failures: the sheet keeps the AppliedCard ("Updated 190,
  /// 10 failed · Retry failed") instead of closing.
  bool get partlyFailed =>
      phase == ReviewPhase.done && (record?.receipt?.failed ?? 0) > 0;

  RunTrigger? get trigger => record?.trigger ?? run?.trigger;

  ReviewSheetState copyWith({
    ReviewPhase? phase,
    RunView? Function()? run,
    RunRecord? Function()? record,
    Map<String, Object?>? Function()? plan,
    Set<String>? Function()? selection,
    ReviewRefusal? Function()? refusal,
    List<String>? reviewsLeft,
  }) => ReviewSheetState(
    runId: runId,
    phase: phase ?? this.phase,
    run: run == null ? this.run : run(),
    record: record == null ? this.record : record(),
    plan: plan == null ? this.plan : plan(),
    selection: selection == null ? this.selection : selection(),
    refusal: refusal == null ? this.refusal : refusal(),
    reviewsLeft: reviewsLeft ?? this.reviewsLeft,
  );

  @override
  List<Object?> get props => [
    runId,
    phase,
    run,
    record,
    plan,
    selection,
    refusal,
    reviewsLeft,
  ];
}

/// Approve refusals Run again can't fix: offline (approve again later) and
/// a review another window took over.
const Set<String> _noRunAgain = {'offline', 'superseded', 'replaced'};

/// One run waiting for review: its PlanCard, approve / reject, Run again,
/// and Next review.
class ReviewSheetCubit extends Cubit<ReviewSheetState> {
  ReviewSheetCubit(this._runner, this._stores, {required String runId})
    : super(_initial(_runner, runId)) {
    _subs = [
      _runner.activityChanges.listen(_activity),
      _stores.runs.watchRecent().listen((runs) {
        final record = runs.where((r) => r.id == state.runId).firstOrNull;
        if (record != null) emit(state.copyWith(record: () => record));
      }),
    ];
    unawaited(_loadRecord());
  }

  final AutomationRunnerApi _runner;
  final AutomationStores _stores;
  late final List<StreamSubscription<Object?>> _subs;

  static ReviewSheetState _initial(AutomationRunnerApi runner, String runId) {
    final plan = runner.reviewPlan(runId);
    return ReviewSheetState(
      runId: runId,
      phase: plan == null ? ReviewPhase.expired : ReviewPhase.review,
      plan: plan,
      run: runner.activity.runs.where((r) => r.runId == runId).firstOrNull,
      reviewsLeft: _reviews(runner.activity, except: runId),
    );
  }

  static List<String> _reviews(
    RunActivity activity, {
    required String except,
  }) => [
    for (final r in [
      ...activity.runs.where(
        (r) => r.status == RunStatus.awaitingReview && r.runId != except,
      ),
    ]..sort((a, b) => a.startedAt.compareTo(b.startedAt)))
      r.runId,
  ];

  Future<void> _loadRecord() async {
    final record = await _stores.runs.get(state.runId);
    if (!isClosed && record != null && state.record == null) {
      emit(state.copyWith(record: () => record));
    }
  }

  void _activity(RunActivity activity) {
    final run = activity.runs.where((r) => r.runId == state.runId).firstOrNull;
    final gone =
        state.phase == ReviewPhase.review &&
        _runner.reviewPlan(state.runId) == null;
    emit(
      state.copyWith(
        run: () => run,
        reviewsLeft: _reviews(activity, except: state.runId),
        phase: gone ? ReviewPhase.expired : null,
        plan: gone ? () => null : null,
      ),
    );
  }

  /// The PlanCard's ticks.
  void select(Set<String> itemIds) =>
      emit(state.copyWith(selection: () => itemIds));

  Future<void> approve() async {
    emit(state.copyWith(phase: ReviewPhase.applying, refusal: () => null));
    try {
      await _runner.approve(state.runId, itemIds: state.selection);
      // The receipt decides whether the sheet closes: read it before done.
      final record = await _stores.runs.get(state.runId);
      if (isClosed) return;
      emit(
        state.copyWith(
          phase: ReviewPhase.done,
          record: record == null ? null : () => record,
        ),
      );
    } on AutomationRefused catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          phase: ReviewPhase.review,
          refusal: () => (
            code: e.code,
            message: e.message,
            runAgain: !_noRunAgain.contains(e.code),
          ),
        ),
      );
    }
  }

  Future<void> reject() async {
    try {
      await _runner.reject(state.runId);
      if (!isClosed) emit(state.copyWith(phase: ReviewPhase.done));
    } on AutomationRefused catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          refusal: () => (code: e.code, message: e.message, runAgain: false),
        ),
      );
    }
  }

  /// The AppliedCard's "Retry failed".
  Future<void> retryFailed() =>
      _decided(() => _runner.retryFailed(state.runId));

  /// The AppliedCard's Undo.
  Future<void> undo() => _decided(() => _runner.undo(state.runId));

  Future<void> _decided(Future<void> Function() action) async {
    try {
      await action();
      final record = await _stores.runs.get(state.runId);
      if (!isClosed && record != null) {
        emit(state.copyWith(record: () => record, refusal: () => null));
      }
    } on AutomationRefused catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          refusal: () => (code: e.code, message: e.message, runAgain: false),
        ),
      );
    }
  }

  /// Run again (expired, refused): returns the new run's id; the new run
  /// opens its own review when it seals.
  Future<String?> runAgain() async {
    try {
      return await _runner.runAgain(state.runId);
    } on AutomationRefused catch (e) {
      if (!isClosed) {
        emit(
          state.copyWith(
            refusal: () => (code: e.code, message: e.message, runAgain: false),
          ),
        );
      }
      return null;
    }
  }

  /// "Next review (N left)": the sheet shows the oldest waiting review.
  void openNext() {
    final next = state.next;
    if (next == null) return;
    final fresh = _initial(_runner, next);
    emit(fresh);
    unawaited(_loadRecord());
  }

  @override
  Future<void> close() async {
    for (final s in _subs) {
      await s.cancel();
    }
    return super.close();
  }
}
