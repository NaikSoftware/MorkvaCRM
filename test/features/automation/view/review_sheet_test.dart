import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/automation/runner_api.dart';
import 'package:morkva_crm/core/domain/automation/automation.dart';
import 'package:morkva_crm/features/assistant/view/widgets/plan_card.dart';
import 'package:morkva_crm/features/automation/view/review_sheet.dart';

import '../../assistant/fakes/assistant_seeds.dart';
import '../widgets/automation_widget_rig.dart';

void main() {
  late AutomationRig rig;

  setUp(() => rig = AutomationRig());

  List<Object?>? argsOf(String method) => [
    for (final (m, args) in rig.runner.calls)
      if (m == method) args,
  ].lastOrNull;

  /// [ids] wait for review, each with the ship plan and a run doc.
  Future<void> waiting(List<String> ids) async {
    rig.runner.activity = RunActivity(
      runs: [
        for (var i = 0; i < ids.length; i++)
          liveRun(
            ids[i],
            status: RunStatus.awaitingReview,
            cardId: 'b_$i',
          ).copyWithStart(fixtureNow.add(Duration(minutes: i))),
      ],
    );
    for (final id in ids) {
      rig.runner.reviewPlans[id] = AssistantSeeds.shipPlan.toJson();
      await rig.stores.runs.create(
        runRecord(id, status: RunStatus.awaitingReview),
      );
    }
  }

  Future<void> open(
    WidgetTester tester, {
    String runId = 'run_1',
    bool overEditor = false,
    Size size = const Size(1440, 900),
  }) async {
    await pumpRig(
      tester,
      rig,
      Builder(
        builder: (context) => TextButton(
          onPressed: () =>
              showReviewSheet(context, runId: runId, overEditor: overEditor),
          child: const Text('open'),
        ),
      ),
      size: size,
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('provenance, context and the PlanCard; Approve sends the ticks '
      'shown', (tester) async {
    await rig.setUp();
    addTearDown(rig.dispose);
    await waiting(['run_1']);
    await open(tester);
    expect(
      find.text(
        'Module · Stamp shipped date (stamp-shipped-date) · Stamp when shipped',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Button pressed on #1042 · '), findsOneWidget);
    expect(find.byType(PlanCard), findsOneWidget);

    await tester.tap(find.textContaining('Approve'));
    await tester.pumpAndSettle();
    expect(argsOf('approve'), [
      'run_1',
      AssistantSeeds.shipPlan.defaultSelection,
    ]);
    // Applied, nothing else waits: the sheet closes.
    expect(find.byType(PlanCard), findsNothing);
  });

  testWidgets('an unticked row is left out of the approve', (tester) async {
    await rig.setUp();
    addTearDown(rig.dispose);
    await waiting(['run_1']);
    await open(tester);
    await tester.tap(find.textContaining('Iryna Melnyk'));
    await tester.pump();
    await tester.tap(find.textContaining('Approve'));
    await tester.pumpAndSettle();
    final sent = argsOf('approve')![1]! as Set<String>;
    expect(sent, AssistantSeeds.shipPlan.defaultSelection.difference({'i1'}));
  });

  testWidgets('several waiting: Next review (N left), oldest first', (
    tester,
  ) async {
    await rig.setUp();
    addTearDown(rig.dispose);
    await waiting(['run_1', 'run_2', 'run_3']);
    await open(tester);
    await tester.tap(find.textContaining('Approve'));
    await tester.pumpAndSettle();
    expect(find.text('Next review (2 left)'), findsOneWidget);
    await tester.tap(find.text('Next review (2 left)'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Approve'));
    await tester.pumpAndSettle();
    expect(argsOf('approve')![0], 'run_2');
  });

  testWidgets('expired: the muted card with Run again', (tester) async {
    await rig.setUp();
    addTearDown(rig.dispose);
    await open(tester, runId: 'run_gone');
    expect(find.textContaining('This review expired.'), findsOneWidget);
    await tester.tap(find.text('Run again'));
    await tester.pumpAndSettle();
    expect(argsOf('runAgain'), ['run_gone']);
    expect(find.textContaining('This review expired.'), findsNothing);
  });

  testWidgets('approve refused: the sentence and Run again', (tester) async {
    await rig.setUp();
    addTearDown(rig.dispose);
    await waiting(['run_1']);
    await open(tester);
    rig.runner.failNext = const AutomationRefused(
      'not_permitted',
      "This module's permissions changed — run it again.",
    );
    await tester.tap(find.textContaining('Approve'));
    await tester.pumpAndSettle();
    expect(
      find.text("This module's permissions changed — run it again."),
      findsOneWidget,
    );
    expect(find.text('Run again'), findsOneWidget);
  });

  testWidgets('over the card editor: a transparent barrier', (tester) async {
    await rig.setUp();
    addTearDown(rig.dispose);
    await waiting(['run_1']);
    await open(tester, overEditor: true);
    final barriers = tester.widgetList<ModalBarrier>(find.byType(ModalBarrier));
    // No second scrim: the editor's already darkens the page.
    expect(barriers.last.color?.a ?? 0, 0);
    // …so the dialog itself stands out: the white card surface, lifted.
    final dialog = tester.widget<Dialog>(find.byType(Dialog));
    expect(
      dialog.backgroundColor,
      Theme.of(
        tester.element(find.byType(Dialog)),
      ).colorScheme.surfaceContainerLowest,
    );
    expect(dialog.shadowColor?.a ?? 0, greaterThan(0));
  });

  testWidgets('dismissed: decide later, "Saved for review"', (tester) async {
    await rig.setUp();
    addTearDown(rig.dispose);
    await waiting(['run_1']);
    await open(tester);
    await tester.tap(find.byTooltip('Decide later'));
    await tester.pumpAndSettle();
    expect(find.byType(PlanCard), findsNothing);
    expect(find.text('Saved for review'), findsOneWidget);
    expect(rig.runner.methods, isNot(contains('reject')));
  });

  testWidgets('phone: a full-height bottom sheet', (tester) async {
    await rig.setUp();
    addTearDown(rig.dispose);
    await waiting(['run_1']);
    await open(tester, size: const Size(390, 844));
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(PlanCard), findsOneWidget);
  });
}

extension on RunView {
  RunView copyWithStart(DateTime at) => RunView(
    runId: runId,
    automationId: automationId,
    moduleId: moduleId,
    actionId: actionId,
    label: label,
    status: status,
    trigger: trigger,
    startedAt: at,
  );
}
