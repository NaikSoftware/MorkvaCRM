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

    testWidgets('re-import of an installed module keeps its collections', (
      tester,
    ) async {
      await seedModule();
      rig.host.file = (name: 'x.morkva.json', text: stampBundle().encode());
      await pump(tester);
      await tester.tap(find.text('Import module').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose file'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      final allow = find.widgetWithText(PrimaryButton, 'Allow and install');
      expect(tester.widget<PrimaryButton>(allow).onPressed, isNotNull);
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
      await seedModule();
      await rig.stores.automations.save(automation());
      rig.runner.activity = RunActivity(runs: [runView('r_live')]);
      await pump(tester, tab: AutomationsTab.runs);
      await tester.pump();
      expect(find.text('Running now'), findsOneWidget);
      // A 14 / 600 title in a short band, not the 44 px section row.
      final title = tester.widget<Text>(find.text('Running now')).style!;
      expect((title.fontSize, title.fontWeight), (14, FontWeight.w600));
      // Titled like the rows below: automation · action.
      expect(
        find.text('Stamp date when shipped · Mark shipped'),
        findsOneWidget,
      );
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
        storedRun('r_review', status: RunStatus.awaitingReview).copyWith(
          planTitle: () => 'Set Shipped on to Nov 12, 2026 · 1 order',
          log: const RunLog(
            plan: [PlanLine(kind: 'updateCard', label: '#1042', change: 'x')],
          ),
        ),
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
      // The change count, as the mockup; run detail has the plan title.
      expect(find.text('Needs your review · 1 change'), findsOneWidget);
      expect(find.text('Review'), findsOneWidget);
      await tester.tap(find.text('Review'));
      expectLastCall(rig.host.calls, 'review', ['r_review']);

      expect(find.text('2 min ago'), findsOneWidget);
      // The table has a card column: the action needn't repeat the card.
      await tester.tap(find.text('Run again'));
      await tester.pump();
      expect(rig.runner.methods, contains('runAgain'));

      await tester.tap(find.text('Module failed'));
      expectLastCall(rig.host.calls, 'openRun', ['r_failed']);
    });

    testWidgets("phone rows: the card in the second line; another window's "
        'review says why, with a muted ring', (tester) async {
      await seedModule();
      await rig.stores.automations.save(automation());
      await rig.stores.runs.create(
        storedRun(
          'r_other',
          status: RunStatus.awaitingReview,
          sessionId: 't_other_window',
        ),
      );
      await rig.stores.runs.create(
        storedRun(
          'r_failed',
          status: RunStatus.failed,
          reason: RunReason.moduleError,
          startedAt: fixtureNow.subtract(const Duration(minutes: 2)),
        ),
      );
      await pump(tester, tab: AutomationsTab.runs, size: phoneWindow);
      expect(find.text('Module failed · #1042'), findsOneWidget);
      expect(find.text('Run again on #1042'), findsOneWidget);
      expect(
        find.text(
          'Review not available here — it was opened in another window, '
          'or before Morkva restarted · #1042',
        ),
        findsOneWidget,
      );
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
      expect(find.text('Undone'), findsOneWidget);
    });

    test('the change count includes plan rows past the log cap', () {
      expect(
        changeCount(
          RunLog(
            plan: [
              for (var i = 0; i < RunLog.kMaxPlanRows; i++)
                const PlanLine(kind: 'updateCard', label: '#1', change: 'x'),
            ],
            dropped: const RunLogDropped(plan: 150),
          ),
        ),
        '200 changes',
      );
    });

    testWidgets('an undone run with a summary says "Undone · …"', (
      tester,
    ) async {
      await seedModule();
      await rig.stores.automations.save(automation());
      await rig.stores.runs.create(
        storedRun(
          'r_undone',
          summary: 'Set Shipped on on #1038',
        ).copyWith(undoneAt: () => fixtureNow),
      );
      await pump(tester, tab: AutomationsTab.runs, size: phoneWindow);
      expect(
        find.textContaining('Undone · Set Shipped on on #1038'),
        findsOneWidget,
      );
    });

    for (final (name, size) in [
      ('table', wideWindow),
      ('tablet', tabletWindow),
      ('phone', phoneWindow),
    ]) {
      testWidgets('$name: a collection run shows its collection', (
        tester,
      ) async {
        await seedModule();
        await rig.stores.automations.save(automation());
        final json = storedRun(
          'r_coll',
          summary: 'Flagged 2 products',
        ).toJson();
        json['trigger'] = const RunTrigger(
          kind: TriggerKind.button,
          collectionId: 'c_orders',
          cardCount: 3,
        ).toJson();
        await rig.stores.runs.create(RunRecord.fromJson('r_coll', json));
        await pump(tester, tab: AutomationsTab.runs, size: size);
        expect(find.textContaining('Orders'), findsOneWidget);
      });
    }

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
          // Nothing says "none" about lists that didn't load.
          expect(find.byType(CountBadge), findsNothing);
          expect(find.text('Install a module first'), findsNothing);
          expect(find.text('New automation'), findsNothing);
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
    // Under 1240 the subtitle goes full width under a title row of one
    // height, so it doesn't wrap beside the actions and the tabs keep their
    // y on every tab.
    testWidgets('tablet: the tab bar stays put across tabs', (tester) async {
      // The test font is far wider than the real one: with "Ask Morkva to
      // write one" the Modules actions wrap here (not in the app, checked
      // live at 1024).
      rig.host.askEnabled = false;
      await seedModule();
      final ys = <double>[];
      for (final tab in AutomationsTab.values) {
        await pump(tester, tab: tab, size: tabletWindow);
        await tester.pumpAndSettle();
        ys.add(tester.getTopLeft(find.byType(TabBar)).dy);
      }
      expect(ys.toSet(), hasLength(1), reason: '$ys');
      // Modules: the subtitle sits under the actions, not beside them.
      await pump(tester, size: tabletWindow);
      await tester.pumpAndSettle();
      final subtitle = find.textContaining('Modules add actions.');
      expect(
        tester.getTopLeft(subtitle).dy,
        greaterThanOrEqualTo(
          tester.getBottomLeft(find.text('Import module')).dy,
        ),
      );
      expect(
        tester.getTopLeft(subtitle).dx,
        tester.getTopLeft(find.text('Automations').first).dx,
      );
    });

    // The phone actions sat in a band above the tabs on two tabs only: the
    // tab bar jumped up to ~97 px on switching.
    testWidgets('phone: the tab bar has one y on every tab', (tester) async {
      await seedModule();
      await rig.stores.automations.save(automation());
      final ys = <double>[];
      for (final tab in AutomationsTab.values) {
        await pump(tester, tab: tab, size: phoneWindow);
        await tester.pumpAndSettle();
        ys.add(tester.getTopLeft(find.byType(TabBar)).dy);
      }
      expect(ys.toSet(), hasLength(1), reason: '$ys');
      // The actions are still there, under the tabs.
      final tabsBottom = tester.getBottomLeft(find.byType(TabBar)).dy;
      await pump(tester, size: phoneWindow);
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.text('Import module')).dy,
        greaterThan(tabsBottom),
      );
      await pump(tester, tab: AutomationsTab.automations, size: phoneWindow);
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.text('New automation')).dy,
        greaterThan(tabsBottom),
      );
    });

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
