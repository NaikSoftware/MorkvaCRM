import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/harness/api/capability.dart';
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

    testWidgets('a row shows every field change it writes', (tester) async {
      const fields = ['Name', 'Status', 'Notes', 'Owner', 'Amount'];
      await pump(
        tester,
        PlanItem.proposed(
          id: 'x',
          plan: PlanView(
            planId: 'p',
            title: 'Update 1 order',
            rows: [
              PlanRow(
                itemId: 'a',
                kind: 'updateCard',
                label: '#1 · Ann',
                collectionId: 'c_orders',
                targetId: 'o_a',
                changes: [
                  for (final f in fields)
                    PlanChange(field: f, beforeText: 'old', afterText: 'new'),
                ],
              ),
            ],
          ),
        ),
      );
      for (final f in fields) {
        expect(find.text(f), findsOneWidget, reason: f);
      }
    });

    testWidgets('a prefixed auto-number is an object chip too', (tester) async {
      await pump(
        tester,
        PlanItem.proposed(
          id: 'x',
          plan: PlanView(
            planId: 'p',
            title: 'Update 2 orders',
            rows: [_card('a', 'ORD-0002 · Ann'), _card('b', 'Bob · Smith')],
          ),
        ),
      );
      await tester.tap(find.text('ORD-0002'));
      expect(actions.calls, ['open(c_orders, o_a, null)']);
      // A title with " · " but no number stays plain text.
      expect(find.text('Bob · Smith'), findsOneWidget);
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

    testWidgets('a new collection lists itself, then its fields', (
      tester,
    ) async {
      PlanRow field(String id, String label, String type) => PlanRow(
        itemId: id,
        kind: 'addField',
        label: label,
        collectionId: 'c_sup',
        detail: type,
      );
      final plan = PlanView(
        planId: 'p_new',
        title: 'Create “Suppliers” · 4 fields',
        rows: [
          const PlanRow(
            itemId: 'c',
            kind: 'createCollection',
            label: 'Suppliers',
            collectionId: 'c_sup',
            targetId: 'c_sup',
            detail: 'Collection · 4 fields',
          ),
          field('f1', 'Name', 'Text · title'),
          field('f2', 'Phone', 'Text'),
          field('f3', 'City', 'Select · Kyiv, Lviv, Odesa'),
          field('f4', 'Fabrics sold', 'Link → Fabrics, many'),
        ],
      );
      expect(plan.groups, hasLength(1));
      await pump(tester, PlanItem.proposed(id: 'x', plan: plan));

      expect(find.text('Create collection · 1'), findsNothing);
      expect(find.text('Add field · 4'), findsNothing);
      expect(find.text('All 5 selected'), findsOneWidget);
      final top = [
        for (final t in ['Suppliers', 'Name', 'Phone', 'City', 'Fabrics sold'])
          tester.getTopLeft(find.text(t)).dy,
      ];
      expect(top, orderedEquals([...top]..sort()));
      expect(find.byType(TypeTag), findsNWidgets(5));
      expect(find.text('Select · Kyiv, Lviv, Odesa'), findsOneWidget);
      expect(find.text('Approve 5 changes'), findsOneWidget);
    });

    test('fields of an existing collection keep their own group', () {
      const plan = PlanView(
        planId: 'p',
        title: 'Changes',
        rows: [
          PlanRow(
            itemId: 'c',
            kind: 'createCollection',
            label: 'Suppliers',
            collectionId: 'c_sup',
          ),
          PlanRow(
            itemId: 'f',
            kind: 'addField',
            label: 'Supplier',
            collectionId: 'c_orders',
          ),
        ],
      );
      expect(plan.groups.map((g) => g.kind), ['createCollection', 'addField']);
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
                  .map((c) => c.foregroundDecoration)
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

    // As the harness titles it.
    const collectionPlan = PlanView(
      planId: 'p_col',
      title: 'Delete collection “AI e2e Suppliers” · 2 cards',
      risk: PlanRisk.high,
      rows: [
        PlanRow(
          itemId: 'i1',
          kind: 'deleteCollection',
          label: 'AI e2e Suppliers',
          risk: PlanRisk.high,
          detail: '2 cards',
        ),
      ],
    );

    testWidgets('a collection delete confirms in short, on one row', (
      tester,
    ) async {
      // The test font draws every glyph square: give the label its room.
      await pumpInScope(
        tester,
        PlanCard(
          item: PlanItem.proposed(id: 'x', plan: collectionPlan),
        ),
        actions: actions,
        width: 560,
      );

      final confirm = find.text('Delete collection');
      expect(confirm, findsOneWidget);
      final keep = tester.getRect(find.text('Keep it'));
      final button = tester.getRect(confirm);
      expect(button.center.dy, moreOrLessEquals(keep.center.dy));
      expect(button.left, greaterThan(keep.right));
      expect(
        tester.renderObject<RenderParagraph>(confirm).didExceedMaxLines,
        isFalse,
      );
    });

    testWidgets('deleting a collection needs its name typed', (tester) async {
      await pump(tester, PlanItem.proposed(id: 'x', plan: collectionPlan));

      await tester.tap(find.text('Delete collection'));
      await tester.pumpAndSettle();
      expect(
        find.text('Delete the AI e2e Suppliers collection?'),
        findsOneWidget,
      );
      final dialogConfirm = find.descendant(
        of: find.byType(MorkvaConfirmDialog),
        matching: find.text('Delete collection'),
      );

      // Confirm stays disabled until the name matches.
      await tester.tap(dialogConfirm);
      await tester.pumpAndSettle();
      expect(actions.calls, isEmpty);

      await tester.enterText(find.byType(TextField), 'AI e2e Suppliers');
      await tester.pump();
      await tester.tap(dialogConfirm);
      await tester.pumpAndSettle();
      expect(actions.calls, ['approve(p_col)']);
    });

    testWidgets('cancelling the typed confirm approves nothing', (
      tester,
    ) async {
      await pump(tester, PlanItem.proposed(id: 'x', plan: collectionPlan));
      await tester.tap(find.text('Delete collection'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(actions.calls, isEmpty);
    });

    testWidgets('cards of an oddly cased collection: "Delete N cards"', (
      tester,
    ) async {
      const plan = PlanView(
        planId: 'p_cards',
        title: 'Delete 2 cards from “AI e2e Suppliers”',
        risk: PlanRisk.high,
        rows: [
          PlanRow(
            itemId: 'i1',
            kind: 'deleteCard',
            label: 'Nova',
            risk: PlanRisk.high,
          ),
          PlanRow(
            itemId: 'i2',
            kind: 'deleteCard',
            label: 'Tkanyna',
            risk: PlanRisk.high,
          ),
        ],
      );
      await pump(tester, PlanItem.proposed(id: 'x', plan: plan));
      expect(find.text('Delete 2 cards'), findsOneWidget);
    });
  });

  testWidgets('approving offline says so and leaves the plan open', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    // As the bloc leaves it after an offline Approve.
    await pump(
      tester,
      PlanItem.proposed(
        id: 'm6',
        plan: AssistantSeeds.shipPlan,
      ).copyWith(message: 'Needs a connection'),
    );

    expect(find.text('Needs a connection'), findsOneWidget);
    expect(find.bySemanticsLabel('Needs a connection'), findsOneWidget);
    await tester.tap(find.text('Approve 3 changes'));
    expect(actions.calls, ['approve(${AssistantSeeds.shipPlan.planId})']);

    // Approved again online: the progress replaces the note.
    await pump(
      tester,
      PlanItem.proposed(
        id: 'm6',
        plan: AssistantSeeds.shipPlan,
      ).copyWith(status: PlanStatus.committing, message: 'Needs a connection'),
      p: const ApplyingPhase(1, 3),
    );
    expect(find.text('Needs a connection'), findsNothing);
    semantics.dispose();
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
      // The spinner-only Approve still says what it is doing.
      expect(find.bySemanticsLabel('Applying changes'), findsOneWidget);
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

  group('PlanCardScope only (the review sheet)', () {
    Future<void> pumpBare(WidgetTester tester, PlanItem item) =>
        pumpInPlanScope(tester, PlanCard(item: item), actions: actions);

    testWidgets('a pending plan selects, approves and opens objects', (
      tester,
    ) async {
      await pumpBare(
        tester,
        PlanItem.proposed(id: 'm6', plan: AssistantSeeds.shipPlan),
      );
      await tester.tap(find.text('Iryna Melnyk'));
      await tester.tap(find.text('#1040'));
      await tester.tap(find.text('Approve 3 changes'));
      await tester.tap(find.text('Reject'));
      expect(actions.calls, [
        'select(p_ship, i2,i3)',
        'open(c_orders, o_1040, null)',
        'approve(p_ship)',
        'reject(p_ship)',
      ]);
    });

    testWidgets('an expired plan\'s Rebuild calls retry', (tester) async {
      await pumpBare(
        tester,
        PlanItem.proposed(
          id: 'm6',
          plan: AssistantSeeds.shipPlan,
        ).copyWith(status: PlanStatus.expired),
      );
      await tester.tap(find.text('Rebuild'));
      expect(actions.calls, ['retry()']);
    });
  });

  group('a module install', () {
    testWidgets('shield header, never the deletion styling', (tester) async {
      final plan = AssistantSeeds.moduleInstallPlan;
      expect(plan.destructive, isFalse);
      expect(plan.grantsPermissions, isTrue);
      await pump(tester, PlanItem.proposed(id: 'm', plan: plan));

      expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);
      expect(find.text('Install “Stamp shipped date”'), findsOneWidget);
      // The grants warning is the subtitle, not a second warning line.
      expect(
        find.text(
          'Approving installs this module and lets it use these '
          'permissions. Auto-apply stays off.',
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
      expect(find.text('Create and change cards'), findsOneWidget);
      expect(find.text('Install module'), findsOneWidget);
      expect(find.text('Applies changes without asking'), findsNothing);
      expect(find.textContaining('Module ·'), findsNothing);
    });

    testWidgets('an update says Update module', (tester) async {
      final plan = PlanView.fromJson({
        ...AssistantSeeds.moduleInstallPlan.toJson(),
        'title': 'Update “Stamp shipped date”',
      });
      await pump(tester, PlanItem.proposed(id: 'm', plan: plan));
      expect(find.text('Update module'), findsOneWidget);
    });

    testWidgets('View code hands the row to viewCode', (tester) async {
      await pump(
        tester,
        PlanItem.proposed(id: 'm', plan: AssistantSeeds.moduleInstallPlan),
      );
      await tester.tap(find.text('View code'));
      expect(actions.calls, ['viewCode(i1)']);
    });

    testWidgets('no code (a restored plan): no View code', (tester) async {
      final plan = PlanView.fromJson(
        AssistantSeeds.moduleInstallPlan.toJson()
          ..['items'] = [
            {
              ...(AssistantSeeds.moduleInstallPlan.toJson()['items']! as List)
                      .single
                  as Map<String, Object?>,
            }..remove('code'),
          ],
      );
      await pump(tester, PlanItem.proposed(id: 'm', plan: plan));
      expect(find.text('View code'), findsNothing);
    });

    testWidgets('an auto-apply automation says so above the rows', (
      tester,
    ) async {
      final plan = AssistantSeeds.moduleWithAutoPlan;
      expect(plan.autoApplies, isTrue);
      await pump(
        tester,
        PlanItem(id: 'm', plan: plan, selected: const {'i1', 'i2'}),
      );
      expect(find.byIcon(Icons.bolt_rounded), findsOneWidget);
      // The banner and the item's own diff line.
      expect(find.text('Applies changes without asking'), findsNWidgets(2));
      expect(find.text('Approve 2 changes'), findsOneWidget);
      expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
    });

    testWidgets('provenance always reads "Module · name (id)"', (tester) async {
      await pumpInPlanScope(
        tester,
        PlanCard(
          item: PlanItem.proposed(id: 'm', plan: AssistantSeeds.shipPlan),
          provenance: (id: 'stamp-shipped', name: 'Stamp shipped date'),
        ),
        actions: actions,
      );
      expect(
        find.text('Module · Stamp shipped date (stamp-shipped)'),
        findsOneWidget,
      );
    });
  });

  group('the destructive rule', () {
    PlanView plan(String kind, {int? itemCount}) => PlanView(
      planId: 'p',
      title: 'x',
      risk: PlanRisk.high,
      itemCount: itemCount,
      rows: [PlanRow(itemId: 'i1', kind: kind, label: 'x')],
    );

    test('high risk that deletes is destructive', () {
      for (final k in [
        'deleteCard',
        'deleteField',
        'deleteCollection',
        'deleteView',
        'deleteAutomation',
      ]) {
        expect(plan(k).destructive, isTrue, reason: k);
      }
    });

    test('high risk that deletes nothing is not', () {
      expect(plan('saveModule').destructive, isFalse);
      expect(plan('updateField').destructive, isFalse);
    });

    test('a high-risk compact plan stays destructive (unseen rows)', () {
      expect(plan('updateCard', itemCount: 9).destructive, isTrue);
    });

    test('low risk never is', () {
      expect(
        const PlanView(
          planId: 'p',
          title: 'x',
          rows: [PlanRow(itemId: 'i1', kind: 'deleteView', label: 'x')],
        ).destructive,
        isFalse,
      );
    });
  });

  test('createdBy, code and apply round-trip the plan JSON', () {
    final plan = AssistantSeeds.moduleWithAutoPlan;
    final withCreator = PlanView.fromJson({
      ...plan.toJson(),
      'createdBy': {
        'actor': 'plugin:stamp-shipped',
        'grants': {
          'caps': ['data:read'],
          'collections': ['c_orders'],
        },
      },
    });
    expect(PlanView.fromJson(withCreator.toJson()), withCreator);
    expect(withCreator.createdBy!.actor.kind, ActorKind.plugin);
    expect(withCreator.createdBy!.actor.id, 'stamp-shipped');
    expect(withCreator.createdBy!.collections, ['c_orders']);
    expect(withCreator.rows.first.code, isNotNull);
    expect(withCreator.rows.last.apply, 'auto');
    expect(
      PlanView.fromJson(AssistantSeeds.moduleInstallPlan.toJson()),
      AssistantSeeds.moduleInstallPlan,
    );
  });

  test('kindLabel splits the item kind', () {
    expect(kindLabel('updateCard'), 'Update card');
    expect(kindLabel('addField'), 'Add field');
    expect(kindLabel('deleteCollection'), 'Delete collection');
  });
}
