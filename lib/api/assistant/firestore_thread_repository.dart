import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/data_repository.dart' show maxBatchWrites;
import 'thread_repository.dart';

/// Cloud Firestore [ThreadRepository]. Writes go through Firestore's offline
/// queue; their futures resolve on server ack, so callers observe rather than
/// await them.
class FirestoreThreadRepository implements ThreadRepository {
  FirestoreThreadRepository({required FirebaseFirestore firestore})
    : _db = firestore;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>>? _threadsRef;

  @override
  void initialize({required String workspaceId, required String uid}) {
    _threadsRef = _db
        .collection('workspaces')
        .doc(workspaceId)
        .collection('members')
        .doc(uid)
        .collection('assistantThreads');
  }

  CollectionReference<Map<String, dynamic>> get _threads =>
      _threadsRef ??
      (throw StateError('FirestoreThreadRepository used before initialize().'));

  CollectionReference<Map<String, dynamic>> _messages(String threadId) =>
      _threads.doc(threadId).collection('messages');

  @override
  String newThreadId() => _threads.doc().id;

  @override
  Stream<List<AssistantRecord>> watchThreads({int limit = kThreadListLimit}) =>
      _threads
          .orderBy('updatedAt', descending: true)
          .limit(limit)
          .snapshots()
          .map(
            (snapshot) => [
              for (final doc in snapshot.docs) {...doc.data(), 'id': doc.id},
            ],
          );

  @override
  Future<List<AssistantRecord>> loadMessages(String threadId) async {
    final snapshot = await _messages(threadId).orderBy('seq').get();
    return [for (final doc in snapshot.docs) doc.data()];
  }

  @override
  Future<void> checkpoint(
    String threadId, {
    required int seq,
    required AssistantRecord message,
    AssistantRecord? thread,
  }) {
    final batch = _db.batch()
      ..set(_messages(threadId).doc(messageDocId(seq)), {
        ...message,
        'seq': seq,
      });
    if (thread != null) {
      batch.set(_threads.doc(threadId), thread, SetOptions(merge: true));
    }
    return batch.commit();
  }

  @override
  Future<void> dropJournal(String threadId, int seq) => _messages(
    threadId,
  ).doc(messageDocId(seq)).update({'journal': FieldValue.delete()});

  @override
  Future<void> deleteThread(String threadId) async {
    // shortcut: offline, get() sees only cached turn docs, so uncached ones
    // outlive the (deleted, unlisted) thread; add a server-side sweep if a
    // backend function ever exists.
    final docs = (await _messages(threadId).get()).docs;
    final refs = [
      for (final doc in docs) doc.reference,
      _threads.doc(threadId),
    ];
    // The thread doc goes last, so a failed chunk leaves it listed.
    for (var start = 0; start < refs.length; start += maxBatchWrites) {
      final batch = _db.batch();
      for (final ref in refs.skip(start).take(maxBatchWrites)) {
        batch.delete(ref);
      }
      await batch.commit();
    }
  }
}
