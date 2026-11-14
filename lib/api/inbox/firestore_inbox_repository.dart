import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/domain/inbox/inbox_item.dart';
import '../automation/firestore_docs.dart';
import 'inbox_repository.dart';

/// [InboxRepository] over `workspaces/{wid}/inbox/{itemId}`, listening to
/// the items assigned to the member (single-field query, no index).
final class FirestoreInboxRepository implements InboxRepository {
  FirestoreInboxRepository({
    required FirebaseFirestore firestore,
    DateTime Function() now = DateTime.now,
  }) : _db = firestore,
       _now = now;

  final FirebaseFirestore _db;
  final DateTime Function() _now;
  CollectionReference<Map<String, dynamic>>? _items;
  String? _uid;

  CollectionReference<Map<String, dynamic>> get _col =>
      _items ?? (throw StateError('InboxRepository used before initialize().'));

  @override
  void initialize({required String workspaceId, required String uid}) {
    _items = _db.collection('workspaces').doc(workspaceId).collection('inbox');
    _uid = uid;
  }

  @override
  Stream<({List<InboxItem> items, bool fromCache})> watch() => _col
      .where('assigneeUid', isEqualTo: _uid)
      // Metadata changes too: a server confirming the cached items
      // unchanged emits nothing otherwise, and fromCache would stay true.
      .snapshots(includeMetadataChanges: true)
      .map(
        (snapshot) => (
          items: readRecords(snapshot, InboxItem.fromJson),
          fromCache: snapshot.metadata.isFromCache,
        ),
      );

  @override
  String newId() => _col.doc().id;

  @override
  Future<void> create(InboxItem item) =>
      _col.doc(item.id).set(encodeDoc(item.toJson()));

  @override
  Future<void> update(String id, Map<String, Object?> fields) =>
      _col.doc(id).update(encodeDoc({...fields, 'updatedAt': _now().toUtc()}));

  @override
  Future<void> delete(String id) => _col.doc(id).delete();
}
