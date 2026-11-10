import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/features/assistant/bloc/assistant_state.dart';
import 'package:morkva_crm/features/assistant/bloc/chat_item.dart';

import 'assistant_seeds.dart';
import 'fake_assistant_bloc.dart';

void main() {
  final now = DateTime(2026, 11, 10, 13);

  test('Main waits on its one pending plan, all 3 orders ticked', () {
    final state = FakeAssistantBloc.main().state;

    expect(state.phase, const AwaitingApprovalPhase('p_ship'));
    expect(state.pendingPlan!.plan.planId, 'p_ship');
    expect(state.pendingPlan!.selected, {'i1', 'i2', 'i3'});
    expect(state.focus!.label, 'Looking at: Orders');
    final table = state.items.whereType<TableItem>().single.table!;
    expect(table.rows, hasLength(5));
    expect(table.totals!.last, '₴ 9 840');
    expect(
      state.items.whereType<StepsItem>().single.headline,
      'Looked at Orders · filtered 148 → 5 · summed Total',
    );
  });

  test('Empty greets Olena over 8 collections with nothing in the chat', () {
    final state = FakeAssistantBloc.empty().state;

    expect(state.items, isEmpty);
    expect(state.userFirstName, 'Olena');
    expect(state.collectionNames, hasLength(8));
    expect(state.availability.canSend, isTrue);
  });

  test('Analyze shows "12 of 14" with 9 minutes of undo left', () {
    final state = FakeAssistantBloc.analyze(now: now).state;
    final applied = state.items.whereType<AppliedItem>().single;

    expect(applied.receipt.approvedCount, 12);
    expect(applied.receipt.totalCount, 14);
    expect(applied.undoUntil!.difference(now), const Duration(minutes: 9));
    final chart = state.items.whereType<ChartItem>().single.chart!;
    expect(chart.points, hasLength(11));
    expect(chart.points.last.partial, isTrue);
  });

  test('Schema waits on a destructive 7-order plan under a retry banner', () {
    final state = FakeAssistantBloc.schema(now: now).state;
    final plan = state.pendingPlan!;

    expect(plan.plan.destructive, isTrue);
    expect(plan.plan.itemCount, 7);
    expect(plan.selected, hasLength(7));
    expect(
      (state.banner! as RetryBanner).until.difference(now),
      const Duration(seconds: 20),
    );
    expect(state.items.whereType<ErrorItem>().single.nothingChanged, isTrue);
  });

  test('Phone streams through its live text while a step runs', () {
    final live = ValueNotifier(AssistantSeeds.phoneStreamingText);
    final state = FakeAssistantBloc.phoneStreaming(live: live).state;
    final text = state.items.whereType<AssistantTextItem>().single;

    expect(state.phase, const StreamingPhase());
    expect(state.phase.active, isTrue);
    expect(text.streaming, isTrue);
    expect(state.items.whereType<StepsItem>().single.running, isTrue);

    live.value = '${live.value} (#1042, #1051).';
    expect(text.currentText, endsWith('(#1042, #1051).'));
  });

  test('the Tablet history lists 5 threads, newest first', () {
    final threads = AssistantSeeds.threads(now: now);
    final updated = [
      for (final t in threads) DateTime.parse(t['updatedAt']! as String),
    ];

    expect(threads.map((t) => t['title']).first, 'Unpaid orders this month');
    expect(updated, [...updated]..sort((a, b) => b.compareTo(a)));
    expect(FakeAssistantBloc.tabletHistory().state.threadId, 't_unpaid');
  });

  blocTest<FakeAssistantBloc, AssistantState>(
    'set moves the fake to the next state',
    build: FakeAssistantBloc.empty,
    act: (bloc) => bloc.set(AssistantSeeds.main()),
    expect: () => [
      isA<AssistantState>().having((s) => s.threadId, 'threadId', 't_unpaid'),
    ],
  );
}
