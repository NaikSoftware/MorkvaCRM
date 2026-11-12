import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/api/api.dart';
import 'package:morkva_crm/core/automation/runner_api.dart';
import 'package:morkva_crm/core/domain/automation/automation.dart';
import 'package:morkva_crm/design/design.dart';
import 'package:morkva_crm/features/automation/widgets/collection_actions_menu.dart';
import 'package:morkva_crm/features/views/views.dart';

import '../../collections/fake_data_repository.dart';
import '../../views/views_fixtures.dart';
import 'automation_widget_rig.dart';

/// The collection page with the app's automation wiring (UX §4, §5).
void main() {
  late AutomationRig rig;

  setUp(() => rig = AutomationRig());

  final flag = buttonAutomation(
    'a_flag',
    'Flag low stock',
    scope: ButtonScope.collection,
    collectionId: 'deals',
  );

  Future<void> pumpPage(
    WidgetTester tester, {
    Size size = const Size(1280, 800),
    double? pageWidth,
  }) async {
    await rig.setUp(automations: [flag]);
    addTearDown(rig.dispose);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = FakeDataRepository([deals, companies])
      ..seedObjects('deals', sampleDeals());
    final cubit = CollectionViewsCubit(repo, 'deals')..initialize();
    addTearDown(cubit.close);
    final sync = SyncStatusCubit();
    addTearDown(sync.close);
    // The shell mounts the app's one notice host around the page.
    final page = RunNoticeHost(
      collectionId: 'deals',
      child: BlocProvider.value(
        value: cubit,
        child: CollectionViewsPage(modes: defaultViewModeRegistry()),
      ),
    );
    await tester.pumpWidget(
      RepositoryProvider<DataRepository>.value(
        value: repo,
        child: BlocProvider.value(
          value: sync,
          child: rig.wrap(
            MaterialApp(
              theme: AppTheme.light,
              debugShowCheckedModeBanner: false,
              // The shell's Scaffold, as in the app.
              home: Scaffold(
                body: pageWidth == null
                    ? page
                    : Align(
                        alignment: Alignment.centerLeft,
                        child: SizedBox(width: pageWidth, child: page),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  List<Object?>? argsOf(String method) => [
    for (final (m, args) in rig.runner.calls)
      if (m == method) args,
  ].lastOrNull;

  testWidgets('wide header: Actions ▾ runs over the view\'s shown cards', (
    tester,
  ) async {
    await pumpPage(tester);
    await tester.tap(find.text('Actions'));
    await tester.pumpAndSettle();
    final shown = sampleDeals().length;
    expect(find.text('Runs on all $shown cards'), findsOneWidget);
    await tester.tap(find.text('Flag low stock'));
    await tester.pumpAndSettle();
    final args = argsOf('pressCollection')!;
    expect(args[0], 'a_flag');
    expect((args[1]! as List).length, shown);
  });

  testWidgets('a squeezed page: Actions goes icon-only', (tester) async {
    await pumpPage(tester, size: const Size(1600, 900), pageWidth: 640);
    expect(find.text('Actions'), findsNothing);
    expect(find.byTooltip('Actions'), findsOneWidget);
  });

  testWidgets('phone: the indicator takes the sync slot; More has Run '
      'action…', (tester) async {
    await pumpPage(tester, size: const Size(390, 844));
    expect(find.byTooltip('Automations · 1 automation running'), findsNothing);
    rig.runner.activity = RunActivity(
      runs: [liveRun('run_1', automationId: 'a_flag', cardId: 'd1')],
    );
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('indicator-ring')), findsOneWidget);
    rig.runner.activity = RunActivity.idle;
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    expect(find.text('Run action…'), findsOneWidget);
    expect(find.text('Automations…'), findsOneWidget);
    expect(find.text('Customize collection'), findsOneWidget);
  });

  testWidgets('a finished run outside the editor: the finish snackbar', (
    tester,
  ) async {
    await pumpPage(tester);
    rig.runner.finish(
      liveRun(
        'run_1',
        automationId: 'a_flag',
        cardId: null,
        label: 'Flag low stock',
        status: RunStatus.succeeded,
        summary: 'Flagged 4 products',
        planId: 'p_1',
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Flag low stock · Flagged 4 products'), findsOneWidget);
    expect(rig.runs.state.notice, isNull);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Undo'));
    await tester.pump();
    expect(argsOf('undo'), ['run_1']);
  });

  testWidgets('while a card editor is open the host stays quiet', (
    tester,
  ) async {
    await pumpPage(tester);
    rig.runs.editorOpened();
    rig.runner.finish(
      liveRun('run_1', status: RunStatus.succeeded, summary: 'Done'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(SnackBar), findsNothing);
    expect(rig.runs.state.notice, isNotNull);
  });

  testWidgets('a collection run waits: its review sheet opens', (tester) async {
    await pumpPage(tester);
    rig.runner.reviewPlans['run_1'] = const {
      'planId': 'p_1',
      'title': 'Flag 1 product',
      'items': <Object?>[],
    };
    rig.runner.finish(
      liveRun(
        'run_1',
        automationId: 'a_flag',
        cardId: null,
        status: RunStatus.awaitingReview,
      ).copyWithCollection('deals'),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Decide later'), findsOneWidget);
  });

  test('RunNoticeHost is exported for the shell', () {
    expect(const RunNoticeHost(child: SizedBox()).collectionId, isNull);
  });
}

extension on RunView {
  RunView copyWithCollection(String collectionId) => RunView(
    runId: runId,
    automationId: automationId,
    moduleId: moduleId,
    actionId: actionId,
    label: label,
    status: status,
    trigger: RunTrigger(kind: TriggerKind.button, collectionId: collectionId),
    startedAt: startedAt,
  );
}
