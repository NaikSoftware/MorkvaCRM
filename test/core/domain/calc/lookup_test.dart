import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';

// Orders ← order items → inventory SKUs: a SKU's reserved stock is the
// quantity of items whose order is still open, read through a lookup.
Collection _orders({String paidLabel = 'Paid'}) => Collection(
  id: 'orders',
  name: 'Orders',
  fields: [
    const TextFieldDefinition(id: 'customer', name: 'Customer'),
    SingleSelectFieldDefinition(
      id: 'status',
      name: 'Status',
      options: [
        const SelectOption(id: 'new', label: 'New'),
        SelectOption(id: 'paid', label: paidLabel),
        const SelectOption(id: 'sent', label: 'Sent'),
      ],
    ),
    const DateFieldDefinition(id: 'due', name: 'Due'),
  ],
);

const _items = Collection(
  id: 'items',
  name: 'Order items',
  fields: [
    ReferenceFieldDefinition(
      id: 'order',
      name: 'Order',
      targetCollectionId: 'orders',
    ),
    ReferenceFieldDefinition(
      id: 'sku',
      name: 'SKU',
      targetCollectionId: 'skus',
    ),
    NumberFieldDefinition(id: 'qty', name: 'Quantity'),
    CalculatedFieldDefinition(
      id: 'orderStatus',
      name: 'Order status',
      declaredOutputType: kSingleSelectFieldType,
      lookup: Lookup(referenceFieldId: 'order', fieldId: 'status'),
    ),
    CalculatedFieldDefinition(
      id: 'customer',
      name: 'Customer',
      declaredOutputType: kTextFieldType,
      lookup: Lookup(referenceFieldId: 'order', fieldId: 'customer'),
    ),
    CalculatedFieldDefinition(
      id: 'due',
      name: 'Due',
      declaredOutputType: kDateFieldType,
      lookup: Lookup(referenceFieldId: 'order', fieldId: 'due'),
    ),
    CalculatedFieldDefinition(
      id: 'label',
      name: 'Label',
      declaredOutputType: kTextFieldType,
      expression: '{customer} & ": " & {orderStatus}',
    ),
  ],
);

const _skus = Collection(
  id: 'skus',
  name: 'SKUs',
  fields: [
    TextFieldDefinition(id: 'name', name: 'Name'),
    CalculatedFieldDefinition(
      id: 'reserved',
      name: 'Reserved',
      declaredOutputType: kNumberFieldType,
      aggregate: Aggregation(
        source: AggregateSource.linkedFrom,
        collectionId: 'items',
        referenceFieldId: 'sku',
        op: AggregateOp.sum,
        fieldId: 'qty',
        filters: [
          ViewFilter(
            fieldId: 'orderStatus',
            op: FilterOp.anyOf,
            operand: ['new', 'paid'],
          ),
        ],
      ),
    ),
  ],
);

final _t = DateTime.utc(2026, 1, 1);

MorkvaObject _o(String id, Collection c, Map<String, FieldValue> values) =>
    MorkvaObject.create(
      id: id,
      collection: c,
      values: values,
      createdAt: _t,
      updatedAt: _t,
    );

MorkvaObject _item(String id, String order, String sku, num qty) =>
    _o(id, _items, {
      'order': ReferenceFieldValue([order]),
      'sku': ReferenceFieldValue([sku]),
      'qty': NumberFieldValue(qty),
    });

Object? _v(List<MorkvaObject> objects, String id, String field) =>
    (objects.firstWhere((o) => o.id == id)[field] as CalculatedFieldValue)
        .cached;

void main() {
  final orders = _orders();
  final orderObjects = [
    _o('o1', orders, {
      'customer': const TextFieldValue('Olena'),
      'status': const SingleSelectFieldValue('new'),
      'due': DateFieldValue(DateTime.utc(2026, 11, 21)),
    }),
    _o('o2', orders, {
      'customer': const TextFieldValue('Taras'),
      'status': const SingleSelectFieldValue('paid'),
    }),
    _o('o3', orders, {
      'customer': const TextFieldValue('Iryna'),
      'status': const SingleSelectFieldValue('sent'),
    }),
  ];
  final skus = [
    _o('black-m', _skus, {'name': const TextFieldValue('Black M')}),
    _o('olive-l', _skus, {'name': const TextFieldValue('Olive L')}),
  ];
  final items = [
    _item('i1', 'o1', 'black-m', 2), // the same SKU twice in one order
    _item('i2', 'o1', 'black-m', 1),
    _item('i3', 'o2', 'black-m', 4),
    _item('i4', 'o3', 'black-m', 10), // sent: not reserved
    _item('i5', 'o2', 'olive-l', 1),
  ];

  Derivation derive(List<Collection> collections) => Derivation(
    collections: resolveLookups(collections),
    objects: {'orders': orderObjects, 'items': items, 'skus': skus},
  );

  test('a lookup of a select keeps the option id', () {
    final out = derive([orders, _items, _skus]).objectsOf('items');
    expect(_v(out, 'i1', 'orderStatus'), 'new');
    expect(_v(out, 'i3', 'orderStatus'), 'paid');
    expect(_v(out, 'i1', 'customer'), 'Olena');
    expect(_v(out, 'i1', 'due'), DateTime.utc(2026, 11, 21).toIso8601String());
    expect(_v(out, 'i3', 'due'), isNull);
  });

  test('a formula reads a looked-up select as its label', () {
    final out = derive([orders, _items, _skus]).objectsOf('items');
    expect(_v(out, 'i1', 'label'), 'Olena: New');
    expect(_v(out, 'i3', 'label'), 'Taras: Paid');
  });

  test('reserved sums item quantities through the lookup filter', () {
    final out = derive([orders, _items, _skus]).objectsOf('skus');
    expect(_v(out, 'black-m', 'reserved'), 7); // 2 + 1 + 4, not the sent 10
    expect(_v(out, 'olive-l', 'reserved'), 1);
  });

  test('renaming an option label does not change the totals', () {
    final renamed = _orders(paidLabel: 'Prepaid');
    final out = derive([renamed, _items, _skus]).objectsOf('skus');
    expect(_v(out, 'black-m', 'reserved'), 7);
  });

  test('resolveLookups presents a lookup as the shown field', () {
    final resolved = resolveLookups([orders, _items, _skus]);
    final status =
        resolved[1].fieldById('orderStatus')! as CalculatedFieldDefinition;
    expect(status.outputField, isA<SingleSelectFieldDefinition>());
    final value = status.outputValue(const CalculatedFieldValue('paid'));
    expect(
      formatFieldValue(status, const CalculatedFieldValue('paid')),
      'Paid',
    );
    expect(value, const SingleSelectFieldValue('paid'));
    expect(Derivation.sourcesOf('items', resolved), containsAll(['orders']));
    expect(Derivation.sourcesOf('skus', resolved), {'items', 'orders'});
  });

  test('a lookup is blank without a link, or while the target loads', () {
    final lonely = _o('i9', _items, {'qty': const NumberFieldValue(1)});
    final d = Derivation(
      collections: resolveLookups([orders, _items, _skus]),
      objects: {
        'items': [lonely],
      },
    );
    expect(_v(d.objectsOf('items'), 'i9', 'orderStatus'), isNull);
    final loaded = Derivation(
      collections: resolveLookups([orders, _items, _skus]),
      objects: {
        'orders': orderObjects,
        'items': [lonely],
      },
    );
    expect(_v(loaded.objectsOf('items'), 'i9', 'orderStatus'), isNull);
  });

  test('the lookup config round-trips through JSON', () {
    final field = _items.fieldById('orderStatus')! as CalculatedFieldDefinition;
    final back = CalculatedFieldDefinition.fromJson(field.toJson());
    expect(back, field);
    expect(back.isLookup, isTrue);
    expect(back.isAggregate, isFalse);
  });
}
