import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/automation/runner_api.dart';
import 'package:morkva_crm/core/domain/automation/automation.dart';
import 'package:morkva_crm/features/automation/bloc/automation_runs_cubit.dart';

import 'automation_fixtures.dart';

void main() {
  late FakeRunner runner;
  late FakeStores stores;
  late DateTime clock;

  setUp(() {
    runner = FakeRunner();
    stores = FakeStores();
    clock = fixtureNow;
  });

  tearDown(() async {
    await runner.dispose();
    await stores.dispose();
  });

  AutomationRunsCubit build() =>
      AutomationRunsCubit(runner, stores.stores, now: () => clock);

  test('starts from the runner\'s current activity', () async {
    runner.activity = RunActivity(runs: [runView('run_1')]);
    final cubit = build();
    expect(cubit.state.running, 1);
    expect(cubit.primary, IndicatorState.running);
    await cubit.close();
  });

  blocTest<AutomationRunsCubit, AutomationRunsState>(
    'running and needs-review counts come from this session only',
    build: build,
    act: (cubit) async {
      // A review held by another window: a doc, never a count.
      await stores.runs.create(
        runRecord(
          'run_x',
          status: RunStatus.awaitingReview,
          sessionId: 't_other',
        ),
      );
      runner.activity = RunActivity(
        runs: [
          runView('run_1'),
          runView('run_2', status: RunStatus.queued),
          runView('run_3', status: RunStatus.awaitingReview),
        ],
      );
      await settle();
    },
    verify: (cubit) {
      expect(cubit.state.running, 2);
      expect(cubit.state.needsReview, 1);
      expect(cubit.primary, IndicatorState.running);
    },
  );

  test('attention: failures and actionable skips since the Runs tab', () async {
    // Before this session: not unseen.
    await stores.runs.create(
      runRecord(
        'run_old',
        status: RunStatus.failed,
        reason: RunReason.moduleError,
        startedAt: fixtureNow.subtract(const Duration(hours: 1)),
      ),
    );
    final cubit = build();
    await settle();
    expect(cubit.primary, IndicatorState.idle);

    clock = fixtureNow.add(const Duration(minutes: 1));
    await stores.runs.create(
      runRecord(
        'run_f',
        status: RunStatus.timedOut,
        startedAt: clock,
        endedAt: clock,
      ),
    );
    await stores.runs.create(
      runRecord(
        'run_s',
        status: RunStatus.skipped,
        reason: RunReason.needsConsent,
        startedAt: clock,
      ),
    );
    // Not actionable: no attention.
    await stores.runs.create(
      runRecord(
        'run_c',
        status: RunStatus.skipped,
        reason: RunReason.cardGone,
        startedAt: clock,
      ),
    );
    await settle();
    expect(cubit.state.failed, 1);
    expect(cubit.state.didntRun, 1);
    expect(cubit.primary, IndicatorState.attention);

    clock = clock.add(const Duration(seconds: 1));
    cubit.markRunsSeen();
    expect(cubit.state.failed + cubit.state.didntRun, 0);
    expect(cubit.primary, IndicatorState.idle);
    await cubit.close();
  });

  test('reviews expired after a reload: own session, not superseded', () async {
    final cubit = build();
    await stores.runs.create(
      runRecord('run_e', status: RunStatus.expired, endedAt: fixtureNow),
    );
    await stores.runs.create(
      runRecord(
        'run_sup',
        status: RunStatus.expired,
        reason: RunReason.superseded,
        endedAt: fixtureNow,
      ),
    );
    await stores.runs.create(
      runRecord(
        'run_other',
        status: RunStatus.expired,
        sessionId: 't_other',
        endedAt: fixtureNow,
      ),
    );
    await settle();
    expect(cubit.state.expired(runner.sessionId), 1);
    expect(cubit.primary, IndicatorState.reviewsExpired);
    await cubit.close();
  });

  test('engine warning only while an automation is enabled', () async {
    runner.activity = const RunActivity(engineUnavailable: true);
    final cubit = build();
    await settle();
    expect(cubit.primary, IndicatorState.idle);
    await stores.automations.save(automation());
    await settle();
    expect(cubit.primary, IndicatorState.engineUnavailable);
    await stores.automations.save(automation(enabled: false));
    await settle();
    expect(cubit.state.engineWarning, isFalse);
    await cubit.close();
  });

  test('needs review outranks attention', () async {
    final cubit = build();
    await stores.runs.create(
      runRecord('run_f', status: RunStatus.failed, startedAt: fixtureNow),
    );
    runner.activity = RunActivity(
      runs: [runView('run_r', status: RunStatus.awaitingReview)],
    );
    await settle();
    expect(cubit.primary, IndicatorState.needsReview);
    await cubit.close();
  });

  test('a press while that run is live focuses it, no second run', () async {
    runner.activity = RunActivity(
      runs: [runView('run_live', status: RunStatus.awaitingReview)],
    );
    final cubit = build();
    expect(await cubit.pressCard('a_1', cardId: 'b_1042'), 'run_live');
    expect(
      await cubit.pressCollection('a_1', cardIds: const ['b_1']),
      'run_live',
    );
    expect(runner.calls, isEmpty);
    expect(await cubit.pressCard('a_1', cardId: 'b_7'), 'run_1');
    expect(await cubit.pressCard('a_2', cardId: 'b_1042'), 'run_2');
    expect(runner.methods, ['pressCard', 'pressCard']);
    await cubit.close();
  });

  test('Stop, Undo and Run again; refusals land in state', () async {
    final cubit = build();
    cubit.stop('run_1');
    expect(await cubit.undo('run_1'), isTrue);
    expect(await cubit.runAgain('run_1'), 'run_1');
    expect(runner.methods, ['stop', 'undo', 'runAgain']);
    runner.failNext = const AutomationRefused(
      'offline',
      'Couldn\'t apply — you\'re offline',
    );
    expect(await cubit.pressCard('a_9', cardId: 'b_1'), isNull);
    expect(cubit.state.error, 'Couldn\'t apply — you\'re offline');
    cubit.clearError();
    expect(cubit.state.error, isNull);
    await cubit.close();
  });

  group('finish routing', () {
    blocTest<AutomationRunsCubit, AutomationRunsState>(
      'a button run waiting for review opens the review sheet',
      build: build,
      act: (_) async {
        runner.finish(runView('run_1', status: RunStatus.awaitingReview));
        await settle();
      },
      verify: (cubit) =>
          expect(cubit.state.notice?.surface, NoticeSurface.reviewSheet),
    );

    test('the open card editor gets a banner, never a snackbar', () async {
      final cubit = build();
      cubit.editorOpened();
      runner.finish(runView('run_1', status: RunStatus.succeeded));
      await settle();
      expect(cubit.state.notice, isNotNull);
      expect(cubit.state.notice!.surface, NoticeSurface.banner);
      expect(cubit.state.notice!.run.runId, 'run_1');

      // An event run's review while the editor is up: still the banner.
      runner.finish(
        runView(
          'run_2',
          status: RunStatus.awaitingReview,
          kind: TriggerKind.cardUpdated,
        ),
      );
      await settle();
      expect(cubit.state.notice!.surface, NoticeSurface.banner);

      cubit.editorClosed();
      runner.finish(runView('run_3', status: RunStatus.failed));
      await settle();
      expect(cubit.state.notice!.surface, NoticeSurface.snackbar);
      cubit.noticeShown();
      expect(cubit.state.notice, isNull);
      await cubit.close();
    });
  });
}
