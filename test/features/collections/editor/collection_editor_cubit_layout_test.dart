import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/features/collections/editor/collection_editor_cubit.dart';
import 'package:morkva_crm/features/collections/editor/collection_editor_state.dart';
import 'package:morkva_crm/features/collections/field_editors/built_in_field_editors.dart';

import '../fake_data_repository.dart';

void main() {
  late FakeDataRepository repository;
  late CollectionEditorCubit cubit;

  CollectionEditorReady ready() => cubit.state as CollectionEditorReady;

  setUp(() async {
    repository = FakeDataRepository(const [
      Collection(
        id: 'c1',
        name: 'Orders',
        fields: [
          TextFieldDefinition(id: 'f1', name: 'A'),
          TextFieldDefinition(id: 'f2', name: 'B'),
        ],
        layout: CardLayout(sections: [
          LayoutSection(id: 's1', rows: [
            LayoutRow(id: 'r1', cells: [LayoutCell(fieldId: 'f1')]),
            LayoutRow(id: 'r2', cells: [LayoutCell(fieldId: 'f2')]),
          ]),
        ]),
      ),
    ]);
    cubit = CollectionEditorCubit(repository, defaultFieldEditorRegistry());
    await cubit.load('c1');
  });

  tearDown(() async {
    await cubit.close();
    await repository.dispose();
  });

  test('setCellSpan updates the draft layout', () {
    cubit.setCellSpan('r1', 'f1', 4);
    final cell = ready()
        .draft
        .layout
        .sections
        .single
        .rows
        .firstWhere((r) => r.id == 'r1')
        .cells
        .single;
    expect(cell.span, 4);
  });

  test('moveCellToRow joins f2 into r1', () {
    cubit.moveCellToRow('f2', 'r1', 1);
    final r1 = ready()
        .draft
        .layout
        .sections
        .single
        .rows
        .firstWhere((r) => r.id == 'r1');
    expect(r1.cells.map((c) => c.fieldId), ['f1', 'f2']);
  });

  test('addSection mints a section and appends it', () {
    cubit.addSection(title: 'More');
    expect(ready().draft.layout.sections.length, 2);
    expect(ready().draft.layout.sections.last.title, 'More');
  });

  test('addField appends the new field into the layout', () {
    cubit.addField('text');
    expect(
      ready().draft.fields.map((f) => f.id).toSet(),
      ready().draft.layout.fieldIds.toSet(),
    );
    expect(ready().draft.layout.fieldIds.length, 3); // f1, f2, + new
  });

  test('removeField drops its cell from the layout', () {
    cubit.removeField('f1');
    expect(ready().draft.layout.fieldIds.toList(), ['f2']);
  });
}
