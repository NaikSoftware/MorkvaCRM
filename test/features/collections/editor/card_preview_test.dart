// test/features/collections/editor/card_preview_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/features/collections/editor/card_preview.dart';
import 'package:morkva_crm/features/collections/field_editors/built_in_field_editors.dart';

Widget _host(Collection c, {double width = 1000}) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: CardPreview(collection: c, registry: defaultFieldEditorRegistry()),
          ),
        ),
      ),
    );

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
        LayoutCell(fieldId: 'f1', span: 2),
        LayoutCell(fieldId: 'f2', span: 10),
      ]),
    ]),
  ]),
);

void main() {
  testWidgets('renders the section title and both field labels', (tester) async {
    await tester.pumpWidget(_host(_collection));
    expect(find.text('Main'), findsOneWidget);
    expect(find.text('Number'), findsOneWidget);
    expect(find.text('Title'), findsOneWidget);
  });

  testWidgets('wide: the two cells sit side by side (same vertical centre)',
      (tester) async {
    await tester.pumpWidget(_host(_collection, width: 1000));
    final num = tester.getCenter(find.text('Number')).dy;
    final title = tester.getCenter(find.text('Title')).dy;
    expect((num - title).abs() < 24, isTrue, reason: 'cells share a row');
  });

  testWidgets('narrow: cells stack (Title clearly below Number)',
      (tester) async {
    await tester.pumpWidget(_host(_collection, width: 360));
    final num = tester.getCenter(find.text('Number')).dy;
    final title = tester.getCenter(find.text('Title')).dy;
    expect(title > num + 24, isTrue, reason: 'cells stacked full-width');
  });
}
