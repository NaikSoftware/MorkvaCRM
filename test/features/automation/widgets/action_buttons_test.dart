import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/automation/runner_api.dart';
import 'package:morkva_crm/core/domain/automation/automation.dart';
import 'package:morkva_crm/features/automation/widgets/action_buttons.dart';

import 'automation_widget_rig.dart';

void main() {
  late AutomationRig rig;
  late List<String> saveAndRun;
  late List<String> navigated;
  late List<String> messages;

  final three = [
    buttonAutomation('a_mark', 'Mark shipped', order: 0),
    buttonAutomation('a_draft', 'Draft thank-you', order: 1),
    buttonAutomation('a_flag', 'Flag low stock', order: 2),
  ];

  setUp(() {
    rig = AutomationRig();
    saveAndRun = [];
    navigated = [];
    messages = [];
  });

  List<Object?>? argsOf(String method) => [
    for (final (m, args) in rig.runner.calls)
      if (m == method) args,
  ].lastOrNull;

  CardActionHooks hooks() => CardActionHooks(
    onSaveAndRun: (e) async => saveAndRun.add(e.automation.id),
    onNavigate: navigated.add,
    onMessage: messages.add,
  );

  Future<void> pump(
    WidgetTester tester, {
    double headerWidth = 2000,
    bool dirty = false,
    String? cardId = 'b_1042',
    bool compact = false,
    Size size = const Size(2200, 900),
  }) => pumpRig(
    tester,
    rig,
    Align(
      alignment: Alignment.topRight,
      child: CardActions(
        collectionId: 'c_orders',
        cardId: cardId,
        dirty: dirty,
        hooks: hooks(),
        compact: compact,
        headerWidth: headerWidth,
      ),
    ),
    size: size,
  );

  group('header width rules', () {
    testWidgets('all fit: every button with its label, no More', (
      tester,
    ) async {
      await rig.setUp(automations: three);
      addTearDown(rig.dispose);
      await pump(tester);
      for (final label in [
        'Mark shipped',
        'Draft thank-you',
        'Flag low stock',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('More'), findsNothing);
    });

    testWidgets('over 45 % of the header: the rest go under More', (
      tester,
    ) async {
      await rig.setUp(automations: three);
      addTearDown(rig.dispose);
      await pump(tester, headerWidth: 1000);
      expect(find.text('More'), findsOneWidget);
      expect(find.text('Mark shipped'), findsOneWidget);
      expect(find.text('Flag low stock'), findsNothing);
      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();
      expect(find.text('Flag low stock'), findsOneWidget);
    });

    testWidgets('labels cut at 16 characters, the full one in the tooltip', (
      tester,
    ) async {
      await rig.setUp(
        automations: [buttonAutomation('a_long', 'Send the invoice to client')],
      );
      addTearDown(rig.dispose);
      await pump(tester);
      expect(find.text('Send the invoic…'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Tooltip &&
              (w.message ?? '').startsWith('Send the invoice to client'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('below a 560 px header: icon-only with tooltips', (
      tester,
    ) async {
      await rig.setUp(automations: three);
      addTearDown(rig.dispose);
      await pump(tester, headerWidth: 520);
      expect(find.text('Mark shipped'), findsNothing);
      expect(
        find.byWidgetPredicate(
          (w) => w is Tooltip && (w.message ?? '').startsWith('Mark shipped'),
        ),
        findsOneWidget,
      );
      // Every pressable keeps a 44 px hit area.
      final hit = tester.getSize(
        find
            .ancestor(
              of: find.byIcon(Icons.local_shipping_outlined).first,
              matching: find.byType(SizedBox),
            )
            .at(1),
      );
      expect(hit.height, 44);
    });
  });

  group('states', () {
    testWidgets('running: spinner and n/N; long press offers Stop', (
      tester,
    ) async {
      await rig.setUp(automations: [three.first]);
      addTearDown(rig.dispose);
      rig.runner.activity = RunActivity(
        runs: [
          liveRun('run_1', progress: const RunProgress(done: 2, total: 3)),
        ],
      );
      await pump(tester);
      expect(find.text('Running… 2/3'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.longPress(find.text('Running… 2/3'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Stop'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(argsOf('stop'), ['run_1']);
    });

    testWidgets('queued: clock and the position', (tester) async {
      await rig.setUp(automations: [three.first]);
      addTearDown(rig.dispose);
      rig.runner.activity = RunActivity(
        runs: [liveRun('run_1', status: RunStatus.queued, queuedAhead: 3)],
      );
      await pump(tester);
      expect(find.text('Queued · 3 ahead'), findsOneWidget);
      expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);
    });

    testWidgets('a run on another card leaves this card idle', (tester) async {
      await rig.setUp(automations: [three.first]);
      addTearDown(rig.dispose);
      rig.runner.activity = RunActivity(
        runs: [liveRun('run_1', cardId: 'b_other')],
      );
      await pump(tester);
      expect(find.text('Mark shipped'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('a clean form runs on the card at once', (tester) async {
      await rig.setUp(automations: [three.first]);
      addTearDown(rig.dispose);
      await pump(tester);
      await tester.tap(find.text('Mark shipped'));
      await tester.pumpAndSettle();
      expect(argsOf('pressCard'), ['a_mark', 'b_1042']);
      expect(saveAndRun, isEmpty);
    });

    testWidgets('an unsaved form opens Save and run; Cancel does nothing', (
      tester,
    ) async {
      await rig.setUp(automations: [three.first]);
      addTearDown(rig.dispose);
      await pump(tester, dirty: true);
      await tester.tap(find.text('Mark shipped'));
      await tester.pumpAndSettle();
      expect(find.text('The action works on the saved card.'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(saveAndRun, isEmpty);

      await tester.tap(find.text('Mark shipped'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save and run'));
      await tester.pumpAndSettle();
      expect(saveAndRun, ['a_mark']);
      expect(rig.runner.methods, isNot(contains('pressCard')));
    });

    testWidgets('needs consent: a press opens the module', (tester) async {
      await rig.setUp(automations: [three.first], consent: false);
      addTearDown(rig.dispose);
      await pump(tester);
      await tester.tap(find.text('Mark shipped'));
      await tester.pumpAndSettle();
      expect(navigated, ['/automations/modules/stamp-shipped-date']);
      expect(rig.runner.methods, isNot(contains('pressCard')));
    });

    testWidgets('last run failed: the dot opens the run', (tester) async {
      await rig.setUp(automations: [three.first]);
      addTearDown(rig.dispose);
      await rig.stores.runs.create(
        runRecord(
          'run_failed',
          status: RunStatus.failed,
          reason: RunReason.moduleError,
          automationId: 'a_mark',
          endedAt: fixtureNow,
          error: const RunError(code: 'module_error', message: 'TypeError'),
        ),
      );
      await pump(tester);
      await tester.tap(find.text('Mark shipped'));
      await tester.pumpAndSettle();
      expect(navigated, ['/automations/runs/run_failed']);
    });

    testWidgets('disabled automations and other collections show nothing', (
      tester,
    ) async {
      await rig.setUp(
        automations: [
          buttonAutomation('a_off', 'Switched off', enabled: false),
          buttonAutomation(
            'a_coll',
            'Flag low stock',
            scope: ButtonScope.collection,
          ),
        ],
      );
      addTearDown(rig.dispose);
      await pump(tester);
      expect(find.byType(Text), findsNothing);
    });
  });

  group('phone ⚡', () {
    testWidgets('a spinner ring with n/N while this card runs', (tester) async {
      await rig.setUp(automations: [three.first]);
      addTearDown(rig.dispose);
      rig.runner.activity = RunActivity(
        runs: [
          liveRun('run_1', progress: const RunProgress(done: 1, total: 3)),
        ],
      );
      await pump(tester, compact: true, size: const Size(390, 844));
      expect(find.byKey(const ValueKey('run-ring')), findsOneWidget);
      expect(find.text('1/3'), findsOneWidget);
    });

    testWidgets('the Actions sheet: Save and run on a dirty form', (
      tester,
    ) async {
      await rig.setUp(automations: three);
      addTearDown(rig.dispose);
      await pump(
        tester,
        compact: true,
        dirty: true,
        size: const Size(390, 844),
      );
      await tester.tap(find.byTooltip('Actions'));
      await tester.pumpAndSettle();
      expect(find.text('Actions'), findsOneWidget);
      expect(
        find.textContaining('Save and run', findRichText: true),
        findsNWidgets(3),
      );
      await tester.tap(find.text('Draft thank-you'));
      await tester.pumpAndSettle();
      expect(find.text('Actions'), findsNothing);
      expect(saveAndRun, ['a_draft']);
    });

    testWidgets('a running row shows Stop', (tester) async {
      await rig.setUp(automations: [three.first]);
      addTearDown(rig.dispose);
      rig.runner.activity = RunActivity(runs: [liveRun('run_1')]);
      await pump(tester, compact: true, size: const Size(390, 844));
      await tester.tap(find.byType(CardActions));
      // A spinner never settles: step the sheet's entrance by hand.
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.tap(find.text('Stop'));
      expect(argsOf('stop'), ['run_1']);
    });
  });

  group('runNoticeCopy', () {
    test('the banner and snackbar words per outcome', () {
      final applied = runNoticeCopy(
        liveRun(
          'r',
          status: RunStatus.succeeded,
          summary: '1 order updated',
          planId: 'p',
        ),
      );
      expect(applied.text, 'Mark shipped · 1 order updated');
      expect(applied.actions, [NoticeAction.undo, NoticeAction.viewRun]);
      expect(applied.error, isFalse);
      expect(
        runNoticeCopy(liveRun('r', status: RunStatus.succeeded)).text,
        'Mark shipped · No changes',
      );
      expect(
        runNoticeCopy(
          liveRun('r', status: RunStatus.failed, reason: RunReason.cancelled),
        ).text,
        'Mark shipped was stopped. Nothing was changed.',
      );
      expect(
        runNoticeCopy(
          liveRun('r', status: RunStatus.failed, reason: RunReason.offline),
        ).actions,
        [NoticeAction.runAgain],
      );
      expect(
        runNoticeCopy(liveRun('r', status: RunStatus.awaitingReview)).actions,
        [NoticeAction.review],
      );
    });
  });
}
