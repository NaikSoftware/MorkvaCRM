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

void main() {
  final now = DateTime.utc(2026, 11, 10, 12);

  test('settled items of every mockup round-trip unchanged', () {
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
      expect(roundTrip(settled), settled);
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

    test('a pending or committing plan comes back expired', () {
      final pending = PlanItem.proposed(id: 'a', plan: AssistantSeeds.shipPlan);
      final committing = pending.copyWith(status: PlanStatus.committing);

      final restored = roundTrip([pending, committing]).cast<PlanItem>();

      expect(restored.map((p) => p.status), [
        PlanStatus.expired,
        PlanStatus.expired,
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
