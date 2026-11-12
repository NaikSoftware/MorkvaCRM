import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/automation/runner_api.dart';
import 'package:morkva_crm/core/domain/automation/automation.dart';
import 'package:morkva_crm/features/automation/bloc/automation_runs_cubit.dart';
import 'package:morkva_crm/features/automation/widgets/run_indicator.dart';

import 'automation_widget_rig.dart';

void main() {
  late AutomationRig rig;

  setUp(() => rig = AutomationRig());

  Widget all() => const Column(
    children: [
      RunIndicatorPill(),
      RunIndicatorRailIcon(),
      RunIndicatorButton(idle: Text('synced')),
    ],
  );

  /// Lets the indicator's spinners run without settling.
  Future<void> frames(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('idle: no pill, a plain bolt, the phone slot keeps sync', (
    tester,
  ) async {
    await rig.setUp();
    addTearDown(rig.dispose);
    await pumpRig(tester, rig, all());
    expect(find.text('synced'), findsOneWidget);
    expect(find.byKey(const ValueKey('indicator-ring')), findsNothing);
    expect(find.byKey(const ValueKey('review-badge')), findsNothing);
    expect(find.byTooltip('Automations'), findsOneWidget);
  });

  testWidgets('running: pill, rings and a second amber badge for reviews', (
    tester,
  ) async {
    await rig.setUp();
    addTearDown(rig.dispose);
    rig.runner.activity = RunActivity(
      runs: [
        liveRun('run_1'),
        liveRun('run_2', status: RunStatus.queued, cardId: 'b_2'),
        liveRun('run_3', status: RunStatus.awaitingReview, cardId: 'b_3'),
      ],
    );
    await pumpRig(tester, rig, all());
    await frames(tester);
    expect(find.text('Running · 2'), findsOneWidget);
    // The pill's badge, the rail's and the phone's.
    expect(find.byKey(const ValueKey('review-badge')), findsNWidgets(3));
    expect(find.byKey(const ValueKey('indicator-ring')), findsNWidgets(2));
    expect(find.text('synced'), findsNothing);
    expect(
      find.byTooltip('Automations · 2 automations running, 1 need review'),
      findsOneWidget,
    );
  });

  testWidgets('needs review: amber pill and a count on the bolt', (
    tester,
  ) async {
    await rig.setUp();
    addTearDown(rig.dispose);
    rig.runner.activity = RunActivity(
      runs: [
        liveRun('run_1', status: RunStatus.awaitingReview),
        liveRun('run_2', status: RunStatus.awaitingReview, cardId: 'b_2'),
      ],
    );
    await pumpRig(tester, rig, all());
    expect(find.text('2 need review'), findsOneWidget);
    expect(find.text('2'), findsNWidgets(2));
    expect(
      find.bySemanticsLabel('Automations, 2 automations need review'),
      findsNWidgets(2),
    );
  });

  testWidgets('attention: unseen failures until the Runs tab opens', (
    tester,
  ) async {
    await rig.setUp();
    addTearDown(rig.dispose);
    final later = fixtureNow.add(const Duration(minutes: 1));
    await rig.stores.runs.create(
      runRecord(
        'run_f',
        status: RunStatus.failed,
        reason: RunReason.moduleError,
        endedAt: later,
        startedAt: later,
        error: const RunError(code: 'module_error', message: 'TypeError'),
      ),
    );
    await rig.stores.runs.create(
      runRecord(
        'run_s',
        status: RunStatus.skipped,
        reason: RunReason.notSettled,
        endedAt: later,
        startedAt: later,
      ),
    );
    await pumpRig(tester, rig, all());
    expect(find.text('1 failed'), findsOneWidget);
    expect(find.byKey(const ValueKey('indicator-dot')), findsNWidgets(3));
    expect(
      find.byTooltip("1 failed, 1 automation didn't run"),
      findsNWidgets(2),
    );

    rig.clock = later.add(const Duration(minutes: 1));
    rig.runs.markRunsSeen();
    await tester.pump();
    await tester.pump();
    expect(find.text('1 failed'), findsNothing);
    expect(find.text('synced'), findsOneWidget);
  });

  test('a tap goes to the Runs tab, filtered by what needs the user', () {
    IndicatorView view(RunActivity activity) => IndicatorView(
      AutomationRunsState(
        seenAt: fixtureNow,
        expiredSince: fixtureNow,
        activity: activity,
      ),
      't_test',
    );
    expect(
      view(RunActivity(runs: [liveRun('r')])).path,
      '/automations?tab=runs',
    );
    expect(
      view(
        RunActivity(runs: [liveRun('r', status: RunStatus.awaitingReview)]),
      ).path,
      '/automations?tab=runs&filter=review',
    );
    expect(view(RunActivity.idle).idle, isTrue);
  });
}
