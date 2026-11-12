import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/automation/runner_api.dart';
import 'package:morkva_crm/core/domain/automation/automation.dart';
import 'package:morkva_crm/design/design.dart';
import 'package:morkva_crm/features/automation/bloc/run_log_cubit.dart';
import 'package:morkva_crm/features/automation/view/automations_page.dart';

import 'automation_view_harness.dart';

void main() {
  late AutomationRig rig;

  setUp(() => rig = AutomationRig());
  tearDown(() => rig.dispose());

  Future<void> pump(
    WidgetTester tester, {
    AutomationsTab tab = AutomationsTab.modules,
    String? collectionId,
    RunFilterKind? filter,
    Size size = wideWindow,
    ThemeData? theme,
  }) async {
    setWindow(tester, size);
    await tester.pumpWidget(
      rig.wrap(
        AutomationsPage(
          tab: tab,
          collectionId: collectionId,
          filter: filter,
          now: () => fixtureNow,
        ),
        theme: theme,
      ),
    );
    await tester.pump();
  }

  Future<void> seedModule({bool consented = true}) async {
    final module = stampModule();
    await rig.stores.modules.save(module);
    if (consented) await rig.stores.grants.save(uid, consentTo(module));
  }

  group('Modules tab', () {
    testWidgets('empty: "No modules yet" with Ask Morkva and Import', (
      tester,
    ) async {
      await pump(tester);
      expect(find.text('No modules yet'), findsOneWidget);
      expect(find.text('Ask Morkva'), findsOneWidget);
      expect(find.text('Import module'), findsNWidgets(2));
    });

    testWidgets('a module card: version, status, permissions and source', (
      tester,
    ) async {
      await seedModule(consented: false);
      await pump(tester);
      expect(find.text('Automations'), findsWidgets);
      expect(find.text('Stamp shipped date'), findsOneWidget);
      expect(find.text('v1.0.0'), findsOneWidget);
      expect(find.text('Needs consent'), findsOneWidget);
      expect(find.textContaining('Read cards'), findsOneWidget);
      expect(find.textContaining('Imported · 0 automations'), findsOneWidget);
      await tester.tap(find.text('Stamp shipped date'));
      expectLastCall(rig.host.calls, 'openModule', [stampId]);
    });

    testWidgets('Ask Morkva entries hide when it is flagged off', (
      tester,
    ) async {
      rig.host.askEnabled = false;
      await seedModule();
      await pump(tester);
      expect(find.text('Ask Morkva to write one'), findsNothing);
      expect(find.text('Installed'), findsOneWidget);
    });

    testWidgets('import: the consent sheet preselects nothing', (tester) async {
      rig.host.file = (name: 'x.morkva.json', text: stampBundle().encode());
      await pump(tester);
      await tester.tap(find.text('Import module').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose file'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Allow "Stamp shipped date"?'), findsOneWidget);
      expect(find.text('Choose where it can work'), findsOneWidget);
      final allow = find.widgetWithText(PrimaryButton, 'Allow and install');
      expect(tester.widget<PrimaryButton>(allow).onPressed, isNull);

      await tester.tap(find.text('Orders'));
      await tester.pump();
      await tester.tap(allow);
      await tester.pumpAndSettle();
      final install = rig.runner.calls.singleWhere((c) => c.$1 == 'install');
      expect(install.$2[1], ['c_orders']);
    });
  });

  group('Automations tab', () {
    setUp(() async {
      await seedModule();
      await rig.stores.automations.save(
        automation(
          trigger: const ButtonTrigger(
            scope: ButtonScope.card,
            collectionId: 'c_orders',
          ),
        ),
      );
    });

    testWidgets('a row: when, do, apply chip; the switch saves at once', (
      tester,
    ) async {
      await pump(tester, tab: AutomationsTab.automations);
      expect(find.text('Stamp date when shipped'), findsOneWidget);
      expect(find.text('Button on a card'), findsOneWidget);
      expect(
        find.text('Do: Stamp shipped date › Stamp shipped date'),
        findsOneWidget,
      );
      expect(find.text('Ask first'), findsOneWidget);
      await tester.tap(find.byType(Switch));
      await tester.pump();
      final saved =
          rig.runner.calls
                  .singleWhere((c) => c.$1 == 'saveAutomation')
                  .$2
                  .single
              as AutomationRecord;
      expect(saved.enabled, isFalse);
    });

    testWidgets('the collection query shows one group with a clear chip', (
      tester,
    ) async {
      await pump(
        tester,
        tab: AutomationsTab.automations,
        collectionId: 'c_clients',
      );
      expect(find.text('No automations yet'), findsOneWidget);
      await tester.tap(find.text('Clients'));
      expect(rig.host.calls.last.$1, 'openAutomations');
      expect(rig.host.calls.last.$2[1], isNull);
    });
  });

  group('query in didUpdateWidget', () {
    testWidgets('a new tab and filter apply while mounted', (tester) async {
      await seedModule();
      await pump(tester);
      expect(find.text('No runs yet'), findsNothing);

      await pump(
        tester,
        tab: AutomationsTab.runs,
        filter: RunFilterKind.review,
      );
      await tester.pumpAndSettle();
      expect(rig.runLog.state.filter.kind, RunFilterKind.review);
      expect(find.text('No runs yet'), findsOneWidget);

      await rig.stores.automations.save(automation());
      await pump(
        tester,
        tab: AutomationsTab.automations,
        collectionId: 'c_orders',
      );
      await tester.pumpAndSettle();
      expect(find.text('Stamp date when shipped'), findsOneWidget);
      expect(rig.runLog.state.filter.kind, RunFilterKind.all);

      await pump(
        tester,
        tab: AutomationsTab.automations,
        collectionId: 'c_clients',
      );
      await tester.pumpAndSettle();
      expect(find.text('Stamp date when shipped'), findsNothing);
    });

    // Run detail → "Runs": the page under the detail route was offstage, so
    // its scrollable tab bar had no viewport when the tab changed.
    testWidgets('a tab change while coming back from offstage', (tester) async {
      setWindow(tester, wideWindow);
      Widget stack(AutomationsTab tab, {bool detail = false}) => rig.wrap(
        Navigator(
          pages: [
            MaterialPage(
              key: const ValueKey('/automations'),
              child: AutomationsPage(tab: tab, now: () => fixtureNow),
            ),
            if (detail)
              const MaterialPage(
                key: ValueKey('/automations/runs/r1'),
                child: Text('Run detail'),
              ),
          ],
          onDidRemovePage: (_) {},
        ),
      );
      await tester.pumpWidget(stack(AutomationsTab.modules, detail: true));
      await tester.pumpAndSettle();

      await tester.pumpWidget(stack(AutomationsTab.runs));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('No runs yet'), findsOneWidget);
    });
  });

  group('Runs tab', () {
    testWidgets('running now: Stop on a running row', (tester) async {
      rig.runner.activity = RunActivity(runs: [runView('r_live')]);
      await pump(tester, tab: AutomationsTab.runs);
      await tester.pump();
      expect(find.text('Running now'), findsOneWidget);
      await tester.tap(find.text('Stop'));
      expectLastCall(rig.runner.calls, 'stop', ['r_live']);
    });

    testWidgets('review here, Run again on a failed run, row → detail', (
      tester,
    ) async {
      await seedModule();
      await rig.stores.automations.save(automation());
      rig.runner.reviewPlans['r_review'] = const {'items': []};
      await rig.stores.runs.create(
        storedRun('r_review', status: RunStatus.awaitingReview),
      );
      await rig.stores.runs.create(
        storedRun(
          'r_failed',
          status: RunStatus.failed,
          reason: RunReason.moduleError,
          startedAt: fixtureNow.subtract(const Duration(minutes: 2)),
        ),
      );
      await pump(tester, tab: AutomationsTab.runs);
      expect(find.text('Review'), findsOneWidget);
      await tester.tap(find.text('Review'));
      expectLastCall(rig.host.calls, 'review', ['r_review']);

      expect(find.text('2 min ago'), findsOneWidget);
      await tester.tap(find.text('Run again on #1042'));
      await tester.pump();
      expect(rig.runner.methods, contains('runAgain'));

      await tester.tap(find.text('Module failed'));
      expectLastCall(rig.host.calls, 'openRun', ['r_failed']);
    });

    testWidgets('an undone run shows the muted undo glyph, not the check', (
      tester,
    ) async {
      await seedModule();
      await rig.stores.automations.save(automation());
      await rig.stores.runs.create(
        storedRun(
          'r_undone',
          status: RunStatus.succeeded,
        ).copyWith(undoneAt: () => fixtureNow),
      );
      await pump(tester, tab: AutomationsTab.runs);
      expect(find.byIcon(Icons.check_circle_outline), findsNothing);
      expect(find.byIcon(Icons.undo), findsOneWidget);
    });

    testWidgets('offline: Run again is disabled with the reason', (
      tester,
    ) async {
      rig.offline = true;
      await seedModule();
      await rig.stores.automations.save(automation());
      await rig.stores.runs.create(
        storedRun(
          'r_failed',
          status: RunStatus.failed,
          reason: RunReason.moduleError,
        ),
      );
      await pump(tester, tab: AutomationsTab.runs);
      expect(find.text('Needs a connection'), findsOneWidget);
    });

    testWidgets('a late offline change keeps the reason', (tester) async {
      await seedModule();
      await rig.stores.automations.save(automation());
      final ran = fixtureNow.subtract(const Duration(minutes: 2));
      final changed = fixtureNow.subtract(const Duration(minutes: 30));
      await rig.stores.runs.create(
        storedRun(
          'r_failed',
          status: RunStatus.failed,
          reason: RunReason.moduleError,
          startedAt: ran,
          changedAt: changed,
        ),
      );
      await pump(tester, tab: AutomationsTab.runs);
      expect(
        find.text(
          'Module failed · Changed offline ${clock(changed)} · ran ${clock(ran)}',
        ),
        findsOneWidget,
      );
    });

    testWidgets('the automation picker filters and clears', (tester) async {
      await seedModule();
      await rig.stores.automations.save(automation());
      await pump(tester, tab: AutomationsTab.runs);
      await tester.tap(find.text('Any automation'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Stamp date when shipped').last);
      await tester.pumpAndSettle();
      expect(rig.runLog.state.filter.automationId, 'a_1');

      await tester.tap(find.text('Stamp date when shipped'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Any automation').last);
      await tester.pumpAndSettle();
      expect(rig.runLog.state.filter.automationId, isNull);
    });

    testWidgets('opening the tab marks runs seen', (tester) async {
      expect(rig.runs.state.expiredSince, isNot(fixtureNow));
      await pump(tester, tab: AutomationsTab.runs);
      expect(rig.runs.state.expiredSince, fixtureNow);
    });
  });

  test('whenLine: one "starts matching" condition leads with its field', () {
    expect(
      whenLine(
        const EventTrigger(
          kind: TriggerKind.cardUpdated,
          collectionId: 'c_orders',
          where: [
            {'field': 'f_title', 'op': 'equals', 'value': 'Shipped'},
          ],
        ),
        orders,
      ),
      'When a card is updated · Title starts matching "is Shipped"',
    );
  });

  group('load failure', () {
    for (final (name, size) in [('wide', wideWindow), ('phone', phoneWindow)]) {
      for (final (tab, title) in [
        (AutomationsTab.modules, "Couldn't load modules"),
        (AutomationsTab.automations, "Couldn't load automations"),
        (AutomationsTab.runs, "Couldn't load runs"),
      ]) {
        testWidgets('$name ${tab.name}: "$title", no raw error', (
          tester,
        ) async {
          rig.stores.failAll();
          await pump(tester, tab: tab, size: size);
          await tester.pumpAndSettle();
          expect(find.text(title), findsOneWidget);
          expect(find.byType(CircularProgressIndicator), findsNothing);
          expect(find.textContaining('permission-denied'), findsNothing);
          expect(find.byType(SnackBar), findsNothing);
        });
      }
    }

    testWidgets('Retry subscribes again and shows the runs', (tester) async {
      rig.stores.failAll();
      await pump(tester, tab: AutomationsTab.runs);
      await tester.pumpAndSettle();
      expect(find.text("Couldn't load runs"), findsOneWidget);

      // The rules now allow it: each store has data again.
      await seedModule();
      await rig.stores.automations.save(automation());
      await rig.stores.runs.create(storedRun('r1', summary: 'Stamped #1042'));
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text("Couldn't load runs"), findsNothing);
      expect(find.text('Stamped #1042'), findsOneWidget);
    });
  });

  group('breakpoints and dark', () {
    for (final (name, size) in [
      ('tablet', tabletWindow),
      ('phone', phoneWindow),
    ]) {
      testWidgets('$name: every tab lays out', (tester) async {
        await seedModule();
        await rig.stores.automations.save(automation());
        await rig.stores.runs.create(storedRun('r1', summary: 'Stamped #1042'));
        for (final tab in AutomationsTab.values) {
          await pump(tester, tab: tab, size: size);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        expect(find.text('Stamped #1042'), findsOneWidget);
      });
    }

    testWidgets('wide: two module cards side by side', (tester) async {
      await seedModule();
      await rig.stores.modules.save(
        ModuleRecord.fromBundle(
          ModuleBundle.of({
            ...stampManifest(),
            'id': 'flag-low-stock',
            'name': 'Flag low stock',
          }, 'x'),
          source: ModuleSource.assistant,
          createdBy: 'agent:assistant',
          now: fixtureNow,
        ),
      );
      await pump(tester);
      final a = tester.getTopLeft(find.text('Flag low stock'));
      final b = tester.getTopLeft(find.text('Stamp shipped date'));
      expect(a.dy, b.dy);
      expect(find.textContaining('Made by Ask Morkva'), findsOneWidget);
    });

    testWidgets('1440 with the Ask panel beside the page: one column, '
        'no overflow', (tester) async {
      await seedModule();
      await rig.stores.modules.save(
        ModuleRecord.fromBundle(
          ModuleBundle.of({
            ...stampManifest(),
            'id': 'flag-low-stock',
            'name': 'Flag low stock',
          }, 'x'),
          source: ModuleSource.assistant,
          createdBy: 'agent:assistant',
          now: fixtureNow,
        ),
      );
      await rig.stores.automations.save(automation());
      await rig.stores.runs.create(
        storedRun('r1', status: RunStatus.failed, reason: RunReason.internal),
      );
      setWindow(tester, wideWindow);
      for (final tab in AutomationsTab.values) {
        await tester.pumpWidget(
          rig.wrap(
            Align(
              alignment: Alignment.topLeft,
              // 1440 − the 272 sidebar − the 440 Ask panel.
              child: SizedBox(
                width: 728,
                child: AutomationsPage(tab: tab, now: () => fixtureNow),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (tab == AutomationsTab.modules) {
          final a = tester.getTopLeft(find.text('Flag low stock'));
          final b = tester.getTopLeft(find.text('Stamp shipped date'));
          expect(a.dx, b.dx);
          expect(a.dy, isNot(b.dy));
        }
      }
    });

    testWidgets('phone: no page title (the shell header has it)', (
      tester,
    ) async {
      await pump(tester, size: phoneWindow);
      expect(
        find.text(
          'Modules add actions. Automations put them on buttons or run them '
          'when cards change.',
        ),
        findsNothing,
      );
    });

    testWidgets('dark theme renders', (tester) async {
      await seedModule(consented: false);
      await pump(tester, theme: AppTheme.dark);
      expect(tester.takeException(), isNull);
      expect(find.text('Needs consent'), findsOneWidget);
    });
  });
}
