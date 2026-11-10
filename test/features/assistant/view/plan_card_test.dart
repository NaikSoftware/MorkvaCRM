import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/design/design.dart';
import 'package:morkva_crm/features/assistant/bloc/assistant_state.dart';
import 'package:morkva_crm/features/assistant/bloc/chat_item.dart';
import 'package:morkva_crm/features/assistant/view/widgets/plan_card.dart';

import '../fakes/assistant_seeds.dart';
import 'assistant_view_harness.dart';

PlanRow _card(String id, String label, {PlanRisk risk = PlanRisk.low}) =>
    PlanRow(
      itemId: id,
      kind: 'updateCard',
      label: label,
      collectionId: 'c_orders',
      targetId: 'o_$id',
      risk: risk,
      changes: const [
        PlanChange(field: 'Status', beforeText: 'New', afterText: 'Paid'),
      ],
    );

void main() {
  late RecordingActions actions;

  setUp(() => actions = RecordingActions());

  Future<void> pump(WidgetTester tester, PlanItem item, {ApplyingPhase? p}) =>
      pumpInScope(
        tester,
        PlanCard(item: item, progress: p),
        actions: actions,
      );

  group('a pending plan', () {
    testWidgets('shows the shared diff once and every item', (tester) async {
      await pump(
        tester,
        PlanItem.proposed(id: 'm6', plan: AssistantSeeds.shipPlan),
      );

      expect(find.text('Set Status to Shipped · 3 orders'), findsOneWidget);
      expect(
        find.text(
          'Nothing changes until you approve. You can undo afterwards.',
        ),
        findsOneWidget,
      );
      expect(find.text('Packing'), findsOneWidget);
      expect(find.text('Shipped'), findsOneWidget);
      expect(find.text('#1042'), findsOneWidget);
      expect(find.text('Oksana Lysenko'), findsOneWidget);
      expect(find.text('All 3 selected'), findsOneWidget);
      expect(find.text('Approve 3 changes'), findsOneWidget);
    });

    testWidgets('approve label and select-all follow the selection', (
      tester,
    ) async {
      final plan = AssistantSeeds.shipPlan;
      await pump(
        tester,
        PlanItem(id: 'm6', plan: plan, selected: const {'i1', 'i3'}),
      );

      expect(find.text('Approve 2 changes'), findsOneWidget);
      expect(find.text('2 of 3 selected'), findsOneWidget);
      final all = tester.widget<Checkbox>(find.byType(Checkbox).first);
      expect(all.tristate, isTrue);
      expect(all.value, isNull);

      // Select-all from a partial selection ticks everything.
      await tester.tap(find.text('2 of 3 selected'));
      expect(actions.selections['p_ship'], {'i1', 'i2', 'i3'});

      // Tapping a row toggles that item only.
      await tester.tap(find.text('Iryna Melnyk'));
      expect(actions.selections['p_ship'], {'i3'});
    });

    testWidgets('nothing selected: approve is disabled', (tester) async {
      await pump(
        tester,
        PlanItem(id: 'm6', plan: AssistantSeeds.shipPlan, selected: const {}),
      );

      expect(find.text('None selected'), findsOneWidget);
      await tester.tap(find.text('Approve 0 changes'));
      expect(actions.calls, isEmpty);

      await tester.tap(find.text('None selected'));
      expect(actions.selections['p_ship'], {'i1', 'i2', 'i3'});
    });

    testWidgets('approve and reject report the plan', (tester) async {
      await pump(
        tester,
        PlanItem.proposed(id: 'm6', plan: AssistantSeeds.shipPlan),
      );

      await tester.tap(find.text('Approve 3 changes'));
      await tester.tap(find.text('Reject'));
      expect(actions.calls, ['approve(p_ship)', 'reject(p_ship)']);
    });

    testWidgets('the object chip opens the card', (tester) async {
      await pump(
        tester,
        PlanItem.proposed(id: 'm6', plan: AssistantSeeds.shipPlan),
      );
      await tester.tap(find.text('#1040'));
      expect(actions.calls, ['open(c_orders, o_1040, null)']);
    });

    testWidgets('per-item diffs show when they differ', (tester) async {
      await pump(
        tester,
        PlanItem.proposed(
          id: 'x',
          plan: PlanView(
            planId: 'p',
            title: 'Update 2 orders',
            rows: [_card('a', '#1 · Ann'), _card('b', '#2 · Bob')],
          ),
        ),
      );
      expect(find.text('New'), findsNWidgets(2));
      expect(find.text('Paid'), findsNWidgets(2));
    });

    testWidgets('long plans show 5 rows, then "Show N more"', (tester) async {
      final plan = PlanView(
        planId: 'p',
        title: 'Update 8 orders',
        rows: [for (var i = 1; i <= 8; i++) _card('i$i', '#$i · Client $i')],
        sharedChange: const PlanChange(
          field: 'Status',
          beforeText: 'New',
          afterText: 'Paid',
        ),
      );
      await pump(tester, PlanItem.proposed(id: 'x', plan: plan));

      expect(find.text('Client 5'), findsOneWidget);
      expect(find.text('Client 6'), findsNothing);
      await tester.tap(find.text('Show 3 more'));
      await tester.pump();
      expect(find.text('Client 8'), findsOneWidget);
      expect(find.text('Show 3 more'), findsNothing);
    });

    testWidgets('mixed plans: medium/high groups start unticked', (
      tester,
    ) async {
      final plan = PlanView(
        planId: 'p',
        title: 'Tidy orders',
        risk: PlanRisk.high,
        rows: [
          _card('u1', '#1 · Ann'),
          const PlanRow(
            itemId: 'd1',
            kind: 'deleteCard',
            label: '#2 · Bob',
            risk: PlanRisk.high,
          ),
        ],
      );
      await pump(tester, PlanItem.proposed(id: 'x', plan: plan));

      expect(find.text('Update card · 1'), findsOneWidget);
      expect(find.text('Delete card · 1'), findsOneWidget);
      final boxes = tester
          .widgetList<Checkbox>(find.byType(Checkbox))
          .map((c) => c.value)
          .toList();
      // [update group, u1, delete group, d1]
      expect(boxes, [true, true, false, false]);
    });

    testWidgets('a compact plan says how many rows are not loaded', (
      tester,
    ) async {
      await pump(
        tester,
        PlanItem.proposed(
          id: 'x',
          plan: PlanView(
            planId: 'p',
            title: 'Update 40 orders',
            itemCount: 40,
            rows: [for (var i = 1; i <= 5; i++) _card('i$i', '#$i · C$i')],
          ),
        ),
      );
      expect(find.text('35 more not shown yet'), findsOneWidget);
    });
  });

  group('a destructive plan', () {
    testWidgets('error styling, 3 rows, count in the confirm', (tester) async {
      await pump(
        tester,
        PlanItem.proposed(id: 's4', plan: AssistantSeeds.deletePlan),
      );

      expect(
        find.text('Client is “Test”. You can undo this for 10 minutes.'),
        findsOneWidget,
      );
      expect(find.text('#1027'), findsOneWidget);
      expect(find.text('#1026'), findsNothing);
      expect(find.text('Show 4 more'), findsOneWidget);
      expect(find.text('Keep them'), findsOneWidget);
      expect(find.text('Delete 7 orders'), findsNWidgets(2)); // title + button

      final border =
          tester
                  .widgetList<Container>(find.byType(Container))
                  .map((c) => c.decoration)
                  .whereType<BoxDecoration>()
                  .firstWhere(
                    (d) => d.border != null && d.borderRadius == Radii.lgAll,
                  )
                  .border!
              as Border;
      expect(border.top.color, AppTheme.light.colorScheme.error);
      expect(border.top.width, 2);
    });

    testWidgets('a partial selection names the count', (tester) async {
      await pump(
        tester,
        PlanItem(
          id: 's4',
          plan: AssistantSeeds.deletePlan,
          selected: const {'i1', 'i2'},
        ),
      );
      expect(find.text('Delete 2 of 7'), findsOneWidget);
      await tester.tap(find.text('Delete 2 of 7'));
      await tester.tap(find.text('Keep them'));
      expect(actions.calls, ['approve(p_delete)', 'reject(p_delete)']);
    });

    testWidgets('deleting a collection needs its name typed', (tester) async {
      const plan = PlanView(
        planId: 'p_col',
        title: 'Delete the Suppliers collection',
        risk: PlanRisk.high,
        rows: [
          PlanRow(
            itemId: 'i1',
            kind: 'deleteCollection',
            label: 'Suppliers',
            risk: PlanRisk.high,
          ),
        ],
      );
      await pump(tester, PlanItem.proposed(id: 'x', plan: plan));

      await tester.tap(find.text('Delete the Suppliers collection').last);
      await tester.pumpAndSettle();
      expect(find.text('Delete the Suppliers collection?'), findsOneWidget);

      // Confirm stays disabled until the name matches.
      await tester.tap(find.text('Delete collection'));
      await tester.pumpAndSettle();
      expect(actions.calls, isEmpty);

      await tester.enterText(find.byType(TextField), 'Suppliers');
      await tester.pump();
      await tester.tap(find.text('Delete collection'));
      await tester.pumpAndSettle();
      expect(actions.calls, ['approve(p_col)']);
    });

    testWidgets('cancelling the typed confirm approves nothing', (
      tester,
    ) async {
      const plan = PlanView(
        planId: 'p_col',
        title: 'Delete the Suppliers collection',
        risk: PlanRisk.high,
        rows: [
          PlanRow(
            itemId: 'i1',
            kind: 'deleteCollection',
            label: 'Suppliers',
            risk: PlanRisk.high,
          ),
        ],
      );
      await pump(tester, PlanItem.proposed(id: 'x', plan: plan));
      await tester.tap(find.text('Delete the Suppliers collection').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(actions.calls, isEmpty);
    });
  });

  group('settled plans', () {
    testWidgets('committing shows progress and locks the card', (tester) async {
      await pump(
        tester,
        PlanItem.proposed(
          id: 'm6',
          plan: AssistantSeeds.shipPlan,
        ).copyWith(status: PlanStatus.committing),
        p: const ApplyingPhase(120, 200),
      );

      expect(find.text('Updating 120 of 200…'), findsOneWidget);
      expect(find.text('Reject'), findsNothing);
      await tester.tap(find.text('Iryna Melnyk'));
      expect(actions.calls, isEmpty);
    });

    for (final (status, line) in [
      (PlanStatus.rejected, 'Rejected — nothing changed'),
      (PlanStatus.skipped, 'Skipped — nothing changed'),
      (PlanStatus.expired, 'This preview expired — nothing changed'),
      (
        PlanStatus.stale,
        'Changed elsewhere since the preview — nothing changed',
      ),
    ]) {
      testWidgets('${status.name} collapses to one line', (tester) async {
        await pump(
          tester,
          PlanItem.proposed(
            id: 'm6',
            plan: AssistantSeeds.shipPlan,
          ).copyWith(status: status),
        );
        expect(find.text(line), findsOneWidget);
        expect(find.byType(Checkbox), findsNothing);
      });
    }

    testWidgets('expired offers Rebuild', (tester) async {
      await pump(
        tester,
        PlanItem.proposed(
          id: 'm6',
          plan: AssistantSeeds.shipPlan,
        ).copyWith(status: PlanStatus.expired),
      );
      await tester.tap(find.text('Rebuild'));
      expect(actions.calls, ['retry()']);
    });

    testWidgets('an applied plan leaves the stage to its applied card', (
      tester,
    ) async {
      await pump(
        tester,
        PlanItem.proposed(
          id: 'm6',
          plan: AssistantSeeds.shipPlan,
        ).copyWith(status: PlanStatus.applied),
      );
      expect(find.text('Set Status to Shipped · 3 orders'), findsNothing);
    });
  });

  test('kindLabel splits the item kind', () {
    expect(kindLabel('updateCard'), 'Update card');
    expect(kindLabel('addField'), 'Add field');
    expect(kindLabel('deleteCollection'), 'Delete collection');
  });
}
