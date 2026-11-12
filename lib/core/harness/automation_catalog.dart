import '../domain/automation/automation.dart';

/// The automation docs as the harness reaches them (module ops, the
/// committer), built before the harness session; `StoreAutomationCatalog`
/// (lib/core/automation) implements it over the stores. The interface lives
/// here because the harness may not import lib/core/automation (the
/// `UiPort` pattern).
///
/// Consents are the signed-in member's: [liveConsent] and [saveConsent] use
/// the uid the implementation is bound to.
abstract interface class AutomationCatalog {
  /// The runner's test-run and diagnostics hooks, set after the runner is
  /// built (null until then, and in hosts without a runner).
  abstract RunnerHooks? hooks;

  Future<List<ModuleRecord>> listModules();

  Future<ModuleRecord?> getModule(String moduleId);

  /// The signed-in member's consent for [moduleId], or null (none, malformed
  /// or signed out).
  Future<GrantRecord?> liveConsent(String moduleId);

  Future<List<AutomationRecord>> listAutomations();

  Future<AutomationRecord?> getAutomation(String automationId);

  /// The latest runs, newest first (the run store's window).
  Future<List<RunRecord>> listRuns();

  Future<RunRecord?> getRun(String runId);

  Future<void> saveModule(ModuleRecord module);

  /// Writes [consent] for the member [uid] (the committer passes the
  /// approving user's).
  Future<void> saveConsent(String uid, GrantRecord consent);

  Future<void> saveAutomation(AutomationRecord automation);

  Future<void> deleteAutomation(String automationId);
}
