import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/automation/runner_api.dart';
import 'package:morkva_crm/core/domain/automation/automation.dart';
import 'package:morkva_crm/design/design.dart';
import 'package:morkva_crm/features/automation/widgets/collection_actions_menu.dart';

import 'automation_widget_rig.dart';

void main() {
  late AutomationRig rig;

  setUp(() => rig = AutomationRig());

  final flag = buttonAutomation(
    'a_flag',
    'Flag low stock',
    scope: ButtonScope.collection,
  );
  final clear = buttonAutomation(
    'a_clear',
    'Clear low-stock flags',
    scope: ButtonScope.collection,
    order: 1,
  );

  CollectionScope scope({bool filtered = true}) => CollectionScope(
    collection: orders,
    shownCardIds: const ['b_1', 'b_2', 'b_3'],
    filtered: filtered,
    viewId: 'v_all',
  );

  List<Object?>? argsOf(String method) => [
    for (final (m, args) in rig.runner.calls)
      if (m == method) args,
  ].lastOrNull;

  testWidgets('Actions ▾: the buttons with what they run on, then links', (
    tester,
  ) async {
    await rig.setUp(automations: [flag, clear]);
    addTearDown(rig.dispose);
    await pumpRig(
      tester,
      rig,
      Align(
        alignment: Alignment.topRight,
        child: CollectionActionsMenu(scope: scope()),
      ),
    );
    await tester.tap(find.text('Actions'));
    await tester.pumpAndSettle();
    expect(find.text('Flag low stock'), findsOneWidget);
    expect(find.text('Clear low-stock flags'), findsOneWidget);
    expect(find.text('Runs on 3 shown cards'), findsNWidgets(2));
    expect(find.text('Automations for Orders…'), findsOneWidget);
    expect(find.text('New automation…'), findsOneWidget);

    await tester.tap(find.text('Flag low stock'));
    await tester.pumpAndSettle();
    expect(argsOf('pressCollection'), [
      'a_flag',
      ['b_1', 'b_2', 'b_3'],
      'v_all',
    ]);
  });

  testWidgets('no filters: "Runs on all N cards"', (tester) async {
    await rig.setUp(automations: [flag]);
    addTearDown(rig.dispose);
    await pumpRig(
      tester,
      rig,
      CollectionActionsMenu(scope: scope(filtered: false)),
    );
    await tester.tap(find.text('Actions'));
    await tester.pumpAndSettle();
    expect(find.text('Runs on all 3 cards'), findsOneWidget);
  });

  testWidgets('narrow: icon-only with the Actions tooltip', (tester) async {
    await rig.setUp(automations: [flag]);
    addTearDown(rig.dispose);
    await pumpRig(
      tester,
      rig,
      CollectionActionsMenu(scope: scope(), narrow: true),
    );
    expect(find.text('Actions'), findsNothing);
    expect(find.byTooltip('Actions'), findsOneWidget);
    await tester.tap(find.byTooltip('Actions'));
    await tester.pumpAndSettle();
    expect(find.text('Flag low stock'), findsOneWidget);
  });

  testWidgets('without the app wiring nothing shows', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: CollectionActionsMenu(scope: scope())),
      ),
    );
    expect(find.text('Actions'), findsNothing);
  });

  testWidgets('a running collection button: the header pill', (tester) async {
    await rig.setUp(automations: [flag]);
    addTearDown(rig.dispose);
    rig.runner.activity = RunActivity(
      runs: [
        liveRun(
          'run_1',
          automationId: 'a_flag',
          cardId: null,
          label: 'Flag low stock',
        ),
      ],
    );
    await pumpRig(
      tester,
      rig,
      const CollectionRunPill(collectionId: 'c_orders'),
    );
    expect(find.text('Running Flag low stock…'), findsOneWidget);
  });

  testWidgets('phone More rows: Run action… opens the Actions sheet', (
    tester,
  ) async {
    await rig.setUp(automations: [flag]);
    addTearDown(rig.dispose);
    await pumpRig(
      tester,
      rig,
      Builder(
        builder: (context) => PopupMenuButton<void>(
          tooltip: 'More',
          itemBuilder: (_) => collectionPhoneMenuItems(context, scope()),
        ),
      ),
      size: const Size(390, 844),
    );
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    expect(find.text('Automations…'), findsOneWidget);
    await tester.tap(find.text('Run action…'));
    await tester.pumpAndSettle();
    expect(find.text('Runs on 3 shown cards'), findsOneWidget);
    await tester.tap(find.text('Flag low stock'));
    await tester.pumpAndSettle();
    expect(argsOf('pressCollection'), [
      'a_flag',
      ['b_1', 'b_2', 'b_3'],
      'v_all',
    ]);
  });
}
