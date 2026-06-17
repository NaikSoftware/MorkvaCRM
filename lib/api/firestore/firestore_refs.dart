import 'package:cloud_firestore/cloud_firestore.dart';

/// Builds the Firestore document and collection references for a workspace's
/// data, centralizing the path layout in one place.
///
/// Layout (`workspaceId == uid` today, membership-ready):
/// ```
/// workspaces/{workspaceId}
/// workspaces/{workspaceId}/collections/{collectionId}
/// workspaces/{workspaceId}/objects/{objectId}
/// ```
abstract interface class FirestoreRefs {
  /// The workspace document.
  DocumentReference<Map<String, dynamic>> workspace(String workspaceId);

  /// The `collections` subcollection of [workspaceId].
  CollectionReference<Map<String, dynamic>> collections(String workspaceId);

  /// A single collection-schema document.
  DocumentReference<Map<String, dynamic>> collection(
    String workspaceId,
    String collectionId,
  );

  /// The `objects` subcollection of [workspaceId].
  CollectionReference<Map<String, dynamic>> objects(String workspaceId);

  /// A single object document.
  DocumentReference<Map<String, dynamic>> object(
    String workspaceId,
    String objectId,
  );

  /// Objects belonging to [collectionId], ordered by `updatedAt` descending.
  Query<Map<String, dynamic>> objectsByCollection(
    String workspaceId,
    String collectionId,
  );
}
