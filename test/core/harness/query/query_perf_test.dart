// Timing guards for the query engines on 5,000 orders (Dart VM, JIT with
// asserts). Targets from the spec: query < 50 ms, aggregate by month with a
// calculated metric < 80 ms, paging a handle < 2 ms. Derivation itself is
// timed by the cache perf test, so the guards run on a memoized derive.
@Tags(['perf'])
library;

import 'package:flutter_test/flutter_test.dart';

import 'query_fixture.dart';

/// The best of [runs] timings of [body], in microseconds: steady state, not
/// a scheduler hiccup while other test files run in parallel.
Future<int> _best(Future<void> Function() body, {int runs = 3}) async {
  var best = 1 << 62;
  for (var i = 0; i < runs; i++) {
    final watch = Stopwatch()..start();
    await body();
    if (watch.elapsedMicroseconds < best) best = watch.elapsedMicroseconds;
  }
  return best;
}

const _query = {
  'collection': 'Orders',
  'where': [
    {
      'field': 'Status',
      'op': 'anyOf',
      'value': ['Packing', 'Shipped'],
    },
    {'field': 'Paid', 'op': 'isTrue'},
  ],
  'sort': {'field': 'Created', 'dir': 'desc'},
};

const _byMonth = {
  'collection': 'Orders',
  'groupBy': {'field': 'Created', 'bucket': 'month'},
  'metrics': [
    {'op': 'count'},
    {'op': 'sum', 'field': 'Total'},
  ],
};

void main() {
  final seed = SeedWorkspace.large();
  late QueryHarness h;

  setUpAll(() async {
    // Warm the JIT on the same paths once, so the guards time steady state.
    final warm = QueryHarness(seed);
    await warm.query(_query);
    await warm.aggregate(_byMonth);
    await warm.dispose();
  });

  setUp(() async {
    h = QueryHarness(seed);
    final derived = await h.cache.derive(SeedIds.orders, today: today);
    derived.objects; // memoized, as after the turn's first calculated read
  });
  tearDown(() => h.dispose());

  test('5k orders: query < 50 ms', () async {
    late Map<String, Object?> r;
    final us = await _best(() async => r = await h.query(_query));
    expect(r['total'], greaterThan(100));
    expect(us, lessThan(50000), reason: 'query ${us}us');
  });

  test(
    '5k orders: aggregate by month over a calculated metric < 80 ms',
    () async {
      late Map<String, Object?> r;
      final us = await _best(() async => r = await h.aggregate(_byMonth));
      expect((r['groups']! as List).length, greaterThan(12));
      expect(us, lessThan(80000), reason: 'aggregate ${us}us');
    },
  );

  test('5k orders: paging a handle < 2 ms', () async {
    final first = await h.query({'collection': 'Orders', 'limit': 20});
    // Warm the page path (a fresh JIT compiles it over the first calls).
    for (var i = 0; i < 20; i++) {
      await h.queries.page(
        {'handle': first['handle'], 'cursor': first['nextCursor']},
        context(),
        thread: thread,
      );
    }
    late Map<String, Object?> next;
    final us = await _best(
      () async => next = await h.queries.page(
        {'handle': first['handle'], 'cursor': 'p40'},
        context(),
        thread: thread,
      ),
      runs: 5,
    );
    expect(next['handle'], first['handle']);
    expect(us, lessThan(2000), reason: 'page ${us}us');
  });

  test('5k orders: 20 calls share one listener', () async {
    for (var i = 0; i < 10; i++) {
      await h.query(_query);
      await h.aggregate(_byMonth);
    }
    expect(h.repo.watchObjectsCalls[SeedIds.orders], 1);
  });
}
