import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/agent/agent_event.dart';
import 'package:morkva_crm/core/agent/llm_client.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/features/assistant/bloc/assistant_bloc.dart';
import 'package:morkva_crm/features/assistant/bloc/assistant_focus.dart';
import 'package:morkva_crm/features/assistant/bloc/assistant_state.dart';
import 'package:morkva_crm/features/assistant/bloc/chat_item.dart';

import 'assistant_rig.dart';

void main() {
  late AssistantRig rig;

  tearDown(() => rig.dispose());

  /// The response the model got for the plan call(s) of request [i].
  Map<String, Object?> planResponse(int request) {
    final contents = rig.llm.requests[request].contents;
    final responses = contents.whereType<LlmFunctionResponses>().last;
    return responses.responses.last.response;
  }

  Future<void> editStatus(int number, String optionId) async {
    final card = rig.order(number)!;
    final schema = rig.seed.collections.firstWhere(
      (c) => c.id == SeedIds.orders,
    );
    await rig.repo.saveObject(
      card.copyWith(
        values: {
          ...card.values,
          OrderFields.status: SingleSelectFieldValue(optionId),
        },
      ),
      schema: schema,
    );
    await rig.settle();
  }

  group('a write turn', () {
    final all = [for (var n = 1001; n <= 1024; n++) n];
    late Map<int, String?> items;

    blocTest<AssistantBloc, AssistantState>(
      'submit → thinking → streaming → steps → plan → partial approve → '
      'applying (progress) → applied → undo',
      setUp: () async {
        rig = AssistantRig(
          replies: [
            FakeReply(
              text: const ['Renaming them now.'],
              calls: [
                call('cards_update', {
                  'collection': 'Orders',
                  'target': {
                    'ids': [for (final n in all) SeedCards.order(n)],
                  },
                  'set': {'Item': 'Batch'},
                }),
              ],
            ),
            const FakeReply(text: ['Renamed 23 orders.']),
          ],
        );
        await rig.start();
        items = {
          for (final n in all)
            n: (rig.order(n)![OrderFields.item] as TextFieldValue?)?.text,
        };
      },
      build: () => rig.bloc,
      act: (bloc) async {
        await rig.ask('Rename every order to Batch, except the last');
        await rig.awaitingApproval();
        final plan = rig.plan.plan;
        bloc
          ..add(
            PlanSelectionChanged(
              plan.planId,
              {for (final r in plan.rows) r.itemId}
                ..remove(plan.rows.last.itemId),
            ),
          )
          ..add(PlanApproved(plan.planId));
        await rig.until(
          (s) =>
              s.phase is IdlePhase &&
              s.items.whereType<AppliedItem>().isNotEmpty,
        );
        await rig.settle();
        bloc.add(UndoRequested(rig.applied.receipt.journalId!));
        await rig.until((s) => rig.applied.undoState == UndoState.undone);
        await rig.settle();
      },
      expect: () => containsAllInOrder([
        stateWhere((s) => s.phase is ThinkingPhase, 'thinking'),
        stateWhere(
          (s) =>
              s.phase is StreamingPhase &&
              s.items.last is AssistantTextItem &&
              (s.items.last as AssistantTextItem).streaming,
          'streaming',
        ),
        stateWhere(
          (s) =>
              s.phase is RunningToolsPhase &&
              s.items.last is StepsItem &&
              (s.items.whereType<AssistantTextItem>().single.text ==
                  'Renaming them now.'),
          'steps',
        ),
        stateWhere(
          (s) =>
              s.phase is AwaitingApprovalPhase &&
              s.pendingPlan?.plan.itemCount == 24 &&
              s.pendingPlan!.selected.length == 24,
          'plan',
        ),
        stateWhere((s) => s.pendingPlan?.selected.length == 23, '23 ticked'),
        stateWhere(
          (s) =>
              s.phase == const ApplyingPhase(0, 23) &&
              s.items.whereType<PlanItem>().single.status ==
                  PlanStatus.committing,
          'applying',
        ),
        stateWhere(
          (s) => s.phase == const ApplyingPhase(23, 23),
          'progress event',
        ),
        stateWhere(
          (s) =>
              s.items.whereType<PlanItem>().single.status ==
                  PlanStatus.applied &&
              s.items.last is AppliedItem,
          'applied',
        ),
        stateWhere(
          (s) =>
              s.phase is IdlePhase &&
              s.items.last is AssistantTextItem &&
              (s.items.last as AssistantTextItem).text == 'Renamed 23 orders.',
          'follow-up',
        ),
        stateWhere(
          (s) =>
              s.items.whereType<AppliedItem>().single.undoState ==
              UndoState.undoing,
          'undoing',
        ),
        stateWhere(
          (s) =>
              s.items.whereType<AppliedItem>().single.undoState ==
              UndoState.undone,
          'undone',
        ),
      ]),
      verify: (_) {
        final receipt = rig.applied.receipt;
        expect(receipt.applied, hasLength(23));
        expect(receipt.declinedByUser, hasLength(1));
        expect(rig.applied.undoNote, isNotNull);
        expect(rig.repo.batchCalls, greaterThanOrEqualTo(2));
        for (final n in all) {
          expect(
            (rig.order(n)![OrderFields.item] as TextFieldValue?)?.text,
            items[n],
            reason: 'order $n restored by undo',
          );
        }
      },
    );
  });

  group('the plan gate', () {
    blocTest<AssistantBloc, AssistantState>(
      'reject: nothing is written and the model hears "rejected"',
      setUp: () async {
        rig = AssistantRig(
          replies: [
            FakeReply(calls: [shipCall(notShipped(3))]),
            const FakeReply(text: ['Okay, I left them as they are.']),
          ],
        );
        await rig.start();
      },
      build: () => rig.bloc,
      act: (bloc) async {
        await rig.ask('Ship three orders');
        await rig.awaitingApproval();
        bloc.add(PlanRejected(rig.plan.plan.planId));
        await rig.idle();
      },
      expect: () => containsAllInOrder([
        stateWhere((s) => s.phase is AwaitingApprovalPhase),
        stateWhere(
          (s) =>
              s.items.whereType<PlanItem>().single.status ==
              PlanStatus.rejected,
          'rejected',
        ),
        stateWhere((s) => s.phase is IdlePhase),
      ]),
      verify: (_) {
        expect(rig.repo.batchCalls, 0);
        expect(planResponse(1), {'status': 'rejected', 'reason': 'user'});
        expect(rig.state.items.whereType<AppliedItem>(), isEmpty);
      },
    );

    blocTest<AssistantBloc, AssistantState>(
      'a new message skips the plan, then starts the next turn',
      setUp: () async {
        rig = AssistantRig(
          replies: [
            FakeReply(calls: [shipCall(notShipped(2))]),
            const FakeReply(text: ['There are 24 orders.']),
          ],
        );
        await rig.start();
      },
      build: () => rig.bloc,
      act: (bloc) async {
        await rig.ask('Ship two orders');
        await rig.awaitingApproval();
        bloc.add(const PromptSubmitted('Actually, how many orders are there?'));
        await rig.until(
          (s) =>
              s.phase is IdlePhase &&
              s.items.whereType<UserItem>().length == 2 &&
              s.items.last is AssistantTextItem,
        );
      },
      expect: () => containsAllInOrder([
        stateWhere(
          (s) =>
              s.items.whereType<PlanItem>().single.status == PlanStatus.skipped,
          'skipped',
        ),
        stateWhere(
          (s) =>
              s.items.whereType<UserItem>().length == 2 &&
              s.phase is ThinkingPhase,
          'next turn',
        ),
      ]),
      verify: (_) {
        expect(rig.repo.batchCalls, 0);
        // The skip ends the turn without a model round; the next turn sees
        // the skipped outcome in its history.
        expect(rig.llm.requests, hasLength(2));
        expect(planResponse(1), {'status': 'rejected', 'reason': 'skipped'});
      },
    );

    blocTest<AssistantBloc, AssistantState>(
      'stale: cards changed since the preview are skipped, not overwritten',
      setUp: () async {
        rig = AssistantRig(
          replies: [
            FakeReply(calls: [shipCall(notShipped(2))]),
            const FakeReply(text: ['Both changed in the meantime.']),
          ],
        );
        await rig.start();
      },
      build: () => rig.bloc,
      act: (bloc) async {
        await rig.ask('Ship two orders');
        await rig.awaitingApproval();
        for (final n in notShipped(2)) {
          await editStatus(n, SeedOptions.done);
        }
        bloc.add(PlanApproved(rig.plan.plan.planId));
        await rig.idle();
      },
      expect: () => containsAllInOrder([
        stateWhere((s) => s.phase is ApplyingPhase),
        stateWhere(
          (s) =>
              s.items.whereType<PlanItem>().single.status == PlanStatus.stale,
          'stale',
        ),
      ]),
      verify: (_) {
        expect(rig.state.items.whereType<AppliedItem>(), isEmpty);
        for (final n in notShipped(2)) {
          expect(rig.statusOf(n), SeedOptions.done, reason: 'kept the edit');
        }
        expect(planResponse(1)['stale'], hasLength(2));
      },
    );
  });

  group('availability', () {
    blocTest<AssistantBloc, AssistantState>(
      'flag off: "isn\'t enabled", and a prompt is ignored',
      setUp: () async {
        rig = AssistantRig(
          replies: const [
            FakeReply(text: ['never']),
          ],
        );
        await rig.firestore.collection('featureFlags').doc(user.uid).set({
          'assistant': false,
        });
        await rig.start();
      },
      build: () => rig.bloc,
      act: (bloc) async {
        bloc.add(const PromptSubmitted('Hello'));
        await rig.settle();
      },
      verify: (_) {
        expect(rig.state.availability, isA<AvailabilityDisabledByFlag>());
        expect(rig.state.items, isEmpty);
        expect(rig.llm.requests, isEmpty);
      },
    );

    blocTest<AssistantBloc, AssistantState>(
      'consent needed: the disclosure until "Enable Ask Morkva"',
      setUp: () async {
        rig = AssistantRig();
        await rig.start(consented: false);
      },
      build: () => rig.bloc,
      act: (bloc) async {
        expect(
          bloc.state.availability,
          const AvailabilityNeedsConsent(freeTier: true),
        );
        bloc.add(const PromptSubmitted('Hello'));
        bloc.add(const ConsentGranted());
        await rig.until((s) => s.availability is AvailabilityEnabled);
        await rig.settle();
      },
      expect: () => [
        stateWhere((s) => s.availability is AvailabilityEnabled, 'enabled'),
      ],
      verify: (_) async {
        expect(rig.state.items, isEmpty, reason: 'sent before consent');
        final doc = await rig.firestore
            .doc('workspaces/$workspaceId/config/assistant')
            .get();
        expect(doc.data()?['consentedBy'], user.uid);
      },
    );

    blocTest<AssistantBloc, AssistantState>(
      'offline: the composer is off, and approving needs a connection',
      setUp: () async {
        rig = AssistantRig(
          replies: [
            FakeReply(calls: [shipCall(notShipped(2))]),
            const FakeReply(text: ['Shipped.']),
          ],
        );
        await rig.start();
      },
      build: () => rig.bloc,
      act: (bloc) async {
        await rig.ask('Ship two orders');
        await rig.awaitingApproval();
        rig.sync.reportSnapshotMeta(isFromCache: true, hasPendingWrites: false);
        await rig.until((s) => s.availability is AvailabilityOffline);
        bloc.add(PlanApproved(rig.plan.plan.planId));
        await rig.until((s) => rig.plan.message == 'Needs a connection');
        expect(rig.plan.status, PlanStatus.pending);
        expect(rig.repo.batchCalls, 0);

        rig.sync.reportSnapshotMeta(
          isFromCache: false,
          hasPendingWrites: false,
        );
        await rig.until((s) => s.availability is AvailabilityEnabled);
        bloc.add(PlanApproved(rig.plan.plan.planId));
        await rig.idle();
      },
      expect: () => containsAllInOrder([
        stateWhere((s) => s.availability is AvailabilityOffline, 'offline'),
        stateWhere((s) => s.availability is AvailabilityEnabled, 'online'),
        stateWhere((s) => s.items.last is AppliedItem, 'applied'),
      ]),
      verify: (_) {
        for (final n in notShipped(2)) {
          expect(rig.statusOf(n), SeedOptions.shipped);
        }
      },
    );

    blocTest<AssistantBloc, AssistantState>(
      'back online, a pending plan drops its "Needs a connection" note',
      setUp: () async {
        rig = AssistantRig(
          replies: [
            FakeReply(calls: [shipCall(notShipped(2))]),
            const FakeReply(text: ['Left as they are.']),
          ],
        );
        await rig.start();
      },
      build: () => rig.bloc,
      act: (bloc) async {
        await rig.ask('Ship two orders');
        await rig.awaitingApproval();
        rig.sync.reportSnapshotMeta(isFromCache: true, hasPendingWrites: false);
        await rig.until((s) => s.availability is AvailabilityOffline);
        bloc.add(PlanApproved(rig.plan.plan.planId));
        await rig.until((s) => rig.plan.message == 'Needs a connection');

        rig.sync.reportSnapshotMeta(
          isFromCache: false,
          hasPendingWrites: false,
        );
        await rig.until((s) => s.availability is AvailabilityEnabled);
        expect(rig.plan.message, isNull);
        expect(rig.plan.status, PlanStatus.pending);

        bloc.add(PlanRejected(rig.plan.plan.planId));
        await rig.idle();
      },
      expect: () => containsAllInOrder([
        stateWhere(
          (s) => s.items.whereType<PlanItem>().lastOrNull?.message != null,
          'note',
        ),
        stateWhere(
          (s) => s.items.whereType<PlanItem>().lastOrNull?.message == null,
          'cleared',
        ),
      ]),
      verify: (_) => expect(rig.repo.batchCalls, 0),
    );

    blocTest<AssistantBloc, AssistantState>(
      'back online, an applied card drops its "Needs a connection to undo" '
      'note and undo then works',
      setUp: () async {
        rig = AssistantRig(
          replies: [
            FakeReply(calls: [shipCall(notShipped(2))]),
            const FakeReply(text: ['Shipped.']),
          ],
        );
        await rig.start();
      },
      build: () => rig.bloc,
      act: (bloc) async {
        await rig.ask('Ship two orders');
        await rig.awaitingApproval();
        bloc.add(PlanApproved(rig.plan.plan.planId));
        await rig.until(
          (s) =>
              s.phase is IdlePhase &&
              s.items.whereType<AppliedItem>().isNotEmpty,
        );
        await rig.settle();
        final journalId = rig.applied.receipt.journalId!;

        rig.sync.reportSnapshotMeta(isFromCache: true, hasPendingWrites: false);
        await rig.until((s) => s.availability is AvailabilityOffline);
        bloc.add(UndoRequested(journalId));
        await rig.until(
          (s) => rig.applied.undoNote == 'Needs a connection to undo',
        );
        expect(rig.applied.undoState, UndoState.available);

        rig.sync.reportSnapshotMeta(
          isFromCache: false,
          hasPendingWrites: false,
        );
        await rig.until((s) => s.availability is AvailabilityEnabled);
        expect(rig.applied.undoNote, isNull);

        bloc.add(UndoRequested(journalId));
        await rig.until((s) => rig.applied.undoState == UndoState.undone);
        await rig.settle();
      },
      verify: (_) {
        expect(rig.applied.undoNote, isNot('Needs a connection to undo'));
        for (final n in notShipped(2)) {
          expect(rig.statusOf(n), isNot(SeedOptions.shipped));
        }
      },
    );

    blocTest<AssistantBloc, AssistantState>(
      'a message sent offline is ignored',
      setUp: () async {
        rig = AssistantRig();
        await rig.start();
        rig.sync.reportSnapshotMeta(isFromCache: true, hasPendingWrites: false);
        await rig.until((s) => s.availability is AvailabilityOffline);
      },
      build: () => rig.bloc,
      act: (bloc) async {
        bloc.add(const PromptSubmitted('Hello'));
        await rig.settle();
      },
      expect: () => isEmpty,
      verify: (_) => expect(rig.llm.requests, isEmpty),
    );
  });

  group('limits and failures', () {
    blocTest<AssistantBloc, AssistantState>(
      'a rate limit shows the retry banner; "Retry now" goes on at once',
      setUp: () async {
        rig = AssistantRig(
          replies: const [
            FakeReply.fail(LlmRateLimited(retryAfter: Duration(seconds: 30))),
            FakeReply(text: ['Back again.']),
          ],
        );
        await rig.start();
      },
      build: () => rig.bloc,
      act: (bloc) async {
        await rig.ask('Hello');
        await rig.until((s) => s.banner is RetryBanner);
        bloc.add(const RetryNowRequested());
        await rig.idle();
      },
      expect: () => containsAllInOrder([
        stateWhere(
          (s) =>
              s.banner ==
              RetryBanner(
                rig.clock.add(const Duration(seconds: 30)),
                RetryReason.rpm,
              ),
          'retry banner',
        ),
        stateWhere(
          (s) =>
              s.banner == null &&
              s.phase is IdlePhase &&
              (s.items.last as AssistantTextItem).text == 'Back again.',
          'answered',
        ),
      ]),
    );

    blocTest<AssistantBloc, AssistantState>(
      'the daily quota closes the composer until the reset',
      setUp: () async {
        rig = AssistantRig(replies: const [FakeReply.fail(LlmDailyQuota())]);
        await rig.start();
      },
      build: () => rig.bloc,
      act: (bloc) async {
        await rig.ask('Hello');
        await rig.until((s) => s.availability is AvailabilityQuotaExhausted);
        bloc.add(const PromptSubmitted('Again'));
        await rig.settle();
      },
      verify: (_) {
        final until = nextPacificMidnight(rig.clock);
        expect(rig.state.availability, AvailabilityQuotaExhausted(until));
        expect(until.isAfter(rig.clock), isTrue);
        final error = rig.state.items.whereType<ErrorItem>().single;
        expect(error.kind, ChatErrorKind.dailyQuota);
        expect(error.retryable, isFalse);
        expect(error.message, contains('Nothing was changed'));
        expect(rig.state.items.whereType<UserItem>(), hasLength(1));
      },
    );

    blocTest<AssistantBloc, AssistantState>(
      'an error row, then "Try again" re-sends the last message',
      setUp: () async {
        rig = AssistantRig(
          replies: const [
            FakeReply.fail(LlmUnknownFailure('boom')),
            FakeReply(text: ['It worked this time.']),
          ],
        );
        await rig.start();
      },
      build: () => rig.bloc,
      act: (bloc) async {
        await rig.ask('Count the orders');
        await rig.until((s) => s.phase is FailedPhase);
        bloc.add(const RetryRequested());
        await rig.until(
          (s) => s.phase is IdlePhase && s.items.last is AssistantTextItem,
        );
      },
      expect: () => containsAllInOrder([
        stateWhere(
          (s) =>
              s.phase is FailedPhase &&
              s.items.last is ErrorItem &&
              (s.items.last as ErrorItem).nothingChanged,
          'error row',
        ),
        stateWhere(
          (s) =>
              s.items.whereType<UserItem>().length == 2 &&
              s.items.whereType<UserItem>().last.text == 'Count the orders',
          're-sent',
        ),
      ]),
    );

    blocTest<AssistantBloc, AssistantState>(
      'an AI backend that is not set up closes the chat',
      setUp: () async {
        rig = AssistantRig(
          replies: const [FakeReply.fail(LlmNotSetUp('API disabled'))],
        );
        await rig.start();
      },
      build: () => rig.bloc,
      act: (bloc) async {
        await rig.ask('Hello');
        await rig.until((s) => s.availability is AvailabilityNotSetUp);
      },
      verify: (_) {
        expect(rig.state.phase, isA<IdlePhase>());
        expect(rig.state.items.whereType<ErrorItem>(), isEmpty);
      },
    );
  });

  group('threads', () {
    blocTest<AssistantBloc, AssistantState>(
      'switching while a plan waits skips it; the thread reopens as saved',
      setUp: () async {
        rig = AssistantRig(
          replies: [
            FakeReply(calls: [shipCall(notShipped(2))]),
          ],
        );
        await rig.start();
      },
      build: () => rig.bloc,
      act: (bloc) async {
        await rig.ask('Ship two orders');
        await rig.awaitingApproval();
        final threadId = bloc.state.threadId!;
        bloc.add(const NewThreadRequested());
        await rig.until((s) => s.threadId == null && s.items.isEmpty);
        bloc.add(ThreadSelected(threadId));
        await rig.until((s) => s.threadId == threadId && s.items.isNotEmpty);
      },
      expect: () => containsAllInOrder([
        stateWhere(
          (s) =>
              s.items.whereType<PlanItem>().single.status == PlanStatus.skipped,
          'skipped',
        ),
        stateWhere((s) => s.threadId == null && s.items.isEmpty, 'new thread'),
        stateWhere(
          (s) =>
              s.threadTitle == 'Ship two orders' &&
              s.items.whereType<PlanItem>().single.status ==
                  PlanStatus.skipped &&
              s.items.first is UserItem,
          'reopened',
        ),
      ]),
      verify: (_) async {
        expect(rig.repo.batchCalls, 0);
        final docs = await rig.turnDocs(rig.state.threadId!);
        expect(docs.single['status'], 'done');
      },
    );

    blocTest<AssistantBloc, AssistantState>(
      'a switch while applying waits for the receipt',
      setUp: () async {
        rig = AssistantRig(
          replies: [
            FakeReply(calls: [shipCall(notShipped(3))]),
            const FakeReply.hold(text: ['Shipped all three']),
          ],
        );
        await rig.start();
      },
      build: () => rig.bloc,
      act: (bloc) async {
        await rig.ask('Ship three orders');
        await rig.awaitingApproval();
        bloc
          ..add(PlanApproved(rig.plan.plan.planId))
          ..add(const NewThreadRequested());
        await rig.until((s) => s.threadId == null && s.items.isEmpty);
        await rig.settle();
      },
      expect: () => containsAllInOrder([
        stateWhere((s) => s.phase is ApplyingPhase, 'applying'),
        stateWhere(
          (s) => s.items.last is AppliedItem && s.threadId != null,
          'applied first',
        ),
        stateWhere((s) => s.threadId == null, 'then switched'),
      ]),
      verify: (_) async {
        for (final n in notShipped(3)) {
          expect(rig.statusOf(n), SeedOptions.shipped);
        }
        final threads = await rig.firestore
            .collection(
              'workspaces/$workspaceId/members/${user.uid}/'
              'assistantThreads',
            )
            .get();
        final docs = await rig.turnDocs(threads.docs.single.id);
        expect(docs.single['status'], 'done');
        expect(
          (docs.single['ui'] as List).map((r) => (r as Map)['type']),
          containsAllInOrder(['user', 'steps', 'plan', 'applied', 'text']),
        );
      },
    );

    blocTest<AssistantBloc, AssistantState>(
      'deleting the open thread starts a new one and removes its docs',
      setUp: () async {
        rig = AssistantRig(
          replies: const [
            FakeReply(text: ['Hi.']),
          ],
        );
        await rig.start();
      },
      build: () => rig.bloc,
      act: (bloc) async {
        await rig.ask('Hello');
        await rig.idle();
        bloc.add(ThreadDeleted(bloc.state.threadId!));
        await rig.until((s) => s.threadId == null);
        await rig.settle();
      },
      verify: (_) async {
        final threads = await rig.firestore
            .collection(
              'workspaces/$workspaceId/members/${user.uid}/'
              'assistantThreads',
            )
            .get();
        expect(threads.docs, isEmpty);
      },
    );
  });

  group('after a reload', () {
    AssistantRig? reloaded;

    tearDown(() async {
      await reloaded?.dispose();
      reloaded = null;
    });

    AssistantRig reload() => AssistantRig(
      repository: rig.repo,
      firestore: rig.firestore,
      replies: const [
        FakeReply(text: ['Fresh answer.']),
      ],
    );

    test('a committed turn comes back applied, with a working Undo; the '
        'gate tail is not replayed', () async {
      final targets = notShipped(2);
      rig = AssistantRig(
        replies: [
          FakeReply(calls: [shipCall(targets)]),
          const FakeReply.hold(),
        ],
      );
      await rig.start();
      final before = {for (final n in targets) n: rig.statusOf(n)};
      await rig.ask('Ship two orders');
      await rig.awaitingApproval();
      rig.bloc.add(PlanApproved(rig.plan.plan.planId));
      await rig.until((s) => s.items.last is AppliedItem);
      await rig.settle();
      final threadId = rig.state.threadId!;
      expect((await rig.turnDocs(threadId)).single['status'], 'committed');

      // The page reloads mid-reply: a new session reads the thread.
      final again = reloaded = reload();
      await again.start();
      again.bloc.add(ThreadSelected(threadId));
      final s = await again.until(
        (s) => s.items.whereType<AppliedItem>().isNotEmpty,
      );
      final applied = s.items.whereType<AppliedItem>().single;
      expect(applied.undoState, UndoState.available);
      expect(applied.undoUntil, isNotNull);
      final turn = again.session.agentLoop.history.single;
      expect(turn.contents.map((c) => (c as LlmRawContent).json['role']), [
        'user',
      ], reason: 'the model call without responses is dropped');

      again.bloc.add(UndoRequested(applied.receipt.journalId!));
      await again.until(
        (s) =>
            s.items.whereType<AppliedItem>().single.undoState ==
            UndoState.undone,
      );
      await again.settle();
      for (final n in targets) {
        expect(rig.statusOf(n), before[n]);
      }

      // The restored thread goes on with the next turn.
      await again.ask('Thanks');
      final next = await again.until(
        (s) => s.phase is IdlePhase && s.items.last is AssistantTextItem,
      );
      expect((next.items.last as AssistantTextItem).text, 'Fresh answer.');
    });

    test('a plan pending at the reload comes back expired', () async {
      rig = AssistantRig(
        replies: [
          FakeReply(calls: [shipCall(notShipped(2))]),
        ],
      );
      await rig.start();
      await rig.ask('Ship two orders');
      await rig.awaitingApproval();
      final threadId = rig.state.threadId!;
      await rig.settle();
      expect((await rig.turnDocs(threadId)).single['status'], 'pending');

      final again = reloaded = reload();
      await again.start();
      again.bloc.add(ThreadSelected(threadId));
      final s = await again.until((s) => s.items.isNotEmpty);
      expect(s.items.whereType<PlanItem>().single.status, PlanStatus.expired);
      expect(s.phase, isA<IdlePhase>());
    });
  });

  group('screen focus and results', () {
    blocTest<AssistantBloc, AssistantState>(
      'the focus becomes the turn\'s screen line; a removed chip omits it',
      setUp: () async {
        rig = AssistantRig(
          replies: const [
            FakeReply(text: ['These are orders.']),
            FakeReply(text: ['Sure.']),
          ],
        );
        await rig.start();
      },
      build: () => rig.bloc,
      act: (bloc) async {
        rig.session.focus.value = const AssistantFocus(
          page: FocusPage.collection,
          collectionId: SeedIds.orders,
          collectionName: 'Orders',
          shownCount: 24,
        );
        await rig.until((s) => s.focus != null);
        await rig.ask('What are these?');
        await rig.idle();
        bloc.add(const FocusCleared());
        await rig.until((s) => s.focus == null);
        await rig.ask('And now?');
        await rig.until((s) => s.phase is IdlePhase && s.items.length == 4);
      },
      expect: () => containsAllInOrder([
        stateWhere(
          (s) => s.focus?.label == 'Looking at: Orders · 24 shown',
          'chip',
        ),
        stateWhere((s) => s.focus == null, 'removed'),
      ]),
      verify: (_) {
        String lastUserText(int request) =>
            (rig.llm.requests[request].contents.last as LlmUserText).text;
        expect(lastUserText(0), startsWith('[Screen:'));
        expect(lastUserText(0), contains('"Orders"'));
        expect(lastUserText(1), 'And now?');
      },
    );

    blocTest<AssistantBloc, AssistantState>(
      'a chart answer is rendered from the stored aggregate',
      setUp: () async {
        rig = AssistantRig(
          replies: [
            FakeReply(
              calls: [
                call('cards_aggregate', {
                  'collection': 'Orders',
                  'groupBy': {'field': 'Status'},
                  'metrics': [
                    {'op': 'count'},
                  ],
                  'present': 'bar',
                }),
              ],
            ),
            const FakeReply(text: ['Most orders are done.']),
          ],
        );
        await rig.start();
      },
      build: () => rig.bloc,
      act: (bloc) async {
        await rig.ask('Orders by status as a chart');
        await rig.idle();
      },
      verify: (_) {
        final chart = rig.state.items.whereType<ChartItem>().single;
        expect(chart.kind, PresentKind.bar);
        expect(chart.spec?['kind'], 'aggregate');
        final points = chart.chart!.points;
        expect(points.map((p) => p.label), contains('Packing'));
        final total = points.fold<double>(0, (sum, p) => sum + (p.value ?? 0));
        expect(total, rig.seed.orderCards.length);
        expect(chart.chart!.collectionId, SeedIds.orders);
      },
    );

    blocTest<AssistantBloc, AssistantState>(
      'a ui.open chip is posted, never navigated to',
      setUp: () async {
        rig = AssistantRig(
          replies: [
            FakeReply(
              calls: [
                call('ui_open', {'collection': 'Orders'}),
              ],
            ),
            const FakeReply(text: ['Tap to open Orders.']),
          ],
        );
        await rig.start();
      },
      build: () => rig.bloc,
      act: (bloc) async {
        await rig.ask('Open orders');
        await rig.idle();
      },
      verify: (_) {
        final chip = rig.state.items.whereType<ObjectChipItem>().single;
        expect(chip.collectionId, SeedIds.orders);
        expect(chip.label, 'Orders');
      },
    );
  });
}
