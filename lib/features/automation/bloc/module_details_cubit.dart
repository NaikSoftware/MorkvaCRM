import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rxdart/rxdart.dart';

import '../../../core/automation/runner_api.dart';
import '../../../core/domain/automation/automation.dart';
import '../../assistant/bloc/assistant_bloc.dart' show currentAppStrings;
import 'modules_cubit.dart';

/// The banner at the top of module details (UX §2).
enum ModuleBanner {
  none,

  /// Never consented: "Allow this module to run."
  allow,

  /// Consented to an older bundle: "This module changed (v1 → v2)."
  changed,

  /// The stored manifest no longer parses.
  broken,
}

/// A confirm dialog's copy.
typedef ConfirmCopy = ({String title, String? body, String confirm});

/// A test run in the Test-run sheet: running, then its result.
final class TestRunState extends Equatable {
  const TestRunState({required this.request, this.result});

  final TestRunRequest request;

  /// Null while running.
  final TestRunResult? result;

  bool get running => result == null;

  @override
  List<Object?> get props => [request, result];
}

final class ModuleDetailsState extends Equatable {
  const ModuleDetailsState({
    this.loading = true,
    this.entry,
    this.automations = const [],
    this.recentRuns = const [],
    this.engineUnavailable = false,
    this.busy = false,
    this.loadFailed = false,
    this.error,
    this.testRun,
  });

  final bool loading;

  /// The stores couldn't be read: "Couldn't load this module" + Retry.
  final bool loadFailed;

  /// Null once loaded: the module is gone (uninstalled elsewhere).
  final ModuleEntry? entry;
  final List<AutomationEntry> automations;

  /// The last 5 runs of this module, newest first.
  final List<RunRecord> recentRuns;
  final bool engineUnavailable;

  /// A runner call is in flight (buttons disabled).
  final bool busy;
  final String? error;
  final TestRunState? testRun;

  ModuleRecord? get module => entry?.module;
  ModuleManifest? get manifest => module?.manifest;
  GrantRecord? get consent => entry?.consent;
  ModuleStatus? get status => entry?.status;

  ModuleBanner get banner => switch (status) {
    ModuleStatus.broken => ModuleBanner.broken,
    ModuleStatus.needsConsent =>
      consent == null ? ModuleBanner.allow : ModuleBanner.changed,
    _ => ModuleBanner.none,
  };

  /// The auto-apply switch shows only for modules whose changes may ever
  /// auto-apply; it is disabled until the module is allowed.
  bool get autoApplyOffered => manifest?.autoApplyEligible ?? false;
  bool get autoApplyEnabled => status == ModuleStatus.ok;
  bool get autoApplyOn =>
      status == ModuleStatus.ok && (consent?.autoApply ?? false);

  /// Automations stored as Auto ("2 automations will ask first.").
  int get autoAutomations =>
      automations.where((a) => a.automation.apply == ApplyMode.auto).length;

  /// Test run works only once allowed ("Allow this module first").
  bool get canTestRun => status == ModuleStatus.ok;

  ModuleDetailsState copyWith({
    bool? loading,
    ModuleEntry? Function()? entry,
    List<AutomationEntry>? automations,
    List<RunRecord>? recentRuns,
    bool? engineUnavailable,
    bool? busy,
    bool? loadFailed,
    String? Function()? error,
    TestRunState? Function()? testRun,
  }) => ModuleDetailsState(
    loading: loading ?? this.loading,
    entry: entry == null ? this.entry : entry(),
    automations: automations ?? this.automations,
    recentRuns: recentRuns ?? this.recentRuns,
    engineUnavailable: engineUnavailable ?? this.engineUnavailable,
    busy: busy ?? this.busy,
    loadFailed: loadFailed ?? this.loadFailed,
    error: error == null ? this.error : error(),
    testRun: testRun == null ? this.testRun : testRun(),
  );

  @override
  List<Object?> get props => [
    loading,
    entry,
    automations,
    recentRuns,
    engineUnavailable,
    busy,
    loadFailed,
    error,
    testRun,
  ];
}

/// Module details: consent (allow, change access, revoke), the auto-apply
/// switch, uninstall, export and test runs. Every write goes through the
/// runner; the stores are only watched.
class ModuleDetailsCubit extends Cubit<ModuleDetailsState> {
  ModuleDetailsCubit(
    this._runner,
    this._stores, {
    required String uid,
    required this.moduleId,
  }) : _uid = uid,
       super(
         ModuleDetailsState(
           engineUnavailable: _runner.activity.engineUnavailable,
         ),
       ) {
    _engine = _runner.activityChanges.listen(
      (a) => emit(state.copyWith(engineUnavailable: a.engineUnavailable)),
    );
    _listen();
  }

  final AutomationRunnerApi _runner;
  final AutomationStores _stores;
  final String _uid;
  final String moduleId;
  late final StreamSubscription<Object?> _engine;
  StreamSubscription<Object?>? _sub;

  void _listen() {
    _sub =
        Rx.combineLatest4(
          _stores.modules.watch(),
          _stores.automations.watch(),
          _stores.grants.watch(_uid),
          _stores.runs.watchRecent(),
          (m, a, g, r) => (entries: joinEntries(m, a, g, uid: _uid), runs: r),
        ).listen(
          (s) => emit(
            state.copyWith(
              loading: false,
              loadFailed: false,
              entry: () => s.entries.modules
                  .where((m) => m.module.id == moduleId)
                  .firstOrNull,
              automations: [
                for (final a in s.entries.automations)
                  if (a.automation.moduleId == moduleId) a,
              ],
              recentRuns: s.runs
                  .where((r) => r.moduleId == moduleId)
                  .take(5)
                  .toList(),
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

  /// The consent sheet for the module as it is now. The sheet keeps this
  /// view, and [allow] gets its bundle: the hash is of what the user saw,
  /// even if the store changes while the sheet is open.
  ConsentView? consentView() => switch (state.module?.bundle) {
    final bundle? => consentViewOf(bundle, state.consent),
    null => null,
  };

  /// "Allow" / "Allow and install" on [view] (from [consentView]).
  Future<bool> allow(ConsentView view, ConsentScope scope) =>
      _guard(() => _runner.allow(view.bundle, collections: scope.collections));

  /// Change access: new collections, same capabilities.
  Future<bool> changeAccess(ConsentScope scope) => _guard(
    () => _runner.changeAccess(moduleId, collections: scope.collections),
  );

  Future<bool> revoke() => _guard(() => _runner.revoke(moduleId));

  /// The confirm before flipping auto-apply to [on]; null = no confirm
  /// (turning it off while no automation uses Auto).
  ConfirmCopy? autoApplyConfirm(bool on) {
    final l10n = currentAppStrings();
    if (on) {
      return (
        title: l10n.automationWidgetsAutoApplyOnTitle,
        body: null,
        confirm: l10n.automationWidgetsTurnOn,
      );
    }
    final n = state.autoAutomations;
    if (n == 0) return null;
    return (
      title: l10n.automationWidgetsAutoApplyOffTitle,
      body: l10n.automationWidgetsAutoApplyOffBody(n),
      confirm: l10n.automationWidgetsTurnOff,
    );
  }

  /// The switch, after [autoApplyConfirm] was accepted.
  Future<bool> setAutoApply(bool on) =>
      _guard(() => _runner.setAutoApply(moduleId, on: on));

  Future<bool> uninstall() => _guard(() => _runner.uninstall(moduleId));

  /// The export file: `<id>.morkva.json` and its text; null when the
  /// manifest no longer parses.
  ({String name, String text})? exportFile() => switch (state.module?.bundle) {
    final bundle? => (name: '$moduleId.morkva.json', text: bundle.encode()),
    null => null,
  };

  /// A dry run (never committed, nothing written to `runs`).
  Future<void> testRun(TestRunRequest request) async {
    emit(state.copyWith(testRun: () => TestRunState(request: request)));
    TestRunResult result;
    try {
      result = await _runner.testRun(request);
    } on AutomationRefused catch (e) {
      result = TestRunResult(
        status: RunStatus.failed,
        error: RunError(code: e.code, message: e.message),
      );
    } catch (e) {
      // Never leave the sheet spinning.
      result = TestRunResult(
        status: RunStatus.failed,
        reason: RunReason.internal,
        error: RunError(code: 'internal', message: '$e'),
      );
    }
    if (isClosed || state.testRun?.request != request) return;
    emit(
      state.copyWith(
        testRun: () => TestRunState(request: request, result: result),
      ),
    );
  }

  void closeTestRun() => emit(state.copyWith(testRun: () => null));

  void clearError() => emit(state.copyWith(error: () => null));

  Future<bool> _guard(Future<void> Function() action) async {
    emit(state.copyWith(busy: true, error: () => null));
    String? error;
    try {
      await action();
    } on AutomationRefused catch (e) {
      error = e.message;
    } finally {
      // Any other throw still frees the buttons (and reaches the zone).
      if (!isClosed) emit(state.copyWith(busy: false, error: () => error));
    }
    return error == null;
  }

  @override
  Future<void> close() async {
    await _engine.cancel();
    await _sub?.cancel();
    return super.close();
  }
}
