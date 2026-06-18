// test/features/collections/editor/layout_canvas_resize_test.dart
//
// Part C tests: edge-resize handle changes cell span but does NOT trigger
// a field move.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/features/collections/editor/layout_canvas.dart';
import 'package:morkva_crm/features/collections/editor/collection_editor_cubit.dart';
import 'package:morkva_crm/features/collections/editor/collection_editor_state.dart';
import 'package:morkva_crm/features/collections/field_editors/built_in_field_editors.dart';
import 'package:morkva_crm/api/data/data_repository.dart';

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

const _twoCell = Collection(
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
            cells: [
              LayoutCell(fieldId: 'f1', span: 6),
              LayoutCell(fieldId: 'f2', span: 6),
            ],
          ),
        ],
      ),
    ],
  ),
);

Future<CollectionEditorCubit> _buildAndPump(WidgetTester tester) async {
  final cubit = CollectionEditorCubit(
    _FakeRepo(_twoCell),
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
                      : _twoCell;
                  return LayoutCanvas(
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

void main() {
  // ── Resize handle exists ─────────────────────────────────────────────────────

  testWidgets('resize handle key exists for first (non-last) cell', (
    tester,
  ) async {
    await _buildAndPump(tester);
    expect(find.byKey(const Key('resize_r1_f1')), findsOneWidget);
  });

  testWidgets('resize handle does NOT exist on last cell in row', (
    tester,
  ) async {
    await _buildAndPump(tester);
    // f2 is the last cell in row r1 — no handle
    expect(find.byKey(const Key('resize_r1_f2')), findsNothing);
  });

  testWidgets('resize handle does NOT exist on a single-cell (full-width) row',
      (tester) async {
    const singleCell = Collection(
      id: 'c2',
      name: 'Single',
      fields: [TextFieldDefinition(id: 'f1', name: 'Only')],
      layout: CardLayout(sections: [
        LayoutSection(id: 's1', rows: [
          LayoutRow(id: 'r1', cells: [LayoutCell(fieldId: 'f1', span: 12)]),
        ]),
      ]),
    );
    final cubit = CollectionEditorCubit(
      _FakeRepo(singleCell),
      defaultFieldEditorRegistry(),
    );
    await cubit.load('c2');
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
                    final c = state is CollectionEditorReady
                        ? state.draft
                        : singleCell;
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
    );
    await tester.pump();

    expect(find.byKey(const Key('resize_r1_f1')), findsNothing);
  });

  // ── Dragging the handle changes span ────────────────────────────────────────

  testWidgets('dragging a cell resize handle left shrinks its span', (
    tester,
  ) async {
    final cubit = await _buildAndPump(tester);

    final initialSpan = (cubit.state as CollectionEditorReady)
        .draft
        .layout
        .sections
        .single
        .rows
        .single
        .cells
        .firstWhere((c) => c.fieldId == 'f1')
        .span;

    await tester.drag(
      find.byKey(const Key('resize_r1_f1')),
      const Offset(-120, 0),
    );
    await tester.pump();

    final f1 = (cubit.state as CollectionEditorReady)
        .draft
        .layout
        .sections
        .single
        .rows
        .single
        .cells
        .firstWhere((c) => c.fieldId == 'f1');

    expect(f1.span < initialSpan, isTrue,
        reason: 'dragging left should reduce span');
  });

  testWidgets('dragging a cell resize handle right increases its span', (
    tester,
  ) async {
    final cubit = await _buildAndPump(tester);

    final initialSpan = (cubit.state as CollectionEditorReady)
        .draft
        .layout
        .sections
        .single
        .rows
        .single
        .cells
        .firstWhere((c) => c.fieldId == 'f1')
        .span;

    await tester.drag(
      find.byKey(const Key('resize_r1_f1')),
      const Offset(120, 0),
    );
    await tester.pump();

    final f1 = (cubit.state as CollectionEditorReady)
        .draft
        .layout
        .sections
        .single
        .rows
        .single
        .cells
        .firstWhere((c) => c.fieldId == 'f1');

    expect(f1.span > initialSpan, isTrue,
        reason: 'dragging right should increase span');
  });

  // ── Resize does NOT trigger a field move ────────────────────────────────────

  testWidgets('edge drag does NOT move the field out of its row', (
    tester,
  ) async {
    final cubit = await _buildAndPump(tester);

    await tester.drag(
      find.byKey(const Key('resize_r1_f1')),
      const Offset(-120, 0),
    );
    await tester.pump();

    // f1 must still be in r1 (not orphaned or moved)
    final layout = (cubit.state as CollectionEditorReady).draft.layout;
    final r1 = layout.sections.single.rows.firstWhere((r) => r.id == 'r1');
    expect(r1.cells.any((c) => c.fieldId == 'f1'), isTrue,
        reason: 'f1 must still be in r1 after resize');
    // Total cells in r1 should still be 2
    expect(r1.cells.length, 2,
        reason: 'row should still have two cells after resize');
  });
}
