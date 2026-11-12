import '../domain/automation/automation.dart';
import '../harness/automation_catalog.dart';

/// [AutomationCatalog] over the automation stores. [uid] names the signed-in
/// member whose consents [liveConsent] reads (null when signed out).
final class StoreAutomationCatalog implements AutomationCatalog {
  StoreAutomationCatalog(this.stores, {required this.uid});

  final AutomationStores stores;
  final String? Function() uid;

  @override
  RunnerHooks? hooks;

  // The stores have no one-shot list; a watch emits the current docs first.
  @override
  Future<List<ModuleRecord>> listModules() => stores.modules.watch().first;

  @override
  Future<ModuleRecord?> getModule(String moduleId) =>
      stores.modules.get(moduleId);

  @override
  Future<GrantRecord?> liveConsent(String moduleId) async {
    final member = uid();
    return member == null ? null : stores.grants.get(member, moduleId);
  }

  @override
  Future<List<AutomationRecord>> listAutomations() =>
      stores.automations.watch().first;

  @override
  Future<AutomationRecord?> getAutomation(String automationId) =>
      stores.automations.get(automationId);

  @override
  Future<List<RunRecord>> listRuns() => stores.runs.watchRecent().first;

  @override
  Future<RunRecord?> getRun(String runId) => stores.runs.get(runId);

  @override
  Future<void> saveModule(ModuleRecord module) => stores.modules.save(module);

  @override
  Future<void> saveConsent(String uid, GrantRecord consent) =>
      stores.grants.save(uid, consent);

  @override
  Future<void> saveAutomation(AutomationRecord automation) =>
      stores.automations.save(automation);

  @override
  Future<void> deleteAutomation(String automationId) =>
      stores.automations.delete(automationId);
}
