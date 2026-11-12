/// Shared rig for the automation page tests: the real T9 cubits over
/// [FakeRunner] / [FakeStores], a recording [FakeHost] and a stubbed
/// collections list.
library;

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:morkva_crm/api/sync/sync_status.dart';
import 'package:morkva_crm/api/sync/sync_status_cubit.dart';
import 'package:morkva_crm/core/domain/automation/automation.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/design/design.dart';
import 'package:morkva_crm/features/automation/bloc/automation_runs_cubit.dart';
import 'package:morkva_crm/features/automation/bloc/module_details_cubit.dart';
import 'package:morkva_crm/features/automation/bloc/modules_cubit.dart';
import 'package:morkva_crm/features/automation/bloc/run_log_cubit.dart';
import 'package:morkva_crm/features/automation/view/automations_page.dart';
import 'package:morkva_crm/features/collections/collections.dart';

import '../bloc/automation_fixtures.dart';

export '../bloc/automation_fixtures.dart';

class _MockCollections extends MockCubit<CollectionsListState>
    implements CollectionsListCubit {}

class _MockSync extends MockCubit<SyncStatus> implements SyncStatusCubit {}

/// Records every host call as `(method, args)`.
final class FakeHost implements AutomationsHost {
  final calls = <(String, List<Object?>)>[];
  bool askEnabled = true;
  ({String name, String text})? file;

  List<String> get methods => [for (final (m, _) in calls) m];

  @override
  void openAutomations({
    AutomationsTab tab = AutomationsTab.modules,
    String? collectionId,
    String? cardId,
    RunFilterKind? filter,
    String? moduleId,
  }) => calls.add((
    'openAutomations',
    [tab, collectionId, cardId, filter, moduleId],
  ));

  @override
  void openModule(String moduleId) => calls.add(('openModule', [moduleId]));

  @override
  void openRun(String runId) => calls.add(('openRun', [runId]));

  @override
  void openCard(String collectionId, String cardId) =>
      calls.add(('openCard', [collectionId, cardId]));

  @override
  void openLink(UiLink link) => calls.add(('openLink', [link]));

  @override
  void newAutomation({
    String? moduleId,
    String? actionId,
    String? collectionId,
  }) => calls.add(('newAutomation', [moduleId, actionId, collectionId]));

  @override
  void editAutomation(String automationId) =>
      calls.add(('editAutomation', [automationId]));

  @override
  void review(String runId) => calls.add(('review', [runId]));

  @override
  void Function(String prefill)? get askMorkva =>
      askEnabled ? (p) => calls.add(('askMorkva', [p])) : null;

  @override
  Future<({String name, String text})?> pickModuleFile() async {
    calls.add(('pickModuleFile', []));
    return file;
  }

  @override
  Future<bool> saveFile(String name, String text) async {
    calls.add(('saveFile', [name, text]));
    return true;
  }
}

/// The rig: stores, runner, host and the cubits the pages read.
final class AutomationRig {
  AutomationRig({List<Collection>? collections})
    : collections = collections ?? [orders, clients];

  final runner = FakeRunner();
  final stores = FakeStores();
  final host = FakeHost();
  final List<Collection> collections;

  /// The sync status the pages see.
  bool offline = false;

  late final modules = ModulesCubit(runner, stores.stores, uid: uid);
  late final runLog = RunLogCubit(
    runner,
    stores.stores,
    uid: uid,
    now: () => fixtureNow,
  );
  late final runs = AutomationRunsCubit(
    runner,
    stores.stores,
    since: fixtureNow.subtract(const Duration(hours: 1)),
    now: () => fixtureNow,
  );
  ModuleDetailsCubit? details;

  ModuleDetailsCubit detailsOf(String moduleId) => details ??=
      ModuleDetailsCubit(runner, stores.stores, uid: uid, moduleId: moduleId);

  Future<void> dispose() async {
    await modules.close();
    await runLog.close();
    await runs.close();
    await details?.close();
    await runner.dispose();
    await stores.dispose();
  }

  Widget wrap(Widget child, {ThemeData? theme}) {
    final list = _MockCollections();
    when(() => list.state).thenReturn(CollectionsListReady(collections));
    final sync = _MockSync();
    when(
      () => sync.state,
    ).thenReturn(offline ? const SyncOffline() : const SyncSynced());
    return MultiRepositoryProvider(
      providers: [RepositoryProvider<AutomationsHost>.value(value: host)],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<ModulesCubit>.value(value: modules),
          BlocProvider<RunLogCubit>.value(value: runLog),
          BlocProvider<AutomationRunsCubit>.value(value: runs),
          BlocProvider<CollectionsListCubit>.value(value: list),
          BlocProvider<SyncStatusCubit>.value(value: sync),
          if (details != null)
            BlocProvider<ModuleDetailsCubit>.value(value: details!),
        ],
        child: MaterialApp(
          theme: theme ?? AppTheme.light,
          home: Scaffold(body: child),
        ),
      ),
    );
  }
}

/// Sets the test window to [size] (logical px) for this test.
void setWindow(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

const wideWindow = Size(1440, 900);
const tabletWindow = Size(1024, 768);
const phoneWindow = Size(390, 844);

/// A run doc for the rig's stores ([runRecord] with a summary).
RunRecord storedRun(
  String id, {
  RunStatus status = RunStatus.succeeded,
  RunReason? reason,
  String sessionId = 't_test',
  String? summary,
  DateTime? startedAt,
  String? journalId,
  RunError? error,
}) => runRecord(
  id,
  status: status,
  reason: reason,
  sessionId: sessionId,
  startedAt: startedAt,
  journalId: journalId,
  error: error,
).copyWith(summary: () => summary);

/// Expects [calls]' last entry to be [method] with [args].
void expectLastCall(
  List<(String, List<Object?>)> calls,
  String method, [
  List<Object?>? args,
]) {
  expect(calls.last.$1, method);
  if (args != null) expect(calls.last.$2, args);
}
