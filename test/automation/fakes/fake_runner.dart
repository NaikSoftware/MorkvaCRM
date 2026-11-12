import 'dart:async';

import 'package:morkva_crm/core/automation/runner_api.dart';
import 'package:morkva_crm/core/domain/automation/automation.dart';

/// A scriptable [AutomationRunnerApi] for cubit and widget tests: records
/// every call in [calls] (`(method, args)`), returns what the test set, and
/// pushes activity and finish events on demand.
final class FakeRunner implements AutomationRunnerApi {
  final calls = <(String, List<Object?>)>[];

  @override
  String sessionId = 't_test';

  /// What [validate] returns (and [saveAutomation] throws when non-empty).
  List<AutomationProblem> problems = const [];

  TestRunResult testRunResult = const TestRunResult(
    status: RunStatus.succeeded,
    summary: 'No changes',
  );

  final lastChecksBy = <String, List<LastCheck>>{};
  final reviewPlans = <String, Map<String, Object?>>{};
  final undoable = <String>{};

  /// Thrown by the next call that returns a Future, then cleared.
  Object? failNext;

  int _runs = 0;
  RunActivity _activity = RunActivity.idle;
  final _activityChanges = StreamController<RunActivity>.broadcast();
  final _finished = StreamController<RunView>.broadcast();

  /// The names of the recorded calls, in order.
  List<String> get methods => [for (final (m, _) in calls) m];

  set activity(RunActivity value) {
    _activity = value;
    _activityChanges.add(value);
  }

  void finish(RunView run) => _finished.add(run);

  Future<void> dispose() async {
    await _activityChanges.close();
    await _finished.close();
  }

  Future<T> _record<T>(String method, List<Object?> args, T result) async {
    calls.add((method, args));
    final error = failNext;
    if (error != null) {
      failNext = null;
      throw error;
    }
    return result;
  }

  String _nextRunId() => 'run_${++_runs}';

  @override
  RunActivity get activity => _activity;

  @override
  Stream<RunActivity> get activityChanges => _activityChanges.stream;

  @override
  Stream<RunView> get finished => _finished.stream;

  @override
  Future<String> pressCard(String automationId, {required String cardId}) =>
      _record('pressCard', [automationId, cardId], _nextRunId());

  @override
  Future<String> pressCollection(
    String automationId, {
    required List<String> cardIds,
    String? viewId,
  }) =>
      _record('pressCollection', [automationId, cardIds, viewId], _nextRunId());

  @override
  Future<String> runAgain(String runId) =>
      _record('runAgain', [runId], _nextRunId());

  @override
  void stop(String runId) => calls.add(('stop', [runId]));

  @override
  Future<void> approve(String runId, {Set<String>? itemIds}) =>
      _record('approve', [runId, itemIds], null);

  @override
  Future<void> reject(String runId) => _record('reject', [runId], null);

  @override
  Future<void> undo(String runId) => _record('undo', [runId], null);

  @override
  Future<void> retryFailed(String runId) =>
      _record('retryFailed', [runId], null);

  @override
  bool canUndo(String runId) => undoable.contains(runId);

  @override
  Map<String, Object?>? reviewPlan(String runId) => reviewPlans[runId];

  @override
  Future<void> install(
    ModuleBundle bundle, {
    required List<String>? collections,
  }) => _record('install', [bundle, collections], null);

  @override
  Future<void> allow(
    ModuleBundle displayed, {
    required List<String>? collections,
  }) => _record('allow', [displayed, collections], null);

  @override
  Future<void> changeAccess(
    String moduleId, {
    required List<String>? collections,
  }) => _record('changeAccess', [moduleId, collections], null);

  @override
  Future<void> setAutoApply(String moduleId, {required bool on}) =>
      _record('setAutoApply', [moduleId, on], null);

  @override
  Future<void> revoke(String moduleId) => _record('revoke', [moduleId], null);

  @override
  Future<void> uninstall(String moduleId) =>
      _record('uninstall', [moduleId], null);

  @override
  Future<List<AutomationProblem>> validate(AutomationRecord draft) =>
      _record('validate', [draft], problems);

  @override
  Future<void> saveAutomation(AutomationRecord automation) async {
    await _record('saveAutomation', [automation], null);
    if (problems.isNotEmpty) throw ManifestProblems(problems);
  }

  @override
  Future<void> deleteAutomation(String automationId) =>
      _record('deleteAutomation', [automationId], null);

  @override
  Future<void> resume(String automationId) =>
      _record('resume', [automationId], null);

  @override
  Future<TestRunResult> testRun(TestRunRequest request) =>
      _record('testRun', [request], testRunResult);

  @override
  List<LastCheck> lastChecks(String automationId, {int limit = 20}) =>
      (lastChecksBy[automationId] ?? const []).take(limit).toList();
}
