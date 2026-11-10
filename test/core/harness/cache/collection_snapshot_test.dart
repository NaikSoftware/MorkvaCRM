import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/core/harness/cache/collection_snapshot.dart';

import '../fixtures/seed_workspace.dart';

void main() {
  final seed = SeedWorkspace();

  CollectionSnapshot snapshotOf(String collectionId) => CollectionSnapshot(
    schema: resolveLookups(
      seed.collections,
    ).firstWhere((c) => c.id == collectionId),
    generation: 1,
    raw: seed.objects[collectionId]!,
  );

  group('CollectionSnapshot', () {
    test('indexes are not built until read', () {
      final snapshot = snapshotOf(SeedIds.orders);

      expect(snapshot.count, seed.orderCards.length);
      expect(snapshot.hasById, isFalse);
      expect(snapshot.hasLabels, isFalse);

      expect(snapshot[SeedCards.order(1001)]!.id, SeedCards.order(1001));
      expect(snapshot.hasById, isTrue);
      expect(snapshot.hasLabels, isFalse);

      expect(snapshot.labels, same(snapshot.labels));
      expect(snapshot.hasLabels, isTrue);
    });

    test('raw cannot be changed', () {
      final snapshot = snapshotOf(SeedIds.clients);

      expect(() => snapshot.raw.removeLast(), throwsUnsupportedError);
    });

    test('withSchema shares the objects under a new generation', () {
      final snapshot = snapshotOf(SeedIds.fabrics);
      final renamed = seed.fabrics.copyWith(name: 'Materials');

      final next = snapshot.withSchema(renamed, 7);

      expect(next.raw, same(snapshot.raw));
      expect(next.schema.name, 'Materials');
      expect(next.generation, 7);
    });
  });

  group('LabelIndex', () {
    final clients = snapshotOf(SeedIds.clients).labels;
    final orders = snapshotOf(SeedIds.orders).labels;

    test('labels every card by its first text field', () {
      expect(clients.labelOf(SeedCards.olena), 'Olena Bondar');
      expect(clients.labels, hasLength(seed.clientCards.length));
      expect(clients.labelOf('b_missing'), 'Untitled');
    });

    test('labels follow the first view order', () {
      final view = seed.clients.views.first.copyWith(filters: const []);
      final ordered = applyView(seed.clients, view, seed.clientCards);

      expect(clients.labels.keys, [for (final o in ordered) o.id]);
    });

    test('a title resolves case-insensitively; duplicates are all listed', () {
      expect(clients.idsWithLabel('  olena BONDAR '), [SeedCards.olena]);
      expect(
        clients.idsWithLabel('Anna Koval'),
        unorderedEquals([SeedCards.annaKyiv, SeedCards.annaOdesa]),
      );
      expect(clients.idsWithLabel('Nobody'), isEmpty);
    });

    test('search needs every term and names the matched field', () {
      final hits = clients.search('anna kyiv');

      expect(hits, [(id: SeedCards.annaKyiv, fieldId: ClientFields.name)]);
      expect(
        clients.search('ODESA').map((h) => h.id),
        contains(SeedCards.annaOdesa),
      );
      final byCity = clients
          .search('odesa')
          .firstWhere((h) => h.id == SeedCards.annaOdesa);
      expect(byCity.fieldId, ClientFields.city);
    });

    test('search covers auto-numbers and select labels, and honours limit', () {
      final number = orders.search('1001');
      expect(number.first, (
        id: SeedCards.order(1001),
        fieldId: OrderFields.no,
      ));

      final done = orders.search('done', limit: 3);
      expect(done, hasLength(3));
      for (final hit in done) {
        expect(hit.fieldId, OrderFields.status);
      }
    });

    test('a blank query matches nothing', () {
      expect(clients.search('   '), isEmpty);
    });
  });
}
