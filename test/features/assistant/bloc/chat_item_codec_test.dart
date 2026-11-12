import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/agent/agent_event.dart';
import 'package:morkva_crm/features/assistant/bloc/chat_item.dart';
import 'package:morkva_crm/features/assistant/bloc/chat_item_codec.dart';

import '../fakes/assistant_seeds.dart';

/// Encodes [items] the way a turn doc stores them (through JSON text) and
/// decodes them back.
List<ChatItem> roundTrip(List<ChatItem> items) => decodeChatItems(
  jsonDecode(jsonEncode(encodeChatItems(items))) as List<Object?>,
);

/// [plan] as a turn doc keeps it: every diff cut to its field.
PlanView withoutValues(PlanView plan) {
  PlanChange field(PlanChange c) =>
      PlanChange(fieldId: c.fieldId, field: c.field);
  return PlanView(
    planId: plan.planId,
    title: plan.title,
    risk: plan.risk,
    rows: [
      for (final r in plan.rows)
        PlanRow(
          itemId: r.itemId,
          kind: r.kind,
          label: r.label,
          collectionId: r.collectionId,
          targetId: r.targetId,
          risk: r.risk,
          changes: [for (final c in r.changes) field(c)],
          detail: r.detail,
        ),
    ],
    itemCount: plan.itemCount,
    sharedChange: plan.sharedChange == null ? null : field(plan.sharedChange!),
    warnings: plan.warnings,
    notes: plan.notes,
    undo: plan.undo,
    expiresAt: plan.expiresAt,
  );
}

void main() {
  final now = DateTime.utc(2026, 11, 10, 12);

  test('settled items of every mockup round-trip unchanged, but for the '
      'values of plan diffs', () {
    for (final seed in [
      AssistantSeeds.main(),
      AssistantSeeds.analyze(now: now),
      AssistantSeeds.schema(now: now),
    ]) {
      final settled = [
        for (final item in seed.items)
          if (item is! PlanItem && item is! TableItem && item is! ChartItem)
            item,
      ];
      expect(roundTrip(settled), [
        for (final item in settled)
          item is AppliedItem
              ? AppliedItem(
                  id: item.id,
                  plan: withoutValues(item.plan),
                  receipt: item.receipt,
                  undoUntil: item.undoUntil,
                  undoState: item.undoState,
                  undoNote: item.undoNote,
                  undoSessionOnly: item.undoSessionOnly,
                )
              : item,
      ]);
    }
  });

  test('a persisted plan keeps its title and labels, never the card values '
      'of its diffs', () {
    final plan = PlanItem(
      id: 'p',
      plan: AssistantSeeds.shipPlan,
      selected: const {'i1'},
      status: PlanStatus.rejected,
    );
    final applied = AppliedItem(
      id: 'a',
      plan: AssistantSeeds.shipPlan,
      receipt: Receipt(
        planId: AssistantSeeds.shipPlan.planId,
        applied: const ['i1'],
        summary: 'Updated 1 order',
      ),
    );

    final json = jsonEncode(encodeChatItems([plan, applied]));
    expect(json, isNot(contains('Packing')), reason: 'the old value');
    expect('Shipped'.allMatches(json), hasLength(2), reason: 'titles only');

    final [restoredPlan, restoredApplied] = roundTrip([plan, applied]);
    for (final restored in [
      (restoredPlan as PlanItem).plan,
      (restoredApplied as AppliedItem).plan,
    ]) {
      expect(restored, withoutValues(AssistantSeeds.shipPlan));
      expect(restored.title, 'Set Status to Shipped · 3 orders');
      expect(restored.rows.first.label, '#1042 · Iryna Melnyk');
      expect(restored.sharedChange?.field, 'Status');
    }
  });

  test('every record carries the schema and its type', () {
    final records = encodeChatItems(AssistantSeeds.schema(now: now).items);

    expect(records.map((r) => r['schema']).toSet(), {kChatItemSchema});
    expect(records.map((r) => r['type']), [
      'user',
      'applied',
      'user',
      'plan',
      'error',
    ]);
  });

  test('tables and charts keep title, summary and spec, never rows', () {
    const spec = {
      'op': 'cards.query',
      'args': {'collection': 'Orders'},
    };
    final table = (AssistantSeeds.main().items[3] as TableItem);
    final withSpec = TableItem(
      id: table.id,
      title: table.title,
      handle: table.handle,
      spec: spec,
      summary: table.summary,
      table: table.table,
    );
    const chart = ChartItem(
      id: 'c',
      title: 'Revenue',
      kind: PresentKind.line,
      handle: 'h',
      spec: spec,
      chart: ResultChart(points: [ChartPoint('J', 1)], metricLabel: 'Sum'),
    );

    final json = jsonEncode(encodeChatItems([withSpec, chart]));
    expect(json, isNot(contains('Iryna Melnyk')));
    expect(json, isNot(contains('h_unpaid')));

    final [restoredTable, restoredChart] = roundTrip([withSpec, chart]);
    expect(
      restoredTable,
      TableItem(
        id: table.id,
        title: table.title,
        spec: spec,
        summary: table.summary,
      ),
    );
    expect(
      restoredChart,
      const ChartItem(
        id: 'c',
        title: 'Revenue',
        kind: PresentKind.line,
        spec: spec,
      ),
    );
  });

  test('a persisted module plan drops the code, keeps apply and createdBy', () {
    final plan = PlanView.fromJson({
      ...AssistantSeeds.moduleWithAutoPlan.toJson(),
      'createdBy': {
        'actor': 'agent:assistant',
        'grants': {
          'caps': ['*'],
          'collections': null,
        },
      },
    });
    expect(plan.rows.first.code, isNotNull);
    final records = encodeChatItems([
      PlanItem(id: 'm', plan: plan, selected: const {'i1', 'i2'}),
    ]);
    expect(jsonEncode(records), isNot(contains('morkva.action')));
    final items = (records.single['plan']! as Map)['items']! as List;
    expect(items.first, isNot(contains('code')));

    final restored =
        roundTrip([
              PlanItem(id: 'm', plan: plan, selected: const {'i1', 'i2'}),
            ]).single
            as PlanItem;
    expect(restored.plan.rows.first.code, isNull);
    expect(restored.plan.rows.last.apply, 'auto');
    expect(restored.plan.autoApplies, isTrue);
    expect(restored.plan.grantsPermissions, isTrue);
    expect(restored.plan.createdBy, plan.createdBy);
  });

  test('a plan keeps its first 5 items, the count and the selection', () {
    final plan = PlanItem(
      id: 'p',
      plan: AssistantSeeds.deletePlan,
      selected: const {'i1', 'i2'},
      status: PlanStatus.rejected,
    );

    final restored = roundTrip([plan]).single as PlanItem;

    expect(restored.plan.rows.map((r) => r.itemId), [
      'i1',
      'i2',
      'i3',
      'i4',
      'i5',
    ]);
    expect(restored.plan.itemCount, 7);
    expect(restored.plan.risk, PlanRisk.high);
    expect(restored.selected, {'i1', 'i2'});
    expect(restored.status, PlanStatus.rejected);
  });

  group('restoring settles in-flight states', () {
    test('streaming text comes back stopped, with the live text', () {
      final live = ValueNotifier('Four fabrics are under 5 metres.');
      final item = AssistantTextItem(
        id: 't',
        text: 'Four',
        streaming: true,
        live: live,
      );

      expect(
        roundTrip([item]).single,
        const AssistantTextItem(
          id: 't',
          text: 'Four fabrics are under 5 metres.',
          stopped: true,
        ),
      );
    });

    test('a pending plan comes back expired, a committing one '
        'interrupted', () {
      final pending = PlanItem.proposed(id: 'a', plan: AssistantSeeds.shipPlan);
      final committing = pending.copyWith(status: PlanStatus.committing);

      final restored = roundTrip([pending, committing]).cast<PlanItem>();

      expect(restored.map((p) => p.status), [
        PlanStatus.expired,
        PlanStatus.interrupted,
      ]);
    });

    test('a running step comes back failed', () {
      const steps = StepsItem(
        id: 's',
        steps: [StepView(callId: 'r1.1', label: 'Filtering…')],
      );

      final restored = roundTrip([steps]).single as StepsItem;

      expect(restored.steps.single.status, StepStatus.failed);
    });

    test('an undo in progress comes back available', () {
      final applied = AssistantSeeds.analyze(
        now: now,
      ).items.whereType<AppliedItem>().single;
      final undoing = applied.copyWith(undoState: UndoState.undoing);

      final restored = roundTrip([undoing]).single as AppliedItem;

      expect(restored.undoState, UndoState.available);
      expect(restored.receipt, applied.receipt);
      expect(restored.undoUntil, applied.undoUntil);
    });
  });

  group('untrusted records are skipped, not fatal', () {
    test('unknown type, newer schema, wrong shapes', () {
      final good = encodeChatItem(const UserItem(id: 'u', text: 'hi'));

      final restored = decodeChatItems([
        {'schema': 1, 'id': 'x', 'type': 'poll'},
        {...good, 'schema': 2},
        {...good, 'text': 42},
        {'schema': 1, 'type': 'user', 'text': 'no id'},
        'not a map',
        null,
        {
          'schema': 1,
          'id': 'p',
          'type': 'plan',
          'planId': 'p_other',
          'plan': AssistantSeeds.shipPlan.toJson(),
          'status': 'applied',
        },
        {
          'schema': 1,
          'id': 'a',
          'type': 'applied',
          'planId': 'p_ship',
          'plan': AssistantSeeds.shipPlan.toJson(),
          'receipt': {'planId': 'p_ship', 'applied': 'everything'},
          'undoState': 'available',
        },
        {
          'schema': 1,
          'id': 'p',
          'type': 'plan',
          'planId': 'p_ship',
          'plan': AssistantSeeds.shipPlan.toJson(),
          'status': 'approved-by-injection',
        },
        good,
      ]);

      expect(restored, [const UserItem(id: 'u', text: 'hi')]);
    });
  });
}
