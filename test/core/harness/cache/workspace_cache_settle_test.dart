import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/core/harness/cache/collection_snapshot.dart';
import 'package:morkva_crm/core/harness/cache/workspace_cache.dart';

import '../../../features/collections/fake_data_repository.dart';
import '../fixtures/seed_workspace.dart';

const _orders = SeedIds.orders;
const _settle = Duration(seconds: 5);

void main() {
  late SeedWorkspace seed;

  setUp(() => seed = SeedWorkspace());

  MorkvaObject order(int n) => seed.card(_orders, SeedCards.order(n));

  /// [o] with [values] merged in, written one minute later.
  MorkvaObject edited(MorkvaObject o, Map<String, FieldValue> values) =>
      o.copyWith(
        values: {...o.values, ...values},
        updatedAt: o.updatedAt.add(const Duration(minutes: 1)),
      );

  bool atOrPast(MorkvaObject written, MorkvaObject? card) =>
      card != null && !card.updatedAt.isBefore(written.updatedAt);

  /// Runs [body] in fake time over a fresh repository and cache; afterwards
  /// nothing is left listening or ticking.
  void inFakeTime(
    void Function(FakeAsync async, FakeDataRepository repo, WorkspaceCache c)
    body,
  ) => fakeAsync((async) {
    final repo = seed.repository();
    final cache = WorkspaceCache(repo)..initialize('ws');
    async.flushMicrotasks();
    body(async, repo, cache);
    cache.reset();
    async.flushMicrotasks();
    expect(repo.liveListeners, 0);
    expect(async.pendingTimers, isEmpty);
  });

  group('settled', () {
    test('a card already at or past the write settles at once, leasing the '
        'collection for the wait only', () {
      inFakeTime((async, repo, cache) {
        final written = edited(order(1001), {
          OrderFields.qty: const NumberFieldValue(9),
        });
        repo.saveObject(written, schema: seed.orders);
        CollectionSnapshot? got;
        cache
            .settled(_orders, written.id, (c) => atOrPast(written, c))
            .then((s) => got = s);
        async.flushMicrotasks();

        expect(got, isNotNull);
        expect(got![written.id]![OrderFields.qty], const NumberFieldValue(9));
        expect(repo.watchObjectsCalls[_orders], 1);
        // Released: the idle TTL timer runs, nothing else.
        expect(async.pendingTimers, hasLength(1));
      });
    });

    test('waits for the emission that carries the write', () {
      inFakeTime((async, repo, cache) {
        final o = order(1002);
        final first = edited(o, {OrderFields.qty: const NumberFieldValue(2)});
        final second = edited(first, {
          OrderFields.qty: const NumberFieldValue(3),
        });
        repo.hiddenFromWatch.add(o.id);
        repo.saveObject(first, schema: seed.orders);
        CollectionSnapshot? got;
        var done = false;
        cache.settled(_orders, o.id, (c) => atOrPast(first, c)).then((s) {
          got = s;
          done = true;
        });
        async.flushMicrotasks();
        expect(done, isFalse);

        // The lagging cache catches up with a later write: past it counts.
        repo.hiddenFromWatch.clear();
        repo.saveObject(second, schema: seed.orders);
        async.flushMicrotasks();

        expect(done, isTrue);
        expect(got![o.id]!.updatedAt, second.updatedAt);
      });
    });

    test('times out with null after 5 s and releases its lease', () {
      inFakeTime((async, repo, cache) {
        final o = order(1003);
        final written = edited(o, {OrderFields.qty: const NumberFieldValue(4)});
        repo.hiddenFromWatch.add(o.id);
        repo.saveObject(written, schema: seed.orders);
        var done = false;
        CollectionSnapshot? got;
        cache.settled(_orders, o.id, (c) => atOrPast(written, c)).then((s) {
          got = s;
          done = true;
        });
        async.elapse(_settle - const Duration(milliseconds: 1));
        expect(done, isFalse);

        async.elapse(const Duration(milliseconds: 1));
        expect(done, isTrue);
        expect(got, isNull);
        expect(async.pendingTimers, hasLength(1)); // the idle TTL only
      });
    });

    test('a delete settles once the card is gone', () {
      inFakeTime((async, repo, cache) {
        final o = order(1004);
        CollectionSnapshot? got;
        cache.settled(_orders, o.id, (c) => c == null).then((s) => got = s);
        async.flushMicrotasks();
        expect(got, isNull);

        repo.deleteObject(_orders, o.id);
        async.flushMicrotasks();

        expect(got, isNotNull);
        expect(got![o.id], isNull);
      });
    });

    test('reset ends a wait with null', () {
      inFakeTime((async, repo, cache) {
        var done = false;
        CollectionSnapshot? got = CollectionSnapshot(
          schema: seed.orders,
          generation: 0,
          raw: const [],
        );
        cache.settled(_orders, 'b_nope', (c) => c != null).then((s) {
          got = s;
          done = true;
        });
        async.flushMicrotasks();
        cache.reset();
        async.flushMicrotasks();

        expect(done, isTrue);
        expect(got, isNull);
      });
    });

    test('an unknown collection is a MissingCollectionException', () async {
      final cache = WorkspaceCache(seed.repository())..initialize('ws');
      await expectLater(
        cache.settled('c_nope', 'b_1', (_) => true),
        throwsA(isA<MissingCollectionException>()),
      );
      await cache.reset();
    });
  });

  group('deriveWith', () {
    late WorkspaceCache cache;

    setUp(() => cache = WorkspaceCache(seed.repository())..initialize('ws'));
    tearDown(() => cache.reset());

    test('derives the substitute in place of the stored card', () async {
      final derived = await cache.derive(_orders, today: seedToday);
      final stored = order(1005);
      final image = edited(stored, {
        OrderFields.price: const NumberFieldValue(100),
        OrderFields.qty: const NumberFieldValue(90),
      });

      final a = derived.deriveWith(image)!;

      expect(a[OrderFields.total], const CalculatedFieldValue(9000));
      expect(a[OrderFields.large], const CalculatedFieldValue(true));
      expect(a.updatedAt, image.updatedAt);
      // The shared derivation still reads the stored card.
      final shared = derived.objects.firstWhere((o) => o.id == stored.id);
      expect(shared[OrderFields.total], isNot(a[OrderFields.total]));
    });

    test('a card the snapshot lacks (a delete\'s before) is added for the '
        'derivation; null stays null', () async {
      final derived = await cache.derive(_orders, today: seedToday);
      final gone = MorkvaObject.create(
        id: 'b_or_gone',
        collection: seed.orders,
        values: {
          OrderFields.price: const NumberFieldValue(10),
          OrderFields.qty: const NumberFieldValue(3),
        },
        createdAt: seedToday,
        updatedAt: seedToday,
      );

      expect(
        derived.deriveWith(gone)![OrderFields.total],
        const CalculatedFieldValue(30),
      );
      expect(derived.deriveWith(null), isNull);
    });

    test(
      'a collection without calculated fields returns the substitute',
      () async {
        final plain = seed.fabrics.copyWith(
          fields: [
            for (final f in seed.fabrics.fields)
              if (f is! CalculatedFieldDefinition) f,
          ],
        );
        final repo = FakeDataRepository([seed.clients, seed.orders, plain]);
        final other = WorkspaceCache(repo)..initialize('ws');
        addTearDown(other.reset);
        final derived = await other.derive(SeedIds.fabrics, today: seedToday);
        final card = seed.fabricCards.first;

        expect(identical(derived.deriveWith(card), card), isTrue);
      },
    );
  });
}
