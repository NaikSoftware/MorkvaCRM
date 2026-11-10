import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/api/data/data_repository.dart';
import 'package:morkva_crm/core/domain/domain.dart';

import 'seed_workspace.dart';

void main() {
  group('SeedWorkspace', () {
    final seed = SeedWorkspace();

    test('covers every built-in field type', () {
      final types = {
        for (final c in seed.collections)
          for (final f in c.fields) f.type,
      };
      final registry = FieldTypeRegistry();
      registerBuiltInFieldTypes(registry);
      expect(types, containsAll(registry.registeredTypes));
      final calcs = [
        for (final c in seed.collections)
          ...c.fields.whereType<CalculatedFieldDefinition>(),
      ];
      expect(calcs.any((f) => f.isLookup), isTrue);
      expect(
        calcs.where((f) => f.isAggregate).map((f) => f.aggregate!.source),
        {...AggregateSource.values},
      );
      expect(calcs.any((f) => f.expression != null && !f.isAggregate), isTrue);
    });

    test('every schema passes the strict harness rules with 2 views', () {
      final ids = {for (final c in seed.collections) c.id};
      for (final c in seed.collections) {
        final result = validateCollectionSchema(
          c,
          collectionIds: ids,
          strict: true,
        );
        expect(result.issues, isEmpty, reason: c.name);
        expect(c.views, hasLength(2), reason: c.name);
      }
    });

    test('every card is valid and every link resolves', () {
      final ids = {
        for (final entry in seed.objects.entries)
          entry.key: {for (final o in entry.value) o.id},
      };
      for (final c in seed.collections) {
        for (final o in seed.objects[c.id]!) {
          expect(o.validateAgainst(c).isValid, isTrue, reason: o.id);
          for (final f in c.fields.whereType<ReferenceFieldDefinition>()) {
            final linked = (o[f.id] as ReferenceFieldValue).objectIds;
            expect(
              ids[f.targetCollectionId]!.containsAll(linked),
              isTrue,
              reason: '${o.id}.${f.name}',
            );
          }
        }
      }
    });

    test('Clients.Orders mirrors Orders.Client', () {
      for (final client in seed.clientCards) {
        final mirrored =
            (client[ClientFields.orders] as ReferenceFieldValue).objectIds;
        final linking = [
          for (final o in seed.orderCards)
            if ((o[OrderFields.client] as ReferenceFieldValue).objectIds
                .contains(client.id))
              o.id,
        ];
        expect(mirrored, linking, reason: client.id);
      }
    });

    test('holds the edge cases the harness tests rely on', () {
      final names = [
        for (final c in seed.clientCards)
          (c[ClientFields.name] as TextFieldValue).text,
      ];
      expect(names.where((n) => n == 'Anna Koval'), hasLength(2));
      final nadiya = seed.card(SeedIds.clients, SeedCards.nadiya);
      expect(
        (nadiya[ClientFields.orders] as ReferenceFieldValue).objectIds,
        isEmpty,
      );
      expect(nadiya[ClientFields.city]!.isEmpty, isTrue);
      final orders = seed.orderCards;
      expect(orders[22][OrderFields.client]!.isEmpty, isTrue);
      expect(orders[16][OrderFields.price]!.isEmpty, isTrue);
      expect(orders[3][OrderFields.legacyPrice], const TextFieldValue('tbd'));
      expect(
        orders.map((o) => (o[OrderFields.no] as AutoNumberFieldValue).sequence),
        [for (var i = 0; i < 24; i++) kFirstOrderNumber + i],
      );
      final statuses = {
        for (final o in orders)
          (o[OrderFields.status] as SingleSelectFieldValue).optionId,
      };
      expect(statuses, hasLength(4));
      final created = {
        for (final o in orders)
          (o[OrderFields.created] as DateFieldValue).value!.month,
      };
      expect(created.length, greaterThan(2), reason: 'spread over months');
      expect(
        orders.any(
          (o) => (o[OrderFields.created] as DateFieldValue).value == seedToday,
        ),
        isTrue,
        reason: 'one order created today',
      );
    });

    test('derives formula, aggregate and lookup values', () {
      final collections = resolveLookups(seed.collections);
      final d = Derivation(
        collections: collections,
        objects: seed.objects,
        today: seedToday,
      );
      final orders = {for (final o in d.objectsOf(SeedIds.orders)) o.id: o};
      final first = orders[SeedCards.order(kFirstOrderNumber)]!;
      num numberOf(MorkvaObject o, String id) =>
          (o[id] as CalculatedFieldValue).cached! as num;

      final price = (first[OrderFields.price] as NumberFieldValue).value!;
      final qty = (first[OrderFields.qty] as NumberFieldValue).value!;
      expect(numberOf(first, OrderFields.total), price * qty);
      expect(numberOf(first, OrderFields.fabricPrice), greaterThan(0));
      expect(
        (first[OrderFields.margin] as CalculatedFieldValue).cached,
        isNotNull,
      );
      expect(
        (first[OrderFields.clientCity] as CalculatedFieldValue).cached,
        isNotNull,
      );
      expect(
        (first[OrderFields.due] as CalculatedFieldValue).cached,
        isNotNull,
      );

      final clients = {for (final c in d.objectsOf(SeedIds.clients)) c.id: c};
      final buyer =
          (first[OrderFields.client] as ReferenceFieldValue).objectIds.single;
      expect(
        numberOf(clients[buyer]!, ClientFields.orderCount),
        (clients[buyer]![ClientFields.orders] as ReferenceFieldValue)
            .objectIds
            .length,
      );
      expect(numberOf(clients[SeedCards.nadiya]!, ClientFields.orderCount), 0);

      final fabrics = d.objectsOf(SeedIds.fabrics);
      final stock = fabrics.fold<num>(
        0,
        (sum, f) => sum + (f[FabricFields.stock] as NumberFieldValue).value!,
      );
      expect(numberOf(fabrics.first, FabricFields.totalStock), stock);
      expect(numberOf(fabrics.first, FabricFields.metresLeft), isNotNull);
    });

    test('loads into the fake repository without counting writes', () async {
      final repo = seed.repository();
      addTearDown(repo.dispose);
      expect(await repo.watchCollections().first, seed.collections);
      for (final c in seed.collections) {
        final cards = await repo.watchObjects(c.id, schema: c).first;
        expect(cards, seed.objects[c.id], reason: c.name);
      }
      expect(repo.saveCount, 0);
      expect(repo.batchCalls, 0);
      expect(repo.sequenceCounters[SeedIds.orders]![OrderFields.no], 1024);

      // A new order continues the auto-number sequence.
      final result = await repo.saveObjectsBatch(
        [
          ObjectCreate(
            MorkvaObject.create(
              id: 'b_or_new',
              collection: seed.orders,
              values: const {OrderFields.item: TextFieldValue('Coat')},
              createdAt: seedToday,
              updatedAt: seedToday,
            ),
          ),
        ],
        schemas: {SeedIds.orders: seed.orders},
      );
      expect(result.failed, isEmpty);
      final created = repo
          .objectsOf(SeedIds.orders)
          .firstWhere((o) => o.id == 'b_or_new');
      expect(created[OrderFields.no], const AutoNumberFieldValue(1025));
    });
  });

  group('SeedWorkspace.large', () {
    test('is deterministic and holds 5,000 orders with 12+ fields', () {
      final a = SeedWorkspace.large();
      final b = SeedWorkspace.large();
      expect(a.orderCards, hasLength(5000));
      expect(a.orders.fields.length, greaterThanOrEqualTo(12));
      expect(a.clientCards, hasLength(250));
      expect(a.fabricCards, hasLength(40));
      expect(a.objects, b.objects);
      expect(
        (a.orderCards.last[OrderFields.no] as AutoNumberFieldValue).sequence,
        kFirstOrderNumber + 4999,
      );
      final names = {
        for (final c in a.clientCards)
          (c[ClientFields.name] as TextFieldValue).text,
      };
      // Only the hand-written "Anna Koval" pair shares a name.
      expect(names, hasLength(249));
      final clientIds = {for (final c in a.clientCards) c.id};
      for (final o in a.orderCards) {
        expect(
          clientIds.containsAll(
            (o[OrderFields.client] as ReferenceFieldValue).objectIds,
          ),
          isTrue,
        );
      }
      final years = {
        for (final o in a.orderCards)
          (o[OrderFields.created] as DateFieldValue).value!.year,
      };
      expect(years.length, greaterThanOrEqualTo(2));
    });
  });
}
