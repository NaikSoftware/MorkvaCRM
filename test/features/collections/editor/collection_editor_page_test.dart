// test/features/collections/editor/collection_editor_page_test.dart
//
// Step 6 — page shell restructure: 2-panel layout tests.
//
// Uses a real CollectionEditorCubit + FakeDataRepository, pumped inside a
// minimal GoRouter at 1200 px wide so the docked 2-pane layout is active.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/design/theme/app_theme.dart';
import 'package:morkva_crm/features/collections/editor/collection_editor_cubit.dart';
import 'package:morkva_crm/features/collections/editor/collection_editor_page.dart';
import 'package:morkva_crm/features/collections/editor/collection_editor_state.dart';
import 'package:morkva_crm/features/collections/editor/field_config_panel.dart';
import 'package:morkva_crm/features/collections/editor/section_config_panel.dart';
import 'package:morkva_crm/features/collections/field_editors/built_in_field_editors.dart';

import '../fake_data_repository.dart';

// ---------------------------------------------------------------------------
// Test fixture
// ---------------------------------------------------------------------------

const _collectionId = 'c1';

const _collection = Collection(
  id: _collectionId,
  name: 'Tasks',
  fields: [
    TextFieldDefinition(id: 'f1', name: 'Title'),
    TextFieldDefinition(id: 'f2', name: 'Notes'),
  ],
  layout: CardLayout(sections: [
    LayoutSection(id: 's1', title: 'Main', rows: [
      LayoutRow(id: 'r1', cells: [
        LayoutCell(fieldId: 'f1', span: 6),
        LayoutCell(fieldId: 'f2', span: 6),
      ]),
    ]),
    LayoutSection(id: 's2', title: 'Extra'),
  ]),
);

// ---------------------------------------------------------------------------
// Pump helper
// ---------------------------------------------------------------------------

/// Pumps [CollectionEditorPage] at [surfaceWidth] using a real cubit backed by
/// [FakeDataRepository]. Returns the loaded cubit for driving state changes.
///
/// Uses a minimal GoRouter so back-navigation calls resolve without errors.
Future<CollectionEditorCubit> _pumpPage(
  WidgetTester tester, {
  double surfaceWidth = 1200,
}) async {
  final repo = FakeDataRepository(const [_collection]);
  final registry = defaultFieldEditorRegistry();
  final cubit = CollectionEditorCubit(repo, registry);
  await cubit.load(_collectionId);
  addTearDown(cubit.close);

  final router = GoRouter(
    initialLocation: '/collections/$_collectionId',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('home')),
      ),
      GoRoute(
        path: '/collections/:id',
        builder: (context, state) => BlocProvider.value(
          value: cubit,
          child: CollectionEditorPage(registry: registry),
        ),
      ),
    ],
  );

  await tester.pumpWidget(
    MaterialApp.router(
      theme: AppTheme.light,
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQueryData(size: Size(surfaceWidth, 900)),
        child: child!,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return cubit;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('CollectionEditorPage — 2-pane layout (wide)', () {
    // ── Two panes render ─────────────────────────────────────────────────────

    testWidgets(
      'renders LayoutCanvas and inspector region in two panes',
      (tester) async {
        await _pumpPage(tester);

        // LayoutCanvas is present (canvas renders the collection name header).
        expect(find.text('Tasks'), findsAtLeast(1));

        // Placeholder is visible when nothing is selected.
        expect(find.text('Select a field or group to edit it.'), findsOneWidget);
      },
    );

    // ── Empty inspector placeholder when nothing selected ────────────────────

    testWidgets(
      'shows empty-state placeholder when no field or section is selected',
      (tester) async {
        final cubit = await _pumpPage(tester);

        // Start clean — no selection.
        final state = cubit.state as CollectionEditorReady;
        expect(state.selectedFieldId, isNull);
        expect(state.selectedSectionId, isNull);

        expect(find.text('Select a field or group to edit it.'), findsOneWidget);
        expect(find.byType(FieldConfigPanel), findsNothing);
        expect(find.byType(SectionConfigPanel), findsNothing);
      },
    );

    // ── Field selection shows FieldConfigPanel ───────────────────────────────

    testWidgets(
      'after selectField the inspector shows FieldConfigPanel',
      (tester) async {
        final cubit = await _pumpPage(tester);

        cubit.selectField('f1');
        await tester.pumpAndSettle();

        expect(find.byType(FieldConfigPanel), findsOneWidget);
        expect(find.byType(SectionConfigPanel), findsNothing);
        expect(
          find.text('Select a field or group to edit it.'),
          findsNothing,
        );
      },
    );

    // ── Section selection shows SectionConfigPanel ───────────────────────────

    testWidgets(
      'after selectSection the inspector shows SectionConfigPanel',
      (tester) async {
        final cubit = await _pumpPage(tester);

        cubit.selectSection('s1');
        await tester.pumpAndSettle();

        expect(find.byType(SectionConfigPanel), findsOneWidget);
        expect(find.byType(FieldConfigPanel), findsNothing);
        expect(
          find.text('Select a field or group to edit it.'),
          findsNothing,
        );
      },
    );

    // ── Switching selection replaces the inspector ───────────────────────────

    testWidgets(
      'switching from field to section swaps the inspector widget',
      (tester) async {
        final cubit = await _pumpPage(tester);

        cubit.selectField('f1');
        await tester.pumpAndSettle();
        expect(find.byType(FieldConfigPanel), findsOneWidget);

        cubit.selectSection('s1');
        await tester.pumpAndSettle();
        expect(find.byType(SectionConfigPanel), findsOneWidget);
        expect(find.byType(FieldConfigPanel), findsNothing);
      },
    );

    // ── Selection alone does not make the draft dirty ────────────────────────

    testWidgets(
      'selection changes do not make the draft dirty',
      (tester) async {
        final cubit = await _pumpPage(tester);

        cubit.selectField('f1');
        await tester.pumpAndSettle();
        expect((cubit.state as CollectionEditorReady).dirty, isFalse);

        cubit.selectSection('s1');
        await tester.pumpAndSettle();
        expect((cubit.state as CollectionEditorReady).dirty, isFalse);

        cubit.selectField(null);
        await tester.pumpAndSettle();
        expect((cubit.state as CollectionEditorReady).dirty, isFalse);
      },
    );

    // ── FieldList is no longer in the page ───────────────────────────────────

    testWidgets(
      'the page header renders (collection name editable)',
      (tester) async {
        await _pumpPage(tester);
        // Header contains the collection name as the editable title field.
        expect(find.text('Tasks'), findsAtLeast(1));
      },
    );
  });
}
