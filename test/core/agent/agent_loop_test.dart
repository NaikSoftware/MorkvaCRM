import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/agent/agent_event.dart';
import 'package:morkva_crm/core/agent/agent_loop.dart';
import 'package:morkva_crm/core/agent/grounding.dart';
import 'package:morkva_crm/core/agent/history_compactor.dart';
import 'package:morkva_crm/core/agent/llm_client.dart';
import 'package:morkva_crm/core/harness/harness.dart';

import '../harness/fixtures/seed_workspace.dart';
import 'fake_harness.dart';
import 'fake_llm_client.dart';

/// Lets queued microtasks and zero timers run.
Future<void> settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// A read result with a handle and a summary.
Map<String, Object?> readResult(String summary, {String handle = 'h_1'}) => {
  'handle': handle,
  'total': 3,
  'rows': const [
    {'id': 'b_1', 'title': '#1042'},
  ],
  'summary': summary,
};

void main() {
  late FakeLlmClient llm;
  late FakeOp query;
  late FakeOp aggregate;
  late FakeOp update;
  late FakeOp addField;
  late FakeOp open;
  late FakeOp seal;
  late Map<String, Object?> Function(HarnessRequest) sealAnswer;
  late Harness harness;
  late FakeWorkspace workspace;

  /// Every plan-op call in arrival order (op id, callId).
  late List<(String, String)> planOrder;

  setUp(() {
    llm = FakeLlmClient();
    planOrder = [];
    query = FakeOp(
      'cards.query',
      handler: (args, ctx, req) =>
          readResult('Filtered 148 → 5 Orders', handle: 'h_${req.callId}'),
    );
    aggregate = FakeOp(
      'cards.aggregate',
      handler: (args, ctx, req) => readResult('Summed Total'),
    );
    FakeHandler planned(String summary) => (args, ctx, req) {
      planOrder.add((req.op, req.callId));
      return {'planId': 'p_1', 'summary': summary};
    };
    update = FakeOp(
      'cards.update',
      kind: OpKind.plan,
      capability: Capability.dataWrite,
      handler: planned('Planned 2 updates'),
    );
    addField = FakeOp(
      'fields.add',
      kind: OpKind.plan,
      capability: Capability.schemaWrite,
      handler: planned('Planned 1 field'),
    );
    open = FakeOp(
      'ui.open',
      kind: OpKind.ui,
      capability: Capability.uiNavigate,
      handler: (args, ctx, req) => {
        'shown': true,
        'collectionId': SeedIds.orders,
        'cardId': 'b_or_1',
        'label': '#1042',
      },
    );
    sealAnswer = (_) => planJson('p_1');
    seal = fakeSeal(handler: (args, ctx, req) => sealAnswer(req));
    harness = fakeHarness([query, aggregate, update, addField, open, seal]);
    workspace = FakeWorkspace(collections: SeedWorkspace().collections);
  });

  AgentLoop loopFor({
    AgentSettings settings = const AgentSettings(rpm: 1000),
    DateTime Function()? now,
    HistoryCompactor compactor = const HistoryCompactor(),
  }) => AgentLoop(
    llm: llm,
    harness: harness,
    workspace: workspace,
    settings: settings,
    compactor: compactor,
    timeZoneName: 'Europe/Kyiv',
    now: now,
  );

  /// Runs a turn, answering every [PlanProposed] with [outcome].
  Future<List<AgentEvent>> runTurn(
    AgentLoop loop,
    String text, {
    ScreenContext? screen,
    PlanOutcome Function(CompactPlan plan)? outcome,
  }) => loop.run(text, screen: screen).map((e) {
    if (e is PlanProposed && outcome != null) {
      loop.deliverOutcome(e.plan.planId, outcome(e.plan));
    }
    return e;
  }).toList();

  String textOf(List<AgentEvent> events) =>
      events.whereType<TextDelta>().map((e) => e.text).join();

  List<LlmFunctionResponse> lastResponses(LlmRequest request) =>
      (request.contents.last as LlmFunctionResponses).responses;

  group('a text turn', () {
    test('streams the answer and ends with the usage', () async {
      llm.add(const FakeReply(text: ['Hello', ' there']));
      final loop = loopFor();

      final events = await runTurn(loop, 'hi');

      expect(events.first, isA<TurnStarted>());
      expect(
        events[1],
        isA<RoundStarted>()
            .having((e) => e.round, 'round', 1)
            .having((e) => e.model, 'model', 'gemini-3.5-flash-lite'),
      );
      expect(textOf(events), 'Hello there');
      expect(
        events.last,
        isA<TurnDone>().having(
          (e) => e.usage,
          'usage',
          const TokenUsage(promptTokens: 100, outputTokens: 10),
        ),
      );
      expect(loop.busy, isFalse);
      expect(loop.history.single.answer, 'Hello there');
    });

    test('sends the system text, the context message, then the message with '
        'its screen line', () async {
      llm.add(const FakeReply(text: ['5 orders']));
      final loop = loopFor();

      await runTurn(
        loop,
        'how many of these are unpaid?',
        screen: ScreenContext(
          page: ScreenPage.collection,
          collectionId: SeedIds.orders,
          shownCount: 23,
        ),
      );

      final request = llm.requests.single;
      expect(request.model, 'gemini-3.5-flash-lite');
      expect(request.systemInstruction, systemInstruction());
      expect(request.toolMode, LlmToolMode.auto);
      final context = (request.contents[0] as LlmUserText).text;
      expect(context, startsWith('Today is '));
      expect(context, contains('Time zone: Europe/Kyiv.'));
      expect(context, contains('<workspace-data>\n- "Orders" (3)'));
      expect(
        (request.contents[1] as LlmUserText).text,
        '[Screen: collection "Orders" · 23 shown]\n'
        'how many of these are unpaid?',
      );
    });

    test('declares model-visible tools only', () async {
      llm.add(const FakeReply(text: ['ok']));

      await runTurn(loopFor(), 'hi');

      expect(
        [for (final t in llm.requests.single.tools) t.name],
        [
          'cards_aggregate',
          'cards_query',
          'cards_update',
          'fields_add',
          'ui_open',
        ],
      );
    });

    test(
      'keeps the system text byte-stable while the digest changes',
      () async {
        llm.addAll([
          const FakeReply(text: ['a']),
          const FakeReply(text: ['b']),
        ]);
        final loop = loopFor();

        await runTurn(loop, 'one');
        workspace.digestText = '- "Orders" (4)';
        await runTurn(loop, 'two');

        expect(
          llm.requests[1].systemInstruction,
          llm.requests[0].systemInstruction,
        );
        expect(
          (llm.requests[1].contents[0] as LlmUserText).text,
          contains('(4)'),
        );
        // Context, the first turn (message and answer), the new message.
        expect(llm.requests[1].contents, hasLength(4));
      },
    );

    test('refuses a second turn while one runs', () async {
      llm.add(const FakeReply.hold());
      final loop = loopFor();
      final sub = loop.run('one').listen((_) {});
      await settle();

      expect(() => loop.run('two'), throwsStateError);

      loop.stop();
      await sub.asFuture<void>();
    });
  });

  group('reads', () {
    test(
      'run in parallel, at most 4 at once, answered in call order',
      () async {
        var inFlight = 0;
        var maxInFlight = 0;
        final slow = FakeOp(
          'cards.get',
          handler: (args, ctx, req) async {
            maxInFlight = ++inFlight > maxInFlight ? inFlight : maxInFlight;
            await Future<void>.delayed(const Duration(milliseconds: 5));
            inFlight--;
            return {'summary': 'Got ${args['n']}'};
          },
        );
        harness = fakeHarness([slow]);
        llm.addAll([
          FakeReply(
            calls: [
              for (var n = 1; n <= 6; n++) call('cards_get', {'n': n}),
            ],
          ),
          const FakeReply(text: ['done']),
        ]);

        final events = await runTurn(loopFor(), 'get them');

        expect(maxInFlight, 4);
        expect(
          [for (final c in slow.calls) c.request.callId],
          [for (var n = 1; n <= 6; n++) 'r1.$n'],
        );
        expect(
          [
            for (final r in lastResponses(llm.requests[1]))
              r.response['summary'],
          ],
          [for (var n = 1; n <= 6; n++) 'Got $n'],
        );
        expect(
          [for (final e in events.whereType<StepFinished>()) e.callId],
          [for (var n = 1; n <= 6; n++) 'r1.$n'],
        );
        expect(events.last, isA<TurnDone>());
      },
    );

    test('run as the agent under the turn with the screen as focus', () async {
      llm.addAll([
        FakeReply(
          calls: [
            call('cards_query', {'from': '@screen'}),
          ],
        ),
        const FakeReply(text: ['5']),
      ]);
      final screen = ScreenContext(
        page: ScreenPage.collection,
        collectionId: SeedIds.orders,
      );

      final events = await runTurn(loopFor(), 'these?', screen: screen);

      final ctx = query.calls.single.ctx;
      expect(ctx.actor, Actor.assistant);
      expect(ctx.focus, screen);
      expect(ctx.turnId, (events.first as TurnStarted).turnId);
      expect(ctx.workspaceId, 'ws_1');
      expect(
        events.whereType<StepStarted>().single.label,
        'Looking at Orders…',
      );
      expect(
        events.whereType<StepFinished>().single,
        isA<StepFinished>()
            .having((e) => e.ok, 'ok', isTrue)
            .having((e) => e.summary, 'summary', 'Filtered 148 → 5 Orders'),
      );
      expect(harness.ownsTurn(Actor.assistant, ctx.turnId!), isFalse);
    });

    test('present renders the stored result from its handle', () async {
      llm.addAll([
        FakeReply(
          calls: [
            call('cards_aggregate', {
              'collection': SeedIds.orders,
              'present': 'bar',
            }),
          ],
        ),
        const FakeReply(text: ['Here it is']),
      ]);

      final events = await runTurn(loopFor(), 'revenue by month');

      expect(
        events.whereType<ResultPresented>().single,
        isA<ResultPresented>()
            .having((e) => e.callId, 'callId', 'r1.1')
            .having((e) => e.handle, 'handle', 'h_1')
            .having((e) => e.kind, 'kind', PresentKind.bar)
            .having((e) => e.title, 'title', 'Summed Total'),
      );
    });

    test('ui.open shows an object chip', () async {
      llm.addAll([
        FakeReply(
          calls: [
            call('ui_open', {'collection': 'Orders'}),
          ],
        ),
        const FakeReply(text: ['Opened']),
      ]);

      final events = await runTurn(loopFor(), 'open it');

      expect(
        events.whereType<ObjectChipShown>().single,
        isA<ObjectChipShown>()
            .having((e) => e.collectionId, 'collectionId', SeedIds.orders)
            .having((e) => e.cardId, 'cardId', 'b_or_1')
            .having((e) => e.label, 'label', '#1042'),
      );
    });

    test('a harness error goes back to the model as the response', () async {
      final failing = FakeOp(
        'cards.query',
        handler: (args, ctx, req) => {
          'error': HarnessError(
            code: ErrorCode.unknownField,
            message: 'No field "Totl" in Orders.',
            candidates: const ['Total'],
          ),
        },
      );
      harness = fakeHarness([failing]);
      llm.addAll([
        FakeReply(
          calls: [
            call('cards_query', {'collection': 'Orders'}),
          ],
        ),
        const FakeReply(text: ['fixed']),
      ]);

      final events = await runTurn(loopFor(), 'q');

      final response = lastResponses(llm.requests[1]).single.response;
      expect(response['error'], containsPair('code', 'unknown_field'));
      expect(response['error'], containsPair('candidates', ['Total']));
      expect(
        events.whereType<StepFinished>().single,
        isA<StepFinished>()
            .having((e) => e.ok, 'ok', isFalse)
            .having((e) => e.errorCode, 'errorCode', 'unknown_field'),
      );
    });

    test('a slip the model corrects shows plain copy, not the model-facing '
        'message', () async {
      llm.addAll([
        FakeReply(calls: [call('cards_cards_create')]),
        const FakeReply(text: ['ok']),
      ]);

      final events = await runTurn(loopFor(), 'add an order');

      final response = lastResponses(llm.requests[1]).single.response;
      expect(
        (response['error'] as Map)['message'],
        contains('cards_cards_create'),
      );
      expect(
        events.whereType<StepStarted>().single.label,
        isNot(contains('cards_cards_create')),
      );
      expect(
        events.whereType<StepFinished>().single,
        isA<StepFinished>()
            .having((e) => e.ok, 'ok', isFalse)
            .having((e) => e.summary, 'summary', AgentLoop.stepCorrected),
      );
    });

    test('wrongly typed args reach the harness instead of failing the '
        'turn', () async {
      llm.addAll([
        FakeReply(
          calls: [
            call('cards_query', {'collection': 7}),
            call('ui_open', {
              'collection': {'id': 'x'},
              'view': 5,
            }),
            call('made_up', {'collection': 1.5}),
          ],
        ),
        const FakeReply(text: ['ok']),
      ]);

      final events = await runTurn(loopFor(), 'q');

      expect(events.whereType<TurnFailed>(), isEmpty);
      expect(events.last, isA<TurnDone>());
      expect(query.calls.single.args, {'collection': 7});
      expect(lastResponses(llm.requests[1]), hasLength(3));
    });

    test(
      'an undeclared tool is refused without reaching the harness',
      () async {
        llm.addAll([
          FakeReply(
            calls: [
              call('plans_commit', {'planId': 'p_1'}),
            ],
          ),
          const FakeReply(text: ['sorry']),
        ]);

        await runTurn(loopFor(), 'commit it yourself');

        final response = lastResponses(llm.requests[1]).single.response;
        expect(response['error'], containsPair('code', 'unknown_op'));
        expect(llm.requests, hasLength(2));
      },
    );
  });

  group('the plan gate', () {
    final receipt = Receipt(
      planId: 'p_1',
      applied: const ['i1', 'i2'],
      journalId: 'j_1',
      summary: 'Updated 2 orders',
    );

    test(
      'merges the round\'s plan calls, pauses, and resumes on the outcome',
      () async {
        llm.addAll([
          FakeReply(
            text: ['Adding the field.'],
            calls: [
              call('fields_add', {'collection': 'Orders'}, 'g_1'),
              call('cards_update', {'collection': 'Orders'}, 'g_2'),
            ],
          ),
          const FakeReply(text: ['Done: 2 orders updated.']),
        ]);
        final loop = loopFor();
        final events = <AgentEvent>[];
        final done = loop
            .run('add Margin and fill it')
            .listen(events.add)
            .asFuture<void>();

        await settle();

        expect(events.last, isA<PlanProposed>());
        expect((events.last as PlanProposed).plan.planId, 'p_1');
        expect(loop.pendingPlanId, 'p_1');
        expect(llm.requests, hasLength(1), reason: 'suspended at the gate');
        expect(planOrder, [('fields.add', 'r1.1'), ('cards.update', 'r1.2')]);
        final turnId = (events.first as TurnStarted).turnId;
        expect(seal.calls.single.args, {'turnId': turnId});
        expect(update.calls.single.ctx.turnId, turnId);

        expect(loop.deliverOutcome('p_1', receipt), isTrue);
        await done;

        final responses = lastResponses(llm.requests[1]);
        expect([for (final r in responses) r.geminiId], ['g_1', 'g_2']);
        expect(
          [for (final r in responses) r.name],
          ['fields_add', 'cards_update'],
        );
        expect(responses.first.response, receipt.toModelJson());
        expect(textOf(events), 'Adding the field.Done: 2 orders updated.');
        expect(events.last, isA<TurnDone>());
        expect(loop.pendingPlanId, isNull);
      },
    );

    test('responses follow call order when the model sent no ids', () async {
      llm.addAll([
        FakeReply(
          calls: [
            call('cards_update', {'n': 1}),
            call('cards_query', {'collection': 'Orders'}),
            call('fields_add', {'n': 2}),
          ],
        ),
        const FakeReply(text: ['ok']),
      ]);

      await runTurn(loopFor(), 'go', outcome: (_) => receipt);

      final responses = lastResponses(llm.requests[1]);
      expect(
        [for (final r in responses) r.name],
        ['cards_update', 'cards_query', 'fields_add'],
      );
      expect(responses.every((r) => r.geminiId == null), isTrue);
      expect(responses[1].response['summary'], 'Filtered 148 → 5 Orders');
      expect(responses[0].response['status'], 'applied');
    });

    test('a receipt with nothing written is not reported as applied', () async {
      llm.addAll([
        FakeReply(calls: [call('cards_update')]),
        const FakeReply(text: ['Nothing changed.']),
      ]);
      final loop = loopFor();

      final events = await runTurn(
        loop,
        'go',
        outcome: (_) => const Receipt(
          planId: 'p_1',
          stale: [StaleItem('i1', StaleReason.changedElsewhere)],
          failed: [FailedItem('i2', 'not_permitted', 'Not allowed')],
          summary: 'Nothing was changed',
        ),
      );

      final response = lastResponses(llm.requests[1]).single.response;
      expect(response['status'], 'not_applied');
      expect(response['applied'], 0);
      expect(events.last, isA<TurnDone>());
    });

    test('a rejection resumes the model with "rejected"', () async {
      llm.addAll([
        FakeReply(calls: [call('cards_update')]),
        const FakeReply(text: ['OK, nothing changed.']),
      ]);

      final events = await runTurn(
        loopFor(),
        'ship them',
        outcome: (_) => const Rejection(RejectReason.user),
      );

      expect(lastResponses(llm.requests[1]).single.response, {
        'status': 'rejected',
        'reason': 'user',
      });
      expect(events.last, isA<TurnDone>());
    });

    test('a skip (new message) answers the calls and ends the turn', () async {
      llm.add(FakeReply(calls: [call('cards_update', const {}, 'g_1')]));
      final loop = loopFor();

      final events = await runTurn(
        loop,
        'ship them',
        outcome: (_) => const Rejection(RejectReason.skipped),
      );

      expect(llm.requests, hasLength(1));
      expect(events.last, isA<TurnDone>());
      final last = loop.history.single.contents.last as LlmFunctionResponses;
      expect(last.responses.single.geminiId, 'g_1');
      expect(last.responses.single.response['reason'], 'skipped');
    });

    test('the next turn can start as soon as a skipped turn is done', () async {
      llm.addAll([
        FakeReply(calls: [call('cards_update')]),
        const FakeReply(text: ['next answer']),
      ]);
      final loop = loopFor();
      final next = Completer<List<AgentEvent>>();

      loop.run('ship').listen((e) {
        if (e is PlanProposed) {
          loop.deliverOutcome('p_1', const Rejection(RejectReason.skipped));
        }
        if (e is TurnDone) next.complete(loop.run('new message').toList());
      });

      final events = await next.future;
      expect(events.last, isA<TurnDone>());
      expect(textOf(events), 'next answer');
    });

    test('Stop at the gate ends the turn without another model call', () async {
      llm.add(FakeReply(calls: [call('cards_update')]));
      final loop = loopFor();
      final events = <AgentEvent>[];
      final done = loop.run('ship').listen(events.add).asFuture<void>();
      await settle();
      expect(events.last, isA<PlanProposed>());

      loop.stop();
      await done;

      expect(events.last, isA<TurnStopped>());
      expect(llm.requests, hasLength(1));
      expect(
        (loop.history.single.contents.last as LlmFunctionResponses)
            .responses
            .single
            .response['status'],
        'rejected',
      );
      expect(loop.deliverOutcome('p_1', receipt), isFalse);
    });

    test('an outcome for another plan is refused', () async {
      llm.addAll([
        FakeReply(calls: [call('cards_update')]),
        const FakeReply(text: ['ok']),
      ]);
      final loop = loopFor();
      final done = loop.run('ship').toList();
      await settle();

      expect(loop.deliverOutcome('p_other', receipt), isFalse);
      expect(loop.deliverOutcome('p_1', receipt), isTrue);
      expect((await done).last, isA<TurnDone>());
    });

    test('one failing call leaves the others unproposed, no preview', () async {
      final failing = FakeOp(
        'cards.delete',
        kind: OpKind.plan,
        capability: Capability.dataDelete,
        handler: (args, ctx, req) => {
          'error': HarnessError(
            code: ErrorCode.countMismatch,
            message: 'Expected 3 cards, found 4.',
            expected: 3,
            actual: 4,
          ),
        },
      );
      sealAnswer = (_) => {
        'errors': [
          {
            'callId': 'r1.2',
            'error': {'code': 'count_mismatch', 'message': 'Expected 3.'},
          },
        ],
      };
      harness = fakeHarness([update, failing, seal]);
      llm.addAll([
        FakeReply(calls: [call('cards_update'), call('cards_delete')]),
        const FakeReply(text: ['Let me recount.']),
      ]);

      final events = await runTurn(loopFor(), 'clean up');

      expect(events.whereType<PlanProposed>(), isEmpty);
      final responses = lastResponses(llm.requests[1]);
      expect(responses[0].response, {
        'status': 'not_proposed',
        'reason': 'another change in this turn failed; resend them together',
      });
      expect(responses[1].response['error'], containsPair('expected', 3));
      expect(seal.calls, hasLength(1), reason: 'the overlay is still sealed');
    });

    test('a refused seal fails every plan call of the round', () async {
      sealAnswer = (_) => {
        'error': HarnessError(
          code: ErrorCode.limitExceeded,
          message: 'A plan holds at most 500 items.',
        ),
      };
      llm.addAll([
        FakeReply(calls: [call('cards_update'), call('fields_add')]),
        const FakeReply(text: ['Too big.']),
      ]);

      final events = await runTurn(loopFor(), 'everything');

      expect(events.whereType<PlanProposed>(), isEmpty);
      for (final r in lastResponses(llm.requests[1])) {
        expect(r.response['error'], containsPair('code', 'limit_exceeded'));
      }
    });

    test(
      'a committed plan marks a later failure as having changed data',
      () async {
        llm.addAll([
          FakeReply(calls: [call('cards_update')]),
          const FakeReply.fail(LlmUnknownFailure('boom')),
        ]);

        final events = await runTurn(loopFor(), 'go', outcome: (_) => receipt);

        expect(
          events.last,
          isA<TurnFailed>().having((e) => e.nothingChanged, 'unchanged', false),
        );
      },
    );
  });

  group('nudges', () {
    for (final (finish, nudge) in [
      (FinishKind.malformedCall, AgentLoop.nudgeMalformed),
      (FinishKind.unexpectedToolCall, AgentLoop.nudgeAnswer),
      (FinishKind.tooManyToolCalls, AgentLoop.nudgeTooMany),
    ]) {
      test(
        '${finish.name} gets one text nudge and counts as a round',
        () async {
          llm.addAll([
            FakeReply(calls: [call('cards_query')], finish: finish),
            const FakeReply(text: ['answer']),
          ]);

          final events = await runTurn(loopFor(), 'q');

          expect(query.calls, isEmpty, reason: 'the bad calls are dropped');
          expect((llm.requests[1].contents.last as LlmUserText).text, nudge);
          expect(
            llm.requests[1].contents.whereType<LlmModelContent>(),
            isEmpty,
          );
          expect(
            [for (final e in events.whereType<RoundStarted>()) e.round],
            [1, 2],
          );
          expect(events.last, isA<TurnDone>());
        },
      );
    }

    test('maxTokens keeps the partial text and drops the calls', () async {
      llm.add(
        FakeReply(
          text: ['The total is'],
          calls: [call('cards_query')],
          finish: FinishKind.maxTokens,
        ),
      );
      final loop = loopFor();

      final events = await runTurn(loop, 'q');

      expect(textOf(events), 'The total is');
      expect(events.whereType<TextCutShort>(), hasLength(1));
      expect(events.last, isA<TurnDone>());
      expect(query.calls, isEmpty);
      expect(llm.requests, hasLength(1));
      expect(loop.history.single.contents, hasLength(1));
    });

    test('maxTokens without calls keeps the model content', () async {
      llm.add(const FakeReply(text: ['Long'], finish: FinishKind.maxTokens));
      final loop = loopFor();

      await runTurn(loop, 'q');

      expect(loop.history.single.contents.last, isA<LlmModelContent>());
    });
  });

  group('rounds', () {
    test('maxRounds forces the last round to answer in text', () async {
      llm.addAll([
        FakeReply(calls: [call('cards_query')]),
        FakeReply(calls: [call('cards_query')]),
        const FakeReply(text: ['Here is what I found.']),
      ]);

      final events = await runTurn(
        loopFor(settings: const AgentSettings(rpm: 1000, maxRounds: 3)),
        'dig in',
      );

      expect(
        [for (final r in llm.requests) r.toolMode],
        [LlmToolMode.auto, LlmToolMode.auto, LlmToolMode.none],
      );
      expect(events.last, isA<TurnDone>());
    });

    test('calls on the forced last round are not run; the nudge is sent '
        'in one more text-only round', () async {
      llm.addAll([
        FakeReply(calls: [call('cards_query')]),
        FakeReply(calls: [call('cards_query')]),
        const FakeReply(text: ['3 orders match.']),
      ]);
      final loop = loopFor(
        settings: const AgentSettings(rpm: 1000, maxRounds: 2),
      );

      final events = await runTurn(loop, 'dig in');

      expect(query.calls, hasLength(1));
      expect(
        [for (final r in llm.requests) r.toolMode],
        [LlmToolMode.auto, LlmToolMode.none, LlmToolMode.none],
      );
      expect(
        (llm.requests.last.contents.last as LlmUserText).text,
        AgentLoop.nudgeAnswer,
      );
      expect(textOf(events), '3 orders match.');
      expect(events.last, isA<TurnDone>());
    });

    test('a forced last round that still calls tools fails visibly, '
        'without an unsent nudge in history', () async {
      llm.addAll([
        FakeReply(calls: [call('cards_query')]),
        const FakeReply(finish: FinishKind.unexpectedToolCall),
        const FakeReply(finish: FinishKind.unexpectedToolCall),
      ]);
      final loop = loopFor(
        settings: const AgentSettings(rpm: 1000, maxRounds: 2),
      );

      final events = await runTurn(loop, 'dig in');

      expect(llm.requests, hasLength(3));
      expect(
        events.last,
        isA<TurnFailed>().having(
          (e) => e.failure,
          'failure',
          isA<LlmUnknownFailure>(),
        ),
      );
      final nudges = [
        for (final c in loop.history.single.contents)
          if (c case LlmUserText(
            :final text,
          ) when text == AgentLoop.nudgeAnswer)
            c,
      ];
      expect(nudges, hasLength(1), reason: 'only the nudge that was sent');
    });
  });

  group('quota and retries', () {
    final start = DateTime.utc(2026, 11, 10, 12);

    /// Runs a turn under fake time; returns the events seen so far and the
    /// loop, with [body] driving the clock.
    void fakeTurn(
      AgentSettings settings,
      void Function(FakeAsync async, AgentLoop loop, List<AgentEvent> events)
      body, {
      int turns = 1,
    }) {
      fakeAsync((async) {
        final loop = loopFor(
          settings: settings,
          now: () => start.add(async.elapsed),
        );
        final events = <AgentEvent>[];
        loop.run('q').listen(events.add);
        async.flushMicrotasks();
        body(async, loop, events);
      });
    }

    test('an RPM limit waits the hinted time, then retries', () {
      llm.addAll([
        const FakeReply.fail(LlmRateLimited(retryAfter: Duration(seconds: 30))),
        const FakeReply(text: ['5 orders']),
      ]);
      fakeTurn(const AgentSettings(rpm: 1000), (async, loop, events) {
        expect(
          events.last,
          isA<RetryWaiting>()
              .having((e) => e.reason, 'reason', RetryReason.rpm)
              .having(
                (e) => e.until,
                'until',
                start.add(const Duration(seconds: 30)),
              ),
        );
        async.elapse(const Duration(seconds: 29));
        expect(llm.requests, hasLength(1));

        async.elapse(const Duration(seconds: 1));
        expect(llm.requests, hasLength(2));
        expect(events.last, isA<TurnDone>());
      });
    });

    test('"Retry now" ends the wait early', () {
      llm.addAll([
        const FakeReply.fail(LlmRateLimited()),
        const FakeReply(text: ['ok']),
      ]);
      fakeTurn(const AgentSettings(rpm: 1000), (async, loop, events) {
        expect(
          (events.last as RetryWaiting).until,
          start.add(const Duration(seconds: 20)),
        );

        loop.retryNow();
        async.flushMicrotasks();

        expect(llm.requests, hasLength(2));
        expect(events.last, isA<TurnDone>());
      });
    });

    test('the TPM bucket waits before a request that would not fit', () {
      fakeAsync((async) {
        final loop = loopFor(
          settings: const AgentSettings(rpm: 1000, tpm: 2000),
          now: () => start.add(async.elapsed),
        );
        llm.addAll([
          const FakeReply(text: ['a'], promptTokens: 9000),
          const FakeReply(text: ['b']),
        ]);
        loop.run('one').listen((_) {});
        async.flushMicrotasks();
        final events = <AgentEvent>[];

        loop.run('two').listen(events.add);
        async.flushMicrotasks();

        expect(llm.requests, hasLength(1));
        final wait = events.whereType<RetryWaiting>().single;
        expect(wait.reason, RetryReason.tpm);
        async.elapse(wait.until.difference(start));
        expect(llm.requests, hasLength(2));
        expect(events.last, isA<TurnDone>());
      });
    });

    test('short local pacing waits quietly', () {
      llm.addAll([
        for (var i = 0; i <= 60; i++) const FakeReply(text: ['x']),
      ]);
      fakeAsync((async) {
        final loop = loopFor(
          // 60 RPM: one request a second once the bucket is drained.
          settings: const AgentSettings(rpm: 60),
          now: () => start.add(async.elapsed),
        );
        for (var i = 0; i < 60; i++) {
          loop.run('drain').listen((_) {});
          async.flushMicrotasks();
        }
        final events = <AgentEvent>[];

        loop.run('paced').listen(events.add);
        async.flushMicrotasks();

        expect(events.whereType<RetryWaiting>(), isEmpty);
        async.elapse(const Duration(seconds: 1));
        expect(events.last, isA<TurnDone>());
      });
    });

    test('after two rate-limit retries it switches to the fallback model', () {
      llm.addAll([
        for (var i = 0; i < 3; i++) const FakeReply.fail(LlmRateLimited()),
        const FakeReply(text: ['done']),
      ]);
      fakeTurn(
        const AgentSettings(rpm: 1000, fallbackModel: 'gemini-2.5-flash'),
        (async, loop, events) {
          async.elapse(const Duration(seconds: 40));

          expect(events.whereType<RetryWaiting>(), hasLength(2));
          expect(
            events.whereType<ModelSwitched>().single,
            isA<ModelSwitched>()
                .having((e) => e.from, 'from', 'gemini-3.5-flash-lite')
                .having((e) => e.to, 'to', 'gemini-2.5-flash'),
          );
          expect(
            [for (final r in llm.requests) r.model],
            [
              'gemini-3.5-flash-lite',
              'gemini-3.5-flash-lite',
              'gemini-3.5-flash-lite',
              'gemini-2.5-flash',
            ],
          );
          expect(loop.model, 'gemini-2.5-flash');
          expect(events.last, isA<TurnDone>());
        },
      );
    });

    test('without a fallback the turn fails after two retries', () {
      llm.addAll([
        for (var i = 0; i < 3; i++)
          const FakeReply.fail(LlmRateLimited(scope: RateLimitScope.tpm)),
      ]);
      fakeTurn(const AgentSettings(rpm: 1000), (async, loop, events) {
        async.elapse(const Duration(seconds: 40));

        expect(events.whereType<ModelSwitched>(), isEmpty);
        expect(
          [for (final e in events.whereType<RetryWaiting>()) e.reason],
          [RetryReason.tpm, RetryReason.tpm],
        );
        expect(
          events.last,
          isA<TurnFailed>()
              .having((e) => e.failure, 'failure', isA<LlmRateLimited>())
              .having((e) => e.nothingChanged, 'unchanged', isTrue),
        );
        expect(llm.requests, hasLength(3));
      });
    });

    test('the daily quota stops the turn with no retry', () async {
      llm.add(const FakeReply.fail(LlmDailyQuota()));

      final events = await runTurn(loopFor(), 'q');

      expect(llm.requests, hasLength(1));
      expect(events.whereType<RetryWaiting>(), isEmpty);
      expect(
        events.last,
        isA<TurnFailed>()
            .having((e) => e.failure, 'failure', isA<LlmDailyQuota>())
            .having((e) => e.nothingChanged, 'unchanged', isTrue),
      );
    });

    test('the daily quota switches once to a configured fallback', () async {
      llm.addAll([
        const FakeReply.fail(LlmDailyQuota()),
        const FakeReply.fail(LlmDailyQuota()),
      ]);

      final events = await runTurn(
        loopFor(settings: const AgentSettings(rpm: 1000, fallbackModel: 'fb')),
        'q',
      );

      expect(events.whereType<ModelSwitched>(), hasLength(1));
      expect(llm.requests.map((r) => r.model), ['gemini-3.5-flash-lite', 'fb']);
      expect(events.last, isA<TurnFailed>());
    });

    test('a dropped connection is retried at 2 s, then 6 s', () {
      llm.addAll([
        const FakeReply.fail(LlmTransient('reset')),
        const FakeReply.fail(LlmTransient('reset')),
        const FakeReply.fail(LlmTransient('reset')),
      ]);
      fakeTurn(const AgentSettings(rpm: 1000), (async, loop, events) {
        async.elapse(const Duration(seconds: 2));
        expect(llm.requests, hasLength(2));
        async.elapse(const Duration(seconds: 6));
        expect(llm.requests, hasLength(3));

        expect(
          [for (final e in events.whereType<RetryWaiting>()) e.reason],
          [RetryReason.transient, RetryReason.transient],
        );
        expect(
          events.last,
          isA<TurnFailed>().having(
            (e) => e.failure,
            'failure',
            isA<LlmTransient>(),
          ),
        );
      });
    });

    test('no retry once text streamed in the round', () async {
      llm.add(const FakeReply.fail(LlmTransient('reset'), text: ['Partly']));

      final events = await runTurn(loopFor(), 'q');

      expect(llm.requests, hasLength(1));
      expect(textOf(events), 'Partly');
      expect(events.last, isA<TurnFailed>());
    });
  });

  group('failures', () {
    test('an unexpected error fails the turn instead of escaping', () async {
      // No scripted reply: the fake client throws a StateError.
      final loop = loopFor();

      final events = await runTurn(loop, 'q');

      expect(
        events.last,
        isA<TurnFailed>().having(
          (e) => e.failure,
          'failure',
          isA<LlmUnknownFailure>(),
        ),
      );
      expect(loop.busy, isFalse);
    });

    test('a blocked response fails the turn without retry', () async {
      llm.add(const FakeReply(blocked: 'SAFETY'));

      final events = await runTurn(loopFor(), 'q');

      expect(
        events.last,
        isA<TurnFailed>().having(
          (e) => e.failure,
          'failure',
          isA<LlmBlockedFailure>().having((f) => f.reason, 'reason', 'SAFETY'),
        ),
      );
      expect(llm.requests, hasLength(1));
    });

    test(
      'a lost thought signature retries once with text-only history',
      () async {
        final loop = loopFor()
          ..restore([
            HistoryTurn(
              userText: 'earlier question',
              answer: 'earlier answer',
              steps: const ['Filtered 148 → 5 Orders'],
              contents: const [
                LlmUserText('earlier question'),
                LlmRawContent({
                  'role': 'model',
                  'parts': [
                    {'text': 'earlier answer', 'thoughtSignature': 'sig'},
                  ],
                }),
              ],
            ),
          ]);
        llm.addAll([
          const FakeReply.fail(LlmMissingSignature()),
          const FakeReply(text: ['ok']),
        ]);

        final events = await runTurn(loop, 'now');

        expect(events.last, isA<TurnDone>());
        final retry = llm.requests[1].contents;
        expect(retry.whereType<LlmRawContent>(), isEmpty);
        expect(
          (retry[1] as LlmUserText).text,
          allOf(
            startsWith('<conversation-summary>'),
            contains('earlier answer'),
          ),
        );
        expect((retry.last as LlmUserText).text, 'now');
      },
    );

    test(
      'Stop while streaming cancels the request and keeps the text',
      () async {
        llm.add(const FakeReply.hold(text: ['Par']));
        final loop = loopFor();
        final events = <AgentEvent>[];
        final done = loop.run('q').listen(events.add).asFuture<void>();
        await settle();

        loop.stop();
        await done;

        expect(textOf(events), 'Par');
        expect(events.last, isA<TurnStopped>());
        expect(llm.cancelled, 1);
        expect(loop.history.single.answer, '');
        expect(loop.busy, isFalse);
      },
    );

    test('cancelling the event stream stops the turn', () async {
      llm.add(const FakeReply.hold());
      final loop = loopFor();
      final sub = loop.run('q').listen((_) {});
      await settle();

      await sub.cancel();
      await settle();

      expect(llm.cancelled, 1);
      expect(loop.busy, isFalse);
    });
  });

  group('compaction', () {
    test(
      'elides in-turn rounds more than 2 back, keeping the pairing',
      () async {
        llm.addAll([
          for (var i = 0; i < 4; i++)
            FakeReply(calls: [call('cards_query', const {}, 'g_$i')]),
          const FakeReply(text: ['done']),
        ]);

        await runTurn(
          loopFor(settings: const AgentSettings(rpm: 1000, maxRounds: 6)),
          'dig',
        );

        final contents = llm.requests[4].contents;
        final groups = contents.whereType<LlmFunctionResponses>().toList();
        expect(groups, hasLength(4));
        expect(
          [for (final g in groups) g.responses.single.response['elided']],
          [true, true, null, null],
        );
        expect(groups.first.responses.single.response, {
          'elided': true,
          'summary': 'Filtered 148 → 5 Orders',
          'handle': 'h_r1.1',
        });
        expect(contents.whereType<LlmModelContent>(), hasLength(4));
        expect(
          [for (final g in groups) g.responses.single.geminiId],
          ['g_0', 'g_1', 'g_2', 'g_3'],
        );
      },
    );

    test('elides payloads of turns older than the last two', () async {
      final loop = loopFor();
      for (var i = 0; i < 3; i++) {
        llm.addAll([
          FakeReply(calls: [call('cards_query')]),
          FakeReply(text: ['answer $i']),
        ]);
        await runTurn(loop, 'turn $i');
      }

      final groups = llm.requests.last.contents
          .whereType<LlmFunctionResponses>()
          .map((g) => g.responses.single.response['elided'])
          .toList();
      expect(groups, [true, null, null]);
    });

    test(
      'folds the oldest turns into a local summary past 12k tokens',
      () async {
        final loop = loopFor();
        for (var i = 0; i < 3; i++) {
          llm.add(FakeReply(text: ['answer $i'], promptTokens: 20000));
          await runTurn(loop, 'question $i');
        }
        llm.add(const FakeReply(text: ['last']));

        await runTurn(loop, 'question 3');

        final contents = llm.requests.last.contents;
        final summary = (contents[1] as LlmUserText).text;
        expect(summary, startsWith('<conversation-summary>'));
        expect(summary, contains('"question 0"'));
        expect(summary, contains('"question 1"'));
        expect(summary, isNot(contains('"question 2"')));
        expect(loop.history.map((t) => t.userText), [
          'question 2',
          'question 3',
        ]);
        expect(loop.summary, summary);
      },
    );
  });

  test('settings changes apply to the next request', () async {
    llm.addAll([
      const FakeReply(text: ['a']),
      const FakeReply(text: ['b']),
    ]);
    final loop = loopFor();
    await runTurn(loop, 'one');

    loop.settings = const AgentSettings(
      rpm: 1000,
      model: 'gemini-next',
      thinking: LlmThinking.low,
    );
    await runTurn(loop, 'two');

    expect(llm.requests[1].model, 'gemini-next');
    expect(llm.requests[1].thinking, LlmThinking.low);
  });

  test('resetThread starts an empty conversation', () async {
    llm.addAll([
      const FakeReply(text: ['a']),
      const FakeReply(text: ['b']),
    ]);
    final loop = loopFor();
    await runTurn(loop, 'one');

    loop.resetThread();
    await runTurn(loop, 'two');

    expect(llm.requests[1].contents, hasLength(2));
    expect(loop.history.single.userText, 'two');
  });

  test(
    'never builds a user context: every harness call is the agent\'s',
    () async {
      llm.addAll([
        FakeReply(calls: [call('cards_query'), call('cards_update')]),
        const FakeReply(text: ['ok']),
      ]);

      await runTurn(
        loopFor(),
        'go',
        outcome: (_) => const Rejection(RejectReason.user),
      );

      for (final c in [...query.calls, ...update.calls, ...seal.calls]) {
        expect(c.ctx.actor.kind, ActorKind.agent);
      }
    },
  );
}
