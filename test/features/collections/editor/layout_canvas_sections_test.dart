// test/features/collections/editor/layout_canvas_sections_test.dart
//
// Part A/section tests: collapse/rename/delete/add-group behavior.
// Ported from card_preview_sections_test.dart, updated for LayoutCanvas.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/features/collections/editor/layout_canvas.dart';
import 'package:morkva_crm/features/collections/editor/collection_editor_cubit.dart';
import 'package:morkva_crm/features/collections/editor/collection_editor_state.dart';
import 'package:morkva_crm/features/collections/field_editors/built_in_field_editors.dart';
import 'package:morkva_crm/api/data/data_repository.dart';

// ---------------------------------------------------------------------------
// Minimal fake repository
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
// Fixtures
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
        title: 'Main',
        rows: [
          LayoutRow(id: 'r1', cells: [LayoutCell(fieldId: 'f1', span: 12)]),
          LayoutRow(id: 'r2', cells: [LayoutCell(fieldId: 'f2', span: 12)]),
        ],
      ),
    ],
  ),
);

// A title-less collection: the section is the "ungrouped" bucket (no header).
const _ungrouped = Collection(
  id: 'c2',
  name: 'Loose',
  fields: [TextFieldDefinition(id: 'f1', name: 'A')],
  layout: CardLayout(
    sections: [
      LayoutSection(
        id: 's1',
        rows: [
          LayoutRow(id: 'r1', cells: [LayoutCell(fieldId: 'f1', span: 12)]),
        ],
      ),
    ],
  ),
);

Future<CollectionEditorCubit> _buildAndPump(
  WidgetTester tester, {
  Collection collection = _collection,
}) async {
  final cubit = CollectionEditorCubit(
    _FakeRepo(collection),
    defaultFieldEditorRegistry(),
  );
  await cubit.load(collection.id);
  addTearDown(cubit.close);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 720,
            child: SingleChildScrollView(
              child: BlocProvider.value(
                value: cubit,
                child: BlocBuilder<CollectionEditorCubit, CollectionEditorState>(
                  builder: (context, state) {
                    final c = state is CollectionEditorReady
                        ? state.draft
                        : collection;
                    return LayoutCanvas(
                      collection: c,
                      registry: defaultFieldEditorRegistry(),
                    );
                  },
                ),
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

  testWidgets('collapse_s1 key exists and toggling it collapses the section',
      (tester) async {
    final cubit = await _buildAndPump(tester);

    expect(find.byKey(const Key('collapse_s1')), findsOneWidget);

    await tester.tap(find.byKey(const Key('collapse_s1')));
    await tester.pump();

    final layout = (cubit.state as CollectionEditorReady).draft.layout;
    expect(
      layout.sections.single.collapsed,
      isTrue,
      reason: 'section should be collapsed after tapping the chevron',
    );
  });

  // ── 2. Add section ───────────────────────────────────────────────────────────

  testWidgets('add_section button exists and adds a second section',
      (tester) async {
    final cubit = await _buildAndPump(tester);

    expect(find.byKey(const Key('add_section')), findsOneWidget);

    await tester.tap(find.byKey(const Key('add_section')));
    await tester.pump();

    final layout = (cubit.state as CollectionEditorReady).draft.layout;
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

      expect(find.byKey(Key('delete_$s2')), findsOneWidget);

      await tester.tap(find.byKey(Key('delete_$s2')));
      await tester.pump();

      final layout = (cubit.state as CollectionEditorReady).draft.layout;
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

  testWidgets('delete button is hidden when there is only one section',
      (tester) async {
    await _buildAndPump(tester);
    expect(find.byKey(const Key('delete_s1')), findsNothing);
  });

  // ── 5. Rename section ─────────────────────────────────────────────────────────

  testWidgets('tapping a group title opens inline TextField for rename',
      (tester) async {
    final cubit = await _buildAndPump(tester);

    expect(find.text('Main'), findsOneWidget);

    // Tap it to enter rename mode.
    await tester.tap(find.text('Main'));
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

    final layout = (cubit.state as CollectionEditorReady).draft.layout;
    expect(
      layout.sections.single.title,
      'Details',
      reason: 'renameSection should have been called with the new title',
    );
  });

  // ── 6. Ungrouped (title-less) section renders headerless ─────────────────────

  testWidgets('a title-less section has no group header (ungrouped)',
      (tester) async {
    await _buildAndPump(tester, collection: _ungrouped);

    // No collapse chevron and no delete: an ungrouped bucket has no header.
    expect(find.byKey(const Key('collapse_s1')), findsNothing);
    expect(find.byKey(const Key('delete_s1')), findsNothing);
    // But its field still renders.
    expect(find.text('A'), findsOneWidget);
  });
}
