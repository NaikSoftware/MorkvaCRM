import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rxdart/rxdart.dart';

import '../../../core/automation/runner_api.dart';
import '../../../core/domain/automation/automation.dart';
import '../widgets/reason_copy.dart';

/// One installed module as the Automations page shows it.
final class ModuleEntry extends Equatable {
  const ModuleEntry({
    required this.module,
    required this.consent,
    required this.automations,
  });

  final ModuleRecord module;

  /// The signed-in member's consent (null: none, or malformed).
  final GrantRecord? consent;

  /// How many automations use it ("2 automations").
  final int automations;

  ModuleStatus get status => moduleStatusOf(module, consent);

  /// The capabilities shown: the consent's once given, else what the
  /// manifest will ask for ("Will ask for: …").
  List<String> get caps =>
      consent?.caps ?? module.manifest?.capabilities ?? const [];

  @override
  List<Object?> get props => [module, consent, automations];
}

/// One automation with what its row needs from its module and consent.
final class AutomationEntry extends Equatable {
  const AutomationEntry({
    required this.automation,
    required this.module,
    required this.status,
    required this.apply,
  });

  final AutomationRecord automation;

  /// Null when the module is gone (the automation is broken).
  final ModuleEntry? module;
  final AutomationStatus status;
  final EffectiveApply apply;

  ActionSpec? get action =>
      module?.module.manifest?.action(automation.actionId);

  @override
  List<Object?> get props => [automation, module, status, apply];
}

/// Joins the three store snapshots into entries (shared by every cubit that
/// lists modules or automations).
({List<ModuleEntry> modules, List<AutomationEntry> automations}) joinEntries(
  List<ModuleRecord> modules,
  List<AutomationRecord> automations,
  Map<String, GrantRecord> consents, {
  required String uid,
}) {
  final counts = <String, int>{};
  for (final a in automations) {
    counts[a.moduleId] = (counts[a.moduleId] ?? 0) + 1;
  }
  final moduleEntries = [
    for (final m in [...modules]..sort((a, b) => a.name.compareTo(b.name)))
      ModuleEntry(
        module: m,
        consent: consents[m.id],
        automations: counts[m.id] ?? 0,
      ),
  ];
  final byId = {for (final m in moduleEntries) m.module.id: m};
  return (
    modules: moduleEntries,
    automations: [
      for (final a in [
        ...automations,
      ]..sort((a, b) => a.name.compareTo(b.name)))
        AutomationEntry(
          automation: a,
          module: byId[a.moduleId],
          status: automationStatusOf(a, byId[a.moduleId]?.status),
          apply: effectiveApplyOf(
            a,
            byId[a.moduleId]?.consent,
            uid: uid,
            module: byId[a.moduleId]?.status,
          ),
        ),
    ],
  );
}

/// The consent sheet's "Where": nothing chosen yet (Allow disabled), all
/// collections, or only some. Distinct from `null` = all collections.
final class ConsentScope extends Equatable {
  const ConsentScope.all() : all = true, only = const {};

  const ConsentScope.only(this.only) : all = false;

  /// An import preselects nothing: "Only these" with the collection the
  /// user came from checked, if any. An update of an installed module
  /// ([replacing] its consent) starts from what that consent allows.
  factory ConsentScope.forImport({
    String? fromCollection,
    GrantRecord? replacing,
  }) => replacing != null
      ? ConsentScope.of(replacing)
      : ConsentScope.only({?fromCollection});

  /// What an existing consent allows (Change access, re-consent).
  factory ConsentScope.of(GrantRecord consent) => switch (consent.collections) {
    null => const ConsentScope.all(),
    final ids => ConsentScope.only(ids.toSet()),
  };

  final bool all;
  final Set<String> only;

  bool get chosen => all || only.isNotEmpty;

  /// The runner's `collections` (null = all); only once [chosen].
  List<String>? get collections {
    if (!chosen) throw StateError('No collection scope chosen');
    return all ? null : (only.toList()..sort());
  }

  ConsentScope toggle(String collectionId) => ConsentScope.only(
    only.contains(collectionId)
        ? ({...only}..remove(collectionId))
        : {...only, collectionId},
  );

  @override
  List<Object?> get props => [all, only];
}

/// How a capability row reads in the consent sheet.
enum CapChange { kept, added, removed }

/// The consent sheet's content for [bundle]: the capability rows (with the
/// diff against [previous] on a re-consent) and the version / size line.
final class ConsentView extends Equatable {
  const ConsentView({required this.bundle, required this.caps, this.previous});

  final ModuleBundle bundle;
  final List<({String cap, String title, String explanation, CapChange change})>
  caps;

  /// The consent this one replaces (re-consent).
  final GrantRecord? previous;

  bool get reconsent => previous != null;

  /// The bundle differs from the one consented to (a re-import of the same
  /// file doesn't).
  bool get codeChanged =>
      previous != null &&
      previous!.codeHash != bundleHashOf(bundle.manifestJson, bundle.code);

  /// "v1.0.0 → v1.1.0" and "2.1 KB → 2.4 KB" come from these.
  String? get fromVersion => previous?.version;
  int? get fromBytes => previous?.codeBytes;

  /// "Auto-apply turns off for the new version."
  bool get autoApplyTurnsOff => previous?.autoApply ?? false;

  @override
  List<Object?> get props => [bundle.manifestJson, bundle.code, caps, previous];
}

ConsentView consentViewOf(ModuleBundle bundle, GrantRecord? previous) {
  final asked = bundle.manifest.capabilities;
  final had = previous?.caps;
  return ConsentView(
    bundle: bundle,
    previous: previous,
    caps: [
      // kCapabilityCopy order, so the sheet and the details page agree.
      for (final MapEntry(key: cap, value: copy) in kCapabilityCopy.entries)
        if (asked.contains(cap) || (had?.contains(cap) ?? false))
          (
            cap: cap,
            title: copy.title,
            explanation: copy.explanation,
            change: had == null || (asked.contains(cap) && had.contains(cap))
                ? CapChange.kept
                : asked.contains(cap)
                ? CapChange.added
                : CapChange.removed,
          ),
    ],
  );
}

/// The import sheet's verdict on a file: the bundle to consent to, or the
/// problems ("path — message"); [replacing] when a module with its id is
/// installed ("Allowing replaces it with v1.1.0 for its 2 automations").
final class ImportPreview extends Equatable {
  const ImportPreview.problems(this.problems) : bundle = null, replacing = null;

  const ImportPreview.ok(ModuleBundle this.bundle, {this.replacing})
    : problems = const [];

  final ModuleBundle? bundle;
  final List<AutomationProblem> problems;
  final ModuleEntry? replacing;

  @override
  List<Object?> get props => [
    bundle?.manifestJson,
    bundle?.code,
    problems,
    replacing,
  ];
}

final class ModulesState extends Equatable {
  const ModulesState({
    this.loading = true,
    this.modules = const [],
    this.automations = const [],
    this.loadFailed = false,
    this.error,
  });

  final bool loading;
  final List<ModuleEntry> modules;
  final List<AutomationEntry> automations;

  /// The stores couldn't be read (denied, or the listener died): the tabs
  /// show "Couldn't load" + Retry.
  final bool loadFailed;

  /// The last refused action, shown as is.
  final String? error;

  /// Every automation of [collectionId] (the `collection` query, the
  /// collection's Actions menu).
  List<AutomationEntry> automationsIn(String collectionId) => [
    for (final a in automations)
      if (a.automation.trigger.collectionId == collectionId) a,
  ];

  ModulesState copyWith({
    bool? loading,
    List<ModuleEntry>? modules,
    List<AutomationEntry>? automations,
    bool? loadFailed,
    String? Function()? error,
  }) => ModulesState(
    loading: loading ?? this.loading,
    modules: modules ?? this.modules,
    automations: automations ?? this.automations,
    loadFailed: loadFailed ?? this.loadFailed,
    error: error == null ? this.error : error(),
  );

  @override
  List<Object?> get props => [loading, modules, automations, loadFailed, error];
}

/// The Modules and Automations tabs: installed modules and automations with
/// their computed status, the automation switch, Resume and import.
class ModulesCubit extends Cubit<ModulesState> {
  ModulesCubit(
    this._runner,
    this._stores, {
    required String uid,
    DateTime Function() now = DateTime.now,
  }) : _uid = uid,
       _now = now,
       super(const ModulesState()) {
    _listen();
  }

  final AutomationRunnerApi _runner;
  final AutomationStores _stores;
  final String _uid;
  final DateTime Function() _now;
  StreamSubscription<Object?>? _sub;

  void _listen() {
    _sub =
        Rx.combineLatest3(
          _stores.modules.watch(),
          _stores.automations.watch(),
          _stores.grants.watch(_uid),
          (m, a, g) => joinEntries(m, a, g, uid: _uid),
        ).listen(
          (e) => emit(
            state.copyWith(
              loading: false,
              loadFailed: false,
              modules: e.modules,
              automations: e.automations,
            ),
          ),
          onError: (Object _) =>
              emit(state.copyWith(loading: false, loadFailed: true)),
        );
  }

  /// "Retry" on a failed load: a failed Firestore listener is dead, so
  /// subscribe again.
  Future<void> retry() async {
    await _sub?.cancel();
    if (isClosed) return;
    emit(state.copyWith(loading: true, loadFailed: false));
    _listen();
  }

  /// The row switch: saved at once (no save button). False when the
  /// automation is gone.
  // T14: saving only `enabled: false` must skip the save-time checks, or a
  // broken automation can't be switched off.
  Future<bool> setEnabled(String automationId, bool enabled) async {
    final entry = state.automations
        .where((a) => a.automation.id == automationId)
        .firstOrNull;
    if (entry == null) return false;
    return _guard(
      () => _runner.saveAutomation(
        entry.automation.copyWith(enabled: enabled, updatedAt: _now()),
      ),
    );
  }

  /// Clears a crash / loop pause.
  Future<bool> resume(String automationId) =>
      _guard(() => _runner.resume(automationId));

  /// Reads a `.morkva.json` file's text.
  ImportPreview previewImport(String text) {
    try {
      final bundle = decodeModuleBundle(text);
      return ImportPreview.ok(
        bundle,
        replacing: state.modules
            .where((m) => m.module.id == bundle.manifest.id)
            .firstOrNull,
      );
    } on ManifestProblems catch (e) {
      return ImportPreview.problems(e.problems);
    }
  }

  /// "Allow and install": installs exactly the bundle the sheet showed.
  Future<bool> install(ModuleBundle bundle, ConsentScope scope) =>
      _guard(() => _runner.install(bundle, collections: scope.collections));

  void clearError() => emit(state.copyWith(error: () => null));

  Future<bool> _guard(Future<void> Function() action) async {
    emit(state.copyWith(error: () => null));
    try {
      await action();
      return true;
    } on AutomationRefused catch (e) {
      if (!isClosed) emit(state.copyWith(error: () => e.message));
    } on ManifestProblems catch (e) {
      if (!isClosed) {
        emit(state.copyWith(error: () => e.problems.first.message));
      }
    }
    return false;
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
