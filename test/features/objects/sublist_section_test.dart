import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/api/api.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/design/design.dart';
import 'package:morkva_crm/features/objects/object_editor.dart';
import 'package:morkva_crm/features/objects/widgets/sublist_section.dart';

import '../collections/fake_data_repository.dart';

const _orders = Collection(
  id: 'orders',
  name: 'Orders',
  fields: [TextFieldDefinition(id: 'customer', name: 'Customer')],
);

const _items = Collection(
  id: 'items',
  name: 'Order items',
  fields: [
    TextFieldDefinition(id: 'what', name: 'What'),
    ReferenceFieldDefinition(
      id: 'order',
      name: 'Order',
      targetCollectionId: 'orders',
    ),
    SingleSelectFieldDefinition(
      id: 'size',
      name: 'Size',
      options: [SelectOption(id: 'm', label: 'M')],
    ),
    NumberFieldDefinition(id: 'qty', name: 'Quantity'),
    BooleanFieldDefinition(id: 'done', name: 'Done'),
  ],
);

final _t = DateTime.utc(2026, 11, 7);

MorkvaObject _o(String id, Collection c, Map<String, FieldValue> values) =>
    MorkvaObject.create(
      id: id,
      collection: c,
      values: values,
      createdAt: _t,
      updatedAt: _t,
    );

void main() {
  late FakeDataRepository repo;
  final order = _o('o1', _orders, {'customer': const TextFieldValue('Olena')});

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    repo = FakeDataRepository([_orders, _items])
      ..seedObjects('orders', [order])
      ..seedObjects('items', [
        _o('i1', _items, {
          'what': const TextFieldValue('Hoodie, "Lviv" on chest'),
          'order': const ReferenceFieldValue(['o1']),
          'size': const SingleSelectFieldValue('m'),
          'qty': const NumberFieldValue(2),
        }),
      ]);
    await tester.pumpWidget(
      RepositoryProvider<DataRepository>.value(
        value: repo,
        child: MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showObjectEditor(
                  context,
                  collection: _orders,
                  object: order,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows linked items with pills, number and done state', (
    tester,
  ) async {
    await open(tester);
    expect(
      find.textContaining('Order items', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('0 of 1 done', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Hoodie, "Lviv" on chest'), findsOneWidget);
    expect(find.text('M'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    expect(
      repo.objectsOf('items').single['done'],
      const BooleanFieldValue(true),
    );
    expect(
      find.textContaining('1 of 1 done', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('Add opens the item form linked to this object', (tester) async {
    await open(tester);
    await tester.tap(find.text('Add order item'));
    await tester.pumpAndSettle();
    expect(find.text('New order item'), findsOneWidget);
    expect(find.text('Linked to this order'), findsOneWidget);
    final itemForm = find.byType(ObjectEditor).last;
    await tester.enterText(
      find.descendant(of: itemForm, matching: find.byType(TextField)).first,
      'Cap',
    );
    // The item form is the top dialog: its Save is the last one.
    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();
    final added = repo.objectsOf('items').where((o) => o.id != 'i1').single;
    expect(added['order'], const ReferenceFieldValue(['o1']));
    expect(
      find.textContaining('0 of 2 done', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('closing the item form keeps the object and its items', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('Add order item'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('New order item'), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(ObjectEditor), findsNothing);
    expect(repo.objectsOf('orders').map((o) => o.id), ['o1']);
    expect(repo.objectsOf('items').map((o) => o.id), ['i1']);
  });

  testWidgets('deleting an item from its form removes only the item', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('Hoodie, "Lviv" on chest'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last); // confirm
    await tester.pumpAndSettle();
    expect(repo.objectsOf('items'), isEmpty);
    expect(repo.objectsOf('orders').map((o) => o.id), ['o1']);
    expect(find.byType(ObjectEditor), findsOneWidget);
    expect(
      find.textContaining('0 of 0 done', findRichText: true),
      findsNothing,
    );
  });

  test('a row is titled by the first filled field, not typed text', () {
    const garments = Collection(
      id: 'items',
      name: 'Order items',
      fields: [
        SingleSelectFieldDefinition(
          id: 'garment',
          name: 'Garment',
          options: [SelectOption(id: 'hoodie', label: 'Hoodie')],
        ),
        SingleSelectFieldDefinition(
          id: 'size',
          name: 'Size',
          options: [SelectOption(id: 'm', label: 'M')],
        ),
        TextFieldDefinition(id: 'note', name: 'Embroidery'),
        ReferenceFieldDefinition(
          id: 'order',
          name: 'Order',
          targetCollectionId: 'orders',
        ),
        NumberFieldDefinition(id: 'qty', name: 'Quantity'),
        BooleanFieldDefinition(id: 'done', name: 'Done'),
        CalculatedFieldDefinition(
          id: 'status',
          name: 'Order status',
          declaredOutputType: kTextFieldType,
          lookup: Lookup(referenceFieldId: 'order', fieldId: 'status'),
        ),
      ],
    );
    final row = SublistRow.of(
      garments,
      _o('i1', garments, {
        'garment': const SingleSelectFieldValue('hoodie'),
        'size': const SingleSelectFieldValue('m'),
        'note': const TextFieldValue('"Lviv" on chest'),
        'order': const ReferenceFieldValue(['o1']),
        'qty': const NumberFieldValue(2),
        'done': const BooleanFieldValue(true),
        'status': const CalculatedFieldValue('New'),
      }),
      viaFieldId: 'order',
    );
    expect(row.title, 'Hoodie');
    expect([for (final p in row.pills) p.label], ['M']);
    expect(row.note, '"Lviv" on chest');
    expect(row.amount, ('Quantity', '2'));

    final empty = SublistRow.of(
      garments,
      _o('i2', garments, {'size': const SingleSelectFieldValue('m')}),
      viaFieldId: 'order',
    );
    expect(empty.title, 'M');
    expect(empty.pills, isEmpty);
  });
}
