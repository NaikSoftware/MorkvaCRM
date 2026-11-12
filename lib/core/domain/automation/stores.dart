import 'automation_record.dart';
import 'grant_record.dart';
import 'module_record.dart';
import 'run_record.dart';

/// Persistence of the automation docs of the signed-in workspace
/// (`workspaces/{wid}/…`; Firestore in `lib/api/automation`, in-memory fakes
/// in tests). Implementations bind the workspace themselves.
///
/// Every `watch` stream emits the current state to each new listener first
/// (a Firestore snapshot listener), then every change. A doc that fails its
/// record's `fromJson` is left out, never an error on the stream.
abstract interface class ModuleStore {
  Stream<List<ModuleRecord>> watch();

  Future<ModuleRecord?> get(String moduleId);

  /// Creates or replaces the doc (id = `module.id`).
  Future<void> save(ModuleRecord module);

  Future<void> delete(String moduleId);
}

abstract interface class AutomationStore {
  Stream<List<AutomationRecord>> watch();

  Future<AutomationRecord?> get(String automationId);

  /// Creates or replaces the doc.
  Future<void> save(AutomationRecord automation);

  Future<void> delete(String automationId);
}

abstract interface class RunStore {
  /// At most the [RunStore.kWindow] latest runs by `startedAt`, newest first;
  /// callers filter in memory (no composite indexes).
  Stream<List<RunRecord>> watchRecent();

  Future<RunRecord?> get(String runId);

  /// Writes a new doc at its first persisted status.
  Future<void> create(RunRecord run);

  /// Writes only [fields] (top-level keys of `run.toJson()`), as the rules
  /// allow per transition, e.g. `{'applyStartedAt'}` or
  /// `{'count', 'endedAt'}` for a coalesced row.
  Future<void> update(RunRecord run, {required Set<String> fields});

  /// Trims the runs down to [keep]: drops the oldest `succeeded` and
  /// `skipped` rows first, then the oldest of the rest (`failed`,
  /// `timed_out`, `rejected`, `expired`, `awaiting_review`), never an
  /// `applying` row (a commit is still writing it). Returns how many went.
  Future<int> prune({int keep = kWindow});

  static const int kWindow = 200;
}

/// Consents are per member: `members/{uid}/grants/{moduleId}`.
abstract interface class GrantStore {
  /// The member's consents by module id.
  Stream<Map<String, GrantRecord>> watch(String uid);

  /// The live consent, or null when absent or malformed.
  Future<GrantRecord?> get(String uid, String moduleId);

  Future<void> save(String uid, GrantRecord grant);

  Future<void> delete(String uid, String moduleId);
}

/// The four stores, built once before the harness session (D17).
final class AutomationStores {
  const AutomationStores({
    required this.modules,
    required this.automations,
    required this.runs,
    required this.grants,
  });

  final ModuleStore modules;
  final AutomationStore automations;
  final RunStore runs;
  final GrantStore grants;
}
