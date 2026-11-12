import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/automation/runner_api.dart';
import 'package:morkva_crm/core/domain/automation/automation.dart';
import 'package:morkva_crm/features/automation/bloc/review_sheet_cubit.dart';

import 'automation_fixtures.dart';

void main() {
  late FakeRunner runner;
  late FakeStores stores;

  setUp(() async {
    runner = FakeRunner();
    stores = FakeStores();
    runner.reviewPlans['run_1'] = const {'planId': 'p_1'};
    runner.reviewPlans['run_old'] = const {'planId': 'p_0'};
    runner.reviewPlans['run_new'] = const {'planId': 'p_2'};
    runner.activity = RunActivity(
      runs: [
        runView('run_1', status: RunStatus.awaitingReview),
        runView(
          'run_new',
          status: RunStatus.awaitingReview,
          startedAt: fixtureNow.add(const Duration(minutes: 5)),
        ),
        runView(
          'run_old',
          status: RunStatus.awaitingReview,
          startedAt: fixtureNow.subtract(const Duration(minutes: 5)),
        ),
      ],
    );
    await stores.runs.create(
      runRecord('run_1', status: RunStatus.awaitingReview),
    );
  });

  tearDown(() async {
    await runner.dispose();
    await stores.dispose();
  });

  ReviewSheetCubit build([String runId = 'run_1']) =>
      ReviewSheetCubit(runner, stores.stores, runId: runId);

  blocTest<ReviewSheetCubit, ReviewSheetState>(
    'opens on the sealed plan with its provenance',
    build: build,
    act: (_) => settle(),
    verify: (cubit) {
      final s = cubit.state;
      expect(s.phase, ReviewPhase.review);
      expect(s.plan, {'planId': 'p_1'});
      expect(
        s.provenance,
        'Module · Stamp shipped date (stamp-shipped-date) · Stamp when shipped',
      );
      expect(s.trigger?.cardLabel, '#1042');
      expect(s.reviewsLeft, ['run_old', 'run_new']);
      expect(s.next, isNull);
    },
  );

  test('approve with the ticks, then Next review (oldest first)', () async {
    final cubit = build();
    cubit.select({'i_1'});
    await cubit.approve();
    expect(runner.calls.single.$1, 'approve');
    expect(runner.calls.single.$2, [
      'run_1',
      {'i_1'},
    ]);
    expect(cubit.state.phase, ReviewPhase.done);
    expect(cubit.state.next, 'run_old');

    cubit.openNext();
    expect(cubit.state.runId, 'run_old');
    expect(cubit.state.phase, ReviewPhase.review);
    expect(cubit.state.plan, {'planId': 'p_0'});
    expect(cubit.state.selection, isNull);
    await cubit.close();
  });

  test('a refused approve: permissions changed offers Run again', () async {
    final cubit = build();
    runner.failNext = const AutomationRefused(
      'needs_consent',
      'This module\'s permissions changed — run it again.',
    );
    await cubit.approve();
    expect(cubit.state.phase, ReviewPhase.review);
    expect(cubit.state.refusal?.message, contains('permissions changed'));
    expect(cubit.state.refusal?.runAgain, isTrue);
    expect(await cubit.runAgain(), 'run_1');
    expect(runner.methods.last, 'runAgain');

    runner.failNext = const AutomationRefused(
      'superseded',
      'This review was replaced in another window.',
    );
    await cubit.approve();
    expect(cubit.state.refusal?.runAgain, isFalse);
    await cubit.close();
  });

  test('reject closes; nothing waiting means no Next', () async {
    runner.activity = RunActivity(
      runs: [runView('run_1', status: RunStatus.awaitingReview)],
    );
    final cubit = build();
    await cubit.reject();
    expect(cubit.state.phase, ReviewPhase.done);
    expect(cubit.state.next, isNull);
    await cubit.close();
  });

  test('no plan (after a reload): expired, Run again', () async {
    final cubit = build('run_gone');
    expect(cubit.state.phase, ReviewPhase.expired);
    expect(cubit.state.plan, isNull);
    await cubit.runAgain();
    expect(runner.calls.single.$2, ['run_gone']);
    await cubit.close();
  });

  test('a plan dropped while open turns the sheet expired', () async {
    final cubit = build();
    runner.reviewPlans.remove('run_1');
    runner.activity = RunActivity(runs: [runView('run_old')]);
    await settle();
    expect(cubit.state.phase, ReviewPhase.expired);
    expect(cubit.state.run, isNull);
    await cubit.close();
  });
}
