// test/features/collections/editor/card_preview_dnd_test.dart
//
// Task 9 — drag-and-drop tests for the wide-mode card preview canvas.
//
// RED phase: the DragTarget keys `rowdrop_r1` and `newrowdrop_s1_0` do not
// exist yet — the first two tests verify they are wired once implemented.
// The widget-gesture test is the primary TDD test.

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
// Minimal fake repository — same pattern used by the resize test.
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
// Shared fixture — layout: s1 → r1[f1(A)], r2[f2(B)], wide (720 px)
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
          LayoutRow(
            id: 'r1',
            cells: [LayoutCell(fieldId: 'f1', span: 12)],
          ),
          LayoutRow(
            id: 'r2',
            cells: [LayoutCell(fieldId: 'f2', span: 12)],
          ),
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
  return cubit;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // ── Structural keys ────────────────────────────────────────────────────────

  testWidgets('row drop target key rowdrop_r1 exists in wide mode', (
    tester,
  ) async {
    await _buildAndPump(tester);
    expect(find.byKey(const Key('rowdrop_r1')), findsOneWidget);
  });

  testWidgets('between-row drop target key newrowdrop_s1_0 exists', (
    tester,
  ) async {
    await _buildAndPump(tester);
    expect(find.byKey(const Key('newrowdrop_s1_0')), findsOneWidget);
  });

  // ── Widget-gesture drag test ───────────────────────────────────────────────
  //
  // Drag cell B (f2) from row r2 onto the rowdrop_r1 slot.
  // After the gesture, r1 should contain both f1 and f2.

  testWidgets('dragging cell B onto rowdrop_r1 joins it into row r1', (
    tester,
  ) async {
    final cubit = await _buildAndPump(tester);

    // Long-press the f2 label to arm the LongPressDraggable.
    final g = await tester.startGesture(tester.getCenter(find.text('B')));
    await tester.pump(const Duration(milliseconds: 600)); // arm long-press
    await tester.pump(); // start drag

    // Slide to the rowdrop_r1 target.
    final dropCenter = tester.getCenter(find.byKey(const Key('rowdrop_r1')));
    await g.moveTo(dropCenter);
    await tester.pump();
    await g.up();
    await tester.pump();

    final layout = (cubit.state as CollectionEditorReady).draft.layout;
    final r1 = layout.sections.single.rows.firstWhere((r) => r.id == 'r1');
    expect(
      r1.cells.any((c) => c.fieldId == 'f2'),
      isTrue,
      reason: 'f2 should have joined r1 after the drag',
    );
  });

  // ── Drop-slot highlight activates on hover ─────────────────────────────────
  //
  // Verifies that onWillAcceptWithDetails is wired: hovering the rowdrop_r1
  // target during a drag populates candidateData → the _DropSlot AnimatedContainer
  // switches from transparent to a coloured decoration.

  testWidgets('rowdrop_r1 slot highlights when cell hovers over it', (
    tester,
  ) async {
    await _buildAndPump(tester);

    // Start long-press drag on cell B (f2).
    final g = await tester.startGesture(tester.getCenter(find.text('B')));
    await tester.pump(const Duration(milliseconds: 600)); // arm long-press
    await tester.pump(); // start drag

    // Move over the rowdrop_r1 target (do NOT release).
    final dropCenter = tester.getCenter(find.byKey(const Key('rowdrop_r1')));
    await g.moveTo(dropCenter);
    await tester.pump();

    // The _DropSlot vertical strip is an AnimatedContainer rendered inside
    // DragTarget. When active==true its decoration colour is non-transparent.
    // Find all AnimatedContainers in the subtree of the DragTarget key.
    final dropTargetFinder = find.byKey(const Key('rowdrop_r1'));
    final animatedContainers = find.descendant(
      of: dropTargetFinder,
      matching: find.byType(AnimatedContainer),
    );
    expect(animatedContainers, findsOneWidget);

    final container = tester.widget<AnimatedContainer>(animatedContainers);
    final decoration = container.decoration as BoxDecoration?;
    expect(
      decoration?.color,
      isNotNull,
      reason: '_DropSlot should carry a non-null colour when active',
    );
    expect(
      decoration!.color,
      isNot(Colors.transparent),
      reason: '_DropSlot color should be non-transparent while hovering',
    );

    await g.up();
    await tester.pump();
  });

  // ── Cubit-level backup: direct call verifies moveCellToRow semantics ───────

  test('cubit.moveCellToRow moves f2 into r1 at index 1', () async {
    final cubit = CollectionEditorCubit(
      _FakeRepo(_collection),
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
}
