import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/automation/automation.dart';
import 'package:morkva_crm/design/design.dart';
import 'package:morkva_crm/features/automation/bloc/automation_editor_cubit.dart';
import 'package:morkva_crm/features/automation/bloc/modules_cubit.dart';
import 'package:morkva_crm/features/automation/view/automation_editor_sheet.dart';

import '../bloc/automation_fixtures.dart';

void main() {
  late FakeRunner runner;
  late ModuleRecord module;

  setUp(() {
    runner = FakeRunner();
    module = stampModule();
  });

  tearDown(() => runner.dispose());

  AutomationEditorCubit create({
    AutomationRecord? existing,
    EditorKind kind = EditorKind.cardButton,
    bool autoApply = false,
  }) => AutomationEditorCubit(
    runner,
    uid: uid,
    modules: [
      ModuleEntry(
        module: module,
        consent: consentTo(module, autoApply: autoApply),
        automations: 0,
      ),
    ],
    collections: [orders, clients],
    existing: existing,
    collectionId: 'c_orders',
    moduleId: existing == null ? stampId : null,
    actionId: existing == null ? 'stamp' : null,
    kind: kind,
    now: () => fixtureNow,
    newId: () => 'a_new',
  );

  AutomationEditorCubit build({
    AutomationRecord? existing,
    EditorKind kind = EditorKind.cardButton,
    bool autoApply = false,
  }) {
    final cubit = create(existing: existing, kind: kind, autoApply: autoApply);
    // The stamp action's required input.
    if (existing == null) cubit.setParam('dateField', 'f_shipped');
    return cubit;
  }

  AutomationRecord? saved() => [
    for (final (m, args) in runner.calls)
      if (m == 'saveAutomation') args.single as AutomationRecord,
  ].lastOrNull;

  Future<AutomationEditorCubit> pump(
    WidgetTester tester,
    AutomationEditorCubit cubit, {
    // Tall enough that the lazy form builds every section.
    Size size = const Size(1440, 4000),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(cubit.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: 480,
              child: BlocProvider.value(
                value: cubit,
                child: const AutomationEditorSheet(compact: false),
              ),
            ),
          ),
        ),
      ),
    );
    return cubit;
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
  }

  testWidgets('a new card button: sections, defaults and the preview', (
    tester,
  ) async {
    await pump(tester, build());
    expect(find.text('New automation'), findsOneWidget);
    for (final label in ['Name', 'When', 'In', 'Do', 'Button', 'Apply']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Button on a card'), findsOneWidget);
    expect(find.text("Shows in the card's header."), findsOneWidget);
    expect(find.text('Stamp shipped date on Orders'), findsOneWidget);
    // Events-only parts stay out of a button.
    expect(find.text('If'), findsNothing);
    final preview = find.byKey(const ValueKey('button-preview'));
    expect(
      find.descendant(of: preview, matching: find.text('Stamp shipped d…')),
      findsOneWidget,
    );
  });

  testWidgets('collections the module may not touch are disabled', (
    tester,
  ) async {
    await pump(tester, build());
    expect(find.text("Clients isn't allowed for this module."), findsOneWidget);
    expect(find.text('Change access'), findsOneWidget);
    await tester.tap(find.text('Orders').first);
    await tester.pumpAndSettle();
    final clientsItem = tester.widget<DropdownMenuItem<String>>(
      find.ancestor(
        of: find.text('Clients').last,
        matching: find.byType(DropdownMenuItem<String>),
      ),
    );
    expect(clientsItem.enabled, isFalse);
    expect(find.text('· Not allowed for this module'), findsWidgets);
  });

  testWidgets('a label over 24 characters is cut with …; empty = action', (
    tester,
  ) async {
    await pump(tester, build());
    await tester.enterText(
      find.widgetWithText(TextField, 'Stamp shipped date').last,
      'Stamp the shipped date today',
    );
    await tester.pump();
    await save(tester);
    expect(saved()!.button!.label, 'Stamp the shipped date …');
    expect(saved()!.button!.label.length, ButtonSpec.kMaxLabel);
  });

  testWidgets('Advanced: only the module\'s collections can be ticked', (
    tester,
  ) async {
    await pump(tester, build());
    expect(
      find.text("Collections it may touch: same as the module's access"),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('Advanced'));
    await tester.tap(find.text('Advanced'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Only these'));
    await tester.tap(find.text('Only these'));
    await tester.pumpAndSettle();
    expect(find.byType(CheckboxListTile), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(CheckboxListTile),
        matching: find.text('Orders'),
      ),
      findsOneWidget,
    );
    await save(tester);
    expect(saved()!.collections, ['c_orders']);
  });

  testWidgets('Apply automatically shows why it is off', (tester) async {
    await pump(tester, build());
    expect(
      find.text('Turn on auto-apply for this module first.'),
      findsOneWidget,
    );
    expect(find.text('Module details'), findsOneWidget);
  });

  testWidgets('a stored Auto the module no longer allows: Apply '
      'automatically stays selected (disabled), the value is kept', (
    tester,
  ) async {
    final cubit = await pump(
      tester,
      build(
        existing: automation(apply: ApplyMode.auto, autoBy: uid),
      ),
    );
    final group = tester.widget<RadioGroup<ApplyMode>>(
      find.byType(RadioGroup<ApplyMode>),
    );
    // Critic r3: no radio selected read as an unanswered required group.
    expect(group.groupValue, ApplyMode.auto);
    expect(cubit.state.apply, ApplyMode.auto);
    expect(
      find.text('Turn on auto-apply for this module first.'),
      findsOneWidget,
    );
  });

  testWidgets('radio titles are 500 14, not body-large 16', (tester) async {
    await pump(tester, build());
    final style = tester.widget<Text>(find.text('Ask first')).style!;
    expect(style.fontSize, 14);
    expect(style.fontWeight, FontWeight.w500);
  });

  testWidgets('When: the two button tiles share one height', (tester) async {
    await pump(tester, build());
    Finder tile(String title) => find
        .ancestor(of: find.text(title), matching: find.byType(Material))
        .first;
    expect(
      tester.getSize(tile('Button on a card')).height,
      tester.getSize(tile('Button on a collection')).height,
    );
  });

  testWidgets('Module and Action split 3:2 so a module name fits', (
    tester,
  ) async {
    await pump(tester, build());
    double width(String label) => tester
        .getSize(
          find
              .ancestor(
                of: find.text(label).first,
                matching: find.byType(Expanded),
              )
              .first,
        )
        .width;
    expect(width('Module') / width('Action'), closeTo(1.5, 0.01));
  });

  testWidgets('selects use the house chevron at 14 px', (tester) async {
    await pump(tester, build());
    expect(find.byIcon(Icons.arrow_drop_down), findsNothing);
    expect(find.byIcon(Icons.expand_more), findsWidgets);
    final module = tester.widget<DropdownButton<String>>(
      find.byType(DropdownButton<String>).at(1),
    );
    expect(module.style?.fontSize, 14);
  });

  testWidgets('Apply automatically once the module allows it', (tester) async {
    await pump(tester, build(autoApply: true));
    expect(
      find.text('Turn on auto-apply for this module first.'),
      findsNothing,
    );
    await tester.ensureVisible(find.text('Apply automatically'));
    await tester.tap(find.text('Apply automatically'));
    await tester.pumpAndSettle();
    await save(tester);
    expect(saved()!.apply, ApplyMode.auto);
    expect(saved()!.autoBy, uid);
  });

  testWidgets('inline problems on Save: a name is required', (tester) async {
    await pump(tester, build());
    await tester.enterText(
      find.widgetWithText(TextField, 'Stamp shipped date on Orders'),
      '',
    );
    await tester.pump();
    await save(tester);
    expect(find.text('Give it a name'), findsOneWidget);
    expect(saved(), isNull);
  });

  testWidgets('updated: conditions, watched fields, Once / Every', (
    tester,
  ) async {
    await pump(tester, build(kind: EditorKind.updated));
    expect(find.text('If'), findsOneWidget);
    expect(find.text('Condition'), findsOneWidget);
    expect(find.text('Only when these fields change'), findsOneWidget);
    expect(find.text('Once, when the card starts matching'), findsOneWidget);
    expect(find.text("Every time it's updated and matches"), findsOneWidget);
    expect(find.text('Button'), findsNothing);
    await save(tester);
    expect(
      find.text('Add at least one condition or pick fields to watch'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(FilterChip, 'Shipped on'));
    await tester.pumpAndSettle();
    await save(tester);
    final trigger = saved()!.trigger as EventTrigger;
    expect(trigger.fields, ['f_shipped']);
    expect(trigger.mode, TriggerMode.enters);
  });

  testWidgets('a loop pause: the amber banner and Resume', (tester) async {
    final existing = automation(paused: PausedReason.loopSuspected);
    await pump(tester, build(existing: existing));
    expect(find.text('Edit automation'), findsOneWidget);
    expect(find.textContaining('Paused: it ran too often'), findsOneWidget);
    await tester.tap(find.text('Resume'));
    await tester.pumpAndSettle();
    expect(runner.methods, contains('resume'));
    expect(find.textContaining('Paused: it ran too often'), findsNothing);
    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets('presented as a 480 side sheet; Save closes it with true', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async =>
                  result = await presentAutomationEditor(context, build()),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(AutomationEditorSheet)).width, 480);
    expect(tester.getTopRight(find.byType(AutomationEditorSheet)).dx, 1440);
    await save(tester);
    expect(find.byType(AutomationEditorSheet), findsNothing);
    expect(result, isTrue);
    expect(saved()!.id, 'a_new');
  });
}
