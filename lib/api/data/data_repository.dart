import 'package:morkva_crm/core/domain/domain.dart';

/// Persistence boundary for MorkvaCRM domain data.
///
/// Deliberately Firestore-agnostic: this contract speaks only the domain types
/// from `lib/core/domain/` so callers (blocs, UI) never touch backend types. The
/// Firestore implementation lives in `lib/api/data/` and is the only place that
/// knows about documents, snapshots, and revisions.
///
/// Object reads take the owning [Collection] `schema` so values can be decoded
/// from native backend types back into the domain's canonical representation.
abstract interface class DataRepository {
  /// Binds this repository to [workspaceId] before any reads or writes.
  Future<void> initialize(String workspaceId);

  // Collections.

  /// Streams the workspace's collections, emitting on every change.
  Stream<List<Collection>> watchCollections();

  /// Reads all collections once.
  Future<List<Collection>> getCollections();

  /// Reads a single collection by [collectionId], or `null` if missing.
  Future<Collection?> getCollection(String collectionId);

  /// Creates or updates [collection].
  Future<void> saveCollection(Collection collection);

  /// Deletes the collection identified by [collectionId].
  Future<void> deleteCollection(String collectionId);

  // Objects.

  /// Streams the objects in [collectionId], emitting on every change.
  ///
  /// [schema] is the owning collection, used to decode object values; when
  /// omitted the implementation resolves it as needed.
  Stream<List<MorkvaObject>> watchObjects(
    String collectionId, {
    Collection? schema,
  });

  /// Reads all objects in [collectionId] once, decoded against [schema].
  Future<List<MorkvaObject>> getObjects(
    String collectionId, {
    required Collection schema,
  });

  /// Reads a single object by [objectId] in [collectionId], decoded against
  /// [schema]; `null` if missing.
  Future<MorkvaObject?> getObject(
    String collectionId,
    String objectId, {
    required Collection schema,
  });

  /// Creates or updates [object], encoding its values against [schema].
  Future<void> saveObject(MorkvaObject object, {required Collection schema});

  /// Deletes the object identified by [objectId] in [collectionId].
  Future<void> deleteObject(String collectionId, String objectId);

  /// Releases resources and cancels any active subscriptions.
  Future<void> dispose();
}
