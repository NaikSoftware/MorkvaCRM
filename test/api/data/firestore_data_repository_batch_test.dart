import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/api/data/data_repository.dart';
import 'package:morkva_crm/api/data/firestore_data_repository.dart';
import 'package:morkva_crm/api/sync/sync_status.dart';
import 'package:morkva_crm/api/sync/sync_status_cubit.dart';
import 'package:morkva_crm/core/domain/domain.dart';

// Note: fake_cloud_firestore applies a WriteBatch task by task without
// rollback and never retries a transaction, so these tests assert on the
// reported BatchResult and on reads of the server document rather than on
// batch atomicity or interleaved writers.
void main() {
  const workspaceId = 'ws-1';

  late FakeFirebaseFirestore firestore;
  late SyncStatusCubit syncStatus;
  late FirestoreDataRepository repository;

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    syncStatus = SyncStatusCubit();
    repository = FirestoreDataRepository(
      firestore: firestore,
      syncStatus: syncStatus,
    );
    await repository.initialize(workspaceId);
  });

  tearDown(() async {
    await repository.dispose();
    await syncStatus.close();
  });

  const orders = Collection(
    id: 'orders',
    name: 'Orders',
    fields: [
      AutoNumberFieldDefinition(id: 'no', name: 'No', start: 100),
      TextFieldDefinition(id: 'client', name: 'Client'),
      NumberFieldDefinition(id: 'qty', name: 'Qty'),
      SingleSelectFieldDefinition(
        id: 'status',
        name: 'Status',
        options: [
          SelectOption(id: 'pack', label: 'Packing'),
          SelectOption(id: 'ship', label: 'Shipped'),
        ],
      ),
      DateFieldDefinition(id: 'due', name: 'Due'),
      CalculatedFieldDefinition(
        id: 'twice',
        name: 'Twice',
        declaredOutputType: 'number',
        expression: '{qty} * 2',
      ),
    ],
  );

  const notes = Collection(
    id: 'notes',
    name: 'Notes',
    fields: [TextFieldDefinition(id: 'body', name: 'Body')],
  );

  const schemas = {'orders': orders, 'notes': notes};

  String objectPath(String id) => 'workspaces/$workspaceId/objects/$id';

  Future<Map<String, dynamic>?> stored(String id) async =>
      (await firestore.doc(objectPath(id)).get()).data();

  Future<Map<String, dynamic>?> counters() async =>
      (await firestore.doc('workspaces/$workspaceId').get()).data()?['counters']
          as Map<String, dynamic>?;

  /// Seeds a stored order document directly, as another client would.
  Future<void> seedOrder(
    String id, {
    int rev = 3,
    Map<String, Object?> values = const {'client': 'Iryna', 'qty': 2},
  }) => firestore.doc(objectPath(id)).set({
    'collectionId': 'orders',
    'rev': rev,
    'createdAt': '2026-01-01T00:00:00.000Z',
    'updatedAt': '2026-01-01T00:00:00.000Z',
    'values': values,
  });

  MorkvaObject order(String id, {int? no, String client = 'Ada'}) =>
      MorkvaObject.create(
        id: id,
        collection: orders,
        createdAt: DateTime.utc(2026, 3, 1, 9),
        updatedAt: DateTime.utc(2026, 3, 1, 9),
        values: {
          'client': TextFieldValue(client),
          'qty': const NumberFieldValue(3),
          if (no != null) 'no': AutoNumberFieldValue(no),
          'twice': const CalculatedFieldValue(6),
        },
      );

  MorkvaObject note(String id) => MorkvaObject.create(
    id: id,
    collection: notes,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
    values: const {'body': TextFieldValue('hi')},
  );

  group('saveObjectsBatch updates', () {
    test('write only the touched keys and bump rev by one', () async {
      await seedOrder('o1', values: {'client': 'Iryna', 'qty': 2});

      final result = await repository.saveObjectsBatch([
        const ObjectUpdate(
          collectionId: 'orders',
          id: 'o1',
          values: {'status': 'ship', 'due': '2026-04-01T00:00:00.000Z'},
        ),
      ], schemas: schemas);

      expect(result.written, ['o1']);
      expect(result.failed, isEmpty);
      final doc = (await stored('o1'))!;
      expect(doc['rev'], 4);
      expect(doc['updatedAt'], isNot('2026-01-01T00:00:00.000Z'));
      final values = doc['values'] as Map<String, dynamic>;
      // Untouched values survive; touched ones are encoded natively.
      expect(values['client'], 'Iryna');
      expect(values['qty'], 2);
      expect(values['status'], 'ship');
      expect(values['due'], isNot(isA<String>()));
      final read = await repository.getObject('orders', 'o1', schema: orders);
      expect(read!['due'], DateFieldValue(DateTime.utc(2026, 4)));
    });

    test('skip calculated and unknown keys', () async {
      await seedOrder('o1');

      await repository.saveObjectsBatch([
        const ObjectUpdate(
          collectionId: 'orders',
          id: 'o1',
          values: {'qty': 5, 'twice': 10, 'gone': 'x'},
        ),
      ], schemas: schemas);

      final values = (await stored('o1'))!['values'] as Map<String, dynamic>;
      expect(values, {'client': 'Iryna', 'qty': 5});
    });

    test('a null value clears the stored one', () async {
      await seedOrder('o1');

      await repository.saveObjectsBatch([
        const ObjectUpdate(
          collectionId: 'orders',
          id: 'o1',
          values: {'client': null},
        ),
      ], schemas: schemas);

      final read = await repository.getObject('orders', 'o1', schema: orders);
      expect(read!['client'], const TextFieldValue(null));
      expect(read['qty'], const NumberFieldValue(2));
    });

    test('a missing object fails its chunk with not-found', () async {
      await seedOrder('o1');
      await seedOrder('o3');

      final result = await repository.saveObjectsBatch([
        for (final id in ['o1', 'gone-1', 'o3', 'gone-2'])
          ObjectUpdate(
            collectionId: 'orders',
            id: id,
            values: const {'qty': 9},
          ),
      ], schemas: schemas);

      expect(result.written, isEmpty);
      expect(result.failed, {
        'o1': 'not-found',
        'gone-1': 'not-found',
        'o3': 'not-found',
        'gone-2': 'not-found',
      });
      // An expected stale outcome: no sync error banner for it.
      expect(syncStatus.state, isA<SyncSynced>());
    });

    test('commit in chunks of $maxBatchWrites; a failed chunk leaves the '
        'others written', () async {
      const total = maxBatchWrites + 10;
      for (var i = 0; i < total; i++) {
        if (i == maxBatchWrites + 5) continue; // missing, in the 2nd chunk
        await seedOrder('o$i', rev: 1);
      }

      final result = await repository.saveObjectsBatch([
        for (var i = 0; i < total; i++)
          ObjectUpdate(
            collectionId: 'orders',
            id: 'o$i',
            values: const {'qty': 7},
          ),
      ], schemas: schemas);

      expect(result.written, [for (var i = 0; i < maxBatchWrites; i++) 'o$i']);
      expect(result.failed.keys, [
        for (var i = maxBatchWrites; i < total; i++) 'o$i',
      ]);
      expect((await stored('o${maxBatchWrites - 1}'))!['rev'], 2);
    });

    test('settles the sync status to synced', () async {
      await seedOrder('o1');

      await repository.saveObjectsBatch([
        const ObjectUpdate(
          collectionId: 'orders',
          id: 'o1',
          values: {'qty': 1},
        ),
      ], schemas: schemas);

      expect(syncStatus.state, isA<SyncSynced>());
    });

    test(
      'our own batch update of a watched object is not a conflict',
      () async {
        await seedOrder('o1', rev: 5);
        final emissions = <List<MorkvaObject>>[];
        final sub = repository
            .watchObjects('orders', schema: orders)
            .listen(emissions.add);
        await Future<void>.delayed(Duration.zero);

        await repository.saveObjectsBatch([
          const ObjectUpdate(
            collectionId: 'orders',
            id: 'o1',
            values: {'qty': 8},
          ),
        ], schemas: schemas);
        await Future<void>.delayed(Duration.zero);
        await repository.saveObjectsBatch([
          const ObjectUpdate(
            collectionId: 'orders',
            id: 'o1',
            values: {'qty': 9},
          ),
        ], schemas: schemas);
        await Future<void>.delayed(Duration.zero);

        expect(emissions.last.single['qty'], const NumberFieldValue(9));
        expect(syncStatus.state, isNot(isA<SyncConflict>()));
        await sub.cancel();
      },
    );
  });

  group('saveObjectsBatch creates', () {
    test('store the saveObject doc shape at rev 1, without calculated '
        'values', () async {
      final result = await repository.saveObjectsBatch([
        ObjectCreate(order('a', no: 7)),
      ], schemas: schemas);

      expect(result.written, ['a']);
      final doc = (await stored('a'))!;
      expect(doc['collectionId'], 'orders');
      expect(doc['rev'], 1);
      expect(doc['createdAt'], '2026-03-01T09:00:00.000Z');
      expect(doc['updatedAt'], '2026-03-01T09:00:00.000Z');
      expect((doc['values'] as Map).containsKey('twice'), isFalse);
      final read = await repository.getObject('orders', 'a', schema: orders);
      expect(read!['client'], const TextFieldValue('Ada'));
    });

    test('one reservation numbers every create of the chunk in order, '
        'continuing the stored counter', () async {
      await firestore.doc('workspaces/$workspaceId').set({
        'counters': {
          'orders': {'no': 120, 'retired': 9},
          'other': {'n': 4},
        },
      });

      await repository.saveObjectsBatch([
        ObjectCreate(order('a')),
        ObjectCreate(order('b')),
        ObjectCreate(note('n1')),
        ObjectCreate(order('c')),
      ], schemas: schemas);

      Future<Object?> numberOf(String id) async =>
          ((await stored(id))!['values'] as Map)['no'];
      expect(await numberOf('a'), 121);
      expect(await numberOf('b'), 122);
      expect(await numberOf('c'), 123);
      // Other counters, here and in other collections, survive.
      expect(await counters(), {
        'orders': {'no': 123, 'retired': 9},
        'other': {'n': 4},
      });
    });

    test('a fresh counter starts at the field start', () async {
      await repository.saveObjectsBatch([
        ObjectCreate(order('a')),
        ObjectCreate(order('b')),
      ], schemas: schemas);

      expect(((await stored('a'))!['values'] as Map)['no'], 100);
      expect(((await stored('b'))!['values'] as Map)['no'], 101);
      expect(await counters(), {
        'orders': {'no': 101},
      });
    });

    test('a create that carries its number keeps it and reserves '
        'nothing', () async {
      await firestore.doc('workspaces/$workspaceId').set({
        'counters': {
          'orders': {'no': 130},
        },
      });

      await repository.saveObjectsBatch([
        ObjectCreate(order('a', no: 104)),
      ], schemas: schemas);

      expect(((await stored('a'))!['values'] as Map)['no'], 104);
      expect(await counters(), {
        'orders': {'no': 130},
      });
    });

    test('a collection without auto-numbers touches no counters', () async {
      await repository.saveObjectsBatch([
        ObjectCreate(note('n1')),
      ], schemas: schemas);

      expect(
        (await firestore.doc('workspaces/$workspaceId').get()).exists,
        isFalse,
      );
    });

    test('a created object reads back through watchObjects', () async {
      await repository.saveObjectsBatch([
        ObjectCreate(order('a')),
      ], schemas: schemas);

      final objects = await repository
          .watchObjects('orders', schema: orders)
          .first;
      expect(objects.single['no'], const AutoNumberFieldValue(100));
    });
  });

  group('saveObjectsBatch deletes and mixes', () {
    test('a delete removes the object; a missing one is a no-op', () async {
      await seedOrder('o1');

      final result = await repository.saveObjectsBatch([
        const ObjectDelete(collectionId: 'orders', id: 'o1'),
        const ObjectDelete(collectionId: 'orders', id: 'gone'),
      ], schemas: const {});

      expect(result.written, ['o1', 'gone']);
      expect(result.failed, isEmpty);
      expect(await stored('o1'), isNull);
    });

    test('creates, updates and deletes apply together', () async {
      await seedOrder('o1');
      await seedOrder('o2');

      final result = await repository.saveObjectsBatch([
        ObjectCreate(order('a')),
        const ObjectUpdate(
          collectionId: 'orders',
          id: 'o1',
          values: {'status': 'pack'},
        ),
        const ObjectDelete(collectionId: 'orders', id: 'o2'),
      ], schemas: schemas);

      expect(result.written, ['a', 'o1', 'o2']);
      final objects = await repository.getObjects('orders', schema: orders);
      expect(objects.map((o) => o.id), unorderedEquals(['a', 'o1']));
    });

    test('an empty list writes nothing', () async {
      final result = await repository.saveObjectsBatch(
        const [],
        schemas: schemas,
      );
      expect(result.written, isEmpty);
      expect(result.failed, isEmpty);
      expect(syncStatus.state, isA<SyncUnknown>());
    });

    test('a write without its schema is rejected before anything is '
        'written', () async {
      await seedOrder('o1');

      await expectLater(
        repository.saveObjectsBatch([
          const ObjectUpdate(
            collectionId: 'orders',
            id: 'o1',
            values: {'qty': 1},
          ),
          const ObjectUpdate(collectionId: 'nope', id: 'x', values: {}),
        ], schemas: schemas),
        throwsArgumentError,
      );
      expect((await stored('o1'))!['rev'], 3);
    });
  });

  group('updateCollection', () {
    const extra = TextFieldDefinition(id: 'extra', name: 'Extra');
    const added = NumberFieldDefinition(id: 'added', name: 'Added');

    test('applies the delta to the server copy, so a field added '
        'elsewhere survives', () async {
      // The caller's cached copy has no `extra`; the server already does.
      await repository.saveCollection(notes);
      await firestore
          .doc('workspaces/$workspaceId/collections/notes')
          .set(notes.copyWith(fields: [...notes.fields, extra]).toJson());

      Collection? seen;
      await repository.updateCollection('notes', (server) {
        seen = server;
        return server.copyWith(
          name: 'Journal',
          fields: [...server.fields, added],
        );
      });

      expect(seen!.fieldById('extra'), extra);
      final saved = await repository.getCollection('notes');
      expect(saved!.name, 'Journal');
      expect(saved.fields.map((f) => f.id), ['body', 'extra', 'added']);
    });

    test('a missing collection throws a StateError', () async {
      await expectLater(
        repository.updateCollection('nope', (c) => c),
        throwsStateError,
      );
    });
  });

  group('updateViews', () {
    const mine = ViewDefinition(id: 'mine', name: 'Mine', fieldIds: ['body']);
    const theirs = ViewDefinition(
      id: 'theirs',
      name: 'Theirs',
      fieldIds: ['body'],
    );
    const added = ViewDefinition(id: 'added', name: 'Added', fieldIds: []);

    test('merges into the server views and leaves fields alone', () async {
      await firestore
          .doc('workspaces/$workspaceId/collections/notes')
          .set(notes.copyWith(views: [mine, theirs]).toJson());

      await repository.updateViews(
        'notes',
        (server) => [
          for (final v in server)
            v.id == 'mine' ? v.copyWith(name: 'Mine (renamed)') : v,
          added,
        ],
      );

      final saved = (await repository.getCollection('notes'))!;
      expect(saved.views.map((v) => v.name), [
        'Mine (renamed)',
        'Theirs',
        'Added',
      ]);
      expect(saved.fields, notes.fields);
    });

    test('a missing collection throws a StateError', () async {
      await expectLater(
        repository.updateViews('nope', (views) => views),
        throwsStateError,
      );
    });
  });
}
