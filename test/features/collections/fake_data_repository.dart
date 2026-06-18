import 'package:morkva_crm/api/data/data_repository.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:rxdart/rxdart.dart';

/// A lightweight in-memory [DataRepository] for cubit tests.
///
/// Models the Epic 2 contract that matters to the collection feature: a
/// replaying [watchCollections] stream (a `BehaviorSubject`, like the real
/// Firestore repository) and collection CRUD that pushes the new list through
/// that stream. Object methods are stubbed since this epic never touches them.
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

  void _emit() => _subject.add(List.unmodifiable(_collections));

  @override
  Future<void> initialize(String workspaceId) async {}

  @override
  Stream<List<Collection>> watchCollections() => _subject.stream;

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
  }

  @override
  Future<void> deleteCollection(String collectionId) async {
    _collections = _collections.where((c) => c.id != collectionId).toList();
    _emit();
  }

  // Objects — unused by Epic 03; stubbed.

  @override
  Stream<List<MorkvaObject>> watchObjects(
    String collectionId, {
    Collection? schema,
  }) => const Stream.empty();

  @override
  Future<List<MorkvaObject>> getObjects(
    String collectionId, {
    required Collection schema,
  }) async => const [];

  @override
  Future<MorkvaObject?> getObject(
    String collectionId,
    String objectId, {
    required Collection schema,
  }) async => null;

  @override
  Future<void> saveObject(
    MorkvaObject object, {
    required Collection schema,
  }) async {}

  @override
  Future<void> deleteObject(String collectionId, String objectId) async {}

  @override
  Future<void> dispose() async {
    await _subject.close();
  }
}
