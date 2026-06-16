import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/api/data/firestore_data_repository.dart';
import 'package:morkva_crm/api/sync/sync_status.dart';
import 'package:morkva_crm/api/sync/sync_status_cubit.dart';
import 'package:morkva_crm/core/domain/domain.dart';

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

  Collection buildCollection() => const Collection(
    id: 'contacts',
    name: 'Contacts',
    description: 'People',
    fields: [
      TextFieldDefinition(id: 'name', name: 'Name'),
      NumberFieldDefinition(id: 'age', name: 'Age'),
      BooleanFieldDefinition(id: 'vip', name: 'VIP'),
      DateFieldDefinition(id: 'joined', name: 'Joined', includeTime: true),
      MultiSelectFieldDefinition(
        id: 'tags',
        name: 'Tags',
        options: [
          SelectOption(id: 'a', label: 'A'),
          SelectOption(id: 'b', label: 'B'),
        ],
      ),
    ],
  );

  MorkvaObject buildObject(Collection schema, {String id = 'obj-1'}) =>
      MorkvaObject.create(
        id: id,
        collection: schema,
        createdAt: DateTime.utc(2026, 1, 1, 8),
        updatedAt: DateTime.utc(2026, 6, 16, 9, 30),
        values: {
          'name': const TextFieldValue('Ada'),
          'age': const NumberFieldValue(36),
          'vip': const BooleanFieldValue(true),
          'joined': DateFieldValue(DateTime.utc(2026, 6, 15, 13, 45, 30)),
          'tags': const MultiSelectFieldValue(['a', 'b']),
        },
      );

  group('collections', () {
    test('saveCollection → getCollection round-trips by value', () async {
      final collection = buildCollection();
      await repository.saveCollection(collection);

      final loaded = await repository.getCollection(collection.id);
      expect(loaded, equals(collection));
    });

    test('getCollections is empty for a fresh workspace', () async {
      expect(await repository.getCollections(), isEmpty);
    });

    test('getCollection returns null for an unknown id', () async {
      expect(await repository.getCollection('nope'), isNull);
    });

    test('persists schemaVersion in the document', () async {
      await repository.saveCollection(buildCollection());
      final doc = await firestore
          .collection('workspaces')
          .doc(workspaceId)
          .collection('collections')
          .doc('contacts')
          .get();
      expect(doc.data()!['schemaVersion'], kCollectionSchemaVersion);
    });

    test('watchCollections emits the saved collections', () async {
      final collection = buildCollection();
      final future = repository.watchCollections().firstWhere(
        (list) => list.isNotEmpty,
      );
      await repository.saveCollection(collection);
      final emitted = await future;
      expect(emitted.single, equals(collection));
    });

    test('deleteCollection removes it', () async {
      final collection = buildCollection();
      await repository.saveCollection(collection);
      await repository.deleteCollection(collection.id);
      expect(await repository.getCollection(collection.id), isNull);
    });
  });

  group('objects', () {
    test('saveObject → getObject round-trips a multi-field object', () async {
      final schema = buildCollection();
      final object = buildObject(schema);

      await repository.saveObject(object, schema: schema);
      final loaded = await repository.getObject(
        schema.id,
        object.id,
        schema: schema,
      );

      expect(loaded, isNotNull);
      expect(loaded!.id, object.id);
      expect(loaded.collectionId, object.collectionId);
      // The date field must round-trip exactly through Timestamp.
      final joined = loaded.values['joined']! as DateFieldValue;
      expect(joined.value, DateTime.utc(2026, 6, 15, 13, 45, 30));
      expect(loaded.values, equals(object.values));
      expect(loaded, equals(object));
    });

    test('stores the date value as a native Firestore Timestamp', () async {
      final schema = buildCollection();
      await repository.saveObject(buildObject(schema), schema: schema);

      final doc = await firestore
          .collection('workspaces')
          .doc(workspaceId)
          .collection('objects')
          .doc('obj-1')
          .get();
      final values = (doc.data()!['values'] as Map).cast<String, dynamic>();
      expect(values['joined'], isA<Timestamp>());
      expect(values['name'], 'Ada');
      expect(values['age'], 36);
    });

    test('getObject returns null for an unknown id', () async {
      final schema = buildCollection();
      expect(
        await repository.getObject(schema.id, 'ghost', schema: schema),
        isNull,
      );
    });

    test('getObjects returns all objects in the collection', () async {
      final schema = buildCollection();
      await repository.saveObject(
        buildObject(schema, id: 'o1'),
        schema: schema,
      );
      await repository.saveObject(
        buildObject(schema, id: 'o2'),
        schema: schema,
      );

      final objects = await repository.getObjects(schema.id, schema: schema);
      expect(objects.map((o) => o.id).toSet(), {'o1', 'o2'});
    });

    test('watchObjects emits the updated list after a save', () async {
      final schema = buildCollection();
      final future = repository
          .watchObjects(schema.id, schema: schema)
          .firstWhere((list) => list.isNotEmpty);

      await repository.saveObject(buildObject(schema), schema: schema);
      final emitted = await future;
      expect(emitted.single.id, 'obj-1');
    });

    test('deleteObject removes the object', () async {
      final schema = buildCollection();
      final object = buildObject(schema);
      await repository.saveObject(object, schema: schema);
      await repository.deleteObject(schema.id, object.id);

      expect(
        await repository.getObject(schema.id, object.id, schema: schema),
        isNull,
      );
    });

    test('rev increments 0 → 1 → 2 across saves', () async {
      final schema = buildCollection();
      final object = buildObject(schema);
      final docRef = firestore
          .collection('workspaces')
          .doc(workspaceId)
          .collection('objects')
          .doc(object.id);

      await repository.saveObject(object, schema: schema);
      expect((await docRef.get()).data()!['rev'], 1);

      await repository.saveObject(object, schema: schema);
      expect((await docRef.get()).data()!['rev'], 2);

      await repository.saveObject(object, schema: schema);
      expect((await docRef.get()).data()!['rev'], 3);
    });
  });

  group('sync status', () {
    test('saveObject reports a pending write', () async {
      final schema = buildCollection();
      final states = <SyncStatus>[];
      final sub = syncStatus.stream.listen(states.add);

      await repository.saveObject(buildObject(schema), schema: schema);
      await sub.cancel();

      expect(states, contains(isA<SyncPending>()));
    });

    test(
      'watchObjects settles the sync status from snapshot metadata',
      () async {
        final schema = buildCollection();
        await repository.saveObject(buildObject(schema), schema: schema);

        // Let the snapshot listener fold metadata into a non-conflict status.
        await repository
            .watchObjects(schema.id, schema: schema)
            .firstWhere((list) => list.isNotEmpty);
        await Future<void>.delayed(Duration.zero);

        expect(syncStatus.state, isNot(isA<SyncConflict>()));
        expect(syncStatus.state, isNot(isA<SyncError>()));
      },
    );
  });

  group('replay on subscribe', () {
    test(
      'watchCollections replays the current list to a late subscriber',
      () async {
        final collection = buildCollection();
        await repository.saveCollection(collection);

        // Subscribe AFTER the data already exists and let the source snapshot
        // settle, then a brand-new subscriber must still receive the current list.
        final stream = repository.watchCollections();
        await stream.firstWhere((list) => list.isNotEmpty);

        final replayed = await stream.first;
        expect(replayed.single, equals(collection));
      },
    );

    test(
      'watchObjects replays the current list to a late subscriber',
      () async {
        final schema = buildCollection();
        await repository.saveObject(buildObject(schema), schema: schema);

        final stream = repository.watchObjects(schema.id, schema: schema);
        await stream.firstWhere((list) => list.isNotEmpty);

        final replayed = await stream.first;
        expect(replayed.single.id, 'obj-1');
      },
    );
  });

  group('conflict detection', () {
    test(
      'observing a pre-existing object at rev>=2 does NOT report a conflict',
      () async {
        final schema = buildCollection();
        // Seed an object the client never wrote, already at rev 5 on the server.
        await firestore
            .collection('workspaces')
            .doc(workspaceId)
            .collection('objects')
            .doc('seeded')
            .set({
              'collectionId': schema.id,
              'rev': 5,
              'createdAt': '2026-01-01T00:00:00.000Z',
              'updatedAt': '2026-01-02T00:00:00.000Z',
              'values': <String, dynamic>{},
            });

        await repository
            .watchObjects(schema.id, schema: schema)
            .firstWhere((list) => list.isNotEmpty);
        await Future<void>.delayed(Duration.zero);

        expect(syncStatus.state, isNot(isA<SyncConflict>()));
      },
    );
  });

  group('lifecycle', () {
    test('initialize / dispose / initialize cycle works', () async {
      final schema = buildCollection();
      await repository.saveCollection(schema);
      await repository.dispose();

      await repository.initialize(workspaceId);
      final loaded = await repository.getCollection(schema.id);
      expect(loaded, equals(schema));
    });

    test(
      'dispose closes the watchObjects stream so consumers get done',
      () async {
        final schema = buildCollection();
        var done = false;
        repository
            .watchObjects(schema.id, schema: schema)
            .listen((_) {}, onDone: () => done = true);
        // Let the listener attach before disposing.
        await Future<void>.delayed(Duration.zero);

        await repository.dispose();
        await Future<void>.delayed(Duration.zero);

        expect(done, isTrue);
      },
    );
  });
}
