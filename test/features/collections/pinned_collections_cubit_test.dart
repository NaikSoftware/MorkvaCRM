import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/features/collections/pins/pinned_collections_cubit.dart';

import 'fake_data_repository.dart';

Collection _c(String id) => Collection(id: id, name: id, fields: const []);

void main() {
  late FakeDataRepository repo;
  late PinnedCollectionsCubit cubit;

  setUp(() {
    repo = FakeDataRepository();
    cubit = PinnedCollectionsCubit(repo)..initialize();
  });
  tearDown(() => cubit.close());

  test('follows the stored pins', () async {
    repo.pinnedIds.add(const ['a', 'b']);
    await pumpEventQueue();
    expect(cubit.state, ['a', 'b']);
  });

  test('toggle pins at the end, then unpins; both are saved', () async {
    await cubit.toggle('a');
    await cubit.toggle('b');
    expect(repo.pinnedIds.value, ['a', 'b']);
    await cubit.toggle('a');
    expect(cubit.state, ['b']);
    expect(repo.pinnedIds.value, ['b']);
  });

  test('reorder moves within the visible pins and drops stale ids', () async {
    repo.pinnedIds.add(const ['a', 'gone', 'b', 'c']);
    await pumpEventQueue();
    // The sidebar shows a, b, c (gone was deleted); drag c to the top.
    await cubit.reorder(const ['a', 'b', 'c'], 2, 0);
    expect(repo.pinnedIds.value, ['c', 'a', 'b']);
    // And a down to the end (index counted without it).
    await cubit.reorder(const ['c', 'a', 'b'], 1, 2);
    expect(repo.pinnedIds.value, ['c', 'b', 'a']);
  });

  test('pinnedCollections keeps pin order and skips deleted ones', () {
    final all = [_c('a'), _c('b'), _c('c')];
    expect(pinnedCollections(const ['c', 'x', 'a'], all).map((c) => c.id), [
      'c',
      'a',
    ]);
  });
}
