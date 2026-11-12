import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/api/api.dart';
import 'package:morkva_crm/core/automation/runner_api.dart';
import 'package:morkva_crm/core/domain/automation/automation.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/core/domain/ids.dart';
import 'package:morkva_crm/design/design.dart';
import 'package:morkva_crm/features/assistant/view/widgets/plan_card.dart';
import 'package:morkva_crm/features/objects/object_editor.dart';
import 'package:morkva_crm/features/objects/object_editor_cubit.dart';

import '../assistant/fakes/assistant_seeds.dart';
import '../automation/widgets/automation_widget_rig.dart';
import '../collections/fake_data_repository.dart';

final _at = DateTime.utc(2026, 11, 12, 9);

MorkvaObject _order({String title = '#1042'}) => MorkvaObject(
  id: 'b_1042',
  collectionId: 'c_orders',
  values: {'f_title': TextFieldValue(title)},
  createdAt: _at,
  updatedAt: _at,
);

class _NewIds extends IdGenerator {
  @override
  String objectId() => 'b_new';
}

void main() {
  group('save(stayOpen: true)', () {
    late FakeDataRepository repo;

    setUp(() {
      repo = FakeDataRepository([orders])..seedObjects('c_orders', [_order()]);
    });

    Future<ObjectEditorCubit> editor({MorkvaObject? object}) async {
      final cubit = ObjectEditorCubit(
        repo,
        orders,
        object: object,
        idGenerator: _NewIds(),
        clock: () => _at,
      );
      addTearDown(cubit.close);
      await cubit.initialize();
      await pumpEventQueue();
      return cubit;
    }

    test('edit: written, the form keeps editing the saved card', () async {
      final cubit = await editor(object: _order());
      cubit.change('f_title', const TextFieldValue('#1042 · gift'));
      expect(await cubit.save(stayOpen: true), isTrue);
      final s = cubit.state;
      expect(s.status, ObjectEditorStatus.editing);
      expect(s.draft, isEmpty);
      expect(s.hasUnsavedChanges, isFalse);
      expect(s.stored!.values['f_title'], const TextFieldValue('#1042 · gift'));
      expect(
        repo.objectsOf('c_orders').single.values['f_title'],
        const TextFieldValue('#1042 · gift'),
      );
      // Still editable.
      cubit.change('f_title', const TextFieldValue('again'));
      expect(cubit.state.hasUnsavedChanges, isTrue);
    });

    test('create: becomes an edit of the new card and follows it', () async {
      final cubit = await editor();
      cubit.change('f_title', const TextFieldValue('#2001'));
      expect(await cubit.save(stayOpen: true), isTrue);
      expect(cubit.state.isCreate, isFalse);
      expect(cubit.state.stored!.id, 'b_new');
      expect(cubit.state.savedObject!.id, 'b_new');

      // An automation's write to the card shows in the form.
      await repo.saveObject(
        cubit.state.stored!.copyWith(
          values: {'f_shipped': DateFieldValue(DateTime.utc(2026, 11, 12))},
        ),
        schema: orders,
      );
      await pumpEventQueue();
      expect(cubit.state.stored!.values['f_shipped'], isNotNull);
      expect(cubit.state.conflictFieldIds, isEmpty);
    });

    test('nothing changed: saved as is, the editor stays', () async {
      final cubit = await editor(object: _order());
      expect(await cubit.save(stayOpen: true), isTrue);
      expect(cubit.state.status, ObjectEditorStatus.editing);
    });

    test('a failed write keeps the draft and runs nothing', () async {
      final cubit = await editor(object: _order());
      cubit.change('f_title', const TextFieldValue('x'));
      repo.objectWriteError = () => Exception('offline');
      expect(await cubit.save(stayOpen: true), isFalse);
      expect(cubit.state.status, ObjectEditorStatus.saveFailed);
      expect(cubit.state.draft, isNotEmpty);
    });

    test('without stayOpen the save still closes the editor', () async {
      final cubit = await editor(object: _order());
      cubit.change('f_title', const TextFieldValue('x'));
      expect(await cubit.save(), isTrue);
      expect(cubit.state.status, ObjectEditorStatus.saved);
    });
  });

  group('card editor with action buttons', () {
    late AutomationRig rig;
    late FakeDataRepository repo;
    ObjectEditorResult? result;
    var closed = false;

    setUp(() {
      rig = AutomationRig();
      repo = FakeDataRepository([orders])..seedObjects('c_orders', [_order()]);
      result = null;
      closed = false;
    });

    List<Object?>? argsOf(String method) => [
      for (final (m, args) in rig.runner.calls)
        if (m == method) args,
    ].lastOrNull;

    Future<void> open(
      WidgetTester tester, {
      MorkvaObject? object,
      Size size = const Size(1440, 900),
    }) async {
      await rig.setUp(
        automations: [buttonAutomation('a_mark', 'Mark shipped')],
      );
      addTearDown(rig.dispose);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        RepositoryProvider<DataRepository>.value(
          value: repo,
          child: rig.wrap(
            MaterialApp(
              theme: AppTheme.light,
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () async {
                      result = await showObjectEditor(
                        context,
                        collection: orders,
                        object: object,
                      );
                      closed = true;
                    },
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    Finder titleField() => find.byType(TextField).first;

    testWidgets('a dirty form: Save and run saves, stays open, runs on the '
        'card', (tester) async {
      await open(tester, object: _order());
      expect(find.text('Mark shipped'), findsOneWidget);
      expect(rig.runs.state.editorOpen, isTrue);

      await tester.enterText(titleField(), '#1042 · gift wrap');
      await tester.pump();
      await tester.tap(find.text('Mark shipped'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save and run'));
      await tester.pumpAndSettle();

      expect(
        repo.objectsOf('c_orders').single.values['f_title'],
        const TextFieldValue('#1042 · gift wrap'),
      );
      expect(find.byType(ObjectEditor), findsOneWidget);
      expect(argsOf('pressCard'), ['a_mark', 'b_1042']);
      expect(closed, isFalse);

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(closed, isTrue);
      expect(result, isA<ObjectEditorSaved>());
      expect(rig.runs.state.editorOpen, isFalse);
    });

    testWidgets('a new card: Save and run creates it, then runs on it', (
      tester,
    ) async {
      await open(tester);
      await tester.enterText(titleField(), '#2001');
      await tester.pump();
      await tester.tap(find.text('Mark shipped'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save and run'));
      await tester.pumpAndSettle();
      final created = repo
          .objectsOf('c_orders')
          .where((o) => o.id != 'b_1042')
          .single;
      expect(argsOf('pressCard'), ['a_mark', created.id]);
      expect(find.byType(ObjectEditor), findsOneWidget);
    });

    testWidgets('a failed save: the usual error, nothing runs', (tester) async {
      repo.objectWriteError = () => Exception('offline');
      await open(tester, object: _order());
      await tester.enterText(titleField(), 'x');
      await tester.pump();
      await tester.tap(find.text('Mark shipped'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save and run'));
      await tester.pumpAndSettle();
      expect(
        find.text("Couldn't save — check your connection"),
        findsOneWidget,
      );
      expect(rig.runner.methods, isNot(contains('pressCard')));
    });

    testWidgets('a finished run: the in-editor banner, never a snackbar', (
      tester,
    ) async {
      await open(tester, object: _order());
      rig.runner.finish(
        liveRun(
          'run_1',
          status: RunStatus.succeeded,
          summary: '1 order updated',
          planId: 'p_1',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('run-banner')), findsOneWidget);
      expect(
        find.textContaining('1 order updated', findRichText: true),
        findsOneWidget,
      );
      expect(find.byType(SnackBar), findsNothing);
      expect(rig.runs.state.notice, isNull);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(argsOf('undo'), ['run_1']);
      expect(
        find.textContaining('Reverted', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('a refused Run again shows in the error tone', (tester) async {
      // Web e2e 2026-11-12: Run again offline said "You are offline.
      // Nothing was changed." in the green success banner.
      await open(tester, object: _order());
      rig.runner.finish(
        liveRun('run_1', status: RunStatus.failed, reason: RunReason.offline),
      );
      await tester.pumpAndSettle();
      rig.runner.failNext = const AutomationRefused(
        'offline',
        'You are offline. Nothing was changed.',
      );
      await tester.tap(find.text('Run again'));
      await tester.pumpAndSettle();

      final banner = find.byKey(const ValueKey('run-banner'));
      expect(
        find.descendant(
          of: banner,
          matching: find.textContaining('You are offline', findRichText: true),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: banner, matching: find.byIcon(Icons.error_outline)),
        findsOneWidget,
      );
    });

    testWidgets('a button run of this card waits: the review sheet opens '
        'above the editor', (tester) async {
      await open(tester, object: _order());
      rig.runner.reviewPlans['run_1'] = AssistantSeeds.shipPlan.toJson();
      rig.runner.activity = RunActivity(
        runs: [liveRun('run_1', status: RunStatus.awaitingReview)],
      );
      rig.runner.finish(liveRun('run_1', status: RunStatus.awaitingReview));
      await tester.pumpAndSettle();
      expect(find.byType(PlanCard), findsOneWidget);
      expect(find.byType(ObjectEditor), findsOneWidget);
      final barrier = tester
          .widgetList<ModalBarrier>(find.byType(ModalBarrier))
          .last;
      expect(barrier.color?.a ?? 0, 0);
    });

    testWidgets('phone: ⚡ in the app bar and a progress line while running', (
      tester,
    ) async {
      await open(tester, object: _order(), size: const Size(390, 844));
      expect(find.byTooltip('Actions'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      rig.runner.activity = RunActivity(
        runs: [
          liveRun('run_1', progress: const RunProgress(done: 1, total: 3)),
        ],
      );
      await tester.pump();
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('1/3'), findsOneWidget);
    });
  });
}
