import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:morkva_crm/core/domain/automation/automation.dart';

import 'firestore_docs.dart';

/// [AutomationStore] over `workspaces/{wid}/automations/{automationId}`,
/// listened to whole (no index).
final class FirestoreAutomationStore implements AutomationStore {
  FirestoreAutomationStore(this._workspace);

  final AutomationWorkspace _workspace;

  CollectionReference<Map<String, dynamic>> get _automations =>
      _workspace.collection('automations');

  @override
  Stream<List<AutomationRecord>> watch() => _automations.snapshots().map(
    (snapshot) => readRecords(snapshot, AutomationRecord.fromJson),
  );

  @override
  Future<AutomationRecord?> get(String automationId) async => readRecord(
    await _automations.doc(automationId).get(),
    AutomationRecord.fromJson,
  );

  @override
  Future<void> save(AutomationRecord automation) =>
      _automations.doc(automation.id).set(encodeDoc(automation.toJson()));

  @override
  Future<void> delete(String automationId) =>
      _automations.doc(automationId).delete();
}
