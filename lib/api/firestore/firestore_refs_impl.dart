import 'package:cloud_firestore/cloud_firestore.dart';

import 'firestore_refs.dart';

/// Concrete [FirestoreRefs] backed by a [FirebaseFirestore] instance.
///
/// Centralizes the workspace-scoped path layout so the rest of the data layer
/// never builds raw document paths:
/// ```
/// workspaces/{workspaceId}
/// workspaces/{workspaceId}/collections/{collectionId}
/// workspaces/{workspaceId}/objects/{objectId}
/// ```
class FirestoreRefsImpl implements FirestoreRefs {
  /// Creates refs against [firestore] (defaults to [FirebaseFirestore.instance]).
  FirestoreRefsImpl([FirebaseFirestore? firestore])
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const String _workspaces = 'workspaces';
  static const String _collections = 'collections';
  static const String _objects = 'objects';

  /// JSON field carrying the owning collection id on each object document.
  static const String fieldCollectionId = 'collectionId';

  /// JSON field carrying the last-updated timestamp (ISO-8601 string) used for
  /// ordering object queries.
  static const String fieldUpdatedAt = 'updatedAt';

  @override
  DocumentReference<Map<String, dynamic>> workspace(String workspaceId) =>
      _db.collection(_workspaces).doc(workspaceId);

  @override
  CollectionReference<Map<String, dynamic>> collections(String workspaceId) =>
      workspace(workspaceId).collection(_collections);

  @override
  DocumentReference<Map<String, dynamic>> collection(
    String workspaceId,
    String collectionId,
  ) => collections(workspaceId).doc(collectionId);

  @override
  CollectionReference<Map<String, dynamic>> objects(String workspaceId) =>
      workspace(workspaceId).collection(_objects);

  @override
  DocumentReference<Map<String, dynamic>> object(
    String workspaceId,
    String objectId,
  ) => objects(workspaceId).doc(objectId);

  @override
  Query<Map<String, dynamic>> objectsByCollection(
    String workspaceId,
    String collectionId,
  ) => objects(workspaceId)
      .where(fieldCollectionId, isEqualTo: collectionId)
      .orderBy(fieldUpdatedAt, descending: true);
}
