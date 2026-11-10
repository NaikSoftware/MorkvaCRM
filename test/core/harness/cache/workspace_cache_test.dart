import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/core/harness/cache/derived_snapshot.dart';
import 'package:morkva_crm/core/harness/cache/workspace_cache.dart';

import '../../../features/collections/fake_data_repository.dart';
import '../fixtures/seed_workspace.dart';

const _ttl = Duration(minutes: 5);
const _orders = SeedIds.orders;
const _clients = SeedIds.clients;
const _fabrics = SeedIds.fabrics;

void main() {
  late SeedWorkspace seed;
  late FakeDataRepository repo;
  late WorkspaceCache cache;

  setUp(() {
    seed = SeedWorkspace();
    repo = seed.repository();
    cache = WorkspaceCache(repo, leaseTtl: _ttl)..initialize('ws');
  });

  tearDown(() => cache.reset());

  /// Opened objects streams (the always-on schema stream excluded).
  int objectListeners() =>
      repo.liveListeners - (cache.workspaceId == null ? 0 : 1);

  group('schema', () {
    test(
      'resolves lookups and bumps the generation on every emission',
      () async {
        await cache.ready;
        expect(cache.collections.map((c) => c.id), [
          _clients,
          _orders,
          _fabrics,
        ]);
        final city =
            cache.collection(_orders)!.fieldById(OrderFields.clientCity)
                as CalculatedFieldDefinition;
        expect(city.lookupTarget, isA<SingleSelectFieldDefinition>());
        final before = cache.schemaGeneration;

        await repo.saveCollection(seed.fabrics.copyWith(name: 'Materials'));
        await pumpEventQueue();

        expect(cache.schemaGeneration, before + 1);
        expect(cache.collection(_fabrics)!.name, 'Materials');
      },
    );

    test('lease before initialize fails', () async {
      final idle = WorkspaceCache(repo);
      await expectLater(idle.lease([_orders]), throwsStateError);
    });

    test('an unknown collection is a MissingCollectionException', () async {
      await expectLater(
        cache.lease(['c_nope']),
        throwsA(
          isA<MissingCollectionException>().having(
            (e) => e.collectionId,
            'collectionId',
            'c_nope',
          ),
        ),
      );
      expect(repo.watchObjectsCalls, isEmpty);
    });
  });

  group('leases', () {
    test('a lease completes with the first emission', () async {
      final lease = await cache.lease([_orders]);

      final snapshot = lease.snapshot(_orders);
      expect(snapshot.count, seed.orderCards.length);
      expect(snapshot.schema, cache.collection(_orders));
      expect(cache.current(_orders), same(snapshot));
      expect(cache.liveCollectionIds, [_orders]);
      expect(() => lease.snapshot(_clients), throwsArgumentError);
      lease.release();
    });

    test('20 calls on one collection share one listener', () async {
      final concurrent = await Future.wait([
        for (var i = 0; i < 20; i++) cache.lease([_orders]),
      ]);
      for (final l in concurrent) {
        l.release();
      }
      for (var i = 0; i < 20; i++) {
        await cache.read(_orders);
        await cache.derive(_orders, today: seedToday);
      }

      expect(repo.watchObjectsCalls[_orders], 1);
      expect(repo.watchObjectsCalls[_clients], 1);
      expect(repo.watchObjectsCalls[_fabrics], 1);
      expect(objectListeners(), 3);
    });

    test('a lease takes only what it names (no warm-up)', () async {
      (await cache.lease([_orders])).release();

      expect(repo.watchObjectsCalls.keys, [_orders]);
    });

    test('a snapshot follows the data with a new generation', () async {
      final lease = await cache.lease([_orders]);
      final first = lease.snapshot(_orders);
      final changed = [...seed.orderCards]..removeLast();

      repo.seedObjects(_orders, changed);
      await pumpEventQueue();

      final next = lease.snapshot(_orders);
      expect(next.count, changed.length);
      expect(next.generation, greaterThan(first.generation));
      expect(first.count, seed.orderCards.length, reason: 'immutable');
      lease.release();
    });

    test('release is idempotent', () async {
      final a = await cache.lease([_orders]);
      final b = await cache.lease([_orders]);
      a
        ..release()
        ..release();
      expect(a.isReleased, isTrue);

      // b still holds it: no idle timer may evict it.
      await Future<void>.delayed(Duration.zero);
      expect(cache.current(_orders), isNotNull);
      b.release();
    });

    test(
      'a stream error fails the lease, and the next lease retries',
      () async {
        repo.failObjects(_clients, StateError('permission-denied'));

        await expectLater(cache.lease([_clients]), throwsStateError);
        expect(cache.current(_clients), isNull);

        repo.seedObjects(_clients, seed.clientCards);
        final lease = await cache.lease([_clients]);
        expect(lease.snapshot(_clients).count, seed.clientCards.length);
        expect(repo.watchObjectsCalls[_clients], 2);
        lease.release();
      },
    );

    test('a deleted collection drops its data and fails its lease', () async {
      final lease = await cache.lease([_fabrics]);

      await repo.deleteCollection(_fabrics);
      await pumpEventQueue();

      expect(cache.current(_fabrics), isNull);
      expect(
        () => lease.snapshot(_fabrics),
        throwsA(isA<MissingCollectionException>()),
      );
      expect(objectListeners(), 0);
      lease.release();
      await expectLater(
        cache.lease([_fabrics]),
        throwsA(isA<MissingCollectionException>()),
      );
    });
  });

  group('schema changes', () {
    test('after a field is added its values are visible', () async {
      const added = 'f_or_courier';
      const courier = TextFieldDefinition(id: added, name: 'Courier');
      // The stored cards already carry the value (another device wrote it);
      // a stream decoding the old schema drops it.
      repo.seedObjects(_orders, [
        for (final o in seed.orderCards)
          o.copyWith(
            values: {...o.values, added: const TextFieldValue('Nova')},
          ),
      ]);
      final lease = await cache.lease([_orders]);
      final before = lease.snapshot(_orders);
      expect(before.raw.first[added], isNull);

      await repo.saveCollection(
        seed.orders.copyWith(fields: [...seed.orders.fields, courier]),
      );
      await pumpEventQueue();
      final read = await cache.read(_orders);

      expect(read.raw.first[added], const TextFieldValue('Nova'));
      expect(read.schema.fieldById(added), isNotNull);
      expect(read.generation, greaterThan(before.generation));
      expect(repo.watchObjectsCalls[_orders], 2);
      expect(objectListeners(), 1, reason: 'the old stream is cancelled');
      lease.release();
    });

    test('a rename keeps the stream and bumps the generation', () async {
      final lease = await cache.lease([_orders]);
      final before = lease.snapshot(_orders);

      await repo.saveCollection(
        seed.orders.copyWith(
          fields: [
            for (final f in seed.orders.fields)
              f.id == OrderFields.item
                  ? const TextFieldDefinition(
                      id: OrderFields.item,
                      name: 'Product',
                    )
                  : f,
          ],
        ),
      );
      await pumpEventQueue();

      final after = lease.snapshot(_orders);
      expect(repo.watchObjectsCalls[_orders], 1);
      expect(after.generation, greaterThan(before.generation));
      expect(after.schema.fieldById(OrderFields.item)!.name, 'Product');
      expect(after.raw, same(before.raw));
      lease.release();
    });

    test('flipping includeTime re-decodes', () async {
      final lease = await cache.lease([_orders]);

      await repo.saveCollection(
        seed.orders.copyWith(
          fields: [
            for (final f in seed.orders.fields)
              f.id == OrderFields.delivery
                  ? DateFieldDefinition(
                      id: f.id,
                      name: f.name,
                      includeTime: !(f as DateFieldDefinition).includeTime,
                    )
                  : f,
          ],
        ),
      );
      await pumpEventQueue();
      await cache.read(_orders);

      expect(repo.watchObjectsCalls[_orders], 2);
      lease.release();
    });
  });

  group('lifetime', () {
    /// Runs [body] in fake time over a fresh cache of the seed workspace.
    void inFakeTime(
      void Function(FakeAsync async, FakeDataRepository repo, WorkspaceCache c)
      body,
    ) => fakeAsync((async) {
      final repo = seed.repository();
      final cache = WorkspaceCache(repo, leaseTtl: _ttl)..initialize('ws');
      body(async, repo, cache);
      cache.reset();
      async.flushMicrotasks();
      expect(repo.liveListeners, 0);
      expect(async.pendingTimers, isEmpty);
    });

    Lease leaseNow(FakeAsync async, WorkspaceCache cache, List<String> ids) {
      Lease? lease;
      cache.lease(ids).then((l) => lease = l);
      async.flushMicrotasks();
      return lease!;
    }

    test(
      'the last release starts the idle TTL, then the stream is cancelled',
      () {
        inFakeTime((async, repo, cache) {
          final lease = leaseNow(async, cache, [_orders]);
          final generation = lease.snapshot(_orders).generation;
          lease.release();
          expect(repo.liveListeners, 2);

          async.elapse(_ttl - const Duration(seconds: 1));
          expect(repo.liveListeners, 2, reason: 'still idling');

          async.elapse(const Duration(seconds: 1));
          // Only the always-on schema listener is left.
          expect(repo.liveListeners, 1);
          expect(cache.current(_orders), isNull);

          final again = leaseNow(async, cache, [_orders]);
          expect(repo.watchObjectsCalls[_orders], 2);
          expect(again.snapshot(_orders).generation, greaterThan(generation));
          again.release();
        });
      },
    );

    test('a re-lease before the TTL keeps the stream', () {
      inFakeTime((async, repo, cache) {
        leaseNow(async, cache, [_orders]).release();

        async.elapse(const Duration(minutes: 4));
        final lease = leaseNow(async, cache, [_orders]);
        async.elapse(const Duration(minutes: 30));

        expect(repo.watchObjectsCalls[_orders], 1);
        expect(repo.liveListeners, 2);
        lease.release();
      });
    });

    test('leases stay alive while the panel is open', () {
      inFakeTime((async, repo, cache) {
        cache.panelOpen = true;
        leaseNow(async, cache, [_orders, _clients]).release();

        async.elapse(const Duration(hours: 2));
        expect(repo.liveListeners, 3);
        expect(cache.liveCollectionIds, unorderedEquals([_orders, _clients]));

        cache.panelOpen = false;
        async.elapse(_ttl);
        expect(repo.liveListeners, 1);
        expect(cache.liveCollectionIds, isEmpty);
      });
    });

    test('closing the panel spares collections a lease still holds', () {
      inFakeTime((async, repo, cache) {
        cache.panelOpen = true;
        final held = leaseNow(async, cache, [_orders]);
        leaseNow(async, cache, [_clients]).release();

        cache.panelOpen = false;
        async.elapse(_ttl * 3);
        expect(cache.liveCollectionIds, [_orders]);

        held.release();
        async.elapse(_ttl);
        expect(cache.liveCollectionIds, isEmpty);
      });
    });

    test('a changed TTL applies to the next idle timer', () {
      inFakeTime((async, repo, cache) {
        cache.leaseTtl = const Duration(minutes: 1);
        leaseNow(async, cache, [_orders]).release();

        async.elapse(const Duration(minutes: 1));
        expect(repo.liveListeners, 1);
      });
    });

    test('reset cancels everything; initialize works again', () async {
      final lease = await cache.lease([_orders, _clients]);

      await cache.reset();

      expect(repo.liveListeners, 0);
      expect(cache.collections, isEmpty);
      expect(cache.current(_orders), isNull);
      expect(cache.workspaceId, isNull);
      lease.release(); // a lease from before the reset releases nothing
      await expectLater(cache.lease([_orders]), throwsStateError);

      cache.initialize('ws2');
      final again = await cache.lease([_orders]);
      expect(again.snapshot(_orders).count, seed.orderCards.length);
      expect(cache.workspaceId, 'ws2');
      again.release();
    });

    test('initialize twice without reset is refused', () {
      expect(() => cache.initialize('other'), throwsStateError);
    });
  });

  group('schema stream errors', () {
    test('an error before the first schema is retried: a later lease '
        'completes instead of hanging', () {
      fakeAsync((async) {
        final repo = _FlakySchemaRepo(
          seed.collections,
          (_) => Stream.error(StateError('permission-denied')),
        );
        final cache = WorkspaceCache(repo)..initialize('ws');
        Object? readyError;
        cache.ready.catchError((Object e) => readyError = e);
        async.flushMicrotasks();
        expect(readyError, isStateError);

        Lease? lease;
        cache.lease([_fabrics]).then((l) => lease = l);
        async.flushMicrotasks();
        expect(lease, isNull);

        async.elapse(const Duration(seconds: 1));
        expect(repo.schemaListens, 2);
        expect(lease, isNotNull);
        lease!.release();
        cache.reset();
        async.flushMicrotasks();
        expect(async.pendingTimers, isEmpty);
      });
    });

    test('an error after the schema is ready is re-listened: later schema '
        'changes still arrive', () {
      fakeAsync((async) {
        final repo = _FlakySchemaRepo(seed.collections, (real) async* {
          yield await real.first;
          throw StateError('resource-exhausted');
        });
        final cache = WorkspaceCache(repo)..initialize('ws');
        async.flushMicrotasks();
        expect(cache.collection(_fabrics)!.name, isNot('Materials'));

        async.elapse(const Duration(seconds: 1));
        repo.saveCollection(seed.fabrics.copyWith(name: 'Materials'));
        async.flushMicrotasks();
        expect(cache.collection(_fabrics)!.name, 'Materials');
        cache.reset();
        async.flushMicrotasks();
      });
    });
  });

  group('derive', () {
    test('awaits every source, then matches a full Derivation', () async {
      final derived = await cache.derive(_orders, today: seedToday);

      expect(
        repo.watchObjectsCalls.keys,
        unorderedEquals([_orders, _clients, _fabrics]),
      );
      expect(derived.sources.keys, unorderedEquals([_clients, _fabrics]));
      final expected = Derivation(
        collections: resolveLookups(seed.collections),
        objects: seed.objects,
        today: seedToday,
      ).objectsOf(_orders);
      expect(derived.objects, expected);
      final first = derived.objects.first;
      expect(first[OrderFields.clientCity], isA<CalculatedFieldValue>());
      expect(
        (first[OrderFields.clientCity]! as CalculatedFieldValue).cached,
        SeedOptions.kyiv,
      );
      expect(
        (first[OrderFields.fabricPrice]! as CalculatedFieldValue).cached,
        isNotNull,
      );
    });

    test('skips Derivation when no calculated field is touched', () async {
      final derived = await cache.derive(_orders, today: seedToday);

      final rows = derived.objectsFor([OrderFields.status, OrderFields.price]);

      expect(rows, same(derived.raw));
      expect(derived.hasDerivation, isFalse);
      expect(
        DerivedSnapshot.touchesCalculated(derived.schema, [OrderFields.total]),
        isTrue,
      );
      expect(derived.objectsFor([OrderFields.total]), same(derived.objects));
      expect(derived.hasDerivation, isTrue);
    });

    test('a page of rows derives only those rows', () async {
      final derived = await cache.derive(_orders, today: seedToday);
      final total =
          derived.schema.fieldById(OrderFields.total)!
              as CalculatedFieldDefinition;
      final order = derived.raw.first;

      final value = derived.value(order, total) as CalculatedFieldValue;

      final price = (order[OrderFields.price]! as NumberFieldValue).value!;
      final qty = (order[OrderFields.qty]! as NumberFieldValue).value!;
      expect(value.cached, price * qty);
      expect(
        derived.value(order, derived.schema.fieldById(OrderFields.qty)!),
        order[OrderFields.qty],
      );
    });

    test('is shared until a generation or today changes', () async {
      final a = await cache.derive(_orders, today: seedToday);
      final b = await cache.derive(_orders, today: seedToday);
      expect(b, same(a));

      final tomorrow = await cache.derive(
        _orders,
        today: seedToday.add(const Duration(days: 1)),
      );
      expect(tomorrow, isNot(same(a)));

      // A source changes: Orders' lookups and fabric prices must re-derive.
      repo.seedObjects(_fabrics, seed.fabricCards.sublist(1));
      await pumpEventQueue();
      final c = await cache.derive(_orders, today: seedToday);
      expect(c, isNot(same(a)));
      expect(c.generations[_fabrics], greaterThan(a.generations[_fabrics]!));
      expect(c.generations[_orders], a.generations[_orders]);
    });

    test('a collection without sources leases only itself', () async {
      final repo = FakeDataRepository([
        Collection(
          id: 'c_notes',
          name: 'Notes',
          fields: const [TextFieldDefinition(id: 'f_t', name: 'Text')],
        ),
      ]);
      final cache = WorkspaceCache(repo)..initialize('ws');

      final derived = await cache.derive('c_notes', today: seedToday);

      expect(derived.sources, isEmpty);
      expect(derived.objects, same(derived.raw));
      expect(repo.watchObjectsCalls.keys, ['c_notes']);
      await cache.reset();
    });
  });
}

/// Wraps the first schema stream (e.g. to make it fail); later listens get
/// the real one, like a re-listened Firestore query.
final class _FlakySchemaRepo extends FakeDataRepository {
  _FlakySchemaRepo(super.initial, this._first);

  Stream<List<Collection>> Function(Stream<List<Collection>> real)? _first;
  int schemaListens = 0;

  @override
  Stream<List<Collection>> watchCollections() {
    schemaListens++;
    final first = _first;
    _first = null;
    final real = super.watchCollections();
    return first == null ? real : first(real);
  }
}
