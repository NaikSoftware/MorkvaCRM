import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/features/collections/list/collections_list_cubit.dart';
import 'package:morkva_crm/features/collections/list/collections_list_state.dart';

import 'fake_data_repository.dart';

void main() {
  late FakeDataRepository repository;
  late CollectionsListCubit cubit;

  setUp(() {
    repository = FakeDataRepository();
    cubit = CollectionsListCubit(repository);
  });

  tearDown(() async {
    await cubit.close();
    await repository.dispose();
  });

  Future<void> pump() => Future<void>.delayed(Duration.zero);

  test('starts in loading before initialize', () {
    expect(cubit.state, isA<CollectionsListLoading>());
  });

  test('initialize emits ready with the (empty) initial list', () async {
    cubit.initialize();
    await pump();
    final state = cubit.state;
    expect(state, isA<CollectionsListReady>());
    expect((state as CollectionsListReady).isEmpty, isTrue);
  });

  test('seeded collections arrive through the stream', () async {
    await repository.dispose();
    repository = FakeDataRepository(const [
      Collection(id: 'c1', name: 'Orders'),
      Collection(id: 'c2', name: 'Contacts'),
    ]);
    cubit = CollectionsListCubit(repository);
    cubit.initialize();
    await pump();
    final state = cubit.state as CollectionsListReady;
    expect(state.collections.map((c) => c.id), ['c1', 'c2']);
  });

  test('createCollection persists, returns id, and the list updates', () async {
    cubit.initialize();
    await pump();

    final id = await cubit.createCollection('Orders', description: ' track ');
    await pump();

    expect(id, startsWith('c_'));
    final state = cubit.state as CollectionsListReady;
    expect(state.collections, hasLength(1));
    final created = state.collections.single;
    expect(created.id, id);
    expect(created.name, 'Orders');
    expect(created.description, 'track');
    expect(created.fields, isEmpty);
  });

  test('createCollection blank description becomes null', () async {
    cubit.initialize();
    await pump();
    final id = await cubit.createCollection('A', description: '   ');
    await pump();
    final created = (cubit.state as CollectionsListReady).collections
        .firstWhere((c) => c.id == id);
    expect(created.description, isNull);
  });

  test('createCollection mints unique ids', () async {
    cubit.initialize();
    await pump();
    final ids = <String>{};
    for (var i = 0; i < 50; i++) {
      ids.add(await cubit.createCollection('C$i'));
    }
    expect(ids, hasLength(50));
  });

  test('renameCollection updates name and preserves fields', () async {
    await repository.saveCollection(
      const Collection(
        id: 'c1',
        name: 'Old',
        fields: [TextFieldDefinition(id: 'f1', name: 'Title')],
      ),
    );
    cubit.initialize();
    await pump();

    await cubit.renameCollection('c1', 'New', description: 'desc');
    await pump();

    final c = (cubit.state as CollectionsListReady).collections.single;
    expect(c.name, 'New');
    expect(c.description, 'desc');
    expect(c.fields, hasLength(1));
  });

  test('renameCollection can clear the description', () async {
    await repository.saveCollection(
      const Collection(id: 'c1', name: 'X', description: 'had one'),
    );
    cubit.initialize();
    await pump();

    await cubit.renameCollection('c1', 'X', description: '');
    await pump();

    expect(
      (cubit.state as CollectionsListReady).collections.single.description,
      isNull,
    );
  });

  test('deleteCollection removes the row', () async {
    await repository.saveCollection(const Collection(id: 'c1', name: 'X'));
    await repository.saveCollection(const Collection(id: 'c2', name: 'Y'));
    cubit.initialize();
    await pump();

    await cubit.deleteCollection('c1');
    await pump();

    final state = cubit.state as CollectionsListReady;
    expect(state.collections.map((c) => c.id), ['c2']);
  });
}
