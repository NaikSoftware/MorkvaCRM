/// The app's automation wiring over fakes, for widget tests.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/automation/runner_api.dart';
import 'package:morkva_crm/core/domain/automation/automation.dart';
import 'package:morkva_crm/design/design.dart';
import 'package:morkva_crm/features/automation/bloc/automation_runs_cubit.dart';
import 'package:morkva_crm/features/automation/bloc/modules_cubit.dart';

import '../bloc/automation_fixtures.dart';

export '../bloc/automation_fixtures.dart';

/// A button automation of the stamp module on Orders.
AutomationRecord buttonAutomation(
  String id,
  String label, {
  ButtonScope scope = ButtonScope.card,
  int order = 0,
  String? tint,
  bool enabled = true,
  String collectionId = 'c_orders',
}) => AutomationRecord(
  id: id,
  name: label,
  enabled: enabled,
  moduleId: stampId,
  actionId: 'stamp',
  params: const {'dateField': 'f_shipped'},
  trigger: ButtonTrigger(scope: scope, collectionId: collectionId),
  button: ButtonSpec(label: label, order: order, tint: tint),
  apply: ApplyMode.ask,
  createdBy: 'user:$uid',
  createdAt: fixtureNow,
  updatedAt: fixtureNow,
);

/// A live run of [automationId] on [cardId] (null: a collection run).
RunView liveRun(
  String runId, {
  String automationId = 'a_mark',
  String? cardId = 'b_1042',
  String cardLabel = '#1042',
  RunStatus status = RunStatus.running,
  String label = 'Mark shipped',
  RunProgress? progress,
  int? queuedAhead,
  String? summary,
  String? outcome,
  String? planId,
  RunReason? reason,
}) => RunView(
  runId: runId,
  automationId: automationId,
  moduleId: stampId,
  actionId: 'stamp',
  label: label,
  status: status,
  reason: reason,
  trigger: RunTrigger(
    kind: TriggerKind.button,
    collectionId: 'c_orders',
    cardId: cardId,
    cardLabel: cardId == null ? null : cardLabel,
  ),
  startedAt: fixtureNow,
  progress: progress,
  queuedAhead: queuedAhead,
  summary: summary,
  outcome: outcome,
  planId: planId,
);

/// FakeRunner + FakeStores behind the real app-level cubits.
final class AutomationRig {
  final runner = FakeRunner();
  final stores = FakeStores();
  late final ModulesCubit modules;
  late final AutomationRunsCubit runs;

  /// The runs cubit's clock ("seen" moves to it).
  DateTime clock = fixtureNow;

  /// Installs the stamp module (consented unless [consent] is false) and
  /// [automations], then builds the cubits.
  Future<void> setUp({
    List<AutomationRecord> automations = const [],
    bool consent = true,
    List<String>? collections = const ['c_orders'],
    bool autoApply = false,
  }) async {
    final module = stampModule();
    await stores.modules.save(module);
    if (consent) {
      await stores.grants.save(
        uid,
        consentTo(module, collections: collections, autoApply: autoApply),
      );
    }
    for (final a in automations) {
      await stores.automations.save(a);
    }
    modules = ModulesCubit(runner, stores.stores, uid: uid);
    runs = AutomationRunsCubit(runner, stores.stores, now: () => clock);
  }

  Widget wrap(Widget child) => MultiRepositoryProvider(
    providers: [
      RepositoryProvider<AutomationRunnerApi>.value(value: runner),
      RepositoryProvider<AutomationStores>.value(value: stores.stores),
    ],
    child: MultiBlocProvider(
      providers: [
        BlocProvider<ModulesCubit>.value(value: modules),
        BlocProvider<AutomationRunsCubit>.value(value: runs),
      ],
      child: child,
    ),
  );

  Future<void> dispose() async {
    await modules.close();
    await runs.close();
    await runner.dispose();
    await stores.dispose();
  }
}

/// Pumps [child] in a Scaffold at [size], under [rig]'s providers.
Future<void> pumpRig(
  WidgetTester tester,
  AutomationRig rig,
  Widget child, {
  Size size = const Size(1440, 900),
  ThemeData? theme,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    rig.wrap(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme ?? AppTheme.light,
        home: Scaffold(body: child),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}
