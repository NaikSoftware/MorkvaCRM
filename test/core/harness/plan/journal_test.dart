import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/core/harness/harness.dart';
import 'package:morkva_crm/core/harness/plan/journal_entry.dart';
import 'package:morkva_crm/core/harness/plan/plan.dart';

import 'commit_fixture.dart';

void main() {
  late CommitHarness h;

  setUp(() => h = CommitHarness());
  tearDown(() => h.dispose());

  String order(int n) => SeedCards.order(n);
  Collection seeded(String id) =>
      h.seed.collections.firstWhere((c) => c.id == id);

  List<int> notShipped(int count) => [
    for (final o in h.seed.orderCards)
      if (optionOf(o, OrderFields.status) != SeedOptions.shipped)
        int.parse(o.id.substring('b_or_'.length)),
  ].take(count).toList();

  Future<Map<String, Object?>> shipAndCommit(List<int> numbers) async {
    final plan = await h.plan('cards.update', {
      'collection': 'Orders',
      'target': {
        'ids': [for (final n in numbers) order(n)],
      },
      'set': {'Status': 'Shipped'},
    });
    final r = await h.commit(plan);
    await h.settle();
    return r;
  }

  Future<void> edit(String collectionId, String id, String fieldId, Object v) {
    final card = h.card(collectionId, id)!;
    final schema = h.p.collection(collectionId);
    return h.p.repo.saveObject(
      card.copyWith(
        values: {
          ...card.values,
          fieldId: schema.fieldById(fieldId)!.valueFromJson(v),
        },
      ),
      schema: schema,
    );
  }

  group('journal.undo', () {
    test('restores only the touched keys; a card edited again is left as it '
        'is', () async {
      final [a, b] = notShipped(2);
      final was = {
        for (final n in [a, b])
          n: optionOf(h.card(SeedIds.orders, order(n)), OrderFields.status),
      };
      final r = await shipAndCommit([a, b]);
      await edit(SeedIds.orders, order(a), OrderFields.item, 'Renamed');
      await edit(
        SeedIds.orders,
        order(b),
        OrderFields.status,
        SeedOptions.done,
      );
      await h.settle();

      final u = await h.undo(r['journalId']! as String);
      expect(u['reverted'], 1);
      expect(u['skipped'], [
        {'id': order(b), 'reason': 'changed_since'},
      ]);
      expect(u['failed'], isEmpty);
      expect(
        u['summary'],
        'Reverted 1 order · 1 changed since; left as they are',
      );
      final cardA = h.card(SeedIds.orders, order(a))!;
      expect(optionOf(cardA, OrderFields.status), was[a]);
      expect(cardA[OrderFields.item], const TextFieldValue('Renamed'));
      expect(
        optionOf(h.card(SeedIds.orders, order(b)), OrderFields.status),
        SeedOptions.done,
      );
      // An entry is undone once.
      final again = await h.error('journal.undo', {
        'journalId': r['journalId'],
      });
      expect(again.code, ErrorCode.planExpired);
    });

    test('a deleted card comes back with its id and auto-number', () async {
      final before = h.card(SeedIds.orders, order(1003))!;
      final plan = await h.plan('cards.delete', {
        'collection': 'Orders',
        'target': {
          'ids': [order(1003)],
        },
      });
      final r = await h.commit(plan);
      expect(r['applied'], [plan.items.single.itemId]);
      expect(h.card(SeedIds.orders, order(1003)), isNull);
      await h.settle();
      final batches = h.p.repo.batchCalls;
      final counter = {...?h.p.repo.sequenceCounters[SeedIds.orders]};

      final u = await h.undo(r['journalId']! as String);
      expect(u['reverted'], 1);
      expect(u['summary'], 'Reverted 1 order');
      final back = h.card(SeedIds.orders, order(1003))!;
      expect(back[OrderFields.no], before[OrderFields.no]);
      expect(back[OrderFields.item], before[OrderFields.item]);
      expect(back.createdAt, before.createdAt);
      expect(h.p.repo.batchCalls, batches + 1);
      // The number was already there: no counter was reserved.
      expect(h.p.repo.sequenceCounters[SeedIds.orders], counter);
    });

    test(
      'schema undo merges onto a live schema with a concurrent edit',
      () async {
        final plan = await h.plan('fields.add', {
          'collection': 'Orders',
          'fields': [
            {'name': 'Rush', 'type': 'boolean'},
          ],
        });
        final r = await h.commit(plan);
        await h.settle();
        final live = (await h.stored(SeedIds.orders))!;
        final rush = live.fields.firstWhere((f) => f.name == 'Rush');
        // Another device renames Item meanwhile.
        await h.p.repo.saveCollection(
          live.copyWith(
            fields: [
              for (final f in live.fields)
                f.id == OrderFields.item
                    ? defaultFieldTypeRegistry().definitionFromJson({
                        ...f.toJson(),
                        'name': 'Product',
                      })
                    : f,
            ],
          ),
        );
        await h.settle();

        final u = await h.undo(r['journalId']! as String);
        expect(u['failed'], isEmpty);
        final after = (await h.stored(SeedIds.orders))!;
        expect(after.fieldById(rush.id), isNull);
        expect(after.fieldById(OrderFields.item)!.name, 'Product');
        expect(after.views.any((v) => v.fieldIds.contains(rush.id)), isFalse);
        expect(after.layout.fieldIds, isNot(contains(rush.id)));
        expect(after.layout.fieldIds, contains(OrderFields.item));
      },
    );

    test('fields.delete undo restores the views\' filters, sort, fields and '
        'layout field, and the layout', () async {
      final orders = seeded(SeedIds.orders);
      final plan = await h.plan('fields.delete', {
        'collection': 'Orders',
        'fields': ['Status', 'Paid', 'Created'],
      });
      final r = await h.commit(plan);
      expect(r['applied'], hasLength(3));
      final gone = (await h.stored(SeedIds.orders))!;
      final unpaid = gone.views.firstWhere((v) => v.id == 'v_or_unpaid');
      expect(unpaid.layoutFieldId, isNull);
      expect(unpaid.filters, isEmpty);
      expect(unpaid.sort, isNull);
      expect(gone.fieldById(OrderFields.status), isNull);
      await h.settle();

      final u = await h.undo(r['journalId']! as String);
      expect(u['failed'], isEmpty);
      expect(u['skipped'], isEmpty);
      final back = (await h.stored(SeedIds.orders))!;
      expect(
        [for (final f in back.fields) f.toJson()],
        [for (final f in orders.fields) f.toJson()],
      );
      expect(back.views, orders.views);
      expect(back.layout, orders.layout);
    });

    test('removeOptions clears the option on cards and in filters; undo puts '
        'it all back', () async {
      final clients = seeded(SeedIds.clients);
      final vip = [
        for (final c in h.seed.clientCards)
          if ((c[ClientFields.tags] as MultiSelectFieldValue).optionIds
              .contains(SeedOptions.vip))
            c,
      ];
      expect(vip, isNotEmpty);
      final plan = await h.plan('fields.update', {
        'collection': 'Clients',
        'field': 'Tags',
        'patch': {
          'removeOptions': ['VIP'],
        },
      });
      final r = await h.commit(plan);
      expect(r['failed'], isEmpty);
      expect(r['stale'], isEmpty);
      final cleared = (await h.stored(SeedIds.clients))!;
      final tags =
          cleared.fieldById(ClientFields.tags)! as MultiSelectFieldDefinition;
      expect(tags.options.map((o) => o.id), isNot(contains(SeedOptions.vip)));
      expect(
        cleared.views.firstWhere((v) => v.id == 'v_cl_vip').filters,
        isEmpty,
      );
      for (final c in vip) {
        expect(
          (h.card(SeedIds.clients, c.id)![ClientFields.tags]
                  as MultiSelectFieldValue)
              .optionIds,
          isNot(contains(SeedOptions.vip)),
        );
      }
      await h.settle();

      final u = await h.undo(r['journalId']! as String);
      expect(u['failed'], isEmpty);
      expect(u['skipped'], isEmpty);
      final back = (await h.stored(SeedIds.clients))!;
      expect(
        back.fieldById(ClientFields.tags),
        clients.fieldById(ClientFields.tags),
      );
      expect(back.views, clients.views);
      for (final c in vip) {
        expect(
          h.card(SeedIds.clients, c.id)![ClientFields.tags],
          c[ClientFields.tags],
        );
      }
    });

    test('collections.create: an unticked field is left out (its seed value '
        'dropped); undo keeps a collection that gained a user card', () async {
      final plan = await h.plan('collections.create', {
        'collections': [
          {
            'ref': '@sup',
            'name': 'Suppliers',
            'fields': [
              {'name': 'Name', 'type': 'text'},
              {'name': 'Phone', 'type': 'text'},
            ],
          },
        ],
        'cards': [
          {
            'collection': '@sup',
            'values': {'Name': 'Nova', 'Phone': '+380'},
          },
        ],
      });
      final create = plan.items.whereType<CreateCollectionItem>().single;
      final phone = plan.items.whereType<AddFieldItem>().firstWhere(
        (f) => f.field.name == 'Phone',
      );
      final seedCard = plan.items.whereType<CreateCardItem>().single;
      final r = await h.commit(
        plan,
        itemIds: [
          for (final i in plan.items)
            if (i.itemId != phone.itemId) i.itemId,
        ],
      );
      expect(r['declinedByUser'], [phone.itemId]);
      expect(r['applied'], hasLength(plan.itemCount - 1));
      final stored = (await h.stored(create.collectionId))!;
      expect(stored.fields.map((f) => f.name), ['Name']);
      expect(stored.layout.fieldIds, [stored.fields.single.id]);
      final card = h.card(create.collectionId, seedCard.object.id)!;
      expect(card.values.keys, [stored.fields.single.id]);
      await h.settle();

      // The user adds a card of their own.
      await h.p.repo.saveObject(
        MorkvaObject.create(
          id: 'b_mine',
          collection: stored,
          values: {stored.fields.single.id: const TextFieldValue('Mine')},
          createdAt: now,
          updatedAt: now,
        ),
        schema: stored,
      );
      await h.settle();
      final u = await h.undo(r['journalId']! as String);
      expect(u['reverted'], 1);
      expect(u['skipped'], [
        {'id': create.collectionId, 'reason': 'has_cards'},
      ]);
      expect(await h.stored(create.collectionId), isNotNull);
      expect(h.card(create.collectionId, seedCard.object.id), isNull);
      expect(h.card(create.collectionId, 'b_mine'), isNotNull);
    });

    test('collections.create undo removes the collection and its seed '
        'cards', () async {
      final plan = await h.plan('collections.create', {
        'collections': [
          {
            'ref': '@sup',
            'name': 'Suppliers',
            'fields': [
              {'name': 'Name', 'type': 'text'},
            ],
          },
        ],
        'cards': [
          {
            'collection': '@sup',
            'values': {'Name': 'Nova'},
          },
        ],
      });
      final id = plan.items
          .whereType<CreateCollectionItem>()
          .single
          .collectionId;
      final r = await h.commit(plan);
      await h.settle();
      final u = await h.undo(r['journalId']! as String);
      expect(u['reverted'], 2);
      expect(u['summary'], 'Reverted 2 changes');
      expect(await h.stored(id), isNull);
      expect(h.p.repo.objectsOf(id), isEmpty);
    });

    test('a created card whose empty field was filled since is kept', () async {
      final plan = await h.plan('cards.create', {
        'collection': 'Clients',
        'cards': [
          {
            'values': {'Name': 'Nova'},
          },
        ],
      });
      final id = plan.items.whereType<CreateCardItem>().single.object.id;
      final r = await h.commit(plan);
      await h.settle();
      expect(h.card(SeedIds.clients, id)![ClientFields.phone]?.isEmpty, true);
      await edit(SeedIds.clients, id, ClientFields.phone, '+380');
      await h.settle();

      final u = await h.undo(r['journalId']! as String);
      expect(u['reverted'], 0);
      expect(u['skipped'], [
        {'id': id, 'reason': 'changed_since'},
      ]);
      expect(h.card(SeedIds.clients, id)![ClientFields.phone], isNotNull);
    });

    test('collections.create undo keeps the collection when its seed card '
        'was filled in since', () async {
      final plan = await h.plan('collections.create', {
        'collections': [
          {
            'ref': '@sup',
            'name': 'Suppliers',
            'fields': [
              {'name': 'Name', 'type': 'text'},
              {'name': 'Phone', 'type': 'text'},
            ],
          },
        ],
        'cards': [
          {
            'collection': '@sup',
            'values': {'Name': 'Nova'},
          },
        ],
      });
      final create = plan.items.whereType<CreateCollectionItem>().single;
      final seedCard = plan.items.whereType<CreateCardItem>().single.object;
      final phone = create.collection.fields
          .firstWhere((f) => f.name == 'Phone')
          .id;
      final r = await h.commit(plan);
      await h.settle();
      final card = h.card(create.collectionId, seedCard.id)!;
      final stored = (await h.stored(create.collectionId))!;
      await h.p.repo.saveObject(
        card.copyWith(
          values: {...card.values, phone: const TextFieldValue('+380')},
        ),
        schema: stored,
      );
      await h.settle();

      final u = await h.undo(r['journalId']! as String);
      expect(u['reverted'], 0);
      expect(u['skipped'], [
        {'id': seedCard.id, 'reason': 'changed_since'},
        {'id': create.collectionId, 'reason': 'has_cards'},
      ]);
      expect(await h.stored(create.collectionId), isNotNull);
      expect(
        h.card(create.collectionId, seedCard.id)![phone],
        const TextFieldValue('+380'),
      );
    });

    test('a second undo of an entry still undoing is refused', () async {
      final c = CommitHarness(ackTimeout: const Duration(milliseconds: 50));
      addTearDown(c.dispose);
      final plan = await c.plan('cards.update', {
        'collection': 'Orders',
        'target': {
          'ids': [for (final n in notShipped(1)) order(n)],
        },
        'set': {'Status': 'Shipped'},
      });
      final r = await c.commit(plan);
      await c.settle();
      final id = r['journalId']! as String;
      c.p.repo.batchNeverCompletes = true;
      final first = c.host('journal.undo', {'journalId': id});
      await c.settle();
      final again = await c.error('journal.undo', {'journalId': id});
      expect(again.code, ErrorCode.invalidArgs);
      expect(again.message, contains('already committing'));
      expect(await first, isA<HarnessOk>());
      expect(c.p.repo.batchCalls, 2);
    });

    test('offline undo writes nothing; an expired one is refused', () async {
      final r = await shipAndCommit(notShipped(1));
      final id = r['journalId']! as String;
      h.online = false;
      final batches = h.p.repo.batchCalls;
      final off = await h.error('journal.undo', {'journalId': id});
      expect(off.code, ErrorCode.offline);
      expect(h.p.repo.batchCalls, batches);
      h.online = true;
      final late = await h.error('journal.undo', {
        'journalId': id,
      }, at: now.add(const Duration(minutes: 10)));
      expect(late.code, ErrorCode.planExpired);
    });
  });

  group('collection delete', () {
    test('is resumable after a failure midway, then undoable', () async {
      final d = CommitHarness(batchSize: 2);
      addTearDown(d.dispose);
      final fabrics = d.seed.fabricCards;
      final plan = await d.plan('collections.delete', {
        'collection': 'Fabrics',
      });
      var calls = 0;
      d.p.repo.batchWriteError = (_) => ++calls == 2 ? 'unavailable' : null;
      final first = await d.commit(plan);
      final item = plan.items.single.itemId;
      expect(first['failed'], [
        {
          'itemId': item,
          'code': 'offline',
          'message': '2 fabrics left, collection kept',
        },
      ]);
      expect(
        first['summary'],
        'Nothing was changed · 2 fabrics left, collection kept',
      );
      expect(await d.stored(SeedIds.fabrics), isNotNull);
      expect(d.p.repo.objectsOf(SeedIds.fabrics), hasLength(2));
      await d.settle();

      d.p.repo.batchWriteError = null;
      final second = await d.ok('plans.retryFailed', {'planId': plan.planId});
      expect(second['applied'], [item]);
      expect(second['failed'], isEmpty);
      expect(await d.stored(SeedIds.fabrics), isNull);
      expect(d.p.repo.objectsOf(SeedIds.fabrics), isEmpty);
      // One journal entry covers both runs.
      expect(second['journalId'], first['journalId']);
      await d.settle();

      final u = await d.undo(second['journalId']! as String);
      expect(u['failed'], isEmpty);
      expect(u['reverted'], fabrics.length + 1);
      expect(await d.stored(SeedIds.fabrics), isNotNull);
      expect(
        d.p.repo.objectsOf(SeedIds.fabrics).map((o) => o.id).toSet(),
        fabrics.map((o) => o.id).toSet(),
      );
    });
  });

  group('journal.restore', () {
    test('delete images of every field type survive a restore: a deleted '
        'collection and a deleted order come back after a reload', () async {
      final fabrics = h.seed.fabricCards;
      final order = h.card(SeedIds.orders, SeedCards.order(1004))!;
      final gone = await h.commit(
        await h.plan('collections.delete', {'collection': 'Fabrics'}),
      );
      await h.settle();
      final deleted = await h.commit(
        await h.plan('cards.delete', {
          'collection': 'Orders',
          'target': {
            'ids': [order.id],
          },
        }),
      );
      await h.settle();
      final mirrors = [
        for (final r in [gone, deleted])
          jsonDecode(jsonEncode(r['journal'])) as Map<String, Object?>,
      ];
      h.journal.reset();

      for (final m in mirrors) {
        final restored = await h.ok('journal.restore', {'entry': m});
        expect(restored['dropped'], isEmpty);
      }
      final u1 = await h.undo(gone['journalId']! as String);
      expect(u1['failed'], isEmpty);
      expect(u1['reverted'], fabrics.length + 1);
      final u2 = await h.undo(deleted['journalId']! as String);
      expect(u2['reverted'], 1);
      expect(await h.stored(SeedIds.fabrics), seeded(SeedIds.fabrics));
      Map<String, FieldValue> stored(MorkvaObject o) => {
        for (final e in o.values.entries)
          if (seeded(SeedIds.fabrics).fieldById(e.key)
              is! CalculatedFieldDefinition)
            e.key: e.value,
      };
      for (final f in fabrics) {
        expect(stored(h.card(SeedIds.fabrics, f.id)!), stored(f));
      }
      final back = h.card(SeedIds.orders, order.id)!;
      expect(back[OrderFields.no], order[OrderFields.no]);
      expect(back[OrderFields.created], order[OrderFields.created]);
      expect(back[OrderFields.fabrics], order[OrderFields.fabrics]);
    });

    test('round trip: persist, drop the journal, restore, undo', () async {
      final [a] = notShipped(1);
      final was = optionOf(
        h.card(SeedIds.orders, order(a)),
        OrderFields.status,
      );
      final r = await shipAndCommit([a]);
      final mirror =
          jsonDecode(jsonEncode(r['journal'])) as Map<String, Object?>;
      h.journal.reset();

      final restored = await h.ok('journal.restore', {'entry': mirror});
      expect(restored, {
        'journalId': r['journalId'],
        'expiresAt': r['undoUntil'],
        'dropped': <Object?>[],
      });
      final u = await h.undo(r['journalId']! as String);
      expect(u['reverted'], 1);
      expect(
        optionOf(h.card(SeedIds.orders, order(a)), OrderFields.status),
        was,
      );
    });

    test('a tampered entry is dropped item by item', () async {
      final numbers = notShipped(4);
      final r = await shipAndCommit(numbers);
      final mirror =
          jsonDecode(jsonEncode(r['journal'])) as Map<String, Object?>;
      final items = (mirror['items']! as List).cast<Map<String, Object?>>();
      Map<String, Object?> keysOf(int i) =>
          (items[i]['keys']! as Map).cast<String, Object?>();
      // An unknown field, a wrong-typed value, an extra key.
      keysOf(0)['f_nope'] = {'before': 'a', 'after': 'b'};
      (keysOf(1)[OrderFields.status]! as Map)['before'] = 42;
      items[2]['extra'] = true;
      h.journal.reset();

      final restored = await h.ok('journal.restore', {'entry': mirror});
      expect(restored['dropped'], [
        {'id': order(numbers[2]), 'reason': 'invalid'},
        {'id': order(numbers[0]), 'reason': 'schema_changed'},
        {'id': order(numbers[1]), 'reason': 'invalid'},
      ]);
      final u = await h.undo(r['journalId']! as String);
      expect(u['reverted'], 1);
      expect(
        optionOf(h.card(SeedIds.orders, order(numbers[3])), OrderFields.status),
        isNot(SeedOptions.shipped),
      );
      expect(
        optionOf(h.card(SeedIds.orders, order(numbers[0])), OrderFields.status),
        SeedOptions.shipped,
      );
    });

    test(
      'expired, someone else\'s or unreadable entries are refused',
      () async {
        final r = await shipAndCommit(notShipped(1));
        final mirror =
            jsonDecode(jsonEncode(r['journal'])) as Map<String, Object?>;
        h.journal.reset();
        final late = await h.error('journal.restore', {
          'entry': mirror,
        }, at: now.add(const Duration(minutes: 11)));
        expect(late.code, ErrorCode.planExpired);
        final other = await h.error('journal.restore', {
          'entry': {...mirror, 'actor': 'user:u2'},
        });
        expect(other.code, ErrorCode.notPermitted);
        final bad = await h.error('journal.restore', {
          'entry': {...mirror, 'schema': 2},
        });
        expect(bad.code, ErrorCode.invalidArgs);
        expect(h.journal.get(r['journalId']! as String), isNull);
      },
    );

    test('a tampered expiry is capped at createdAt + 10 min; a future '
        'createdAt is refused', () async {
      final r = await shipAndCommit(notShipped(1));
      final mirror =
          jsonDecode(jsonEncode(r['journal'])) as Map<String, Object?>;
      h.journal.reset();
      final future = await h.error('journal.restore', {
        'entry': {
          ...mirror,
          'createdAt': now.add(const Duration(days: 1)).toIso8601String(),
          'expiresAt': now.add(const Duration(days: 2)).toIso8601String(),
        },
      });
      expect(future.code, ErrorCode.invalidArgs);
      expect(future.path, 'entry.createdAt');

      final tampered = {
        ...mirror,
        'expiresAt': now.add(const Duration(days: 365)).toIso8601String(),
      };
      final restored = await h.ok('journal.restore', {'entry': tampered});
      expect(restored['expiresAt'], r['undoUntil']);
      final late = await h.error('journal.undo', {
        'journalId': r['journalId'],
      }, at: now.add(const Duration(minutes: 10)));
      expect(late.code, ErrorCode.planExpired);
    });

    test('an entry with nothing left to restore fails plan_expired', () async {
      final r = await shipAndCommit(notShipped(1));
      final mirror =
          jsonDecode(jsonEncode(r['journal'])) as Map<String, Object?>;
      final item = (mirror['items']! as List).single as Map<String, Object?>;
      item['extra'] = true;
      h.journal.reset();
      final e = await h.error('journal.restore', {'entry': mirror});
      expect(e.code, ErrorCode.planExpired);
      expect(h.journal.get(r['journalId']! as String), isNull);
    });
  });

  group('JournalEntry', () {
    final layout = CardLayout.synthesize(const ['f_a', 'f_b']);
    final items = <JournalItem>[
      const JournalCardUpdate(
        collectionId: 'c_1',
        id: 'b_1',
        keys: {'f_a': (before: 'x', after: 'y')},
      ),
      const JournalCardCreate(
        collectionId: 'c_1',
        id: 'b_2',
        after: {'f_a': 'z'},
      ),
      const JournalCardDelete(
        collectionId: 'c_1',
        id: 'b_3',
        before: {
          'createdAt': '2026-11-10T10:00:00.000Z',
          'updatedAt': '2026-11-10T10:00:00.000Z',
          'values': {'f_a': 'w'},
        },
      ),
      JournalFieldEntry(
        collectionId: 'c_1',
        fieldId: 'f_b',
        index: 1,
        before: const TextFieldDefinition(id: 'f_b', name: 'B').toJson(),
      ),
      JournalViewEntry(
        collectionId: 'c_1',
        viewId: 'all',
        index: 0,
        before: const ViewDefinition(id: 'all', name: 'All').toJson(),
        after: const ViewDefinition(id: 'all', name: 'Everything').toJson(),
      ),
      JournalLayoutEntry(
        collectionId: 'c_1',
        fieldId: 'f_b',
        before: CellPlacement.of(layout, 'f_b'),
      ),
      const JournalCollectionMeta(
        collectionId: 'c_1',
        keys: {'name': (before: 'Old', after: 'New')},
      ),
      const JournalCollectionCreate(
        collectionId: 'c_2',
        createdCardIds: ['b_9'],
      ),
      JournalCollectionDelete(
        collectionId: 'c_3',
        before: const Collection(id: 'c_3', name: 'Gone').toJson(),
      ),
    ];
    JournalEntry entry(List<JournalItem> items) => JournalEntry(
      journalId: 'j_1',
      planId: 'p_1',
      actor: 'user:u1',
      createdAt: DateTime.utc(2026, 11, 10, 12),
      expiresAt: DateTime.utc(2026, 11, 10, 12, 10),
      items: items,
    );

    test('every item kind round-trips through JSON', () {
      final json =
          jsonDecode(jsonEncode(entry(items).toJson())) as Map<String, Object?>;
      expect(json['schema'], 1);
      final parsed = JournalEntry.parse(json);
      expect(parsed.dropped, isEmpty);
      expect(parsed.entry.toJson(), entry(items).toJson());
      expect(CellPlacement.of(layout, 'f_b')!.toJson(), {
        'sectionId': 'sec_main',
        'rowId': 'row_f_b',
        'rowIndex': 1,
        'cellIndex': 0,
        'span': 12,
      });
    });

    test('the mirror is omitted above 400 KB', () {
      final big = JournalCardCreate(
        collectionId: 'c_1',
        id: 'b_big',
        after: {'f_a': 'x' * (kJournalMirrorMaxBytes + 1)},
      );
      expect(entry(items).mirror(), isNotNull);
      expect(entry([big]).mirror(), isNull);
    });

    test('an unknown kind or a malformed head is refused', () {
      final json = entry(items).toJson();
      final parsed = JournalEntry.parse({
        ...json,
        'items': [
          ...json['items']! as List,
          {'kind': 'card.teleport', 'collectionId': 'c_1', 'id': 'b_x'},
          'not an item',
        ],
      });
      expect(parsed.entry.items, hasLength(items.length));
      expect(parsed.dropped, [
        (id: 'b_x', reason: 'invalid'),
        (id: 'items[${items.length + 1}]', reason: 'invalid'),
      ]);
      expect(
        () => JournalEntry.parse({...json, 'extra': 1}),
        throwsFormatException,
      );
      expect(
        () => JournalEntry.parse({...json, 'expiresAt': 'soon'}),
        throwsFormatException,
      );
    });
  });
}
