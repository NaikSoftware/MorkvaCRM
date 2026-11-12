import 'package:equatable/equatable.dart';

import 'run_record.dart';

/// What the harness's module ops need from the automation runner, which is
/// built after the harness: late-bound on `AutomationCatalog.hooks`. Domain
/// types, so the harness can name them without importing lib/core/automation.
abstract interface class RunnerHooks {
  /// A dry run of one action: the plan is built, never sealed or committed,
  /// and nothing is written to `runs`. Bypasses the queue. A module that is
  /// not `ok` comes back `skipped` with the reason.
  Future<TestRunResult> testRun(TestRunRequest request);

  /// The latest evaluations of an event automation, newest first (an
  /// in-memory ring of 20).
  List<LastCheck> lastChecks(String automationId, {int limit = 20});
}

/// A test run's input; refs are already resolved to ids under the module's
/// effective grants.
final class TestRunRequest extends Equatable {
  const TestRunRequest({
    required this.moduleId,
    required this.actionId,
    this.cardId,
    this.collectionId,
    this.params = const {},
  });

  final String moduleId;
  final String actionId;

  /// A card action's card.
  final String? cardId;

  /// A collection action's collection (or the card's).
  final String? collectionId;
  final Map<String, Object?> params;

  @override
  List<Object?> get props => [moduleId, actionId, cardId, collectionId, params];
}

/// A test run's outcome (`modules.testRun`, the Test-run sheet, the chat's
/// test-run card).
final class TestRunResult extends Equatable {
  const TestRunResult({
    required this.status,
    this.reason,
    this.summary,
    this.plan = const [],
    this.log = RunLog.empty,
    this.error,
  });

  static const int kMaxPlanRows = 20;
  static const int kMaxLogBytes = 8 * 1024;

  /// `succeeded`, `failed`, `timedOut` or `skipped`.
  final RunStatus status;
  final RunReason? reason;
  final String? summary;
  final List<PlanLine> plan;

  /// Calls and console lines.
  final RunLog log;
  final RunError? error;

  /// The `modules.testRun` result: plan ≤ 20 rows, log ≤ 8 KB.
  Map<String, Object?> toJson() {
    final log = decodeRunLog(
      encodeRunLog(
        RunLog(calls: this.log.calls, console: this.log.console),
        maxBytes: kMaxLogBytes,
      ),
    );
    return {
      'status': status.wire,
      'reason': ?reason?.wire,
      'summary': ?summary,
      'plan': [for (final p in plan.take(kMaxPlanRows)) p.toJson()],
      'log': {
        'calls': [for (final c in log.calls) c.toJson()],
        'console': [for (final c in log.console) c.toJson()],
      },
      'error': ?error?.toJson(),
    };
  }

  @override
  List<Object?> get props => [status, reason, summary, plan, log, error];
}

enum LastCheckResult {
  ran('ran'),
  notRun('not_run'),
  skipped('skipped');

  const LastCheckResult(this.wire);

  final String wire;
}

/// One evaluation of an event automation: "#1042 · 12:04 · 'Status is
/// Shipped' was false after the change → didn't run".
final class LastCheck extends Equatable {
  const LastCheck({
    required this.cardLabel,
    required this.at,
    required this.result,
    required this.why,
  });

  final String cardLabel;
  final DateTime at;
  final LastCheckResult result;
  final String why;

  Map<String, Object?> toJson() => {
    'cardLabel': cardLabel,
    'at': at.toUtc().toIso8601String(),
    'result': result.wire,
    'why': why,
  };

  @override
  List<Object?> get props => [cardLabel, at, result, why];
}
