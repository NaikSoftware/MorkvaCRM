import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/automation/automation.dart';
import 'package:morkva_crm/design/design.dart';
import 'package:morkva_crm/features/automation/view/test_run_sheet.dart';

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

  Future<void> open(WidgetTester tester, {Size size = wideWindow}) async {
    setWindow(tester, size);
    final cubit = rig.detailsOf(stampId);
    await tester.pumpWidget(
      rig.wrap(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showTestRunSheet(
              context,
              cubit: cubit,
              action: module.manifest!.actions.single,
              collections: [orders],
              loadCards: (_) async => const [
                (id: 'b_1042', label: '#1042 · Acme'),
                (id: 'b_1043', label: '#1043 · Bolt'),
              ],
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  PrimaryButton runTest(WidgetTester tester) => tester.widget<PrimaryButton>(
    find.widgetWithText(PrimaryButton, 'Run test'),
  );

  testWidgets('before consent: disabled with the visible reason', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('Test "Stamp shipped date"'), findsOneWidget);
    expect(find.text('Allow the module to test it'), findsOneWidget);
    expect(runTest(tester).onPressed, isNull);
  });

  testWidgets('a card and the params, then the result block', (tester) async {
    await rig.stores.grants.save(uid, consentTo(module));
    rig.runner.testRunResult = const TestRunResult(
      status: RunStatus.succeeded,
      plan: [
        PlanLine(
          kind: 'updateCard',
          label: '#1042',
          change: 'Shipped on: — → 12 Nov',
        ),
      ],
      log: RunLog(
        calls: [
          RunCall(
            t: 0,
            op: 'cards.get',
            kind: 'read',
            args: '#1042',
            ok: true,
            result: '1 card',
            ms: 4,
          ),
        ],
        console: [ConsoleLine(t: 1, level: 'warn', text: 'careful')],
      ),
    );
    await open(tester);
    expect(
      find.text(
        "Test runs never change data — you'll see what would "
        'change.',
      ),
      findsOneWidget,
    );
    // A card and the required field are missing.
    expect(runTest(tester).onPressed, isNull);

    await tester.enterText(find.byType(TextField).first, 'bolt');
    await tester.pump();
    expect(find.text('#1042 · Acme'), findsNothing);
    await tester.tap(find.text('#1043 · Bolt'));
    await tester.pump();

    await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Shipped on').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Run test'));
    await tester.pumpAndSettle();

    final request =
        rig.runner.calls.singleWhere((c) => c.$1 == 'testRun').$2.single
            as TestRunRequest;
    expect(request.cardId, 'b_1043');
    expect(request.collectionId, 'c_orders');
    expect(request.params['dateField'], 'f_shipped');
    expect(request.params['mode'], 'today');
    expect(find.text('Would change 1 card · 4 ms'), findsOneWidget);
    expect(find.text('Shipped on: — → 12 Nov'), findsOneWidget);
    expect(find.text('Calls (1)'), findsOneWidget);
    expect(find.text('Console (1)'), findsOneWidget);
  });

  testWidgets('result view: a failure reads "Failed: …"', (tester) async {
    setWindow(tester, wideWindow);
    await tester.pumpWidget(
      rig.wrap(
        const TestRunResultView(
          result: TestRunResult(
            status: RunStatus.failed,
            reason: RunReason.moduleError,
            error: RunError(code: 'module_error', message: 'TypeError: x'),
          ),
        ),
        theme: AppTheme.dark,
      ),
    );
    expect(find.text('Failed: TypeError: x'), findsOneWidget);
  });

  testWidgets('phone: a bottom sheet', (tester) async {
    await open(tester, size: phoneWindow);
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
