// test/features/collections/editor/card_preview_resize_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/features/collections/editor/card_preview.dart';
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

void main() {
  testWidgets('dragging a cell resize handle shrinks its span', (tester) async {
    const collection = Collection(
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
    final cubit = CollectionEditorCubit(
      _FakeRepo(collection),
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
                child: CardPreview(
                  collection: cubit.state is CollectionEditorReady
                      ? (cubit.state as CollectionEditorReady).draft
                      : collection,
                  registry: defaultFieldEditorRegistry(),
                ),
              ),
            ),
          ),
        ),
      ),
    );

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
    expect(f1.span < 6, isTrue);
  });
}
