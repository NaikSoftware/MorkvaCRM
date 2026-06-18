// test/features/collections/editor/card_preview_sections_test.dart
//
// Task 10 — section controls: collapse, add, delete (+ rename bonus).
//
// RED phase: collapse_s1 / add_section / delete_<id> keys do not exist yet.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/features/collections/editor/card_preview.dart';
import 'package:morkva_crm/features/collections/editor/collection_editor_cubit.dart';
import 'package:morkva_crm/features/collections/editor/collection_editor_state.dart';
import 'package:morkva_crm/features/collections/field_editors/built_in_field_editors.dart';
import 'package:morkva_crm/api/data/data_repository.dart';

// ---------------------------------------------------------------------------
// Minimal fake repository — same pattern as Tasks 8–9 tests.
// ---------------------------------------------------------------------------

class _FakeRepo implements DataRepository {
  _FakeRepo(this._c);
  final Collection _c;

  @override
  Future<Collection?> getCollection(String id) async => _c;

  @override
  Future<List<Collection>> getCollections() async => [_c];

  @override
  Future<void> saveCollection(Collection c) async {}

  @override
  noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

// ---------------------------------------------------------------------------
// Fixture: s1 → r1[f1], r2[f2]; wide (720 px).
// ---------------------------------------------------------------------------

const _collection = Collection(
  id: 'c1',
  name: 'Orders',
  fields: [
    TextFieldDefinition(id: 'f1', name: 'A'),
    TextFieldDefinition(id: 'f2', name: 'B'),
  ],
  layout: CardLayout(
    sections: [
      LayoutSection(
        id: 's1',
        rows: [
          LayoutRow(id: 'r1', cells: [LayoutCell(fieldId: 'f1', span: 12)]),
          LayoutRow(id: 'r2', cells: [LayoutCell(fieldId: 'f2', span: 12)]),
        ],
      ),
    ],
  ),
);

Future<CollectionEditorCubit> _buildAndPump(WidgetTester tester) async {
  final cubit = CollectionEditorCubit(
    _FakeRepo(_collection),
    defaultFieldEditorRegistry(),
  );
  await cubit.load('c1');
  addTearDown(cubit.close);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 720,
            child: BlocProvider.value(
              value: cubit,
              child: BlocBuilder<CollectionEditorCubit, CollectionEditorState>(
                builder: (context, state) {
                  final collection = state is CollectionEditorReady
                      ? state.draft
                      : _collection;
                  return CardPreview(
                    collection: collection,
                    registry: defaultFieldEditorRegistry(),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return cubit;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // ── 1. Collapse ─────────────────────────────────────────────────────────────

  testWidgets('collapse_s1 key exists and toggling it collapses the section', (
    tester,
  ) async {
    final cubit = await _buildAndPump(tester);

    expect(find.byKey(const Key('collapse_s1')), findsOneWidget);

    await tester.tap(find.byKey(const Key('collapse_s1')));
    await tester.pump();

    final layout =
        (cubit.state as CollectionEditorReady).draft.layout;
    expect(
      layout.sections.single.collapsed,
      isTrue,
      reason: 'section should be collapsed after tapping the chevron',
    );
  });

  // ── 2. Add section ───────────────────────────────────────────────────────────

  testWidgets('add_section button exists and adds a second section', (
    tester,
  ) async {
    final cubit = await _buildAndPump(tester);

    expect(find.byKey(const Key('add_section')), findsOneWidget);

    await tester.tap(find.byKey(const Key('add_section')));
    await tester.pump();

    final layout =
        (cubit.state as CollectionEditorReady).draft.layout;
    expect(
      layout.sections.length,
      2,
      reason: 'a second section should have been added',
    );
  });

  // ── 3. Delete section (re-homes rows, nothing orphaned) ──────────────────────

  testWidgets(
    'delete_<s2id> removes section 2 and re-homes its rows into s1',
    (tester) async {
      final cubit = await _buildAndPump(tester);

      // Add a second section first.
      await tester.tap(find.byKey(const Key('add_section')));
      await tester.pump();

      final s2 =
          (cubit.state as CollectionEditorReady).draft.layout.sections[1].id;

      // After pump the delete button for s2 should be present.
      expect(find.byKey(Key('delete_$s2')), findsOneWidget);

      await tester.tap(find.byKey(Key('delete_$s2')));
      await tester.pump();

      final layout =
          (cubit.state as CollectionEditorReady).draft.layout;
      expect(
        layout.sections.length,
        1,
        reason: 'second section should have been deleted',
      );
      expect(
        layout.fieldIds.toSet(),
        {'f1', 'f2'},
        reason: 'all fields must still be present (nothing orphaned)',
      );
    },
  );

  // ── 4. Delete hidden when only one section ────────────────────────────────────

  testWidgets(
    'delete button is hidden when there is only one section',
    (tester) async {
      await _buildAndPump(tester);
      expect(find.byKey(const Key('delete_s1')), findsNothing);
    },
  );

  // ── 5. Rename section (bonus) ─────────────────────────────────────────────────

  testWidgets('tapping section title opens inline TextField for rename', (
    tester,
  ) async {
    final cubit = await _buildAndPump(tester);

    // The section has no title — the muted placeholder "Untitled section" is shown.
    expect(find.text('Untitled section'), findsOneWidget);

    // Tap it to enter rename mode.
    await tester.tap(find.text('Untitled section'));
    await tester.pump();

    // A TextField should now be visible.
    expect(
      find.byType(TextField),
      findsOneWidget,
      reason: 'tapping section title should open a rename TextField',
    );

    // Type a new name and submit.
    await tester.enterText(find.byType(TextField), 'Details');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    final layout =
        (cubit.state as CollectionEditorReady).draft.layout;
    expect(
      layout.sections.single.title,
      'Details',
      reason: 'renameSection should have been called with the new title',
    );
  });
}
