import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/api/data/data_repository.dart';
import 'package:morkva_crm/api/data/firestore_data_repository.dart';
import 'package:morkva_crm/api/firestore/firestore_value_codec_impl.dart';
import 'package:morkva_crm/api/sync/sync_status_cubit.dart';
import 'package:morkva_crm/core/domain/domain.dart';

// The write seam (D5): every card write this repository made shows up on
// `changes` once it resolved, with an exact before/after and its origin.
void main() {
  const workspaceId = 'ws-1';

  const orders = Collection(
    id: 'orders',
    name: 'Orders',
    fields: [
      AutoNumberFieldDefinition(id: 'no', name: 'No', start: 100),
      TextFieldDefinition(id: 'client', name: 'Client'),
      NumberFieldDefinition(id: 'qty', name: 'Qty'),
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
  const plan = WriteOrigin(
    kind: WriteKind.plan,
    actor: 'agent:assistant',
    commitId: 'plan_1',
  );

  late FakeFirebaseFirestore firestore;
  late SyncStatusCubit syncStatus;
  late FirestoreDataRepository repository;
  late List<CardChange> events;

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    syncStatus = SyncStatusCubit();
    repository = FirestoreDataRepository(
      firestore: firestore,
      syncStatus: syncStatus,
    );
    await repository.initialize(workspaceId);
    events = [];
    final sub = repository.changes.listen(events.add);
    addTearDown(sub.cancel);
  });

  tearDown(() async {
    await repository.dispose();
    await syncStatus.close();
  });

  String objectPath(String id) => 'workspaces/$workspaceId/objects/$id';

  Future<Map<String, dynamic>?> stored(String id) async =>
      (await firestore.doc(objectPath(id)).get()).data();

  MorkvaObject order(String id, {String client = 'Ada', int qty = 3}) =>
      MorkvaObject.create(
        id: id,
        collection: orders,
        createdAt: DateTime.utc(2026, 3, 1, 9),
        updatedAt: DateTime.utc(2026, 3, 1, 9),
        values: {
          'client': TextFieldValue(client),
          'qty': NumberFieldValue(qty),
        },
      );

  MorkvaObject note(String id) => MorkvaObject.create(
    id: id,
    collection: notes,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
    values: const {'body': TextFieldValue('hi')},
  );

  /// Lets the broadcast stream deliver what the writes added.
  Future<List<CardChange>> drained() async {
    await pumpEventQueue();
    return events;
  }

  /// Drops what the setup writes emitted.
  Future<void> settled() async {
    await pumpEventQueue();
    events.clear();
  }

  group('saveObject', () {
    test('a create emits before: null and the auto-number in after', () async {
      await repository.saveObject(order('o1'), schema: orders);

      final [change] = await drained();
      expect(change.collectionId, 'orders');
      expect(change.cardId, 'o1');
      expect(change.before, isNull);
      expect(change.after!['no'], const AutoNumberFieldValue(100));
      expect(change.after!['client'], const TextFieldValue('Ada'));
      expect(change.rev, 1);
      expect(change.writeId, startsWith('w_'));
      expect(change.origin.kind, WriteKind.ui);
      expect(change.origin.commitId, isNotNull, reason: 'minted per call');
    });

    test('an update emits the stored before and the merged after', () async {
      await repository.saveObject(order('o1'), schema: orders);
      // Only the changed key, as the editor saves it.
      final later = order('o1').copyWith(
        values: {'client': const TextFieldValue('Bo')},
        updatedAt: DateTime.utc(2026, 3, 2),
      );
      await repository.saveObject(later, schema: orders, origin: plan);

      final [_, change] = await drained();
      expect(change.before!['client'], const TextFieldValue('Ada'));
      expect(change.before!['no'], const AutoNumberFieldValue(100));
      expect(change.after!['client'], const TextFieldValue('Bo'));
      expect(change.after!['no'], const AutoNumberFieldValue(100));
      expect(change.after!.updatedAt, DateTime.utc(2026, 3, 2));
      expect(change.rev, 2);
      expect(change.origin, same(plan), reason: 'a given commitId is kept');
    });

    test('an update that changes no value emits nothing', () async {
      await repository.saveObject(order('o1'), schema: orders);
      await repository.saveObject(
        order('o1').copyWith(
          values: {'client': const TextFieldValue('Ada')},
          updatedAt: DateTime.utc(2026, 4),
        ),
        schema: orders,
      );

      expect(await drained(), hasLength(1));
      expect((await stored('o1'))!['rev'], 2, reason: 'still written');
    });

    test('each call mints its own commit and write ids', () async {
      await repository.saveObject(order('o1'), schema: orders);
      await repository.saveObject(order('o2'), schema: orders);

      final [a, b] = await drained();
      expect(a.origin.commitId, isNot(b.origin.commitId));
      expect(a.writeId, isNot(b.writeId));
    });

    test('a write from an older epoch emits nothing', () async {
      // Notes: no auto-number, so the in-flight write needs no workspace.
      final write = repository.saveObject(note('n1'), schema: notes);
      // Sign-out → sign-in as the same user while the write is in flight.
      await repository.dispose();
      await repository.initialize(workspaceId);
      await write;
      expect(await drained(), isEmpty);
      expect(await stored('n1'), isNotNull);

      await repository.saveObject(note('n2'), schema: notes);
      expect((await drained()).single.cardId, 'n2');
    });
  });

  group('deleteObject', () {
    test('emits the given before, after: null', () async {
      final before = order('o1');
      await repository.saveObject(before, schema: orders);
      await settled();

      await repository.deleteObject(
        'orders',
        'o1',
        before: before,
        origin: plan,
      );

      final [change] = await drained();
      expect(change.before, same(before));
      expect(change.after, isNull);
      expect(change.origin, same(plan));
      expect(await stored('o1'), isNull);
    });

    test('without before, reads it locally before deleting', () async {
      await firestore
          .doc('workspaces/$workspaceId/collections/orders')
          .set(orders.toJson());
      await repository.saveObject(order('o1'), schema: orders);
      await settled();

      await repository.deleteObject('orders', 'o1');

      final [change] = await drained();
      expect(change.before!['client'], const TextFieldValue('Ada'));
      expect(change.before!['no'], const AutoNumberFieldValue(100));
      expect(change.after, isNull);
      expect(change.origin.kind, WriteKind.ui);
      expect(await stored('o1'), isNull);
    });

    test('nothing known about the object: deletes, emits nothing', () async {
      await repository.saveObject(order('o1'), schema: orders);
      await settled();

      // No cached schema to decode with.
      await repository.deleteObject('orders', 'o1');
      await repository.deleteObject('orders', 'missing');

      expect(await drained(), isEmpty);
      expect(await stored('o1'), isNull);
    });
  });

  group('saveObjectsBatch', () {
    test('emits per write kind in one commit', () async {
      await repository.saveObject(order('o1'), schema: orders);
      await repository.saveObject(order('o2'), schema: orders);
      final o1 = order('o1').copyWith(
        values: {...order('o1').values, 'no': const AutoNumberFieldValue(100)},
      );
      final o2 = order('o2');
      await settled();

      final result = await repository.saveObjectsBatch(
        [
          ObjectCreate(order('o3')),
          ObjectUpdate(
            collectionId: 'orders',
            id: 'o1',
            values: const {'qty': 7},
            before: o1,
          ),
          ObjectDelete(collectionId: 'orders', id: 'o2', before: o2),
          // No before: written, but nothing to emit.
          const ObjectUpdate(
            collectionId: 'orders',
            id: 'o1',
            values: {'client': 'Cy'},
          ),
        ],
        schemas: schemas,
        origin: plan,
      );
      expect(result.failed, isEmpty);

      final [created, updated, deleted] = await drained();
      expect(created.before, isNull);
      expect(created.after!['no'], const AutoNumberFieldValue(102));
      expect(created.rev, isNull);

      expect(updated.before, same(o1));
      expect(updated.after!['qty'], const NumberFieldValue(7));
      expect(updated.after!['client'], const TextFieldValue('Ada'));
      expect(updated.after!['no'], const AutoNumberFieldValue(100));
      // The batch's own `now`, as a later snapshot decodes it.
      final doc = await stored('o1');
      expect(
        updated.after!.updatedAt,
        DateTime.parse(doc!['updatedAt'] as String),
      );
      expect(updated.after!.updatedAt, isNot(o1.updatedAt));

      expect(deleted.before, same(o2));
      expect(deleted.after, isNull);

      for (final c in [created, updated, deleted]) {
        expect(c.origin, same(plan));
      }
      expect({for (final c in events) c.writeId}, hasLength(3));
    });

    test('an update that changes no value emits nothing', () async {
      await repository.saveObject(order('o1'), schema: orders);
      await settled();

      await repository.saveObjectsBatch([
        ObjectUpdate(
          collectionId: 'orders',
          id: 'o1',
          values: const {'qty': 3},
          before: order('o1'),
        ),
      ], schemas: schemas);

      expect(await drained(), isEmpty);
    });

    test('a failed chunk emits nothing', () async {
      final result = await repository.saveObjectsBatch([
        ObjectUpdate(
          collectionId: 'orders',
          id: 'gone',
          values: const {'qty': 1},
          before: order('gone'),
        ),
      ], schemas: schemas);

      expect(result.failed, {'gone': 'not-found'});
      expect(await drained(), isEmpty);
    });

    test('a batch from an older epoch emits nothing', () async {
      final write = repository.saveObjectsBatch([
        ObjectCreate(note('n1')),
      ], schemas: schemas);
      await repository.dispose();
      await repository.initialize(workspaceId);
      expect((await write).failed, isEmpty);
      expect(await drained(), isEmpty);
    });

    test('every chunk of one call shares a minted commit id', () async {
      final writes = [
        for (var i = 0; i <= maxBatchWrites; i++) ObjectCreate(note('n$i')),
      ];

      await repository.saveObjectsBatch(writes, schemas: schemas);

      final changes = await drained();
      expect(changes, hasLength(maxBatchWrites + 1));
      final commitIds = {for (final c in changes) c.origin.commitId};
      expect(commitIds, hasLength(1));
      expect(commitIds.single, isNotNull);
      expect(changes.map((c) => c.writeId).toSet(), hasLength(changes.length));
    });
  });

  test('schema writes emit nothing', () async {
    await repository.saveCollection(orders);
    await repository.saveViews('orders', const []);
    await repository.deleteCollection('orders');

    expect(await drained(), isEmpty);
  });

  test('a change that fails to build never fails its write', () async {
    final broken = FirestoreDataRepository(
      firestore: firestore,
      syncStatus: syncStatus,
      codec: _ThrowingDecodeCodec(),
    );
    await broken.initialize(workspaceId);
    addTearDown(broken.dispose);
    final seen = <CardChange>[];
    final sub = broken.changes.listen(seen.add);
    addTearDown(sub.cancel);
    final reported = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = reported.add;
    addTearDown(() => FlutterError.onError = previous);

    await broken.saveObject(note('n1'), schema: notes);
    final result = await broken.saveObjectsBatch([
      ObjectCreate(note('n2')),
    ], schemas: schemas);
    await pumpEventQueue();

    expect(result.failed, isEmpty);
    expect(result.written, ['n2']);
    expect(await stored('n1'), isNotNull);
    expect(seen, isEmpty);
    expect(reported, hasLength(2));
  });
}

/// Encodes like the real codec; every decode throws.
class _ThrowingDecodeCodec extends FirestoreValueCodecImpl {
  @override
  Object? decode(FieldDefinition field, Object? firestoreValue) =>
      throw StateError('decode');
}
