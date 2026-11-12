import 'dart:async';
import 'dart:math' show min;

import 'package:morkva_crm/api/data/data_repository.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/core/domain/ids.dart';
import 'package:rxdart/rxdart.dart';

/// A lightweight in-memory [DataRepository] for cubit tests.
///
/// Models the Epic 2 contract that matters to the collection feature: a
/// replaying [watchCollections] stream (a `BehaviorSubject`, like the real
/// Firestore repository) and collection CRUD that pushes the new list through
/// that stream. Objects live in per-collection replaying subjects too.
///
/// Seeds the stream with an initial (possibly empty) list so subscribers get an
/// immediate snapshot, exercising the cubits' empty-initial-list tolerance.
class FakeDataRepository implements DataRepository {
  FakeDataRepository([List<Collection> initial = const []]) {
    _collections = [...initial];
    _subject = BehaviorSubject<List<Collection>>.seeded(
      List.unmodifiable(_collections),
    );
  }

  late List<Collection> _collections;
  late final BehaviorSubject<List<Collection>> _subject;

  /// Set to a non-null factory to make the next [saveCollection] throw.
  Object Function()? saveError;

  /// Last auto-number handed out, by collection id then field id.
  final Map<String, Map<String, Object?>> sequenceCounters = {};

  /// Count of [saveCollection] calls, for assertions.
  int saveCount = 0;

  /// Count of [saveViews] calls, for assertions.
  int saveViewsCount = 0;

  /// When set, collection writes apply (and emit) at once but only complete
  /// once this completes — like Firestore while offline.
  Completer<void>? collectionAck;

  void _emit() => _subject.add(List.unmodifiable(_collections));

  @override
  Future<void> initialize(String workspaceId) async {}

  @override
  Stream<List<Collection>> watchCollections() => _counted(_subject.stream);

  /// The pinned collection ids, replayed like the real repository.
  final pinnedIds = BehaviorSubject<List<String>>.seeded(const []);

  @override
  Stream<List<String>> watchPinnedCollectionIds() => pinnedIds.stream;

  @override
  Future<void> savePinnedCollectionIds(List<String> ids) async =>
      pinnedIds.add(List.unmodifiable(ids));

  @override
  Future<List<Collection>> getCollections() async =>
      List.unmodifiable(_collections);

  @override
  Future<Collection?> getCollection(String collectionId) async {
    for (final c in _collections) {
      if (c.id == collectionId) return c;
    }
    return null;
  }

  @override
  Future<void> saveCollection(Collection collection) async {
    saveCount++;
    final error = saveError;
    if (error != null) throw error();
    final index = _collections.indexWhere((c) => c.id == collection.id);
    if (index < 0) {
      _collections = [..._collections, collection];
    } else {
      _collections = [..._collections]..[index] = collection;
    }
    _emit();
    await collectionAck?.future;
  }

  @override
  Future<void> saveViews(
    String collectionId,
    List<ViewDefinition> views,
  ) async {
    saveViewsCount++;
    final error = saveError;
    if (error != null) throw error();
    final index = _collections.indexWhere((c) => c.id == collectionId);
    if (index < 0) throw StateError('No collection $collectionId');
    _collections = [..._collections]
      ..[index] = _collections[index].copyWith(views: views);
    _emit();
    await collectionAck?.future;
  }

  @override
  Future<void> deleteCollection(String collectionId) async {
    _collections = _collections.where((c) => c.id != collectionId).toList();
    _emit();
  }

  // Objects: one replaying subject per collection, seeded with [objects].

  final Map<String, List<MorkvaObject>> _objects = {};
  final Map<String, BehaviorSubject<List<MorkvaObject>>> _objectSubjects = {};

  /// Object ids [watchObjects] leaves out while the reads still return them
  /// — a client cache that lags the server.
  final Set<String> hiddenFromWatch = {};

  /// Count of [watchObjects] calls per collection id, for assertions.
  final Map<String, int> watchObjectsCalls = {};

  /// Subscriptions currently open on any watch stream, for leak tests.
  int liveListeners = 0;

  Stream<T> _counted<T>(Stream<T> stream) => stream
      .doOnListen(() => liveListeners++)
      .doOnCancel(() => liveListeners--);

  /// Set to a non-null factory to make the next [saveObject] /
  /// [deleteObject] throw (cleared after one use).
  Object Function()? objectWriteError;

  /// Seeds (or replaces) the objects of [collectionId] and emits them.
  void seedObjects(String collectionId, List<MorkvaObject> objects) {
    _objects[collectionId] = [...objects];
    _emitObjects(collectionId);
  }

  /// The stored objects of [collectionId].
  List<MorkvaObject> objectsOf(String collectionId) =>
      List.unmodifiable(_objects[collectionId] ?? const []);

  /// Emits an error on the objects stream of [collectionId].
  void failObjects(String collectionId, Object error) =>
      _subjectFor(collectionId).addError(error);

  BehaviorSubject<List<MorkvaObject>> _subjectFor(String collectionId) =>
      _objectSubjects.putIfAbsent(
        collectionId,
        () => BehaviorSubject.seeded(
          List.unmodifiable(_objects[collectionId] ?? const []),
        ),
      );

  void _emitObjects(String collectionId) => _subjectFor(
    collectionId,
  ).add(List.unmodifiable(_objects[collectionId] ?? const []));

  void _throwIfWriteFails() {
    final error = objectWriteError;
    if (error == null) return;
    objectWriteError = null;
    throw error();
  }

  @override
  Stream<List<MorkvaObject>> watchObjects(
    String collectionId, {
    Collection? schema,
  }) {
    watchObjectsCalls.update(collectionId, (n) => n + 1, ifAbsent: () => 1);
    final stream = _subjectFor(collectionId).stream.map(
      (objects) => [
        for (final o in objects)
          if (!hiddenFromWatch.contains(o.id)) o,
      ],
    );
    // Decoded against [schema] like the real repository: values of fields
    // the schema lacks are dropped, missing ones come back empty.
    return _counted(
      schema == null
          ? stream
          : stream.map(
              (objects) => [for (final o in objects) _decoded(o, schema)],
            ),
    );
  }

  /// [o] as decoded against [schema]: values of fields the schema lacks are
  /// dropped, missing ones come back empty.
  static MorkvaObject _decoded(MorkvaObject o, Collection schema) => o.copyWith(
    values: {
      for (final f in schema.fields) f.id: o.values[f.id] ?? f.emptyValue(),
    },
  );

  /// Count of [watchObject] calls per object id, for assertions.
  final Map<String, int> watchObjectCalls = {};

  @override
  Stream<MorkvaObject?> watchObject(
    String collectionId,
    String objectId, {
    required Collection schema,
  }) {
    watchObjectCalls.update(objectId, (n) => n + 1, ifAbsent: () => 1);
    return _counted(
      _subjectFor(collectionId).stream
          .map((objects) => objects.where((o) => o.id == objectId).firstOrNull)
          .map((o) => o == null ? null : _decoded(o, schema))
          .distinct(),
    );
  }

  @override
  Future<List<MorkvaObject>> getObjects(
    String collectionId, {
    required Collection schema,
  }) async => objectsOf(collectionId);

  /// When non-null, [getServerObjects] throws it — like a server read
  /// while the server is unreachable.
  Object? serverReadError;

  @override
  Future<List<MorkvaObject>> getServerObjects(
    String collectionId, {
    required Collection schema,
  }) async {
    if (serverReadError case final e?) throw e;
    return objectsOf(collectionId);
  }

  @override
  Future<MorkvaObject?> getObject(
    String collectionId,
    String objectId, {
    required Collection schema,
  }) async =>
      objectsOf(collectionId).where((o) => o.id == objectId).firstOrNull;

  final _changes = StreamController<CardChange>.broadcast();
  final _ids = IdGenerator();

  /// Every card write, like the real repository: after it applied, never for
  /// a failed write, nothing for an update that changed no value.
  @override
  Stream<CardChange> get changes => _changes.stream;

  void _emitChange(
    String collectionId,
    String cardId,
    MorkvaObject? before,
    MorkvaObject? after,
    WriteOrigin origin,
  ) => _changes.add(
    CardChange(
      collectionId: collectionId,
      cardId: cardId,
      before: before,
      after: after,
      writeId: _ids.writeId(),
      origin: origin,
    ),
  );

  WriteOrigin _committed(WriteOrigin origin) =>
      origin.commitId == null ? origin.withCommitId(_ids.writeId()) : origin;

  /// The field ids of [values] a write stores (calculated and unknown ids
  /// are skipped, like the real encoder).
  static Iterable<String> _stored(Iterable<String> ids, Collection schema) =>
      ids.where(
        (id) => switch (schema.fieldById(id)) {
          null || CalculatedFieldDefinition() => false,
          _ => true,
        },
      );

  @override
  Future<void> saveObject(
    MorkvaObject object, {
    required Collection schema,
    WriteOrigin origin = const WriteOrigin.ui(),
  }) async {
    _throwIfWriteFails();
    final list = [...?_objects[object.collectionId]];
    final index = list.indexWhere((o) => o.id == object.id);
    final before = index < 0 ? null : list[index];
    if (before == null) {
      list.add(_numbered(object, schema));
    } else {
      // Merged over the stored values, like the real repository.
      list[index] = object.copyWith(
        values: {...before.values, ...object.values},
      );
    }
    _objects[object.collectionId] = list;
    _emitObjects(object.collectionId);
    final after = before == null ? list.last : list[index];
    if (before != null &&
        isNoOpUpdate(before, after, _stored(object.values.keys, schema))) {
      return;
    }
    _emitChange(
      object.collectionId,
      object.id,
      before,
      after,
      _committed(origin),
    );
  }

  /// [object] with numbers for the auto-number fields it lacks, from
  /// [sequenceCounters] — like the real repository's counter transaction.
  MorkvaObject _numbered(MorkvaObject object, Collection schema) {
    final counters = sequenceCounters[object.collectionId] ??= {};
    final allocated = allocateSequences(schema, {
      for (final e in object.values.entries) e.key: e.value.toJson(),
    }, counters);
    counters.addAll(allocated.counters);
    return object.copyWith(
      values: {
        ...object.values,
        for (final e in allocated.assigned.entries)
          e.key: AutoNumberFieldValue(e.value),
      },
    );
  }

  @override
  Future<void> deleteObject(
    String collectionId,
    String objectId, {
    MorkvaObject? before,
    WriteOrigin origin = const WriteOrigin.ui(),
  }) async {
    _throwIfWriteFails();
    final stood =
        before ??
        _objects[collectionId]?.where((o) => o.id == objectId).firstOrNull;
    _objects[collectionId] = [
      ...?_objects[collectionId]?.where((o) => o.id != objectId),
    ];
    _emitObjects(collectionId);
    if (stood != null) {
      _emitChange(collectionId, objectId, stood, null, _committed(origin));
    }
  }

  /// Count of [saveObjectsBatch] calls, for assertions.
  int batchCalls = 0;

  /// Called with each [saveObjectsBatch] chunk before it applies; a non-null
  /// return is the error code every id of that chunk fails with, and nothing
  /// of the chunk is written (batches are atomic).
  String? Function(List<ObjectWrite> chunk)? batchWriteError;

  /// When true, [saveObjectsBatch] applies its first chunk (and emits) but
  /// never completes — like a batch waiting for a server ack while offline.
  bool batchNeverCompletes = false;

  /// When true, [saveObjectsBatch] never completes and writes nothing for a
  /// chunk with creates — like an auto-number reservation transaction that
  /// cannot reach the server.
  bool reservationNeverCompletes = false;

  @override
  Future<BatchResult> saveObjectsBatch(
    List<ObjectWrite> writes, {
    required Map<String, Collection> schemas,
    WriteOrigin origin = const WriteOrigin.ui(),
  }) async {
    batchCalls++;
    final committedOrigin = _committed(origin);
    for (final write in writes) {
      if (write is! ObjectDelete && !schemas.containsKey(write.collectionId)) {
        throw ArgumentError.value(write.collectionId, 'schemas');
      }
    }
    final written = <String>[];
    final failed = <String, String>{};
    for (var start = 0; start < writes.length; start += maxBatchWrites) {
      final chunk = writes.sublist(
        start,
        min(start + maxBatchWrites, writes.length),
      );
      // Like Firestore: updating a missing object fails its whole batch.
      final code =
          batchWriteError?.call(chunk) ??
          (chunk.any((w) => w is ObjectUpdate && !_exists(w))
              ? 'not-found'
              : null);
      if (code != null) {
        for (final write in chunk) {
          failed[write.id] = code;
        }
        continue;
      }
      if (reservationNeverCompletes && chunk.any((w) => w is ObjectCreate)) {
        await Completer<void>().future;
      }
      final touched = <String>{};
      final now = DateTime.now().toUtc();
      final changes = <CardChange>[];
      for (final write in chunk) {
        final cid = write.collectionId;
        final rest = [...?_objects[cid]?.where((o) => o.id != write.id)];
        _objects[cid] = switch (write) {
          ObjectCreate(:final object) => [
            ...rest,
            _numbered(object, schemas[cid]!),
          ],
          ObjectUpdate() => [
            for (final o in _objects[cid]!)
              o.id == write.id ? _updated(o, write, schemas[cid]!, now) : o,
          ],
          ObjectDelete() => rest,
        };
        touched.add(cid);
        written.add(write.id);
        // Like the real repository: `before` only from the write itself.
        final (before, after) = switch (write) {
          ObjectCreate() => (null, _objects[cid]!.last),
          ObjectUpdate(:final before?) => (
            before,
            _updated(before, write, schemas[cid]!, now),
          ),
          ObjectDelete(:final before?) => (before, null),
          ObjectUpdate() || ObjectDelete() => (null, null),
        };
        if (before == null && after == null) continue;
        if (before != null &&
            after != null &&
            write is ObjectUpdate &&
            isNoOpUpdate(
              before,
              after,
              _stored(write.values.keys, schemas[cid]!),
            )) {
          continue;
        }
        changes.add(
          CardChange(
            collectionId: cid,
            cardId: write.id,
            before: before,
            after: after,
            writeId: _ids.writeId(),
            origin: committedOrigin,
          ),
        );
      }
      touched.forEach(_emitObjects);
      changes.forEach(_changes.add);
      if (batchNeverCompletes) await Completer<void>().future;
    }
    return BatchResult(written: written, failed: failed);
  }

  bool _exists(ObjectWrite write) =>
      _objects[write.collectionId]?.any((o) => o.id == write.id) ?? false;

  /// [object] with the touched values of [update] (domain JSON) decoded over
  /// it; calculated and unknown field ids are skipped like the real encoder.
  static MorkvaObject _updated(
    MorkvaObject object,
    ObjectUpdate update,
    Collection schema,
    DateTime now,
  ) => object.copyWith(
    values: {
      ...object.values,
      for (final e in update.values.entries)
        if (schema.fieldById(e.key) case final field?
            when field is! CalculatedFieldDefinition)
          e.key: field.valueFromJson(e.value),
    },
    updatedAt: now,
  );

  /// Applies [apply] to the stored collection through [saveCollection], so
  /// it counts in [saveCount] and honours [saveError] / [collectionAck].
  @override
  Future<void> updateCollection(
    String id,
    Collection Function(Collection server) apply,
  ) async {
    final server = await getCollection(id);
    if (server == null) throw StateError('Collection $id does not exist.');
    await saveCollection(apply(server));
  }

  /// Applies [apply] to the stored views through [saveViews], so it counts
  /// in [saveViewsCount] and honours [saveError] / [collectionAck].
  @override
  Future<void> updateViews(
    String collectionId,
    List<ViewDefinition> Function(List<ViewDefinition> server) apply,
  ) async {
    final server = await getCollection(collectionId);
    if (server == null) {
      throw StateError('Collection $collectionId does not exist.');
    }
    await saveViews(collectionId, apply(server.views));
  }

  @override
  Future<void> dispose() async {
    await _changes.close();
    await _subject.close();
    for (final subject in _objectSubjects.values) {
      await subject.close();
    }
  }
}
