import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/automation/runner_api.dart';
import 'package:morkva_crm/core/domain/automation/automation.dart';

import '../../../automation/fakes/fake_runner.dart';
import '../../../automation/fakes/fake_stores.dart';
import 'fixtures.dart';

void main() {
  group('runner contract (FakeRunner)', () {
    test('validate returns the problems and save refuses with them', () async {
      final runner = FakeRunner();
      final draft = automation();
      expect(await runner.validate(draft), isEmpty);
      runner.problems = const [
        AutomationProblem('name', 'missing', 'Give it a name'),
      ];
      expect(await runner.validate(draft), runner.problems);
      await expectLater(
        runner.saveAutomation(draft),
        throwsA(
          isA<ManifestProblems>().having(
            (e) => e.problems,
            'problems',
            runner.problems,
          ),
        ),
      );
      expect(runner.methods, ['validate', 'validate', 'saveAutomation']);
      expect(runner.calls.first.$2, [draft]);
      await runner.dispose();
    });

    test('runs get ids, activity and finish events are pushed', () async {
      final runner = FakeRunner();
      expect(await runner.pressCard('a_1', cardId: 'b_1'), 'run_1');
      expect(await runner.runAgain('run_1'), 'run_2');
      final view = RunView(
        runId: 'run_1',
        automationId: 'a_1',
        moduleId: 'stamp-shipped-date',
        actionId: 'stamp',
        label: 'Stamp',
        status: RunStatus.awaitingReview,
        trigger: const RunTrigger(
          kind: TriggerKind.button,
          collectionId: 'c_orders',
          cardId: 'b_1',
        ),
        startedAt: DateTime.utc(2026, 11, 12),
      );
      final queued = RunView(
        runId: 'run_2',
        automationId: 'a_2',
        moduleId: 'stamp-shipped-date',
        actionId: 'stamp',
        label: 'Stamp',
        status: RunStatus.queued,
        queuedAhead: 1,
        trigger: const RunTrigger(
          kind: TriggerKind.cardUpdated,
          collectionId: 'c_orders',
        ),
        startedAt: DateTime.utc(2026, 11, 12),
      );
      final activity = expectLater(
        runner.activityChanges,
        emits(RunActivity(runs: [queued, view])),
      );
      final finished = expectLater(runner.finished, emits(view));
      runner.activity = RunActivity(runs: [queued, view]);
      runner.finish(view);
      await activity;
      await finished;
      expect(runner.activity.active, 1);
      expect(runner.activity.needsReview, 1);
      expect(runner.activity.runOf('a_1', cardId: 'b_1'), view);
      expect(runner.activity.runOf('a_1', cardId: 'b_2'), isNull);

      runner.failNext = StateError('offline');
      await expectLater(runner.approve('run_1'), throwsStateError);
      await runner.reject('run_1');
      expect(runner.methods.last, 'reject');
      await runner.dispose();
    });
  });

  test('a test-run result caps its plan and log for modules.testRun', () {
    final result = TestRunResult(
      status: RunStatus.failed,
      reason: RunReason.moduleError,
      plan: [
        for (var i = 0; i < 30; i++)
          PlanLine(kind: 'updateCard', label: '#$i', change: 'a → b'),
      ],
      log: RunLog(
        console: [
          for (var i = 0; i < 100; i++)
            ConsoleLine(t: i, level: 'info', text: 'x' * 400),
        ],
      ),
      error: const RunError(code: 'module_error', message: 'boom'),
    );
    final json = result.toJson();
    expect(json['status'], 'failed');
    expect(json['reason'], 'module_error');
    expect(json['plan'] as List, hasLength(TestRunResult.kMaxPlanRows));
    final log = json['log']! as Map<String, Object?>;
    expect(
      utf8.encode(jsonEncode(log)).length,
      lessThanOrEqualTo(TestRunResult.kMaxLogBytes),
    );
    expect(log['console'] as List, isNotEmpty);
    expect(
      LastCheck(
        cardLabel: '#1042',
        at: DateTime.utc(2026, 11, 12, 12, 4),
        result: LastCheckResult.notRun,
        why: "'Status is Shipped' was false after the change",
      ).toJson()['result'],
      'not_run',
    );
  });

  group('fake stores', () {
    test('watch replays the current docs and every change', () async {
      final fakes = FakeAutomationStores();
      final a = automation();
      await fakes.automations.save(a);
      expect(await fakes.automations.watch().first, [a]);
      final later = expectLater(
        fakes.automations.watch(),
        emitsInOrder([
          [a],
          isEmpty,
        ]),
      );
      await fakes.automations.delete(a.id);
      await later;
      await fakes.dispose();
    });

    test('a malformed consent reads as none', () async {
      final fakes = FakeAutomationStores();
      await fakes.grants.save('u1', consent());
      expect(await fakes.grants.get('u1', 'stamp-shipped-date'), consent());
      expect(await fakes.grants.get('u2', 'stamp-shipped-date'), isNull);
      fakes.grants.putRaw('u1', 'stamp-shipped-date', {
        ...consent().toJson(),
        'caps': ['*'],
      });
      expect(await fakes.grants.get('u1', 'stamp-shipped-date'), isNull);
      expect(await fakes.grants.watch('u1').first, isEmpty);
      await fakes.dispose();
    });
  });
}
