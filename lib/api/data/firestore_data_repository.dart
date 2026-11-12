import 'dart:async';
import 'dart:math' show min;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'
    show ErrorDescription, FlutterError, FlutterErrorDetails, visibleForTesting;
import 'package:morkva_crm/core/domain/domain.dart' hide FieldValue;
import 'package:morkva_crm/core/domain/ids.dart';
import 'package:rxdart/rxdart.dart';

import '../firestore/firestore_refs.dart';
import '../firestore/firestore_refs_impl.dart';
import '../firestore/firestore_value_codec.dart';
import '../firestore/firestore_value_codec_impl.dart';
import '../sync/sync_status_cubit.dart';
import 'data_repository.dart';

/// What a committed batch chunk wrote: the create documents and its `now`.
typedef _CommittedChunk = ({
  Map<ObjectCreate, Map<String, dynamic>> created,
  String now,
});

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
  /// pending/snapshot/conflict signals. [ids] mints write and commit ids.
  FirestoreDataRepository({
    required FirebaseFirestore firestore,
    required SyncStatusCubit syncStatus,
    FirestoreRefs? refs,
    FirestoreValueCodec? codec,
    FieldTypeRegistry? registry,
    IdGenerator? ids,
  }) : _refs = refs ?? FirestoreRefsImpl(firestore),
       _codec = codec ?? const FirestoreValueCodecImpl(),
       _registry = registry ?? defaultFieldTypeRegistry(),
       _ids = ids ?? IdGenerator(),
       _syncStatus = syncStatus,
       _db = firestore;

  final FirebaseFirestore _db;
  final FirestoreRefs _refs;
  final FirestoreValueCodec _codec;
  final FieldTypeRegistry _registry;
  final IdGenerator _ids;
  final SyncStatusCubit _syncStatus;

  String? _workspaceId;

  // Not closed in dispose: the app disposes and re-initializes this same
  // instance on sign-out → sign-in, so the stream outlives a session; the
  // epoch keeps an old session's writes off it.
  final _changes = StreamController<CardChange>.broadcast();

  /// Bumped by [initialize] and [dispose]; a write emits only if it is still
  /// the epoch the write started in. The workspace id equals the uid, so a
  /// sign-out → sign-in as the same user would pass a workspace-id check.
  int _epoch = 0;

  @override
  Stream<CardChange> get changes => _changes.stream;

  /// Whether a write that started in [epoch] should build its change: no
  /// decoding (or delete-time cache read) when nobody listens.
  bool _wants(int epoch) => epoch == _epoch && _changes.hasListener;

  void _emit(
    int epoch,
    String collectionId,
    String cardId, {
    required MorkvaObject? before,
    required MorkvaObject? after,
    required WriteOrigin origin,
    int? rev,
  }) {
    if (epoch != _epoch) return;
    _changes.add(
      CardChange(
        collectionId: collectionId,
        cardId: cardId,
        before: before,
        after: after,
        rev: rev,
        writeId: _ids.writeId(),
        origin: origin,
      ),
    );
  }

  /// [origin] with a commit id minted for this call when it carries none.
  WriteOrigin _committed(WriteOrigin origin) =>
      origin.commitId == null ? origin.withCommitId(_ids.writeId()) : origin;

  /// Last revision this client has reconciled per object id — either written by
  /// us or observed on a server snapshot. Used as the baseline for last-write-
  /// wins conflict detection.
  final Map<String, int> _localRev = {};

  /// Object ids with a local write not yet confirmed by the server.
  final Set<String> _pendingObjects = {};

  /// Live Firestore listener subscriptions feeding the watch subjects. A
  /// listener starts with its subject's first subscriber and is cancelled when
  /// the last one leaves (and on [dispose]).
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  /// Watch subjects that have listeners, closed on [dispose] so consumers
  /// receive a done event. A subject leaves this list when its last listener
  /// does (and rejoins if it is listened to again), so abandoned watches don't
  /// pile up. [BehaviorSubject]s so a late subscriber replays the latest value.
  final List<Subject<dynamic>> _subjects = [];

  /// How many Firestore listeners are live, for leak tests.
  @visibleForTesting
  int get activeListenerCount => _subscriptions.length;

  /// How many watch subjects are tracked, for leak tests.
  @visibleForTesting
  int get trackedSubjectCount => _subjects.length;

  /// A replaying stream whose Firestore listener ([listen]) runs only while
  /// the stream has subscribers, so an abandoned watch costs no listener.
  Stream<T> _watch<T>(
    StreamSubscription<dynamic> Function(BehaviorSubject<T> subject) listen,
  ) {
    StreamSubscription<dynamic>? source;
    late final BehaviorSubject<T> subject;
    subject = BehaviorSubject<T>(
      onListen: () {
        if (source != null || _workspaceId == null) return;
        _subjects.add(subject);
        final started = listen(subject);
        source = started;
        _subscriptions.add(started);
      },
      onCancel: () {
        _subjects.remove(subject);
        final running = source;
        source = null;
        if (running == null) return;
        _subscriptions.remove(running);
        unawaited(running.cancel());
      },
    );
    return subject.stream;
  }

  String get _wid {
    final id = _workspaceId;
    if (id == null) {
      throw StateError('FirestoreDataRepository used before initialize().');
    }
    return id;
  }

  @override
  Future<void> initialize(String workspaceId) async {
    _epoch++;
    _workspaceId = workspaceId;
    _localRev.clear();
    _pendingObjects.clear();
  }

  // ---------------------------------------------------------------------------
  // Collections.
  // ---------------------------------------------------------------------------

  @override
  Stream<List<Collection>> watchCollections() {
    final wid = _wid;
    return _watch<List<Collection>>(
      (subject) => _refs
          .collections(wid)
          .snapshots()
          .listen(
            (snapshot) {
              if (subject.isClosed) return;
              subject.add(snapshot.docs.map(_collectionFromDoc).toList());
            },
            onError: (Object error, StackTrace stackTrace) {
              if (!subject.isClosed) subject.addError(error, stackTrace);
            },
          ),
    );
  }

  // shortcut: pins live on the workspace doc, so a shared workspace would share
  // them; move them to a per-member doc when memberships land.
  static const _pinsField = 'pinnedCollections';

  @override
  Stream<List<String>> watchPinnedCollectionIds() {
    final wid = _wid;
    return _watch<List<String>>(
      (subject) => _refs
          .workspace(wid)
          .snapshots()
          .listen(
            (snapshot) {
              if (subject.isClosed) return;
              final raw = snapshot.data()?[_pinsField];
              subject.add(raw is List ? raw.whereType<String>().toList() : []);
            },
            onError: (Object error, StackTrace stackTrace) {
              if (!subject.isClosed) subject.addError(error, stackTrace);
            },
          ),
    );
  }

  @override
  Future<void> savePinnedCollectionIds(List<String> ids) =>
      _refs.workspace(_wid).set({_pinsField: ids}, SetOptions(merge: true));

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
  Future<void> saveViews(
    String collectionId,
    List<ViewDefinition> views,
  ) async {
    await _refs.collection(_wid, collectionId).update({
      'views': views.map((v) => v.toJson()).toList(),
    });
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
    final wid = _wid;
    Collection? resolved = schema;
    Future<Collection?>? resolving;

    // One shared lookup, so snapshots arriving meanwhile stay in order.
    Future<Collection?> ensureSchema() async {
      if (resolved != null) return resolved;
      resolved = await (resolving ??= getCollection(collectionId));
      resolving = null;
      return resolved;
    }

    // includeMetadataChanges so the metadata-only transition (hasPendingWrites
    // true→false) fires — that is what confirms our own writes and lets the
    // sync status settle to synced.
    return _watch<List<MorkvaObject>>((subject) {
      // Decoded objects by id: a snapshot decodes only its changed docs, so
      // unchanged objects keep their instances (cheap equality downstream).
      final decoded = <String, MorkvaObject>{};
      var emitted = false;
      return _refs
          .objectsByCollection(wid, collectionId)
          .snapshots(includeMetadataChanges: true)
          .listen(
            (snapshot) async {
              final collection = await ensureSchema();
              if (subject.isClosed) return;
              if (collection == null) {
                subject.add(const []);
                return;
              }
              processSnapshotMeta(snapshot);
              var changed = !emitted;
              for (final change in snapshot.docChanges) {
                final id = change.doc.id;
                final data = change.doc.data();
                if (change.type == DocumentChangeType.removed || data == null) {
                  changed = decoded.remove(id) != null || changed;
                  continue;
                }
                final object = _objectFromData(id, data, collection);
                if (decoded[id] != object) {
                  decoded[id] = object;
                  changed = true;
                }
              }
              // Metadata only (e.g. a write confirmed): same objects.
              if (!changed) return;
              emitted = true;
              final objects = [
                for (final doc in snapshot.docs)
                  decoded[doc.id] ??= _objectFromData(
                    doc.id,
                    doc.data(),
                    collection,
                  ),
              ];
              if (!subject.isClosed) subject.add(objects);
            },
            onError: (Object error, StackTrace stackTrace) {
              _syncStatus.reportError('Failed to watch objects', cause: error);
              if (!subject.isClosed) subject.addError(error, stackTrace);
            },
          );
    });
  }

  @override
  Stream<MorkvaObject?> watchObject(
    String collectionId,
    String objectId, {
    required Collection schema,
  }) {
    final wid = _wid;
    return _watch<MorkvaObject?>(
      (subject) => _refs
          .object(wid, objectId)
          .snapshots()
          .listen(
            (doc) {
              if (subject.isClosed) return;
              final data = doc.data();
              subject.add(
                data == null || data['collectionId'] != collectionId
                    ? null
                    : _objectFromData(objectId, data, schema),
              );
            },
            onError: (Object error, StackTrace stackTrace) {
              if (!subject.isClosed) subject.addError(error, stackTrace);
            },
          ),
    );
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
  Future<List<MorkvaObject>> getServerObjects(
    String collectionId, {
    required Collection schema,
  }) async {
    final snapshot = await _refs
        .objectsByCollection(_wid, collectionId)
        .get(const GetOptions(source: Source.server));
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
    WriteOrigin origin = const WriteOrigin.ui(),
  }) async {
    final epoch = _epoch;
    _syncStatus.reportPendingWrite();
    _pendingObjects.add(object.id);

    final json = object.toJson();
    final encodedValues = _encodeValues(
      (json['values'] as Map).cast<String, dynamic>(),
      schema,
    );
    final docRef = _refs.object(_wid, object.id);

    // Plain assignments: the callback may re-run on contention, and the
    // committed attempt overwrites them.
    Map<String, dynamic>? beforeDoc;
    var afterDoc = const <String, dynamic>{};
    final int newRev;
    try {
      newRev = await _db.runTransaction<int>((transaction) async {
        final snapshot = await transaction.get(docRef);
        final current = snapshot.data();
        final currentRev = (current?['rev'] as num?)?.toInt() ?? 0;
        final nextRev = currentRev + 1;
        // Merged so values this client's (possibly older) schema doesn't
        // carry survive; a present key with an empty value still clears.
        final storedValues =
            (current?['values'] as Map?)?.cast<String, dynamic>() ?? const {};
        final values = {...storedValues, ...encodedValues};
        if (current == null &&
            schema.fields.any((f) => f is AutoNumberFieldDefinition)) {
          // Numbered here so two writers never get the same one: the
          // counters live on the workspace doc, read and bumped atomically.
          final workspaceRef = _refs.workspace(_wid);
          final workspace = (await transaction.get(workspaceRef)).data();
          final counters =
              ((workspace?['counters'] as Map?)?[object.collectionId] as Map?)
                  ?.cast<String, Object?>() ??
              const {};
          final allocated = allocateSequences(schema, values, counters);
          values.addAll(allocated.assigned);
          if (allocated.counters.isNotEmpty) {
            transaction.set(workspaceRef, {
              'counters': {object.collectionId: allocated.counters},
            }, SetOptions(merge: true));
          }
        }
        final doc = {
          'collectionId': object.collectionId,
          'rev': nextRev,
          'createdAt': json['createdAt'],
          'updatedAt': json['updatedAt'],
          'values': values,
        };
        transaction.set(docRef, doc);
        beforeDoc = current;
        afterDoc = doc;
        return nextRev;
      });
      _localRev[object.id] = newRev;
      // A transaction completes only once the server committed it, so the
      // write is settled here — no open listener is needed for that.
      if (_pendingObjects.remove(object.id) && _pendingObjects.isEmpty) {
        _syncStatus.reportSnapshotMeta(
          isFromCache: false,
          hasPendingWrites: false,
        );
      }
    } catch (error) {
      _pendingObjects.remove(object.id);
      _syncStatus.reportError('Failed to save object', cause: error);
      rethrow;
    }
    if (!_wants(epoch)) return;
    _guarded(() {
      final before = switch (beforeDoc) {
        final doc? => _objectFromData(object.id, doc, schema),
        null => null,
      };
      final after = _objectFromData(object.id, afterDoc, schema);
      if (before != null && isNoOpUpdate(before, after, encodedValues.keys)) {
        return;
      }
      _emit(
        epoch,
        object.collectionId,
        object.id,
        before: before,
        after: after,
        origin: _committed(origin),
        rev: newRev,
      );
    });
  }

  /// Runs [emit] so that building a change can never fail the committed
  /// write it reports on; a failing change is reported and dropped.
  void _guarded(void Function() emit) {
    try {
      emit();
    } catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'morkva data',
          context: ErrorDescription('while emitting a card change'),
        ),
      );
    }
  }

  @override
  Future<void> deleteObject(
    String collectionId,
    String objectId, {
    MorkvaObject? before,
    WriteOrigin origin = const WriteOrigin.ui(),
  }) async {
    final epoch = _epoch;
    final wid = _wid;
    _localRev.remove(objectId);
    _pendingObjects.remove(objectId);
    // Read first: after a local delete the cache reports the doc missing.
    final stood =
        before ??
        (_wants(epoch)
            ? await _cachedObject(wid, collectionId, objectId)
            : null);
    await _refs.object(wid, objectId).delete();
    if (stood == null) return;
    _emit(
      epoch,
      collectionId,
      objectId,
      before: stood,
      after: null,
      origin: _committed(origin),
    );
  }

  /// The object [objectId] of [collectionId] as the local cache holds it,
  /// decoded against the cached schema; null when either is missing or the
  /// read fails.
  Future<MorkvaObject?> _cachedObject(
    String wid,
    String collectionId,
    String objectId,
  ) async {
    const cache = GetOptions(source: Source.cache);
    try {
      final data = (await _refs.object(wid, objectId).get(cache)).data();
      if (data == null || data['collectionId'] != collectionId) return null;
      final schema = (await _refs.collection(wid, collectionId).get(cache))
          .data();
      if (schema == null) return null;
      return _objectFromData(
        objectId,
        data,
        _collectionFromData(collectionId, schema),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<BatchResult> saveObjectsBatch(
    List<ObjectWrite> writes, {
    required Map<String, Collection> schemas,
    WriteOrigin origin = const WriteOrigin.ui(),
  }) async {
    final epoch = _epoch;
    // One commit id for every chunk of the call (the fan-out key).
    final committedOrigin = _committed(origin);
    for (final write in writes) {
      if (write is! ObjectDelete && !schemas.containsKey(write.collectionId)) {
        throw ArgumentError.value(
          write.collectionId,
          'schemas',
          'No schema for the collection of object ${write.id}',
        );
      }
    }
    if (writes.isEmpty) return const BatchResult();

    _syncStatus.reportPendingWrite();
    final written = <String>[];
    final failed = <String, String>{};
    var errored = false;
    for (var start = 0; start < writes.length; start += maxBatchWrites) {
      final chunk = writes.sublist(
        start,
        min(start + maxBatchWrites, writes.length),
      );
      final tracked = <String>[];
      for (final write in chunk) {
        if (write is ObjectDelete) {
          _localRev.remove(write.id);
          _pendingObjects.remove(write.id);
        } else {
          tracked.add(write.id);
        }
      }
      _pendingObjects.addAll(tracked);
      try {
        final committed = await _commitChunk(chunk, schemas);
        for (final write in chunk) {
          switch (write) {
            case ObjectCreate():
              _localRev[write.id] = 1;
            case ObjectUpdate():
              final rev = _localRev[write.id];
              // Unless a server snapshot already adopted the new rev.
              if (rev != null && _pendingObjects.contains(write.id)) {
                _localRev[write.id] = rev + 1;
              }
            case ObjectDelete():
          }
          written.add(write.id);
        }
        _guarded(
          () => _emitChunk(epoch, chunk, schemas, committed, committedOrigin),
        );
      } catch (error) {
        final code = error is FirebaseException ? error.code : 'unknown';
        for (final write in chunk) {
          failed[write.id] = code;
        }
        // A vanished object is an expected stale outcome the caller handles.
        if (code != 'not-found') {
          errored = true;
          _syncStatus.reportError('Failed to save objects', cause: error);
        }
      } finally {
        _pendingObjects.removeAll(tracked);
      }
    }
    // Batches complete only once the server committed them (see saveObject),
    // and a rejected chunk wrote nothing, so only an error leaves it unsettled.
    if (!errored && _pendingObjects.isEmpty) {
      _syncStatus.reportSnapshotMeta(
        isFromCache: false,
        hasPendingWrites: false,
      );
    }
    return BatchResult(written: written, failed: failed);
  }

  /// Emits a [CardChange] for each write of a committed [chunk]: creates from
  /// the documents written, updates as `before` ⊕ the written values at the
  /// batch's `now`, deletes as `before`. An update or delete without `before`
  /// emits nothing.
  void _emitChunk(
    int epoch,
    List<ObjectWrite> chunk,
    Map<String, Collection> schemas,
    _CommittedChunk committed,
    WriteOrigin origin,
  ) {
    if (!_wants(epoch)) return;
    for (final write in chunk) {
      switch (write) {
        case ObjectCreate():
          _emit(
            epoch,
            write.collectionId,
            write.id,
            before: null,
            after: _objectFromData(
              write.id,
              committed.created[write]!,
              schemas[write.collectionId]!,
            ),
            origin: origin,
          );
        case ObjectUpdate(:final before?):
          final schema = schemas[write.collectionId]!;
          final touched = _encodeValues(write.values, schema);
          final stood = before.toJson();
          final after = _objectFromData(write.id, {
            'collectionId': write.collectionId,
            'createdAt': stood['createdAt'],
            'updatedAt': committed.now,
            'values': {
              ..._encodeValues(
                (stood['values'] as Map).cast<String, dynamic>(),
                schema,
              ),
              ...touched,
            },
          }, schema);
          if (isNoOpUpdate(before, after, touched.keys)) continue;
          _emit(
            epoch,
            write.collectionId,
            write.id,
            before: before,
            after: after,
            origin: origin,
          );
        case ObjectDelete(:final before?):
          _emit(
            epoch,
            write.collectionId,
            write.id,
            before: before,
            after: null,
            origin: origin,
          );
        case ObjectUpdate() || ObjectDelete():
      }
    }
  }

  /// Commits one [chunk] of at most [maxBatchWrites] writes as a single
  /// [WriteBatch], after reserving the auto-numbers its creates lack.
  Future<_CommittedChunk> _commitChunk(
    List<ObjectWrite> chunk,
    Map<String, Collection> schemas,
  ) async {
    final wid = _wid;
    final creates = [
      for (final write in chunk)
        if (write is ObjectCreate)
          (
            write: write,
            schema: schemas[write.collectionId]!,
            values: _encodeValues(
              (write.object.toJson()['values'] as Map).cast<String, dynamic>(),
              schemas[write.collectionId]!,
            ),
          ),
    ];
    await _reserveSequences(creates);

    final createValues = {for (final c in creates) c.write: c.values};
    final now = DateTime.now().toUtc().toIso8601String();
    final created = <ObjectCreate, Map<String, dynamic>>{};
    final batch = _db.batch();
    for (final write in chunk) {
      final ref = _refs.object(wid, write.id);
      switch (write) {
        case ObjectCreate(:final object):
          batch.set(
            ref,
            created[write] = {
              'collectionId': object.collectionId,
              'rev': 1,
              'createdAt': object.createdAt.toUtc().toIso8601String(),
              'updatedAt': object.updatedAt.toUtc().toIso8601String(),
              'values': createValues[write],
            },
          );
        case ObjectUpdate(:final collectionId, :final values):
          // Only the touched keys, so concurrent edits to other fields stay.
          // FieldPath, not a dotted string, so any field id is safe.
          batch.update(ref, {
            for (final e in _encodeValues(
              values,
              schemas[collectionId]!,
            ).entries)
              FieldPath(['values', e.key]): e.value,
            'rev': FieldValue.increment(1),
            'updatedAt': now,
          });
        case ObjectDelete():
          batch.delete(ref);
      }
    }
    await batch.commit();
    return (created: created, now: now);
  }

  /// Gives the [creates] that lack an auto-number one, reserving the whole
  /// range in one transaction on the workspace counters (the same counters
  /// and [allocateSequences] semantics as [saveObject]). Runs no transaction
  /// when every number is already present.
  Future<void> _reserveSequences(
    List<({ObjectCreate write, Collection schema, Map<String, dynamic> values})>
    creates,
  ) async {
    bool lacksNumber(Collection schema, Map<String, dynamic> values) => schema
        .fields
        .whereType<AutoNumberFieldDefinition>()
        .any((f) => values[f.id] is! num);
    if (!creates.any((c) => lacksNumber(c.schema, c.values))) return;

    final workspaceRef = _refs.workspace(_wid);
    // Computed inside the transaction and applied after it, so a retried
    // transaction starts over from the fresh counters.
    final assigned = await _db.runTransaction<List<Map<String, int>>>((
      transaction,
    ) async {
      final workspace = (await transaction.get(workspaceRef)).data();
      final stored = ((workspace?['counters'] as Map?) ?? const {})
          .cast<String, Object?>();
      final running = <String, Map<String, Object?>>{};
      final result = <Map<String, int>>[];
      for (final c in creates) {
        final cid = c.write.collectionId;
        final counters = running.putIfAbsent(
          cid,
          () => {...?(stored[cid] as Map?)?.cast<String, Object?>()},
        );
        final allocated = allocateSequences(c.schema, c.values, counters);
        counters.addAll(allocated.counters);
        result.add(allocated.assigned);
      }
      // The whole counters map, read in this transaction, so the write is
      // right whether a merge is deep (Firestore) or shallow (the test fake).
      transaction.set(workspaceRef, {
        'counters': {
          ...stored,
          for (final e in running.entries)
            if (e.value.isNotEmpty) e.key: e.value,
        },
      }, SetOptions(merge: true));
      return result;
    });
    for (var i = 0; i < creates.length; i++) {
      creates[i].values.addAll(assigned[i]);
    }
  }

  @override
  Future<void> updateCollection(
    String id,
    Collection Function(Collection server) apply,
  ) async {
    final ref = _refs.collection(_wid, id);
    await _db.runTransaction<void>((transaction) async {
      final data = (await transaction.get(ref)).data();
      if (data == null) throw StateError('Collection $id does not exist.');
      final updated = apply(_collectionFromData(id, data));
      assert(updated.id == id, 'apply must keep the collection id');
      transaction.set(ref, updated.toJson());
    });
  }

  @override
  Future<void> updateViews(
    String collectionId,
    List<ViewDefinition> Function(List<ViewDefinition> server) apply,
  ) async {
    final ref = _refs.collection(_wid, collectionId);
    await _db.runTransaction<void>((transaction) async {
      final data = (await transaction.get(ref)).data();
      if (data == null) {
        throw StateError('Collection $collectionId does not exist.');
      }
      // Parsed like every other reader, so the views are reconciled.
      final server = _collectionFromData(collectionId, data);
      transaction.update(ref, {
        'views': [for (final v in apply(server.views)) v.toJson()],
      });
    });
  }

  @override
  Future<void> dispose() async {
    // Teardown fence: drop the workspace binding and rev tracking BEFORE any
    // await, so a snapshot callback or watch* call racing during teardown can
    // neither create untracked subscriptions nor touch the cubit after close.
    _epoch++;
    _workspaceId = null;
    _localRev.clear();
    _pendingObjects.clear();

    final subscriptions = List.of(_subscriptions);
    final subjects = List.of(_subjects);
    _subscriptions.clear();
    _subjects.clear();
    for (final subscription in subscriptions) {
      await subscription.cancel();
    }
    for (final subject in subjects) {
      await subject.close();
    }
  }

  /// Encodes the canonical JSON value of each schema field present in
  /// [rawValues] to its native Firestore representation. Ids not in [schema]
  /// and schema fields missing from [rawValues] are left out.
  Map<String, dynamic> _encodeValues(
    Map<String, dynamic> rawValues,
    Collection schema,
  ) {
    final encoded = <String, dynamic>{};
    for (final field in schema.fields) {
      // Derived on read, never stored.
      if (field is CalculatedFieldDefinition) continue;
      if (!rawValues.containsKey(field.id)) continue;
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

  /// The stored `rev` of [doc]; reads just that field (cheaper than
  /// `data()`, which converts the whole document on the web).
  static int _revOf(DocumentSnapshot<Map<String, dynamic>> doc) {
    try {
      return (doc.get('rev') as num?)?.toInt() ?? 0;
    } on StateError {
      return 0;
    }
  }

  /// Folds an object snapshot's per-doc revisions and metadata into the sync
  /// status, detecting last-write-wins conflicts (see spec §"Conflict
  /// algorithm").
  @visibleForTesting
  void processSnapshotMeta(QuerySnapshot<Map<String, dynamic>> snapshot) {
    final metadata = snapshot.metadata;
    // A cache snapshot (app start, offline) holds possibly stale revs: taking
    // them as the baseline made the first server snapshot after edits made
    // elsewhere look like a conflict.
    final isServer = !metadata.isFromCache && !metadata.hasPendingWrites;
    final conflicts = <String>{};

    for (final doc in snapshot.docs) {
      if (!isServer) break;
      final id = doc.id;
      final incomingRev = _revOf(doc);
      if (_pendingObjects.contains(id)) {
        // Our own write confirmed by the server.
        _pendingObjects.remove(id);
        _localRev[id] = incomingRev;
      } else if (_localRev.containsKey(id) &&
          incomingRev > _localRev[id]! + 1) {
        // We had a known baseline for this object and a remote writer advanced
        // rev past it (more than our own +1) → last-write-wins conflict.
        conflicts.add(id);
        _localRev[id] = incomingRev; // adopt new baseline so we don't re-fire.
      } else {
        // First sight, or an expected single-step advance: track the observed
        // rev as the baseline. Passive observation is never a conflict.
        _localRev[id] = incomingRev;
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
