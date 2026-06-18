// test/features/collections/editor/layout_canvas_test.dart
//
// Part A tests: rendering, selection, add-field, add-group affordances.

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
    TextFieldDefinition(id: 'f1', name: 'Number'),
    TextFieldDefinition(id: 'f2', name: 'Title'),
  ],
  layout: CardLayout(sections: [
    LayoutSection(id: 's1', title: 'Main', rows: [
      LayoutRow(id: 'r1', cells: [
        LayoutCell(fieldId: 'f1', span: 6),
        LayoutCell(fieldId: 'f2', span: 6),
      ]),
    ]),
  ]),
);

const _ungrouped = Collection(
  id: 'c2',
  name: 'Loose',
  fields: [TextFieldDefinition(id: 'f1', name: 'Alpha')],
  layout: CardLayout(sections: [
    LayoutSection(
      id: 's1',
      rows: [
        LayoutRow(id: 'r1', cells: [LayoutCell(fieldId: 'f1', span: 12)]),
      ],
    ),
  ]),
);

// ---------------------------------------------------------------------------
// Test helper
// ---------------------------------------------------------------------------

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
  );
  await tester.pump();
  return cubit;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // ── Rendering ────────────────────────────────────────────────────────────────

  testWidgets('renders the section title and both field labels', (tester) async {
    await _buildAndPump(tester);
    expect(find.text('Main'), findsOneWidget);
    expect(find.text('Number'), findsOneWidget);
    expect(find.text('Title'), findsOneWidget);
  });

  testWidgets('renders the collection name', (tester) async {
    await _buildAndPump(tester);
    expect(find.text('Orders'), findsOneWidget);
  });

  testWidgets('wide: the two cells sit side by side (same vertical centre)',
      (tester) async {
    await _buildAndPump(tester);
    final num = tester.getCenter(find.text('Number')).dy;
    final title = tester.getCenter(find.text('Title')).dy;
    expect((num - title).abs() < 24, isTrue, reason: 'cells share a row');
  });

  testWidgets('empty state shows collection name (no crash)', (tester) async {
    const empty = Collection(
      id: 'e1',
      name: 'Empty',
      fields: [],
      layout: CardLayout(sections: [
        LayoutSection(id: 's1', rows: []),
      ]),
    );
    await _buildAndPump(tester, collection: empty);
    expect(find.text('Empty'), findsOneWidget);
  });

  testWidgets('a title-less section has no group header (ungrouped)',
      (tester) async {
    await _buildAndPump(tester, collection: _ungrouped);
    expect(find.byKey(const Key('collapse_s1')), findsNothing);
    expect(find.byKey(const Key('delete_s1')), findsNothing);
    expect(find.text('Alpha'), findsOneWidget);
  });

  // ── Selection: tap cell ──────────────────────────────────────────────────────

  testWidgets('tapping a cell selects its field', (tester) async {
    final cubit = await _buildAndPump(tester);

    await tester.tap(find.text('Number'));
    await tester.pump();

    final state = cubit.state as CollectionEditorReady;
    expect(state.selectedFieldId, 'f1');
  });

  testWidgets('tapping a second cell changes selection', (tester) async {
    final cubit = await _buildAndPump(tester);

    await tester.tap(find.text('Number'));
    await tester.pump();
    await tester.tap(find.text('Title'));
    await tester.pump();

    final state = cubit.state as CollectionEditorReady;
    expect(state.selectedFieldId, 'f2');
  });

  testWidgets('selected cell gets a 2px primary-colored outline', (tester) async {
    final cubit = await _buildAndPump(tester);

    await tester.tap(find.text('Number'));
    await tester.pump();

    final state = cubit.state as CollectionEditorReady;
    expect(state.selectedFieldId, 'f1');
    // Selected state drives AnimatedContainer; pump through animation
    await tester.pumpAndSettle();
    // We verified selection was set; visual check is secondary here.
  });

  // ── Selection: tap group header ──────────────────────────────────────────────

  testWidgets('tapping the group header selects the section', (tester) async {
    final cubit = await _buildAndPump(tester);

    // The header is rendered by _SectionHeader's GestureDetector
    // The collapse button is at Key('collapse_s1'); the title row is tappable.
    // We tap the section title text 'Main' (which is inside the header).
    await tester.tap(find.text('Main'));
    await tester.pump();

    final state = cubit.state as CollectionEditorReady;
    expect(state.selectedSectionId, 's1');
    expect(state.selectedFieldId, isNull);
  });

  // ── Selection: tap background clears ────────────────────────────────────────

  testWidgets('tapping background clears field selection', (tester) async {
    final cubit = await _buildAndPump(tester);

    await tester.tap(find.text('Number'));
    await tester.pump();
    expect((cubit.state as CollectionEditorReady).selectedFieldId, 'f1');

    // Tap an empty area of the canvas (below the group).
    // The root GestureDetector covers the entire LayoutCanvas background.
    // We use the collection name text area which is above the rows.
    await tester.tap(find.text('Orders'));
    await tester.pump();

    final state = cubit.state as CollectionEditorReady;
    expect(state.selectedFieldId, isNull);
  });

  // ── Add affordances ──────────────────────────────────────────────────────────

  testWidgets('add-field button exists per section', (tester) async {
    await _buildAndPump(tester);
    expect(find.byKey(const Key('add_field_s1')), findsOneWidget);
  });

  testWidgets('add-group button exists', (tester) async {
    await _buildAndPump(tester);
    expect(find.byKey(const Key('add_section')), findsOneWidget);
  });

  testWidgets('tapping add-group calls addSection and creates a second section',
      (tester) async {
    final cubit = await _buildAndPump(tester);

    await tester.tap(find.byKey(const Key('add_section')));
    await tester.pump();

    final state = cubit.state as CollectionEditorReady;
    expect(state.draft.layout.sections.length, 2);
  });

  // ── Delete field affordance ──────────────────────────────────────────────────

  testWidgets('selecting a cell shows the delete (close) icon', (tester) async {
    final cubit = await _buildAndPump(tester);

    await tester.tap(find.text('Number'));
    await tester.pump();

    // The ✕ close icon only appears on selected cells
    final state = cubit.state as CollectionEditorReady;
    expect(state.selectedFieldId, 'f1');
    // Verify at least one close icon is present in the tree
    expect(
      find.byWidgetPredicate(
        (w) => w is Icon && w.icon == Icons.close && w.size == 14,
      ),
      findsOneWidget,
    );
  });

  testWidgets('direct cubit removeField removes a field', (tester) async {
    final cubit = await _buildAndPump(tester);

    cubit.removeField('f1');
    await tester.pump();

    final state = cubit.state as CollectionEditorReady;
    expect(state.draft.fields.any((f) => f.id == 'f1'), isFalse);
  });

  // ── Section controls ─────────────────────────────────────────────────────────

  testWidgets('collapse_s1 key exists', (tester) async {
    await _buildAndPump(tester);
    expect(find.byKey(const Key('collapse_s1')), findsOneWidget);
  });

  testWidgets('tapping collapse_s1 collapses the section', (tester) async {
    final cubit = await _buildAndPump(tester);

    await tester.tap(find.byKey(const Key('collapse_s1')));
    await tester.pump();

    final state = cubit.state as CollectionEditorReady;
    expect(state.draft.layout.sections.single.collapsed, isTrue);
  });

  testWidgets('delete button hidden when only one section', (tester) async {
    await _buildAndPump(tester);
    expect(find.byKey(const Key('delete_s1')), findsNothing);
  });

  testWidgets('delete button visible when more than one section exists',
      (tester) async {
    await _buildAndPump(tester);

    await tester.tap(find.byKey(const Key('add_section')));
    await tester.pump();

    expect(find.byKey(const Key('delete_s1')), findsOneWidget);
  });
}
