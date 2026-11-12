import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:morkva_crm/api/api.dart';
import 'package:morkva_crm/app/router/app_router.dart';
import 'package:morkva_crm/app/shell/shell_sidebar.dart';
import 'package:morkva_crm/core/automation/runner_api.dart';
import 'package:morkva_crm/core/domain/automation/automation.dart';
import 'package:morkva_crm/design/design.dart';
import 'package:morkva_crm/features/automation/bloc/module_details_cubit.dart';
import 'package:morkva_crm/features/automation/bloc/run_log_cubit.dart';
import 'package:morkva_crm/features/automation/view/automations_page.dart';
import 'package:morkva_crm/features/automation/view/module_details_page.dart';
import 'package:morkva_crm/features/automation/view/run_detail_page.dart';
import 'package:morkva_crm/features/automation/widgets/collection_actions_menu.dart';
import 'package:morkva_crm/features/settings/settings_page.dart';

import '../../features/automation/widgets/automation_widget_rig.dart';
import '../../features/collections/fake_data_repository.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

/// The shell's Automations entries, routes and run indicator (T16).
void main() {
  late GoRouter router;
  late AutomationRig rig;

  Future<void> pumpApp(
    WidgetTester tester, {
    Size size = const Size(1440, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final auth = _MockAuthRepository();
    when(
      () => auth.authStateChanges,
    ).thenAnswer((_) => Stream.value(const AuthUser(uid: uid, email: 'a@b.c')));
    final authCubit = AuthCubit(auth)..initialize();
    addTearDown(authCubit.close);
    rig = AutomationRig();
    await rig.setUp();
    final runLog = RunLogCubit(rig.runner, rig.stores.stores, uid: uid);
    addTearDown(() async {
      await runLog.close();
      await rig.dispose();
    });
    final data = FakeDataRepository([orders]);
    router = createAppRouter(authCubit, sessionReady: ValueNotifier(true));
    addTearDown(router.dispose);

    await tester.pumpWidget(
      RepositoryProvider<DataRepository>.value(
        value: data,
        child: MultiBlocProvider(
          providers: [
            BlocProvider.value(value: authCubit),
            BlocProvider(create: (_) => SyncStatusCubit()),
            BlocProvider.value(value: runLog),
          ],
          child: rig.wrap(
            MaterialApp.router(theme: AppTheme.light, routerConfig: router),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  ShellSidebar sidebar(WidgetTester tester) =>
      tester.widget(find.byType(ShellSidebar));

  Finder inSidebar(Finder finder) =>
      find.descendant(of: find.byType(ShellSidebar), matching: finder);

  testWidgets('the sidebar row opens /automations, the shell marks the place', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(sidebar(tester).place, ShellPlace.allCollections);

    await tester.tap(inSidebar(find.text('Automations')));
    await tester.pumpAndSettle();
    expect(router.state.uri.toString(), '/automations');
    expect(find.byType(AutomationsPage), findsOneWidget);
    expect(sidebar(tester).place, ShellPlace.automations);
    // Wide, the page draws its own header (no second "Automations" title).
    expect(
      find.descendant(
        of: find.byType(AutomationsPage),
        matching: find.text('Automations'),
      ),
      findsWidgets,
    );
    // Exactly one notice host, the shell's.
    expect(find.byType(RunNoticeHost), findsOneWidget);
  });

  testWidgets('detail routes are keyed per id and are not collections', (
    tester,
  ) async {
    await pumpApp(tester);

    router.go('/automations/modules/$stampId');
    await tester.pumpAndSettle();
    expect(find.byType(ModuleDetailsPage), findsOneWidget);
    expect(sidebar(tester).place, ShellPlace.automations);
    expect(sidebar(tester).collectionId, isNull);
    ModuleDetailsCubit details() =>
        tester.element(find.byType(ModuleDetailsPage)).read();
    final first = details();
    expect(first.moduleId, stampId);

    router.go('/automations/modules/other');
    await tester.pumpAndSettle();
    expect(details().moduleId, 'other');
    expect(details(), isNot(same(first)));

    router.go('/automations/runs/run_1');
    await tester.pumpAndSettle();
    final run = find.byType(RunDetailPage);
    expect(tester.widget<RunDetailPage>(run).runId, 'run_1');
    router.go('/automations/runs/run_2');
    await tester.pumpAndSettle();
    expect(tester.widget<RunDetailPage>(run).runId, 'run_2');
  });

  testWidgets('the query is the page state', (tester) async {
    await pumpApp(tester);
    router.go('/automations?tab=runs&filter=review');
    await tester.pumpAndSettle();
    final page = tester.widget<AutomationsPage>(find.byType(AutomationsPage));
    expect(page.tab, AutomationsTab.runs);
    expect(page.filter, RunFilterKind.review);
  });

  testWidgets('the indicator: a live pill on the row, its path on tap', (
    tester,
  ) async {
    await pumpApp(tester);
    rig.runner.activity = RunActivity(runs: [liveRun('run_1')]);
    await tester.pump();
    await tester.pump();
    expect(inSidebar(find.text('Running · 1')), findsOneWidget);

    rig.runner.activity = RunActivity(
      runs: [liveRun('run_1', status: RunStatus.awaitingReview)],
    );
    await tester.pump();
    await tester.pump();
    expect(inSidebar(find.text('1 needs review')), findsOneWidget);
    await tester.tap(inSidebar(find.text('Automations')));
    await tester.pumpAndSettle();
    expect(router.state.uri.toString(), '/automations?tab=runs&filter=review');
  });

  testWidgets('rail: the bolt carries the run state', (tester) async {
    await pumpApp(tester, size: const Size(1024, 768));
    expect(sidebar(tester).extended, isFalse);
    rig.runner.activity = RunActivity(runs: [liveRun('run_1')]);
    await tester.pump();
    await tester.pump();
    expect(
      inSidebar(find.byKey(const ValueKey('indicator-ring'))),
      findsOneWidget,
    );
    expect(find.byTooltip('Automations · 1 automation running'), findsOne);
  });

  testWidgets('phone: Settings has the entry; the header shows back, the '
      'title and the indicator', (tester) async {
    await pumpApp(tester, size: const Size(390, 844));
    router.go('/settings');
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPage), findsOneWidget);
    await tester.tap(find.text('Automations'));
    await tester.pumpAndSettle();
    expect(find.byType(AutomationsPage), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);

    expect(find.byKey(const ValueKey('indicator-ring')), findsNothing);
    rig.runner.activity = RunActivity(runs: [liveRun('run_1')]);
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('indicator-ring')), findsOneWidget);
  });

  testWidgets('the shell provides the automations host', (tester) async {
    await pumpApp(tester);
    router.go('/automations');
    await tester.pumpAndSettle();
    final host = tester
        .element(find.byType(AutomationsPage))
        .read<AutomationsHost>();
    host.openModule(stampId);
    await tester.pumpAndSettle();
    expect(router.state.uri.toString(), '/automations/modules/$stampId');
    host.openAutomations(
      tab: AutomationsTab.automations,
      collectionId: 'c_orders',
    );
    await tester.pumpAndSettle();
    expect(
      router.state.uri.toString(),
      '/automations?tab=automations&collection=c_orders',
    );
  });
}
