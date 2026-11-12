import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/automation/runner_api.dart';
import 'package:morkva_crm/core/domain/automation/automation.dart';
import 'package:morkva_crm/features/automation/bloc/run_log_cubit.dart';
import 'package:morkva_crm/features/automation/widgets/reason_copy.dart';

import 'automation_fixtures.dart';

void main() {
  group('runRowOf', () {
    RunRow row(
      RunRecord run, {
      bool hasReviewPlan = false,
      bool live = false,
      bool canUndo = false,
      DateTime? now,
      AutomationStatus? automation = AutomationStatus.active,
    }) => runRowOf(
      run,
      sessionId: 't_test',
      hasReviewPlan: hasReviewPlan,
      live: live,
      canUndo: canUndo,
      now: now ?? fixtureNow,
      automation: automation,
    );

    test('a review this session holds: Review', () {
      final r = row(
        runRecord('r', status: RunStatus.awaitingReview),
        hasReviewPlan: true,
      );
      expect(r.display, RunDisplay.reviewHere);
      expect(r.action, RunRowAction.review);
    });

    test('a review of another window or an earlier start: Run again', () {
      for (final r in [
        row(
          runRecord(
            'r',
            status: RunStatus.awaitingReview,
            sessionId: 't_other',
          ),
          hasReviewPlan: true,
        ),
        row(runRecord('r', status: RunStatus.awaitingReview)),
      ]) {
        expect(r.display, RunDisplay.reviewNotHere);
        expect(r.copy, same(kReviewNotHereCopy));
        expect(r.action, RunRowAction.runAgain);
      }
    });

    test('applying elsewhere is an unknown outcome, never Run again', () {
      final foreign = row(
        runRecord('r', status: RunStatus.applying, sessionId: 't_other'),
      );
      expect(foreign.display, RunDisplay.outcomeUnknown);
      expect(foreign.copy.row, 'Outcome unknown');
      expect(foreign.action, RunRowAction.none);

      final approving = row(
        runRecord(
          'r',
          status: RunStatus.awaitingReview,
          applyStartedAt: fixtureNow,
          sessionId: 't_other',
        ),
      );
      expect(approving.display, RunDisplay.outcomeUnknown);

      final here = row(runRecord('r', status: RunStatus.applying), live: true);
      expect(here.display, RunDisplay.applyingHere);
      expect(here.copy.row, 'Applying…');
    });

    test('interrupted: outcome unknown, "Check the card"', () {
      final r = row(
        runRecord('r', status: RunStatus.failed, reason: RunReason.interrupted),
      );
      expect(r.display, RunDisplay.outcomeUnknown);
      expect(r.copy.advice?.text, 'Check the card');
      expect(r.action, RunRowAction.none);
    });

    test('Run again: replaced by the fix, hidden when unsafe', () {
      final failed = runRecord(
        'r',
        status: RunStatus.failed,
        reason: RunReason.moduleError,
      );
      expect(row(failed).action, RunRowAction.runAgain);
      expect(
        row(failed, automation: AutomationStatus.needsConsent).action,
        RunRowAction.reviewPermissions,
      );
      expect(
        row(failed, automation: AutomationStatus.broken).action,
        RunRowAction.editAutomation,
      );
      // The automation is gone.
      expect(row(failed, automation: null).action, RunRowAction.none);
      expect(
        row(
          runRecord(
            'r',
            status: RunStatus.skipped,
            reason: RunReason.notSettled,
            kind: TriggerKind.cardDeleted,
          ),
        ).action,
        RunRowAction.none,
      );
      expect(
        row(
          runRecord(
            'r',
            status: RunStatus.failed,
            reason: RunReason.internal,
            receipt: const RunReceipt(unconfirmed: 2),
          ),
        ).action,
        RunRowAction.none,
      );
      expect(row(runRecord('r')).action, RunRowAction.none);
      expect(
        row(runRecord('r', status: RunStatus.expired)).action,
        RunRowAction.runAgain,
      );
    });

    test('the undo window', () {
      final applied = runRecord('r', journalId: 'j_1', endedAt: fixtureNow);
      final available = row(applied, canUndo: true);
      expect(available.undo, UndoState.available);
      expect(available.undoUntil, fixtureNow.add(kUndoWindow));
      expect(
        row(applied, now: fixtureNow.add(const Duration(minutes: 2))).undo,
        UndoState.afterReload,
      );
      expect(
        row(applied, now: fixtureNow.add(const Duration(minutes: 11))).undo,
        UndoState.expired,
      );
      expect(
        row(
          runRecord(
            'r',
            journalId: 'j_1',
            endedAt: fixtureNow,
            undoneAt: fixtureNow,
          ),
          canUndo: true,
        ).undo,
        UndoState.undone,
      );
      expect(row(runRecord('r')).undo, UndoState.none);
    });
  });

  group('groupRuns', () {
    RunRow skip(String id, RunReason reason) => runRowOf(
      runRecord(id, status: RunStatus.skipped, reason: reason),
      sessionId: 't_test',
      hasReviewPlan: false,
      live: false,
      canUndo: false,
      now: fixtureNow,
      automation: AutomationStatus.active,
    );

    test('more than 3 skips in a row with one reason fold', () {
      final rows = [
        for (var i = 0; i < 5; i++) skip('s$i', RunReason.notSettled),
        skip('t0', RunReason.loop),
        skip('t1', RunReason.loop),
        skip('t2', RunReason.loop),
      ];
      final entries = groupRuns(rows, const {});
      expect(entries.length, 4);
      expect((entries.first as RunEntryGroup).rows.length, 5);
      expect(entries.skip(1).every((e) => e is RunEntryRow), isTrue);
      expect(groupRuns(rows, const {'s0'}).length, 8);
    });
  });

  group('RunLogCubit', () {
    late FakeRunner runner;
    late FakeStores stores;

    setUp(() async {
      runner = FakeRunner();
      stores = FakeStores();
      final module = stampModule();
      await stores.modules.save(module);
      await stores.grants.save(uid, consentTo(module));
      await stores.automations.save(automation());
    });

    tearDown(() async {
      await runner.dispose();
      await stores.dispose();
    });

    RunLogCubit build({RunFilter filter = const RunFilter()}) => RunLogCubit(
      runner,
      stores.stores,
      uid: uid,
      filter: filter,
      now: () => fixtureNow,
    );

    Future<void> seedRuns() async {
      await stores.runs.create(
        runRecord(
          'run_ok',
          startedAt: fixtureNow.add(const Duration(minutes: 3)),
          touched: const ['b_7'],
          cardId: 'b_7',
        ),
      );
      await stores.runs.create(
        runRecord(
          'run_review',
          status: RunStatus.awaitingReview,
          startedAt: fixtureNow.add(const Duration(minutes: 2)),
        ),
      );
      await stores.runs.create(
        runRecord(
          'run_fail',
          status: RunStatus.failed,
          reason: RunReason.moduleError,
          startedAt: fixtureNow.add(const Duration(minutes: 1)),
        ),
      );
      await stores.runs.create(
        runRecord(
          'run_skip',
          status: RunStatus.skipped,
          reason: RunReason.needsConsent,
          automationId: 'a_2',
        ),
      );
    }

    blocTest<RunLogCubit, RunLogState>(
      'maps runs for this session, newest first',
      setUp: () async {
        await seedRuns();
        runner.reviewPlans['run_review'] = const {'planId': 'p_1'};
      },
      build: build,
      act: (_) => settle(),
      verify: (cubit) {
        final s = cubit.state;
        expect(
          [for (final r in s.rows) r.run.id],
          ['run_ok', 'run_review', 'run_fail', 'run_skip'],
        );
        expect(s.row('run_review')?.action, RunRowAction.review);
        expect(s.row('run_fail')?.action, RunRowAction.runAgain);
        // Its automation doesn't exist.
        expect(s.row('run_skip')?.action, RunRowAction.none);
        expect(s.needsReview, 1);
      },
    );

    test('filters: review, failed, automation, card', () async {
      await seedRuns();
      final cubit = build();
      await settle();
      List<String> ids() => [
        for (final e in cubit.state.entries) (e as RunEntryRow).row.run.id,
      ];
      cubit.setFilter(const RunFilter(kind: RunFilterKind.review));
      expect(ids(), ['run_review']);
      cubit.setFilter(const RunFilter(kind: RunFilterKind.failed));
      expect(ids(), ['run_fail', 'run_skip']);
      cubit.setFilter(const RunFilter(automationId: 'a_2'));
      expect(ids(), ['run_skip']);
      cubit.setFilter(const RunFilter(cardId: 'b_7'));
      expect(ids(), ['run_ok']);
      await cubit.close();
    });

    test('running now: live runs, reviews left out', () async {
      final cubit = build();
      runner.activity = RunActivity(
        runs: [
          runView('run_1'),
          runView('run_2', status: RunStatus.awaitingReview),
        ],
      );
      await settle();
      expect([for (final r in cubit.state.live) r.runId], ['run_1']);
      expect(cubit.state.liveRun('run_1')?.status, RunStatus.running);
      await cubit.close();
    });

    test('a run detail outside the 200-run window is fetched', () async {
      await stores.runs.create(runRecord('run_old'));
      for (var i = 0; i < 200; i++) {
        await stores.runs.create(
          runRecord(
            'run_$i',
            startedAt: fixtureNow.add(Duration(seconds: i + 1)),
          ),
        );
      }
      final cubit = build();
      await settle();
      expect(cubit.state.rows.length, 200);
      expect(cubit.state.row('run_old'), isNull);
      await cubit.load('run_old');
      expect(cubit.state.row('run_old')?.run.id, 'run_old');
      await cubit.close();
    });

    test('Run again, Undo, Retry failed and Stop go to the runner', () async {
      await seedRuns();
      final cubit = build();
      await settle();
      expect(await cubit.runAgain('run_fail'), 'run_1');
      await cubit.undo('run_ok');
      await cubit.retryFailed('run_ok');
      cubit.stop('run_1');
      expect(runner.methods, ['runAgain', 'undo', 'retryFailed', 'stop']);

      runner.failNext = const AutomationRefused(
        'expired',
        'Undo isn\'t available after a reload',
      );
      expect(await cubit.undo('run_ok'), isFalse);
      expect(cubit.state.error, 'Undo isn\'t available after a reload');
      await cubit.close();
    });

    test('undo state follows the runner after an undo', () async {
      await stores.runs.create(
        runRecord('run_a', journalId: 'j_1', endedAt: fixtureNow),
      );
      runner.undoable.add('run_a');
      final cubit = build();
      await settle();
      expect(cubit.state.row('run_a')?.undo, UndoState.available);
      runner.undoable.clear();
      await cubit.undo('run_a');
      expect(cubit.state.row('run_a')?.undo, UndoState.afterReload);
      await cubit.close();
    });
  });
}
