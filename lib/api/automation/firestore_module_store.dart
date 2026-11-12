import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:morkva_crm/core/domain/automation/automation.dart';

import 'firestore_docs.dart';

/// [ModuleStore] over `workspaces/{wid}/modules/{moduleId}`.
final class FirestoreModuleStore implements ModuleStore {
  FirestoreModuleStore(this._workspace);

  final AutomationWorkspace _workspace;

  CollectionReference<Map<String, dynamic>> get _modules =>
      _workspace.collection('modules');

  @override
  Stream<List<ModuleRecord>> watch() => _modules.snapshots().map(
    (snapshot) => readRecords(snapshot, ModuleRecord.fromJson),
  );

  @override
  Future<ModuleRecord?> get(String moduleId) async =>
      readRecord(await _modules.doc(moduleId).get(), ModuleRecord.fromJson);

  @override
  Future<void> save(ModuleRecord module) =>
      _modules.doc(module.id).set(encodeDoc(module.toJson()));

  @override
  Future<void> delete(String moduleId) => _modules.doc(moduleId).delete();
}
