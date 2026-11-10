import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/agent/llm_client.dart';
import 'package:morkva_crm/features/assistant/bloc/assistant_bloc.dart';
import 'package:morkva_crm/features/assistant/bloc/assistant_session.dart';
import 'package:morkva_crm/features/assistant/bloc/assistant_state.dart';
import 'package:morkva_crm/features/assistant/bloc/chat_item.dart';

import 'assistant_rig.dart';

/// End to end through the real harness and agent loop with a scripted
/// model: every write lands in (and is undone from) the FakeDataRepository.
void main() {
  late AssistantRig rig;

  tearDown(() => rig.dispose());

  test(
    'ask → query → answer, then plan → approve 2 of 3 → applied → undo',
    () async {
      final targets = notShipped(3);
      rig = AssistantRig(
        replies: [
          FakeReply(text: const ['Let me look. '], calls: [queryCall()]),
          const FakeReply(text: ['Here are the packing orders.']),
          FakeReply(calls: [shipCall(targets)]),
          const FakeReply(text: ['Shipped 2 orders; I left one as it was.']),
        ],
      );
      await rig.start();
      final before = {for (final n in targets) n: rig.statusOf(n)};

      // Ask → query → answer.
      await rig.ask('Which orders are packing?');
      var s = await rig.idle();
      final table = s.items.whereType<TableItem>().single;
      expect(table.table, isNotNull);
      final packing = rig.seed.orderCards
          .where(
            (o) =>
                (o[OrderFields.status] as dynamic).optionId ==
                SeedOptions.packing,
          )
          .map((o) => o.id)
          .toSet();
      expect(table.table!.rows.map((r) => r.cardId).toSet(), packing);
      expect(table.table!.collectionId, SeedIds.orders);
      expect(
        s.items.whereType<AssistantTextItem>().map((t) => t.text).join(),
        contains('Here are the packing orders.'),
      );
      final steps = s.items.whereType<StepsItem>().single;
      expect(steps.steps.single.status, StepStatus.done);
      expect(steps.steps.single.summary, contains('Orders'));

      // The model saw the result rows; persistence keeps only the summary.
      final firstDocs = await rig.turnDocs(s.threadId!);
      expect(firstDocs.single['status'], 'done');
      final llm = firstDocs.single['llm']! as String;
      expect(llm, contains('functionResponse'));
      expect(llm, isNot(contains('"rows"')));
      expect((jsonDecode(llm) as List).length, greaterThanOrEqualTo(4));

      // Plan → approve 2 of 3.
      await rig.ask('Ship those three');
      s = await rig.awaitingApproval();
      final plan = rig.plan;
      expect(plan.plan.itemCount, 3);
      expect(plan.selected, hasLength(3));
      expect(rig.repo.batchCalls, 0, reason: 'planning writes nothing');
      final keep = plan.plan.rows.last;
      rig.bloc
        ..add(
          PlanSelectionChanged(
            plan.plan.planId,
            {for (final r in plan.plan.rows) r.itemId}..remove(keep.itemId),
          ),
        )
        ..add(PlanApproved(plan.plan.planId));
      s = await rig.until(
        (s) =>
            s.phase is IdlePhase && s.items.whereType<AppliedItem>().isNotEmpty,
      );
      await rig.settle();
      final applied = rig.applied;
      expect(applied.receipt.applied, hasLength(2));
      expect(applied.receipt.declinedByUser, [keep.itemId]);
      expect(applied.undoState, UndoState.available);
      expect(rig.plan.status, PlanStatus.applied);
      final shipped = [
        for (final n in targets)
          if (rig.statusOf(n) == SeedOptions.shipped) n,
      ];
      expect(shipped, hasLength(2));
      expect(rig.statusOf(targets.last), before[targets.last]);

      // The model got the receipt as the plan call's response.
      final followUp = rig.llm.requests.last.contents.last;
      expect(followUp, isA<LlmFunctionResponses>());
      final response = (followUp as LlmFunctionResponses).responses.single;
      expect(response.response['status'], 'applied');
      expect(response.response['applied'], 2);

      // The committed doc carries the journal mirror for undo after a reload.
      final docs = await rig.turnDocs(s.threadId!);
      expect(docs.last['status'], 'done');
      expect(docs.last['journal'], isA<Map>());

      // Undo.
      rig.bloc.add(UndoRequested(applied.receipt.journalId!));
      await rig.until((s) => rig.applied.undoState == UndoState.undone);
      await rig.settle();
      for (final n in targets) {
        expect(rig.statusOf(n), before[n], reason: 'order $n restored');
      }
      final undoneDocs = await rig.turnDocs(s.threadId!);
      expect(undoneDocs.last['journal'], isNull);
    },
  );

  test('sign-out → sign-in: reset then initialize, and the bloc works '
      'again', () async {
    rig = AssistantRig(
      replies: const [
        FakeReply(text: ['First answer.']),
        FakeReply(text: ['Second answer.']),
      ],
    );
    await rig.start();
    await rig.ask('Hello');
    await rig.idle();
    expect(rig.state.threadId, isNotNull);

    await rig.session.reset();
    await rig.until((s) => s.threadId == null && s.items.isEmpty);
    expect(rig.state.availability, isA<AvailabilityChecking>());
    expect(rig.session.cache.workspaceId, isNull);

    await rig.session.initialize(workspaceId, user: user);
    await rig.until((s) => s.availability is AvailabilityEnabled);
    expect(rig.state.userFirstName, 'Olena');
    await rig.ask('Again');
    final s = await rig.idle();
    expect(
      s.items.whereType<AssistantTextItem>().single.text,
      'Second answer.',
    );
    // The new thread replays nothing from before the sign-out.
    expect(rig.llm.requests.last.contents.whereType<LlmUserText>().length, 2);
  });

  test('firstNameOf takes the first word of the display name', () {
    rig = AssistantRig();
    expect(AssistantSession.firstNameOf('Olena  Koval'), 'Olena');
    expect(AssistantSession.firstNameOf('  '), isNull);
    expect(AssistantSession.firstNameOf(null), isNull);
  });
}
