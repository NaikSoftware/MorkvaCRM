import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/api/data/data_repository.dart';
import 'package:morkva_crm/core/agent/agent_event.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/core/harness/harness.dart';
import 'package:morkva_crm/core/harness/plan/plan.dart';

import 'commit_fixture.dart';

void main() {
  late CommitHarness h;

  setUp(() => h = CommitHarness());
  tearDown(() => h.dispose());

  String order(int n) => SeedCards.order(n);

  /// Plans Status → Shipped on [numbers].
  Future<Plan> ship(List<int> numbers) => h.plan('cards.update', {
    'collection': 'Orders',
    'target': {
      'ids': [for (final n in numbers) order(n)],
    },
    'set': {'Status': 'Shipped'},
  });

  /// Orders whose Status is not Shipped, by number.
  List<int> notShipped(int count) => [
    for (final o in h.seed.orderCards)
      if (optionOf(o, OrderFields.status) != SeedOptions.shipped)
        int.parse(o.id.substring('b_or_'.length)),
  ].take(count).toList();

  group('plans.commit', () {
    test('applies only the ticked items; the receipt parses as a Receipt and '
        'one batch writes them', () async {
      final numbers = notShipped(3);
      final plan = await ship(numbers);
      final [i1, i2, i3] = [for (final i in plan.items) i.itemId];

      final r = await h.commit(plan, itemIds: [i1, i3]);
      final receipt = Receipt.fromJson(r);
      expect(receipt.applied, [i1, i3]);
      expect(receipt.declinedByUser, [i2]);
      expect(receipt.stale, isEmpty);
      expect(receipt.failed, isEmpty);
      expect(receipt.journalId, startsWith('j_'));
      expect(receipt.undoUntil, now.add(const Duration(minutes: 10)).toUtc());
      expect(receipt.summary, 'Applied 2 of 3');
      expect(receipt.toJson(), {...r}..remove('journal'));
      expect(h.p.repo.batchCalls, 1);
      expect(
        optionOf(h.card(SeedIds.orders, order(numbers[0])), OrderFields.status),
        SeedOptions.shipped,
      );
      expect(
        optionOf(h.card(SeedIds.orders, order(numbers[1])), OrderFields.status),
        isNot(SeedOptions.shipped),
      );
      // The journal mirror covers only what was written.
      final journal = r['journal']! as Map<String, Object?>;
      expect(journal['journalId'], receipt.journalId);
      expect((journal['items']! as List).length, 2);
    });

    test('everything applied: the summary is the plan title', () async {
      final plan = await ship(notShipped(2));
      final r = await h.commit(plan);
      expect(r['summary'], plan.title);
      expect(r['applied'], [for (final i in plan.items) i.itemId]);
    });

    test('a fill of an unticked new field is declined with it; nothing is '
        'written', () async {
      h.p.newTurn();
      await h.p.ok('fields.add', {
        'collection': 'Orders',
        'fields': [
          {'name': 'Rush', 'type': 'boolean'},
        ],
      });
      await h.p.ok('cards.update', {
        'collection': 'Orders',
        'target': {
          'ids': [order(1001), order(1002)],
        },
        'set': {'Rush': true},
      });
      final plan = await h.p.sealPlan();
      final add = plan.items.whereType<AddFieldItem>().single;
      final fills = [
        for (final i in plan.items.whereType<UpdateCardItem>()) i.itemId,
      ];
      expect(
        plan.items.whereType<UpdateCardItem>().every(
          (i) => i.dependsOn.contains(add.itemId),
        ),
        isTrue,
      );

      final r = await h.commit(plan, itemIds: fills);
      expect(r['declinedByUser'], [add.itemId, ...fills]);
      expect(r['applied'], isEmpty);
      expect(r['journalId'], isNull);
      expect(r['summary'], 'Nothing was changed');
      expect(h.p.repo.saveCount, 0);
      expect(h.p.repo.batchCalls, 0);
    });

    test('a new field and its fill commit together: schema in a transaction '
        'on the server copy, then the cards', () async {
      h.p.newTurn();
      await h.p.ok('fields.add', {
        'collection': 'Orders',
        'fields': [
          {'name': 'Rush', 'type': 'boolean'},
        ],
      });
      await h.p.ok('cards.update', {
        'collection': 'Orders',
        'target': {
          'ids': [order(1001)],
        },
        'set': {'Rush': true},
      });
      final plan = await h.p.sealPlan();
      final r = await h.commit(plan);
      expect(r['applied'], hasLength(2));
      final orders = (await h.stored(SeedIds.orders))!;
      final rush = orders.fields.firstWhere((f) => f.name == 'Rush');
      // Shown in every view and placed in the layout, like the editor does.
      expect(orders.views.every((v) => v.fieldIds.contains(rush.id)), isTrue);
      expect(orders.layout.fieldIds, contains(rush.id));
      expect(
        h.card(SeedIds.orders, order(1001))![rush.id],
        const BooleanFieldValue(true),
      );
    });

    test('a stale touched key is skipped; a concurrent edit to an untouched '
        'key is not stale and survives', () async {
      final [a, b] = notShipped(2);
      final plan = await ship([a, b]);
      final cardA = h.card(SeedIds.orders, order(a))!;
      final cardB = h.card(SeedIds.orders, order(b))!;
      final orders = h.p.collection(SeedIds.orders);
      await h.p.repo.saveObject(
        cardA.copyWith(
          values: {
            ...cardA.values,
            OrderFields.status: const SingleSelectFieldValue(SeedOptions.done),
          },
        ),
        schema: orders,
      );
      await h.p.repo.saveObject(
        cardB.copyWith(
          values: {
            ...cardB.values,
            OrderFields.item: const TextFieldValue('X'),
          },
        ),
        schema: orders,
      );
      await h.settle();

      final r = await h.commit(plan);
      final receipt = Receipt.fromJson(r);
      expect(receipt.stale, [
        StaleItem(plan.items[0].itemId, StaleReason.changedElsewhere),
      ]);
      expect(receipt.applied, [plan.items[1].itemId]);
      expect(receipt.summary, 'Applied 1 of 2 · 1 changed elsewhere');
      final storedA = h.card(SeedIds.orders, order(a))!;
      final storedB = h.card(SeedIds.orders, order(b))!;
      expect(optionOf(storedA, OrderFields.status), SeedOptions.done);
      expect(optionOf(storedB, OrderFields.status), SeedOptions.shipped);
      expect(storedB[OrderFields.item], const TextFieldValue('X'));
    });

    test('a card deleted after the preview is stale missing', () async {
      final [a, b] = notShipped(2);
      final plan = await ship([a, b]);
      await h.p.repo.deleteObject(SeedIds.orders, order(a));
      await h.settle();
      final r = await h.commit(plan);
      expect(r['stale'], [
        {'itemId': plan.items[0].itemId, 'reason': 'missing'},
      ]);
      expect(r['applied'], [plan.items[1].itemId]);
    });

    test('a chunk refused not-found is re-verified, its missing ids dropped '
        'and the rest retried', () async {
      final numbers = notShipped(4);
      final plan = await ship(numbers);
      var calls = 0;
      h.p.repo.batchWriteError = (chunk) {
        // Two cards vanish between the stale check and the batch.
        if (calls++ == 0) {
          h.p.repo.deleteObject(SeedIds.orders, order(numbers[0]));
          h.p.repo.deleteObject(SeedIds.orders, order(numbers[2]));
        }
        return null;
      };
      final r = await h.commit(plan);
      final [i1, i2, i3, i4] = [for (final i in plan.items) i.itemId];
      expect(r['stale'], [
        {'itemId': i1, 'reason': 'missing'},
        {'itemId': i3, 'reason': 'missing'},
      ]);
      expect(r['applied'], [i2, i4]);
      expect(h.p.repo.batchCalls, 2);
      expect(
        optionOf(h.card(SeedIds.orders, order(numbers[1])), OrderFields.status),
        SeedOptions.shipped,
      );
    });

    test('offline: nothing is written and the call fails offline', () async {
      final plan = await ship(notShipped(2));
      h.online = false;
      final e = await h.error('plans.commit', {'planId': plan.planId});
      expect(e.code, ErrorCode.offline);
      expect(e.retryable, isTrue);
      expect(h.p.repo.batchCalls, 0);
      expect(h.p.repo.saveCount, 0);
      // Still committable once online.
      h.online = true;
      expect((await h.commit(plan))['applied'], hasLength(2));
    });

    test('an agent cannot commit; only the user', () async {
      final plan = await ship(notShipped(1));
      final e = await h.error('plans.commit', {
        'planId': plan.planId,
      }, actor: Actor.assistant);
      expect(e.code, ErrorCode.notPermitted);
      expect(h.p.repo.batchCalls, 0);
    });

    test('expired, unknown, twice and unknown item ids', () async {
      final plan = await ship(notShipped(1));
      final late = await h.error('plans.commit', {
        'planId': plan.planId,
      }, at: now.add(const Duration(minutes: 15)));
      expect(late.code, ErrorCode.planExpired);
      expect(
        (await h.error('plans.commit', {'planId': 'p_nope'})).code,
        ErrorCode.planExpired,
      );
      final bad = await h.error('plans.commit', {
        'planId': plan.planId,
        'itemIds': ['i99'],
      });
      expect(bad.code, ErrorCode.invalidArgs);
      expect(bad.candidates, [plan.items.single.itemId]);
      await h.commit(plan);
      final twice = await h.error('plans.commit', {'planId': plan.planId});
      expect(twice.code, ErrorCode.invalidArgs);
    });

    test('an update linking a card created in the same turn waits for the '
        'create: a failed create leaves no dangling reference', () async {
      final [n] = notShipped(1);
      final was = h.card(SeedIds.orders, order(n))![OrderFields.client];
      h.p.newTurn();
      await h.p.ok('cards.create', {
        'collection': 'Clients',
        'cards': [
          {
            'ref': '@nova',
            'values': {'Name': 'Nova Atelier'},
          },
        ],
      });
      await h.p.ok('cards.update', {
        'collection': 'Orders',
        'target': {
          'ids': [order(n)],
        },
        'set': {'Client': '@nova'},
      });
      final plan = await h.p.sealPlan();
      final create = plan.items.whereType<CreateCardItem>().single;
      final update = plan.items.whereType<UpdateCardItem>().single;
      expect(update.dependsOn, contains(create.itemId));
      h.p.repo.batchWriteError = (chunk) =>
          chunk.any((w) => w is ObjectCreate) ? 'unavailable' : null;

      final r = Receipt.fromJson(await h.commit(plan));
      expect(r.applied, isEmpty);
      expect(
        {for (final f in r.failed) f.itemId},
        {create.itemId, update.itemId},
      );
      expect(h.card(SeedIds.orders, order(n))![OrderFields.client], was);
      expect(h.card(SeedIds.clients, create.object.id), isNull);
    });

    test('a view on a collection created in the same turn is added even '
        'before the cache has the new schema', () async {
      h.p.newTurn();
      await h.p.ok('collections.create', {
        'collections': [
          {
            'ref': '@sup',
            'name': 'Suppliers',
            'fields': [
              {'name': 'Name', 'type': 'text'},
            ],
          },
        ],
      });
      await h.p.ok('views.create', {
        'collection': '@sup',
        'name': 'All suppliers',
        'mode': 'table',
      });
      final plan = await h.p.sealPlan();
      final id = plan.items
          .whereType<CreateCollectionItem>()
          .single
          .collectionId;

      final r = await h.commit(plan);
      expect(r['stale'], isEmpty);
      expect(r['failed'], isEmpty);
      expect(r['applied'], hasLength(plan.itemCount));
      expect(
        (await h.stored(id))!.views.map((v) => v.name),
        contains('All suppliers'),
      );
    });

    test('a second commit of a plan still committing is refused', () async {
      final c = CommitHarness(ackTimeout: const Duration(milliseconds: 50));
      addTearDown(c.dispose);
      final plan = await c.plan('cards.update', {
        'collection': 'Orders',
        'target': {
          'ids': [for (final n in notShippedIn(c, 2)) order(n)],
        },
        'set': {'Status': 'Shipped'},
      });
      c.p.repo.batchNeverCompletes = true;
      final first = c.host('plans.commit', {'planId': plan.planId});
      await c.settle();
      final again = await c.error('plans.commit', {'planId': plan.planId});
      expect(again.code, ErrorCode.invalidArgs);
      expect(again.message, contains('already committing'));
      final retry = await c.error('plans.retryFailed', {'planId': plan.planId});
      expect(retry.code, ErrorCode.invalidArgs);
      expect(retry.message, contains('already committing'));
      expect(await first, isA<HarnessOk>());
      expect(c.p.repo.batchCalls, 1);
      // Done: the usual "already committed" from now on.
      final twice = await c.error('plans.commit', {'planId': plan.planId});
      expect(twice.message, contains('already committed.'));
    });

    test('progress events above 20 items, ending at the total', () async {
      final big = CommitHarness(seed: SeedWorkspace(orders: 60));
      addTearDown(big.dispose);
      final all = [
        for (final o in big.seed.orderCards)
          if (optionOf(o, OrderFields.status) != SeedOptions.shipped) o.id,
      ];
      expect(all.length, greaterThan(20));
      final plan = await big.plan('cards.update', {
        'collection': 'Orders',
        'target': {'ids': all},
        'set': {'Status': 'Shipped'},
        'expectedCount': all.length,
      });
      await big.commit(plan);
      final progress = big.events.whereType<ProgressEvent>().toList();
      expect(progress, isNotEmpty);
      expect(progress.last.done, all.length);
      expect(progress.last.total, all.length);
      expect(progress.every((e) => e.callId == 'h.1'), isTrue);
    });

    test('no progress events for a small plan', () async {
      await h.commit(await ship(notShipped(2)));
      expect(h.events, isEmpty);
    });

    test('a plan is re-checked against its creator\'s grants', () async {
      final orders = h.p.collection(SeedIds.orders);
      final card = h.seed.orderCards.first;
      final plugin = Plan(
        planId: 'p_plugin',
        turnId: 't_x',
        title: 'Plugin edit',
        createdBy: PlanCreator(
          const Actor.plugin('m1'),
          Grants(Capability.values, collections: [SeedIds.clients]),
        ),
        items: [
          UpdateCardItem(
            itemId: 'i1',
            callId: 'r1.1',
            collectionId: orders.id,
            targetId: card.id,
            label: '#1',
            risk: Risk.low,
            changes: [
              FieldChange(
                fieldId: OrderFields.item,
                field: 'Item',
                before: card[OrderFields.item]?.toJson(),
                after: 'Hacked',
              ),
            ],
          ),
        ],
        createdAt: now,
        expiresAt: now.add(const Duration(minutes: 15)),
      );
      final result = await h.committer.commit(
        plugin,
        h.userContext(),
        callId: 'h.1',
      );
      expect(result.outcomes['i1']!.code, 'not_permitted');
      expect(result.journal, isEmpty);
      expect(h.p.repo.batchCalls, 0);
    });
  });

  group('plans.reject / retryFailed', () {
    test('reject drops the plan; a later commit gets plan_expired', () async {
      final plan = await ship(notShipped(1));
      expect(
        await h.ok('plans.reject', {
          'planId': plan.planId,
          'reason': 'skipped',
        }),
        isEmpty,
      );
      expect(h.p.store.get(plan.planId), isNull);
      final e = await h.error('plans.commit', {'planId': plan.planId});
      expect(e.code, ErrorCode.planExpired);
      // Rejecting again (or an unknown plan) is a no-op.
      expect(await h.ok('plans.reject', {'planId': plan.planId}), isEmpty);
    });

    test('a committed plan cannot be rejected; retryFailed needs a '
        'commit', () async {
      final plan = await ship(notShipped(1));
      final early = await h.error('plans.retryFailed', {'planId': plan.planId});
      expect(early.code, ErrorCode.invalidArgs);
      await h.commit(plan);
      final e = await h.error('plans.reject', {'planId': plan.planId});
      expect(e.code, ErrorCode.invalidArgs);
    });

    test('retryFailed re-runs only the failed items and extends the same '
        'journal entry', () async {
      final numbers = notShipped(3);
      final plan = await ship(numbers);
      final ids = [for (final i in plan.items) i.itemId];
      var calls = 0;
      h.p.repo.batchWriteError = (_) => calls++ == 0 ? 'unavailable' : null;
      final first = await h.commit(plan);
      expect(first['failed'], [
        for (final id in ids)
          {
            'itemId': id,
            'code': 'offline',
            'message': 'The server refused the write (unavailable).',
          },
      ]);
      expect(first['journalId'], isNull);
      expect(first['summary'], 'Nothing was changed · 3 failed');

      final second = await h.ok('plans.retryFailed', {'planId': plan.planId});
      expect(second['applied'], ids);
      expect(second['failed'], isEmpty);
      expect(second['summary'], plan.title);
      expect(second['journalId'], startsWith('j_'));
      // Nothing failed, so another retry returns the same receipt.
      final third = await h.ok('plans.retryFailed', {'planId': plan.planId});
      expect(third, {...second}..remove('journal'));
    });
  });

  group('watchdog', () {
    test('a batch never acknowledged: its items are queued and journaled, '
        'later chunks fail offline', () {
      fakeAsync((async) {
        final w = CommitHarness(batchSize: 2);
        Map<String, Object?>? receipt;
        final numbers = notShippedIn(w, 5);
        w
            .plan('cards.update', {
              'collection': 'Orders',
              'target': {
                'ids': [for (final n in numbers) SeedCards.order(n)],
              },
              'set': {'Status': 'Shipped'},
            })
            .then((plan) {
              w.p.repo.batchNeverCompletes = true;
              return w.commit(plan);
            })
            .then((r) => receipt = r);
        async.flushMicrotasks();
        expect(receipt, isNull);
        async.elapse(const Duration(seconds: 29));
        expect(receipt, isNull);
        async.elapse(const Duration(seconds: 2));
        expect(receipt, isNotNull);
        final r = Receipt.fromJson(receipt!);
        expect(r.queued, ['i1', 'i2']);
        expect(r.applied, isEmpty);
        expect([for (final f in r.failed) f.itemId], ['i3', 'i4', 'i5']);
        expect(r.failed.every((f) => f.code == 'offline'), isTrue);
        expect(r.summary, contains('2 changes waiting for a connection'));
        expect(r.journalId, isNotNull);
        expect(w.journal.get(r.journalId!)!.items, hasLength(2));
        expect(w.p.repo.batchCalls, 1);
        w.dispose();
        async.flushMicrotasks();
      });
    });
  });
}

/// Orders of [h] whose Status is not Shipped, by number.
List<int> notShippedIn(CommitHarness h, int count) => [
  for (final o in h.seed.orderCards)
    if (optionOf(o, OrderFields.status) != SeedOptions.shipped)
      int.parse(o.id.substring('b_or_'.length)),
].take(count).toList();
