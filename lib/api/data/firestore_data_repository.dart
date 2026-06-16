import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:morkva_crm/core/domain/domain.dart';

import '../firestore/firestore_refs.dart';
import '../firestore/firestore_refs_impl.dart';
import '../firestore/firestore_value_codec.dart';
import '../firestore/firestore_value_codec_impl.dart';
import '../sync/sync_status_cubit.dart';
import 'data_repository.dart';

/// Cloud Firestore implementation of [DataRepository].
///
/// Translates between the Firestore-agnostic domain model and the workspace's
/// Firestore documents. Firestore types are confined to this file (and its refs
/// / codec collaborators); nothing leaks through the [DataRepository] surface.
///
/// ## Object document shape
/// ```json
/// { "collectionId": "<id>", "rev": <int>,
///   "createdAt": "<iso8601>", "updatedAt": "<iso8601>",
///   "values": { "<fieldId>": <native firestore value> } }
/// ```
/// `rev` starts at 1 on create and increments by one on every update inside a
/// Firestore transaction (read current rev, write rev+1). It backs the
/// last-write-wins conflict detection.
///
/// ## Schema on reads
/// Object values must be decoded against their owning [Collection] schema. The
/// read methods ([getObjects]/[getObject]) require `schema`. [watchObjects]
/// accepts an optional `schema` (per spec §5.5): when omitted it resolves the
/// collection once via [getCollection] and reuses it for the stream's lifetime.
/// If the collection cannot be resolved the stream emits an empty list.
class FirestoreDataRepository implements DataRepository {
  /// Creates a repository bound to [firestore].
  ///
  /// [refs] and [codec] default to the standard implementations; [registry]
  /// defaults to the built-in field-type registry. [syncStatus] receives
  /// pending/snapshot/conflict signals.
  FirestoreDataRepository({
    required FirebaseFirestore firestore,
    required SyncStatusCubit syncStatus,
    FirestoreRefs? refs,
    FirestoreValueCodec? codec,
    FieldTypeRegistry? registry,
  }) : _refs = refs ?? FirestoreRefsImpl(firestore),
       _codec = codec ?? const FirestoreValueCodecImpl(),
       _registry = registry ?? defaultFieldTypeRegistry(),
       _syncStatus = syncStatus,
       _db = firestore;

  final FirebaseFirestore _db;
  final FirestoreRefs _refs;
  final FirestoreValueCodec _codec;
  final FieldTypeRegistry _registry;
  final SyncStatusCubit _syncStatus;

  String? _workspaceId;

  /// Last revision this client successfully wrote, per object id.
  final Map<String, int> _localRev = {};

  /// Object ids with a local write not yet confirmed by the server.
  final Set<String> _pendingObjects = {};

  /// Active object-stream subscriptions, cancelled on [dispose].
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  String get _wid {
    final id = _workspaceId;
    if (id == null) {
      throw StateError('FirestoreDataRepository used before initialize().');
    }
    return id;
  }

  @override
  Future<void> initialize(String workspaceId) async {
    _workspaceId = workspaceId;
    _localRev.clear();
    _pendingObjects.clear();
  }

  // ---------------------------------------------------------------------------
  // Collections.
  // ---------------------------------------------------------------------------

  @override
  Stream<List<Collection>> watchCollections() {
    return _refs
        .collections(_wid)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(_collectionFromDoc).toList());
  }

  @override
  Future<List<Collection>> getCollections() async {
    final snapshot = await _refs.collections(_wid).get();
    return snapshot.docs.map(_collectionFromDoc).toList();
  }

  @override
  Future<Collection?> getCollection(String collectionId) async {
    final doc = await _refs.collection(_wid, collectionId).get();
    final data = doc.data();
    if (!doc.exists || data == null) return null;
    return _collectionFromData(collectionId, data);
  }

  @override
  Future<void> saveCollection(Collection collection) async {
    await _refs
        .collection(_wid, collection.id)
        .set(collection.toJson(), SetOptions(merge: false));
  }

  @override
  Future<void> deleteCollection(String collectionId) async {
    await _refs.collection(_wid, collectionId).delete();
  }

  Collection _collectionFromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) => _collectionFromData(doc.id, doc.data());

  Collection _collectionFromData(String id, Map<String, dynamic> data) {
    // Collection.fromJson reads 'id' from the map; trust the document id.
    return Collection.fromJson({...data, 'id': id}, _registry);
  }

  // ---------------------------------------------------------------------------
  // Objects.
  // ---------------------------------------------------------------------------

  @override
  Stream<List<MorkvaObject>> watchObjects(
    String collectionId, {
    Collection? schema,
  }) {
    final controller = StreamController<List<MorkvaObject>>();
    Collection? resolved = schema;

    Future<Collection?> ensureSchema() async {
      resolved ??= await getCollection(collectionId);
      return resolved;
    }

    final subscription = _refs
        .objectsByCollection(_wid, collectionId)
        .snapshots()
        .listen(
          (snapshot) async {
            final collection = await ensureSchema();
            if (collection == null) {
              if (!controller.isClosed) controller.add(const []);
              return;
            }
            _processSnapshotMeta(snapshot);
            final objects = snapshot.docs
                .map((doc) => _objectFromData(doc.id, doc.data(), collection))
                .toList();
            if (!controller.isClosed) controller.add(objects);
          },
          onError: (Object error, StackTrace stackTrace) {
            _syncStatus.reportError('Failed to watch objects', cause: error);
            if (!controller.isClosed) controller.addError(error, stackTrace);
          },
        );

    _subscriptions.add(subscription);
    controller.onCancel = () async {
      await subscription.cancel();
      _subscriptions.remove(subscription);
    };
    return controller.stream;
  }

  @override
  Future<List<MorkvaObject>> getObjects(
    String collectionId, {
    required Collection schema,
  }) async {
    final snapshot = await _refs.objectsByCollection(_wid, collectionId).get();
    return snapshot.docs
        .map((doc) => _objectFromData(doc.id, doc.data(), schema))
        .toList();
  }

  @override
  Future<MorkvaObject?> getObject(
    String collectionId,
    String objectId, {
    required Collection schema,
  }) async {
    final doc = await _refs.object(_wid, objectId).get();
    final data = doc.data();
    if (!doc.exists || data == null) return null;
    return _objectFromData(objectId, data, schema);
  }

  @override
  Future<void> saveObject(
    MorkvaObject object, {
    required Collection schema,
  }) async {
    _syncStatus.reportPendingWrite();
    _pendingObjects.add(object.id);

    final json = object.toJson();
    final encodedValues = _encodeValues(
      (json['values'] as Map).cast<String, dynamic>(),
      schema,
    );
    final docRef = _refs.object(_wid, object.id);

    try {
      final newRev = await _db.runTransaction<int>((transaction) async {
        final snapshot = await transaction.get(docRef);
        final currentRev = (snapshot.data()?['rev'] as num?)?.toInt() ?? 0;
        final nextRev = currentRev + 1;
        transaction.set(docRef, {
          'collectionId': object.collectionId,
          'rev': nextRev,
          'createdAt': json['createdAt'],
          'updatedAt': json['updatedAt'],
          'values': encodedValues,
        });
        return nextRev;
      });
      _localRev[object.id] = newRev;
    } catch (error) {
      _pendingObjects.remove(object.id);
      _syncStatus.reportError('Failed to save object', cause: error);
      rethrow;
    }
  }

  @override
  Future<void> deleteObject(String collectionId, String objectId) async {
    _localRev.remove(objectId);
    _pendingObjects.remove(objectId);
    await _refs.object(_wid, objectId).delete();
  }

  @override
  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    _localRev.clear();
    _pendingObjects.clear();
    _workspaceId = null;
  }

  /// Encodes each schema field's canonical JSON value to its native Firestore
  /// representation. Values for ids not in [schema] are dropped.
  Map<String, dynamic> _encodeValues(
    Map<String, dynamic> rawValues,
    Collection schema,
  ) {
    final encoded = <String, dynamic>{};
    for (final field in schema.fields) {
      encoded[field.id] = _codec.encode(field, rawValues[field.id]);
    }
    return encoded;
  }

  /// Decodes a stored object document into a [MorkvaObject] against [schema].
  MorkvaObject _objectFromData(
    String objectId,
    Map<String, dynamic> data,
    Collection schema,
  ) {
    final rawValues =
        (data['values'] as Map?)?.cast<String, dynamic>() ?? const {};
    final decodedValues = <String, dynamic>{};
    for (final field in schema.fields) {
      decodedValues[field.id] = _codec.decode(field, rawValues[field.id]);
    }
    return MorkvaObject.fromJson({
      'id': objectId,
      'collectionId': data['collectionId'],
      'createdAt': data['createdAt'],
      'updatedAt': data['updatedAt'],
      'values': decodedValues,
    }, schema);
  }

  /// Folds an object snapshot's per-doc revisions and metadata into the sync
  /// status, detecting last-write-wins conflicts (see spec §"Conflict
  /// algorithm").
  void _processSnapshotMeta(QuerySnapshot<Map<String, dynamic>> snapshot) {
    final metadata = snapshot.metadata;
    final isServer = !metadata.hasPendingWrites;
    final conflicts = <String>{};

    for (final doc in snapshot.docs) {
      final id = doc.id;
      final incomingRev = (doc.data()['rev'] as num?)?.toInt() ?? 0;
      if (!isServer) continue;
      if (_pendingObjects.contains(id)) {
        // Our own write confirmed by the server.
        _pendingObjects.remove(id);
        _localRev[id] = incomingRev;
      } else if (incomingRev > (_localRev[id] ?? 0) + 1) {
        // A remote writer advanced rev past what we last saw → conflict.
        conflicts.add(id);
      }
    }

    if (conflicts.isNotEmpty) {
      _syncStatus.reportConflict(conflicts);
    } else {
      _syncStatus.reportSnapshotMeta(
        isFromCache: metadata.isFromCache,
        hasPendingWrites: metadata.hasPendingWrites,
      );
    }
  }
}
