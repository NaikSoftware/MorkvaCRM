import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/harness/cache/result_store.dart';

void main() {
  late ResultStore store;

  setUp(() => store = ResultStore());

  StoredResult put(
    String thread,
    int n, {
    Map<String, int> generations = const {'c_orders': 1},
  }) => store.put(
    thread: thread,
    spec: {'op': 'cards.query', 'collection': 'c_orders', 'n': n},
    generations: generations,
    orderedIds: ['b_$n'],
  );

  test('stores a result under a fresh handle', () {
    final result = store.put(
      thread: 't1',
      spec: const {'collection': 'c_orders', 'where': []},
      generations: const {'c_orders': 4, 'c_clients': 2},
      orderedIds: const ['b_2', 'b_1'],
      groups: const ['g'],
    );

    expect(result.handle, startsWith('h_'));
    expect(store.get(result.handle), same(result));
    expect(result.total, 2);
    expect(result.groups, ['g']);
    expect(() => result.orderedIds.add('b_3'), throwsUnsupportedError);
  });

  test('a repeated query over the same data reuses its handle', () {
    final a = store.put(
      thread: 't1',
      spec: const {
        'collection': 'c_orders',
        'sort': {'field': 'f_total', 'dir': 'desc'},
      },
      generations: const {'c_orders': 4, 'c_clients': 2},
      orderedIds: const ['b_1'],
    );
    final b = store.put(
      thread: 't1',
      spec: const {
        'sort': {'dir': 'desc', 'field': 'f_total'},
        'collection': 'c_orders',
      },
      generations: const {'c_clients': 2, 'c_orders': 4},
      orderedIds: const ['b_1'],
    );

    expect(b, same(a));
    expect(store.length, 1);
  });

  test('moved data or another thread gets a new handle', () {
    final a = put('t1', 1);

    expect(put('t1', 1, generations: {'c_orders': 2}).handle, isNot(a.handle));
    expect(put('t2', 1).handle, isNot(a.handle));
  });

  test('isCurrent compares every generation it was computed over', () {
    final result = put('t1', 1, generations: {'c_orders': 3, 'c_clients': 5});

    expect(result.isCurrent({'c_orders': 3, 'c_clients': 5, 'c_x': 1}), isTrue);
    expect(result.isCurrent({'c_orders': 4, 'c_clients': 5}), isFalse);
    expect(result.isCurrent({'c_orders': 3}), isFalse);
  });

  test('a thread keeps its 32 most recently used results', () {
    final first = put('t1', 0);
    final second = put('t1', 1);
    for (var i = 2; i < 32; i++) {
      put('t1', i);
    }
    store.get(first.handle); // used again: now the newest

    put('t1', 32);

    expect(store.length, 32);
    expect(store.get(second.handle), isNull);
    expect(store.get(first.handle), isNotNull);
  });

  test('all threads together keep the 64 most recently used results', () {
    final old = [for (var i = 0; i < 30; i++) put('t1', i)];
    for (var i = 0; i < 30; i++) {
      put('t2', i);
    }
    final t3 = [for (var i = 0; i < 5; i++) put('t3', i)];

    expect(store.length, 64);
    expect(store.get(old[0].handle), isNull);
    expect(store.get(old[1].handle), isNotNull);
    expect(t3.every((r) => store.get(r.handle) != null), isTrue);
  });

  test('a handle of another thread is not served to it', () {
    final result = put('t1', 1);

    expect(store.get(result.handle, thread: 't2'), isNull);
    expect(store.get(result.handle, thread: 't1'), same(result));
  });

  test('switching away from a thread drops its handles', () {
    final mine = put('t1', 1);
    final other = put('t2', 1);

    store.dropThread('t1');

    expect(store.get(mine.handle), isNull);
    expect(store.get(other.handle), same(other));
    // The same query re-runs under a new handle.
    expect(put('t1', 1).handle, isNot(mine.handle));
  });

  test('clear drops everything', () {
    final result = put('t1', 1);

    store.clear();

    expect(store.length, 0);
    expect(store.get(result.handle), isNull);
  });
}
