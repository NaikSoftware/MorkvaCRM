import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/automation/automation.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/design/design.dart';
import 'package:morkva_crm/features/automation/view/automations_page.dart';
import 'package:morkva_crm/features/automation/view/module_details_page.dart';

import '../../collections/fake_data_repository.dart';
import 'automation_view_harness.dart';

void main() {
  late AutomationRig rig;
  late ModuleRecord module;

  setUp(() async {
    rig = AutomationRig();
    module = stampModule();
    await rig.stores.modules.save(module);
  });
  tearDown(() => rig.dispose());

  Future<void> pump(
    WidgetTester tester, {
    Size size = wideWindow,
    ThemeData? theme,
  }) async {
    setWindow(tester, size);
    rig.detailsOf(stampId);
    await tester.pumpWidget(
      rig.wrap(ModuleDetailsPage(now: () => fixtureNow), theme: theme),
    );
    await tester.pump();
  }

  Future<void> consent({bool autoApply = false}) =>
      rig.stores.grants.save(uid, consentTo(module, autoApply: autoApply));

  testWidgets('never consented: allow banner → consent sheet → Allow', (
    tester,
  ) async {
    await pump(tester);
    expect(find.textContaining('Allow this module to run.'), findsOneWidget);
    expect(find.text('Allow this module first'), findsWidgets);
    final test = find.widgetWithText(TextActionButton, 'Test run');
    expect(tester.widget<TextActionButton>(test).onPressed, isNull);
    expect(find.text('Change access'), findsNothing);

    await tester.tap(find.text('Review permissions'));
    await tester.pumpAndSettle();
    expect(find.text('Allow "Stamp shipped date"?'), findsOneWidget);
    final allow = find.widgetWithText(PrimaryButton, 'Allow');
    expect(tester.widget<PrimaryButton>(allow).onPressed, isNull);
    await tester.tap(find.text('All collections'));
    await tester.pump();
    await tester.tap(allow);
    await tester.pumpAndSettle();
    final call = rig.runner.calls.singleWhere((c) => c.$1 == 'allow');
    expect(call.$2[1], isNull);
  });

  testWidgets('code changed: the changed banner names both versions', (
    tester,
  ) async {
    await consent();
    await rig.stores.modules.save(
      stampModule(
        bundle: stampBundle(code: 'v2()', version: '1.1.0'),
      ),
    );
    await pump(tester);
    expect(
      find.textContaining('This module changed (v1.0.0 → v1.1.0).'),
      findsOneWidget,
    );
    await tester.tap(find.text('Review changes'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Code changed: v1.0.0 → v1.1.0'),
      findsOneWidget,
    );
  });

  testWidgets('change access saves the new collections', (tester) async {
    await consent();
    await pump(tester);
    expect(find.text('Installed'), findsOneWidget);
    expect(find.textContaining('In Orders'), findsWidgets);
    await tester.tap(find.text('Change access'));
    await tester.pumpAndSettle();
    expect(find.text('Change access for "Stamp shipped date"'), findsOneWidget);
    expect(find.text('It can:'), findsNothing);
    await tester.tap(find.text('Clients'));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final call = rig.runner.calls.singleWhere((c) => c.$1 == 'changeAccess');
    expect(call.$2, [
      stampId,
      ['c_clients', 'c_orders'],
    ]);
  });

  testWidgets('revoke asks first, then revokes', (tester) async {
    await consent();
    await pump(tester);
    await tester.tap(find.text('Revoke'));
    await tester.pumpAndSettle();
    expect(
      find.text('Revoke access for "Stamp shipped date"?'),
      findsOneWidget,
    );
    await tester.tap(find.text('Revoke').last);
    await tester.pumpAndSettle();
    expect(rig.runner.methods, contains('revoke'));
  });

  testWidgets('auto-apply: turning it on confirms first', (tester) async {
    await consent();
    await pump(tester);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(
      find.text("Apply this module's changes automatically?"),
      findsOneWidget,
    );
    await tester.tap(find.text('Turn on'));
    await tester.pumpAndSettle();
    expectLastCall(rig.runner.calls, 'setAutoApply', [stampId, true]);
  });

  testWidgets('menu: export saves the file, uninstall confirms and leaves', (
    tester,
  ) async {
    await consent();
    await pump(tester);
    final more = tester.getSize(
      find.byWidgetPredicate((w) => w is PopupMenuButton).first,
    );
    expect(more.shortestSide, greaterThanOrEqualTo(44));
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();
    expect(rig.host.calls.last.$1, 'saveFile');
    expect(rig.host.calls.last.$2.first, '$stampId.morkva.json');
    expect(find.text('Exported $stampId.morkva.json'), findsOneWidget);

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Uninstall'));
    await tester.pumpAndSettle();
    expect(find.text('Uninstall "Stamp shipped date"?'), findsOneWidget);
    expect(
      find.text(
        'Its pending reviews are dropped and its permissions are removed. '
        'The run history stays.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Uninstall').last);
    await tester.pumpAndSettle();
    expect(rig.runner.methods, contains('uninstall'));
    expectLastCall(rig.host.calls, 'openAutomations');
  });

  testWidgets('actions: Add to a button opens the editor preset', (
    tester,
  ) async {
    await consent();
    await pump(tester);
    await tester.tap(find.text('Add to a button'));
    expectLastCall(rig.host.calls, 'newAutomation', [stampId, 'stamp', null]);
    expect(find.text('No automations use it yet.'), findsOneWidget);
  });

  testWidgets(
    'Test run offers only the consented collections and their cards',
    (tester) async {
      await consent();
      rig.data = FakeDataRepository([orders, clients])
        ..seedObjects('c_orders', [
          MorkvaObject.create(
            id: 'b_1042',
            collection: orders,
            values: const {'f_title': TextFieldValue('#1042 · Acme')},
            createdAt: fixtureNow,
            updatedAt: fixtureNow,
          ),
        ]);
      await pump(tester);
      await tester.ensureVisible(find.text('Test run'));
      await tester.tap(find.text('Test run'));
      await tester.pumpAndSettle();
      final dropdown = tester.widget<DropdownButton<String>>(
        // The first is Collection; the action's params follow.
        find.byType(DropdownButton<String>).first,
      );
      expect([for (final i in dropdown.items!) i.value], ['c_orders']);
      expect(find.text('#1042 · Acme'), findsOneWidget);
    },
  );

  testWidgets('a module that is gone says so', (tester) async {
    await rig.stores.modules.delete(stampId);
    await pump(tester);
    expect(find.text("This module isn't installed"), findsOneWidget);
  });

  testWidgets('wide: two columns; phone: one; dark renders', (tester) async {
    await consent();
    await pump(tester);
    final about = tester.getTopLeft(find.text('About'));
    final can = tester.getTopLeft(find.text('What it can do'));
    expect((about.dy - can.dy).abs(), lessThan(32));
    expect(about.dx, greaterThan(can.dx));

    await pump(tester, size: phoneWindow);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      tester.getTopLeft(find.text('About')).dy,
      lessThan(tester.getTopLeft(find.text('What it can do')).dy),
    );

    await pump(tester, theme: AppTheme.dark);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a page narrowed by the Ask panel stacks its sections', (
    tester,
  ) async {
    await consent();
    setWindow(tester, wideWindow);
    rig.detailsOf(stampId);
    await tester.pumpWidget(
      rig.wrap(
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 728,
            child: ModuleDetailsPage(now: () => fixtureNow),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      tester.getTopLeft(find.text('About')).dy,
      lessThan(tester.getTopLeft(find.text('What it can do')).dy),
    );
  });

  testWidgets('All runs opens the Runs tab filtered to the module', (
    tester,
  ) async {
    await consent();
    await pump(tester);
    await tester.scrollUntilVisible(find.text('All runs'), 200);
    await tester.tap(find.text('All runs'));
    expectLastCall(rig.host.calls, 'openAutomations', [
      AutomationsTab.runs,
      null,
      null,
      null,
      stampId,
    ]);
  });

  testWidgets('a failed load: "Couldn\'t load this module" + Retry', (
    tester,
  ) async {
    rig.stores.failAll();
    await pump(tester);
    await tester.pump();
    await tester.pump();
    expect(find.text("Couldn't load this module"), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('permission-denied'), findsNothing);

    // The rules allow it again: every store reads.
    await rig.stores.modules.save(module);
    await consent();
    await rig.stores.automations.save(automation());
    await rig.stores.runs.create(storedRun('r1'));
    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump();
    expect(find.text("Couldn't load this module"), findsNothing);
  });
}
