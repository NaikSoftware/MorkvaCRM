import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/design/design.dart';
import 'package:morkva_crm/features/collections/field_editors/widgets/calculation_config.dart';

const _orders = Collection(
  id: 'orders',
  name: 'Orders',
  fields: [
    NumberFieldDefinition(id: 'price', name: 'Price'),
    NumberFieldDefinition(id: 'qty', name: 'Qty'),
    ReferenceFieldDefinition(
      id: 'item',
      name: 'Item',
      targetCollectionId: 'items',
    ),
    CalculatedFieldDefinition(
      id: 'total',
      name: 'Total',
      declaredOutputType: 'number',
    ),
  ],
);

const _items = Collection(
  id: 'items',
  name: 'Items',
  fields: [
    TextFieldDefinition(id: 'name', name: 'Name'),
    CalculatedFieldDefinition(
      id: 'reserved',
      name: 'Reserved',
      declaredOutputType: 'number',
    ),
  ],
);

void main() {
  Future<List<CalculatedFieldDefinition>> pump(
    WidgetTester tester,
    Collection owner,
    String fieldId,
  ) async {
    final emitted = <CalculatedFieldDefinition>[];
    var field = owner.fieldById(fieldId)! as CalculatedFieldDefinition;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: CalculationConfig(
                field: field,
                collections: owner.withWorkspace(const [_orders, _items]),
                editingCollectionId: owner.id,
                onChanged: (next) => setState(() {
                  field = next as CalculatedFieldDefinition;
                  emitted.add(field);
                }),
              ),
            ),
          ),
        ),
      ),
    );
    return emitted;
  }

  testWidgets('a typed formula is stored by id and typed as its result', (
    tester,
  ) async {
    final emitted = await pump(tester, _orders, 'total');
    await tester.enterText(
      find.byKey(const ValueKey('formula_total')),
      '{Price} * {Qty}',
    );
    await tester.pump();
    expect(emitted.last.expression, '{price} * {qty}');
    expect(emitted.last.declaredOutputType, 'number');
    expect(find.text('Result: Number'), findsOneWidget);
    // Number results offer decimals and a unit.
    expect(find.text('Decimals'), findsOneWidget);
  });

  testWidgets('insert chips put a field at the cursor; errors show inline', (
    tester,
  ) async {
    final emitted = await pump(tester, _orders, 'total');
    await tester.tap(find.widgetWithText(ActionChip, 'Price'));
    await tester.pump();
    expect(emitted.last.expression, '{price}');
    await tester.enterText(
      find.byKey(const ValueKey('formula_total')),
      '{Nope} + 1',
    );
    await tester.pump();
    expect(find.text('No field named "Nope"'), findsOneWidget);
    // The reference field is not offered for insertion.
    expect(find.widgetWithText(ActionChip, 'Item'), findsNothing);
  });

  testWidgets('aggregate: pick a source, an op and its field', (tester) async {
    final emitted = await pump(tester, _items, 'reserved');
    await tester.tap(find.text('Aggregate'));
    await tester.pumpAndSettle();
    final a = emitted.last.aggregate!;
    expect(a.source, AggregateSource.linkedFrom);
    expect(a.collectionId, 'orders');
    expect(a.referenceFieldId, 'item');
    expect(a.op, AggregateOp.count);
    expect(find.text('Count of Orders linking here via Item'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Sum'));
    await tester.pumpAndSettle();
    expect(emitted.last.aggregate!.op, AggregateOp.sum);
    // The first number field of Orders is picked for you.
    expect(emitted.last.aggregate!.fieldId, 'price');
    expect(emitted.last.declaredOutputType, 'number');
    expect(
      find.text('Sum of Price of Orders linking here via Item'),
      findsOneWidget,
    );

    // Back to Formula and again: the aggregate comes back.
    await tester.tap(find.text('Formula'));
    await tester.pumpAndSettle();
    expect(emitted.last.aggregate, isNull);
    await tester.tap(find.text('Aggregate'));
    await tester.pumpAndSettle();
    expect(emitted.last.aggregate!.op, AggregateOp.sum);
  });

  testWidgets('a formula loop names the fields in it', (tester) async {
    const looped = Collection(
      id: 'c',
      name: 'C',
      fields: [
        CalculatedFieldDefinition(
          id: 'a',
          name: 'A',
          declaredOutputType: 'number',
          expression: '{b} + 1',
        ),
        CalculatedFieldDefinition(
          id: 'b',
          name: 'B',
          declaredOutputType: 'number',
          expression: '{a} * 2',
        ),
      ],
    );
    await pump(tester, looped, 'a');
    expect(find.text('Circular: A → B → A'), findsOneWidget);
  });
}
