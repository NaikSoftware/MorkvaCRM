import 'dart:async';

import 'package:morkva_crm/api/data/data_repository.dart';
import 'package:morkva_crm/core/domain/domain.dart';
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
    final stream = _subjectFor(collectionId).stream;
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

  @override
  Future<MorkvaObject?> getObject(
    String collectionId,
    String objectId, {
    required Collection schema,
  }) async =>
      objectsOf(collectionId).where((o) => o.id == objectId).firstOrNull;

  @override
  Future<void> saveObject(
    MorkvaObject object, {
    required Collection schema,
  }) async {
    _throwIfWriteFails();
    final list = [...?_objects[object.collectionId]];
    final index = list.indexWhere((o) => o.id == object.id);
    if (index < 0) {
      list.add(object);
    } else {
      // Merged over the stored values, like the real repository.
      list[index] = object.copyWith(
        values: {...list[index].values, ...object.values},
      );
    }
    _objects[object.collectionId] = list;
    _emitObjects(object.collectionId);
  }

  @override
  Future<void> deleteObject(String collectionId, String objectId) async {
    _throwIfWriteFails();
    _objects[collectionId] = [
      ...?_objects[collectionId]?.where((o) => o.id != objectId),
    ];
    _emitObjects(collectionId);
  }

  @override
  Future<void> dispose() async {
    await _subject.close();
    for (final subject in _objectSubjects.values) {
      await subject.close();
    }
  }
}
