// Timing guards for the cache on 5,000 orders (Dart VM, JIT with asserts, so
// the bounds sit well above measured times: they catch an accidental O(n²)
// or an eager rebuild, not a few milliseconds).
@Tags(['perf'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/core/harness/cache/workspace_cache.dart';

import '../../../features/collections/fake_data_repository.dart';
import '../fixtures/seed_workspace.dart';

const _orders = SeedIds.orders;

/// Milliseconds [body] takes.
Future<int> _ms(Future<void> Function() body) async {
  final watch = Stopwatch()..start();
  await body();
  return watch.elapsedMilliseconds;
}

void main() {
  final seed = SeedWorkspace.large();
  late FakeDataRepository repo;
  late WorkspaceCache cache;

  setUp(() {
    repo = seed.repository();
    cache = WorkspaceCache(repo)..initialize('ws');
  });

  tearDown(() => cache.reset());

  setUpAll(() async {
    // Warm the JIT on the same paths once, so the guards time steady state.
    final warm = WorkspaceCache(seed.repository())..initialize('warm');
    final derived = await warm.derive(_orders, today: seedToday);
    derived.objects;
    derived.base.labels.search('linen');
    await warm.reset();
  });

  test('5k orders: cold lease, then 20 calls on one listener', () async {
    final cold = await _ms(() => cache.read(_orders));
    final warm = await _ms(() async {
      for (var i = 0; i < 20; i++) {
        await cache.read(_orders);
      }
    });

    expect(repo.watchObjectsCalls[_orders], 1);
    expect(cold, lessThan(250), reason: 'cold lease ${cold}ms');
    expect(warm, lessThan(20), reason: '20 warm reads ${warm}ms');
  });

  test('5k orders: indexes build once, lazily and fast', () async {
    final snapshot = await cache.read(_orders);
    expect(snapshot.hasById, isFalse);
    expect(snapshot.hasLabels, isFalse);

    final byId = await _ms(() async => snapshot[SeedCards.order(5000)]);
    final labels = await _ms(() async => snapshot.labels);
    final search = await _ms(() async => snapshot.labels.search('linen'));

    expect(byId, lessThan(30), reason: 'byId ${byId}ms');
    expect(labels, lessThan(200), reason: 'labels ${labels}ms');
    expect(search, lessThan(50), reason: 'search ${search}ms');
  });

  test('5k orders: full derivation once, then shared', () async {
    late List<MorkvaObject> objects;
    final first = await _ms(() async {
      final derived = await cache.derive(_orders, today: seedToday);
      objects = derived.objects;
    });
    final again = await _ms(() async {
      final derived = await cache.derive(_orders, today: seedToday);
      expect(derived.objects, same(objects));
    });

    expect(objects, hasLength(5000));
    expect(first, lessThan(600), reason: 'derive ${first}ms');
    expect(again, lessThan(5), reason: 'memoized derive ${again}ms');
  });

  test('5k orders: no calculated field touched skips Derivation', () async {
    final derived = await cache.derive(_orders, today: seedToday);
    final skip = await _ms(
      () async => derived.objectsFor([OrderFields.status, OrderFields.paid]),
    );

    expect(derived.hasDerivation, isFalse);
    expect(skip, lessThan(2), reason: 'skip ${skip}ms');
  });

  test(
    '5k orders: a page of calculated values derives only the page',
    () async {
      final derived = await cache.derive(_orders, today: seedToday);
      final margin =
          derived.schema.fieldById(OrderFields.margin)!
              as CalculatedFieldDefinition;
      final page = await _ms(() async {
        for (final o in derived.raw.take(20)) {
          derived.valueOf(o, margin);
        }
      });

      expect(page, lessThan(20), reason: 'page ${page}ms');
    },
  );
}
