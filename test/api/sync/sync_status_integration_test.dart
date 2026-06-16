import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/api/data/firestore_data_repository.dart';
import 'package:morkva_crm/api/sync/sync_status.dart';
import 'package:morkva_crm/api/sync/sync_status_cubit.dart';
import 'package:morkva_crm/core/domain/domain.dart';

/// End-to-end coverage of the metadata → status pipeline: a real
/// [FirestoreDataRepository] backed by [FakeFirebaseFirestore] feeds a real
/// [SyncStatusCubit] through its `report*` hooks. Mirrors the setup/builders in
/// `test/api/data/firestore_data_repository_test.dart`.
/// Lets pending microtasks/timers drain so the watch listener — which awaits
/// schema resolution before folding metadata — can settle the cubit.
Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 50));

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
    fields: [TextFieldDefinition(id: 'name', name: 'Name')],
  );

  MorkvaObject buildObject(Collection schema, {String id = 'obj-1'}) =>
      MorkvaObject.create(
        id: id,
        collection: schema,
        createdAt: DateTime.utc(2026, 1, 1, 8),
        updatedAt: DateTime.utc(2026, 6, 16, 9, 30),
        values: {'name': const TextFieldValue('Ada')},
      );

  DocumentReference<Map<String, dynamic>> objectDoc(String id) => firestore
      .collection('workspaces')
      .doc(workspaceId)
      .collection('objects')
      .doc(id);

  group('save pipeline', () {
    test('saveObject reports SyncPending to the cubit', () async {
      final schema = buildCollection();
      final states = <SyncStatus>[];
      final sub = syncStatus.stream.listen(states.add);

      await repository.saveObject(buildObject(schema), schema: schema);
      await sub.cancel();

      expect(states, contains(isA<SyncPending>()));
    });

    test('after a save settles, status is not conflict/error', () async {
      final schema = buildCollection();
      await repository.saveObject(buildObject(schema), schema: schema);

      // Drain the snapshot listener so it folds metadata into a steady state.
      await repository
          .watchObjects(schema.id, schema: schema)
          .firstWhere((list) => list.isNotEmpty);
      await _settle();

      expect(syncStatus.state, isNot(isA<SyncConflict>()));
      expect(syncStatus.state, isNot(isA<SyncError>()));
    });
  });

  group('conflict detection', () {
    test(
      'pre-existing object observed at rev>=2 does NOT fire SyncConflict',
      () async {
        // Regression guard for the baseline bug fixed in Task 5: passively
        // observing an object the client never wrote — at any rev — is never a
        // conflict; it just seeds the baseline.
        final schema = buildCollection();
        await objectDoc('seeded').set({
          'collectionId': schema.id,
          'rev': 5,
          'createdAt': '2026-01-01T00:00:00.000Z',
          'updatedAt': '2026-01-02T00:00:00.000Z',
          'values': <String, dynamic>{},
        });

        await repository
            .watchObjects(schema.id, schema: schema)
            .firstWhere((list) => list.isNotEmpty);
        await _settle();

        expect(syncStatus.state, isNot(isA<SyncConflict>()));
      },
    );

    test(
      'remote writer advancing rev past the baseline surfaces SyncConflict',
      () async {
        // The repository establishes a baseline for an object by passively
        // observing it on a server snapshot (rev 1). A second writer then jumps
        // rev to 3 — a gap of +2 beyond the baseline, i.e. more than our own
        // +1 — which the conflict algorithm classifies as last-write-wins.
        final schema = buildCollection();
        await objectDoc('shared').set({
          'collectionId': schema.id,
          'rev': 1,
          'createdAt': '2026-01-01T00:00:00.000Z',
          'updatedAt': '2026-01-02T00:00:00.000Z',
          'values': <String, dynamic>{},
        });

        // Future that resolves the first time the cubit reaches SyncConflict.
        final firstConflict = syncStatus.stream
            .firstWhere((s) => s is SyncConflict)
            .then((s) => s as SyncConflict);

        // Establish the baseline (rev 1) via the first server snapshot. The
        // watch listener resolves its schema asynchronously, so wait for the
        // baseline to settle to a non-conflict steady state before mutating.
        repository.watchObjects(schema.id, schema: schema).listen((_) {});
        await _settle();
        expect(syncStatus.state, isNot(isA<SyncConflict>()));

        // Simulate a concurrent remote writer: jump rev 1 → 3 (gap > +1).
        await objectDoc('shared').update({'rev': 3});

        // NOTE on fake_cloud_firestore (4.1.1): it faithfully re-emits a server
        // snapshot (isFromCache=false, hasPendingWrites=false) carrying the new
        // rev after the direct update, which is exactly what the conflict
        // algorithm needs — so the rev-gap transition IS reproducible here. The
        // only subtlety is timing: the repository's watch listener awaits schema
        // resolution, so we await the conflict via the stream rather than a
        // fixed delay. If a future fake version stopped re-emitting the
        // post-update server snapshot, this await would hang — the canary that
        // the fake can no longer simulate the transition.
        final conflict = await firstConflict;
        expect(conflict.affectedObjectIds, contains('shared'));
        expect(syncStatus.state, isA<SyncConflict>());
      },
    );
  });
}
