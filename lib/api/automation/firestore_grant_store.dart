import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:morkva_crm/core/domain/automation/automation.dart';

import 'firestore_docs.dart';

/// [GrantStore] over `workspaces/{wid}/members/{uid}/grants/{moduleId}`.
///
/// Consents are parsed with the module capability allowlist
/// ([GrantRecord.fromJson]); a malformed one reads as no consent.
final class FirestoreGrantStore implements GrantStore {
  FirestoreGrantStore(this._workspace);

  final AutomationWorkspace _workspace;

  CollectionReference<Map<String, dynamic>> _grants(String uid) =>
      _workspace.collection('members').doc(uid).collection('grants');

  @override
  Stream<Map<String, GrantRecord>> watch(String uid) =>
      _grants(uid).snapshots().map(
        (snapshot) => {
          for (final grant in readRecords(snapshot, GrantRecord.fromJson))
            grant.moduleId: grant,
        },
      );

  @override
  Future<GrantRecord?> get(String uid, String moduleId) async =>
      readRecord(await _grants(uid).doc(moduleId).get(), GrantRecord.fromJson);

  @override
  Future<void> save(String uid, GrantRecord grant) =>
      _grants(uid).doc(grant.moduleId).set(encodeDoc(grant.toJson()));

  @override
  Future<void> delete(String uid, String moduleId) =>
      _grants(uid).doc(moduleId).delete();
}
