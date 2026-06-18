import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/design/theme/app_theme.dart';
import 'package:morkva_crm/features/collections/editor/collection_editor_cubit.dart';
import 'package:morkva_crm/features/collections/editor/collection_editor_state.dart';
import 'package:morkva_crm/features/collections/editor/section_config_panel.dart';
import 'package:morkva_crm/features/collections/field_editors/built_in_field_editors.dart';

import '../fake_data_repository.dart';

/// Two-section collection used across all tests.
const _collectionId = 'c1';

const _collection = Collection(
  id: _collectionId,
  name: 'Tasks',
  fields: [
    TextFieldDefinition(id: 'f1', name: 'Title'),
  ],
  layout: CardLayout(sections: [
    LayoutSection(id: 's1', title: 'Details', rows: [
      LayoutRow(id: 'r1', cells: [LayoutCell(fieldId: 'f1')]),
    ]),
    LayoutSection(id: 's2', title: 'Extra'),
  ]),
);

Future<CollectionEditorCubit> _loadCubit() async {
  final repo = FakeDataRepository(const [_collection]);
  final cubit = CollectionEditorCubit(repo, defaultFieldEditorRegistry());
  await cubit.load(_collectionId);
  return cubit;
}

/// Pumps [SectionConfigPanel] for [sectionId], inside a real cubit + theme.
Future<void> _pumpPanel(
  WidgetTester tester,
  CollectionEditorCubit cubit,
  String sectionId, {
  bool canDelete = true,
}) async {
  final state = cubit.state as CollectionEditorReady;
  final section = state.draft.layout.sections.firstWhere((s) => s.id == sectionId);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: BlocProvider.value(
          value: cubit,
          child: SectionConfigPanel(
            section: section,
            canDelete: canDelete,
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('SectionConfigPanel', () {
    late CollectionEditorCubit cubit;

    setUp(() async {
      cubit = await _loadCubit();
    });

    tearDown(() async {
      await cubit.close();
    });

    // -------------------------------------------------------------------------
    // Title rename
    // -------------------------------------------------------------------------

    testWidgets('shows the current section title in the text field',
        (tester) async {
      await _pumpPanel(tester, cubit, 's1');
      expect(find.widgetWithText(TextField, 'Details'), findsOneWidget);
    });

    testWidgets('editing the title field calls renameSection in the cubit',
        (tester) async {
      await _pumpPanel(tester, cubit, 's1');

      await tester.enterText(find.byType(TextField).first, 'New Title');
      await tester.pump();

      final state = cubit.state as CollectionEditorReady;
      final s1 = state.draft.layout.sections.firstWhere((s) => s.id == 's1');
      expect(s1.title, 'New Title');
    });

    testWidgets('empty title is accepted (ungrouped header)', (tester) async {
      await _pumpPanel(tester, cubit, 's1');

      await tester.enterText(find.byType(TextField).first, '');
      await tester.pump();

      final state = cubit.state as CollectionEditorReady;
      final s1 = state.draft.layout.sections.firstWhere((s) => s.id == 's1');
      // Empty title is acceptable — section renders header-less when title is empty/null
      expect(s1.title == null || s1.title!.isEmpty, isTrue);
    });

    // -------------------------------------------------------------------------
    // Collapsed toggle
    // -------------------------------------------------------------------------

    testWidgets('shows the collapsed switch seeded from section.collapsed',
        (tester) async {
      await _pumpPanel(tester, cubit, 's1');

      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.value, isFalse); // s1 starts with collapsed: false
    });

    testWidgets('toggling the switch flips collapsed in cubit state',
        (tester) async {
      await _pumpPanel(tester, cubit, 's1');

      await tester.tap(find.byType(Switch));
      await tester.pump();

      final state = cubit.state as CollectionEditorReady;
      final s1 = state.draft.layout.sections.firstWhere((s) => s.id == 's1');
      expect(s1.collapsed, isTrue);
    });

    testWidgets('toggling twice restores collapsed to false', (tester) async {
      await _pumpPanel(tester, cubit, 's1');

      await tester.tap(find.byType(Switch));
      await tester.pump();
      await tester.tap(find.byType(Switch));
      await tester.pump();

      final state = cubit.state as CollectionEditorReady;
      final s1 = state.draft.layout.sections.firstWhere((s) => s.id == 's1');
      expect(s1.collapsed, isFalse);
    });

    // -------------------------------------------------------------------------
    // Delete section
    // -------------------------------------------------------------------------

    testWidgets('delete button is present when canDelete is true',
        (tester) async {
      await _pumpPanel(tester, cubit, 's1', canDelete: true);
      expect(find.text('Delete group'), findsOneWidget);
    });

    testWidgets('delete button is absent (or disabled) when canDelete is false',
        (tester) async {
      await _pumpPanel(tester, cubit, 's1', canDelete: false);
      // The button should be visually absent or semantically disabled.
      // SectionConfigPanel hides it entirely when canDelete is false.
      expect(find.text('Delete group'), findsNothing);
    });

    testWidgets(
        'tapping delete then confirming the dialog removes the section',
        (tester) async {
      await _pumpPanel(tester, cubit, 's2', canDelete: true);

      // Tap the delete affordance
      await tester.tap(find.text('Delete group'));
      await tester.pumpAndSettle();

      // MorkvaConfirmDialog should appear — tap the confirm label
      expect(find.text('Delete'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      final state = cubit.state as CollectionEditorReady;
      expect(
        state.draft.layout.sections.any((s) => s.id == 's2'),
        isFalse,
        reason: 'Section s2 should have been deleted',
      );
    });

    testWidgets('tapping delete then cancelling the dialog keeps the section',
        (tester) async {
      await _pumpPanel(tester, cubit, 's2', canDelete: true);

      await tester.tap(find.text('Delete group'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      final state = cubit.state as CollectionEditorReady;
      expect(
        state.draft.layout.sections.any((s) => s.id == 's2'),
        isTrue,
        reason: 'Section s2 should still exist after cancel',
      );
    });
  });
}
