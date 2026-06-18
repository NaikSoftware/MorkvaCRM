// test/features/collections/editor/layout_canvas_dnd_test.dart
//
// Part B tests: drag-and-drop for field cells, rows, and sections.

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
// Fake repo
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

// Two fields in two separate rows, one section.
const _twoRows = Collection(
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

// Two named sections for section reorder test.
const _twoSections = Collection(
  id: 'c2',
  name: 'Multi',
  fields: [
    TextFieldDefinition(id: 'f1', name: 'Alpha'),
    TextFieldDefinition(id: 'f2', name: 'Beta'),
  ],
  layout: CardLayout(
    sections: [
      LayoutSection(
        id: 's1',
        title: 'First',
        rows: [
          LayoutRow(id: 'r1', cells: [LayoutCell(fieldId: 'f1', span: 12)]),
        ],
      ),
      LayoutSection(
        id: 's2',
        title: 'Second',
        rows: [
          LayoutRow(id: 'r2', cells: [LayoutCell(fieldId: 'f2', span: 12)]),
        ],
      ),
    ],
  ),
);

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

Future<CollectionEditorCubit> _build(
  WidgetTester tester,
  Collection collection,
) async {
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
// Structural key tests
// ---------------------------------------------------------------------------

void main() {
  testWidgets('row drop target key rowdrop_r1 exists', (tester) async {
    await _build(tester, _twoRows);
    expect(find.byKey(const Key('rowdrop_r1')), findsOneWidget);
  });

  testWidgets('between-row drop target key newrowdrop_s1_0 exists',
      (tester) async {
    await _build(tester, _twoRows);
    expect(find.byKey(const Key('newrowdrop_s1_0')), findsOneWidget);
  });

  testWidgets('between-row drop target at tail exists (newrowdrop_s1_2)',
      (tester) async {
    await _build(tester, _twoRows);
    expect(find.byKey(const Key('newrowdrop_s1_2')), findsOneWidget);
  });

  // ---------------------------------------------------------------------------
  // Cubit-level wiring tests (direct calls verify moveCellToRow semantics)
  // ---------------------------------------------------------------------------

  test('cubit.moveCellToRow moves f2 into r1 at index 1', () async {
    final cubit = CollectionEditorCubit(
      _FakeRepo(_twoRows),
      defaultFieldEditorRegistry(),
    );
    await cubit.load('c1');
    addTearDown(cubit.close);

    cubit.moveCellToRow('f2', 'r1', 1);

    final layout = (cubit.state as CollectionEditorReady).draft.layout;
    final r1 = layout.sections.single.rows.firstWhere((r) => r.id == 'r1');
    expect(r1.cells.length, 2);
    expect(r1.cells.any((c) => c.fieldId == 'f2'), isTrue);
  });

  test('cubit.moveCellToNewRow creates new row with the field', () async {
    final cubit = CollectionEditorCubit(
      _FakeRepo(_twoRows),
      defaultFieldEditorRegistry(),
    );
    await cubit.load('c1');
    addTearDown(cubit.close);

    // Move f2 to a new row at index 0 (before r1)
    cubit.moveCellToNewRow('f2', 's1', 0);

    final layout = (cubit.state as CollectionEditorReady).draft.layout;
    expect(layout.sections.single.rows.length, 2);
    expect(layout.sections.single.rows.first.cells.single.fieldId, 'f2');
  });

  test('cubit.reorderSections reorders two sections', () async {
    final cubit = CollectionEditorCubit(
      _FakeRepo(_twoSections),
      defaultFieldEditorRegistry(),
    );
    await cubit.load('c2');
    addTearDown(cubit.close);

    cubit.reorderSections(0, 2); // move s1 after s2

    final layout = (cubit.state as CollectionEditorReady).draft.layout;
    expect(layout.sections.first.id, 's2');
    expect(layout.sections.last.id, 's1');
  });

  test('cubit.moveRowToSection moves row to another section', () async {
    final cubit = CollectionEditorCubit(
      _FakeRepo(_twoSections),
      defaultFieldEditorRegistry(),
    );
    await cubit.load('c2');
    addTearDown(cubit.close);

    cubit.moveRowToSection('r1', 's2', 0);

    final layout = (cubit.state as CollectionEditorReady).draft.layout;
    final s1 = layout.sections.firstWhere((s) => s.id == 's1');
    final s2 = layout.sections.firstWhere((s) => s.id == 's2');
    expect(s1.rows.isEmpty, isTrue,
        reason: 'r1 should have left s1');
    expect(s2.rows.any((r) => r.id == 'r1'), isTrue,
        reason: 'r1 should now be in s2');
  });

  // ---------------------------------------------------------------------------
  // Widget-gesture drag test — immediate Draggable (no long press)
  // ---------------------------------------------------------------------------

  testWidgets(
      'immediate drag: dragging cell B onto rowdrop_r1 joins it into row r1',
      (tester) async {
    final cubit = await _build(tester, _twoRows);

    // Use a gesture that mimics Draggable (pan-start immediately, no long press)
    final cellBCenter = tester.getCenter(find.text('B'));
    final dropCenter = tester.getCenter(find.byKey(const Key('rowdrop_r1')));

    final g = await tester.startGesture(cellBCenter);
    await tester.pump(const Duration(milliseconds: 50));
    await g.moveBy(const Offset(10, 0)); // start the pan
    await tester.pump();
    await g.moveTo(dropCenter);
    await tester.pump();
    await g.up();
    await tester.pump();
    await tester.pumpAndSettle();

    final layout = (cubit.state as CollectionEditorReady).draft.layout;
    final r1 = layout.sections.single.rows.firstWhere((r) => r.id == 'r1');
    expect(
      r1.cells.any((c) => c.fieldId == 'f2'),
      isTrue,
      reason: 'f2 should have joined r1 after the drag',
    );
  });

  // ---------------------------------------------------------------------------
  // Self-drop regression: dropping a lone field on its own row must not lose it
  // ---------------------------------------------------------------------------

  test('self-drop (moveCellToRow onto own single-cell row) is a no-op', () async {
    final cubit = CollectionEditorCubit(
      _FakeRepo(_twoRows),
      defaultFieldEditorRegistry(),
    );
    await cubit.load('c1');
    addTearDown(cubit.close);

    // r1 has only f1; dropping f1 onto r1 is a no-op (domain detects this)
    final before = (cubit.state as CollectionEditorReady).draft.layout;
    cubit.moveCellToRow('f1', 'r1', 0);
    final after = (cubit.state as CollectionEditorReady).draft.layout;

    // f1 must still be present somewhere in the layout
    expect(after.fieldIds.contains('f1'), isTrue,
        reason: 'self-drop must not orphan the field');
    // Layout should be unchanged (domain returns this)
    expect(after, equals(before));
  });

  // ---------------------------------------------------------------------------
  // DragTarget accept-wiring: rowdrop highlights on hover
  // ---------------------------------------------------------------------------

  testWidgets('rowdrop_r1 slot highlights when a field cell hovers over it',
      (tester) async {
    await _build(tester, _twoRows);

    final cellBCenter = tester.getCenter(find.text('B'));
    final dropCenter = tester.getCenter(find.byKey(const Key('rowdrop_r1')));

    final g = await tester.startGesture(cellBCenter);
    await tester.pump(const Duration(milliseconds: 50));
    await g.moveBy(const Offset(10, 0));
    await tester.pump();
    await g.moveTo(dropCenter);
    await tester.pump();

    // The _RowDropTarget's DragTarget should have candidateData
    // The AnimatedContainer inside should have a non-transparent color
    final dropTargetFinder = find.byKey(const Key('rowdrop_r1'));
    final animatedContainers = find.descendant(
      of: dropTargetFinder,
      matching: find.byType(AnimatedContainer),
    );
    expect(animatedContainers, findsOneWidget);

    final container =
        tester.widget<AnimatedContainer>(animatedContainers);
    final decoration = container.decoration as BoxDecoration?;
    expect(
      decoration?.color,
      isNotNull,
      reason: '_RowDropTarget should carry a non-null color when active',
    );

    await g.up();
    await tester.pump();
  });

  // ---------------------------------------------------------------------------
  // Between-section DragTargets exist when there are multiple sections
  // ---------------------------------------------------------------------------

  testWidgets('between-section drop targets exist with two sections',
      (tester) async {
    await _build(tester, _twoSections);
    // Between-row drop targets exist for each section
    // s1 has r1 → targets at index 0 and 1; s2 has r2 → targets at 0 and 1
    expect(find.byKey(const Key('newrowdrop_s1_0')), findsOneWidget);
    expect(find.byKey(const Key('newrowdrop_s2_0')), findsOneWidget);
  });
}
