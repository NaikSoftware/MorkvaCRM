import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';

// The orders → inventory setup from the morkvawear Trello, as configuration.
const _inventory = Collection(
  id: 'inventory',
  name: 'Inventory',
  fields: [
    TextFieldDefinition(id: 'size', name: 'Size'),
    NumberFieldDefinition(id: 'stock', name: 'Stock'),
    CalculatedFieldDefinition(
      id: 'reserved',
      name: 'Reserved',
      declaredOutputType: 'number',
      aggregate: Aggregation(
        source: AggregateSource.linkedFrom,
        collectionId: 'orders',
        referenceFieldId: 'item',
        op: AggregateOp.sum,
        fieldId: 'qty',
        filters: [
          ViewFilter(
            fieldId: 'status',
            op: FilterOp.anyOf,
            operand: ['new', 'paid'],
          ),
        ],
      ),
    ),
    CalculatedFieldDefinition(
      id: 'used',
      name: 'Used',
      declaredOutputType: 'number',
      aggregate: Aggregation(
        source: AggregateSource.linkedFrom,
        collectionId: 'orders',
        referenceFieldId: 'item',
        op: AggregateOp.sum,
        fieldId: 'qty',
        filters: [
          ViewFilter(fieldId: 'status', op: FilterOp.anyOf, operand: ['sent']),
        ],
      ),
    ),
    CalculatedFieldDefinition(
      id: 'available',
      name: 'Available',
      declaredOutputType: 'number',
      expression: '{stock} - {reserved} - {used}',
    ),
    CalculatedFieldDefinition(
      id: 'orders',
      name: 'Orders',
      declaredOutputType: 'number',
      aggregate: Aggregation(
        source: AggregateSource.linkedFrom,
        collectionId: 'orders',
        referenceFieldId: 'item',
      ),
    ),
  ],
);

const _orders = Collection(
  id: 'orders',
  name: 'Orders',
  fields: [
    AutoNumberFieldDefinition(id: 'no', name: 'No'),
    ReferenceFieldDefinition(
      id: 'item',
      name: 'Item',
      targetCollectionId: 'inventory',
    ),
    NumberFieldDefinition(id: 'qty', name: 'Quantity'),
    SingleSelectFieldDefinition(
      id: 'status',
      name: 'Status',
      options: [
        SelectOption(id: 'new', label: 'New'),
        SelectOption(id: 'paid', label: 'Paid'),
        SelectOption(id: 'sent', label: 'Sent'),
      ],
    ),
    CalculatedFieldDefinition(
      id: 'price',
      name: 'Unit price',
      declaredOutputType: 'number',
      aggregate: Aggregation(
        source: AggregateSource.linked,
        collectionId: 'inventory',
        referenceFieldId: 'item',
        op: AggregateOp.max,
        fieldId: 'unit',
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

MorkvaObject _order(String id, String item, num qty, String status) =>
    _o(id, _orders, {
      'item': ReferenceFieldValue([item]),
      'qty': NumberFieldValue(qty),
      'status': SingleSelectFieldValue(status),
    });

Object? _v(List<MorkvaObject> objects, String id, String field) =>
    (objects.firstWhere((o) => o.id == id)[field] as CalculatedFieldValue)
        .cached;

void main() {
  group('orders → inventory', () {
    final inventory = [
      _o('m', _inventory, {
        'size': const TextFieldValue('M'),
        'stock': const NumberFieldValue(20),
      }),
      _o('l', _inventory, {
        'size': const TextFieldValue('L'),
        'stock': const NumberFieldValue(5),
      }),
    ];
    final orders = [
      _order('o1', 'm', 2, 'new'),
      _order('o2', 'm', 3, 'paid'),
      _order('o3', 'm', 4, 'sent'),
      _order('o4', 'l', 1, 'sent'),
      _order('o5', 'l', 6, 'new'),
    ];

    List<MorkvaObject> derive(List<MorkvaObject> orderList) => Derivation(
      collections: const [_inventory, _orders],
      objects: {'inventory': inventory, 'orders': orderList},
    ).objectsOf('inventory');

    test('reserved / used are filtered SUMIFs, available a formula', () {
      final out = derive(orders);
      expect(_v(out, 'm', 'reserved'), 5); // 2 + 3
      expect(_v(out, 'm', 'used'), 4);
      expect(_v(out, 'm', 'available'), 11); // 20 - 5 - 4
      expect(_v(out, 'm', 'orders'), 3);
      expect(_v(out, 'l', 'reserved'), 6);
      expect(_v(out, 'l', 'available'), -2);
    });

    test('follows order changes', () {
      final shipped = [
        for (final o in orders)
          o.id == 'o1'
              ? o.copyWith(
                  values: {
                    ...o.values,
                    'status': const SingleSelectFieldValue('sent'),
                  },
                )
              : o,
        _order('o6', 'm', 10, 'paid'),
      ];
      final out = derive(shipped);
      expect(_v(out, 'm', 'reserved'), 13); // 3 + 10
      expect(_v(out, 'm', 'used'), 6); // 4 + 2
    });

    test('no linked orders: sums are 0, count 0', () {
      final out = Derivation(
        collections: const [_inventory, _orders],
        objects: {'inventory': inventory, 'orders': const []},
      ).objectsOf('inventory');
      expect(_v(out, 'm', 'reserved'), 0);
      expect(_v(out, 'm', 'orders'), 0);
      expect(_v(out, 'm', 'available'), 20);
    });

    test('orders not loaded yet: aggregates are blank, not 0', () {
      final out = Derivation(
        collections: const [_inventory, _orders],
        objects: {'inventory': inventory},
      ).objectsOf('inventory');
      expect(_v(out, 'm', 'reserved'), isNull);
    });
  });

  test('linked: reads the referenced object', () {
    final inv = _inventory.copyWith(
      fields: [
        ..._inventory.fields,
        const NumberFieldDefinition(id: 'unit', name: 'Unit price'),
      ],
    );
    final out = Derivation(
      collections: [inv, _orders],
      objects: {
        'inventory': [
          _o('m', inv, {'unit': const NumberFieldValue(450)}),
        ],
        'orders': [_order('o1', 'm', 2, 'new'), _order('o2', 'gone', 1, 'new')],
      },
    ).objectsOf('orders');
    expect(_v(out, 'o1', 'price'), 450);
    expect(_v(out, 'o2', 'price'), isNull);
  });

  group('hoodie spreadsheet', () {
    // Clothes link a color; colors sum cost and kg (SUMIF by color); the
    // dashboard sums everything and adds a fixed sewing fee.
    const colors = Collection(
      id: 'colors',
      name: 'Colors',
      fields: [
        TextFieldDefinition(id: 'name', name: 'Name'),
        CalculatedFieldDefinition(
          id: 'cost',
          name: 'Cost',
          declaredOutputType: 'number',
          aggregate: Aggregation(
            source: AggregateSource.linkedFrom,
            collectionId: 'clothes',
            referenceFieldId: 'color',
            op: AggregateOp.sum,
            fieldId: 'cost',
          ),
        ),
        CalculatedFieldDefinition(
          id: 'kg',
          name: 'Fabric kg',
          declaredOutputType: 'number',
          aggregate: Aggregation(
            source: AggregateSource.linkedFrom,
            collectionId: 'clothes',
            referenceFieldId: 'color',
            op: AggregateOp.sum,
            fieldId: 'kg',
          ),
        ),
      ],
    );
    const clothes = Collection(
      id: 'clothes',
      name: 'Clothes',
      fields: [
        ReferenceFieldDefinition(
          id: 'color',
          name: 'Color',
          targetCollectionId: 'colors',
        ),
        NumberFieldDefinition(id: 'units', name: 'Units'),
        NumberFieldDefinition(id: 'unitCost', name: 'Unit cost'),
        NumberFieldDefinition(id: 'kg', name: 'Kg'),
        CalculatedFieldDefinition(
          id: 'cost',
          name: 'Cost',
          declaredOutputType: 'number',
          expression: '{units} * {unitCost}',
        ),
      ],
    );
    const dashboard = Collection(
      id: 'dash',
      name: 'Dashboard',
      fields: [
        NumberFieldDefinition(id: 'fee', name: 'Sewing fee'),
        CalculatedFieldDefinition(
          id: 'units',
          name: 'Units sewn',
          declaredOutputType: 'number',
          aggregate: Aggregation(
            source: AggregateSource.all,
            collectionId: 'clothes',
            op: AggregateOp.sum,
            fieldId: 'units',
          ),
        ),
        CalculatedFieldDefinition(
          id: 'cost',
          name: 'Total cost',
          declaredOutputType: 'number',
          aggregate: Aggregation(
            source: AggregateSource.all,
            collectionId: 'colors',
            op: AggregateOp.sum,
            fieldId: 'cost',
          ),
        ),
        CalculatedFieldDefinition(
          id: 'perUnit',
          name: 'Cost per unit',
          declaredOutputType: 'number',
          expression: 'ROUND(({cost} + {fee}) / {units}, 2)',
        ),
        CalculatedFieldDefinition(
          id: 'avg',
          name: 'Average batch',
          declaredOutputType: 'number',
          aggregate: Aggregation(
            source: AggregateSource.all,
            collectionId: 'clothes',
            op: AggregateOp.average,
            fieldId: 'units',
            filters: [
              ViewFilter(fieldId: 'kg', op: FilterOp.greaterThan, operand: 1),
            ],
          ),
        ),
      ],
    );

    MorkvaObject piece(String id, String color, int units, num cost, num kg) =>
        _o(id, clothes, {
          'color': ReferenceFieldValue([color]),
          'units': NumberFieldValue(units),
          'unitCost': NumberFieldValue(cost),
          'kg': NumberFieldValue(kg),
        });

    final derivation = Derivation(
      collections: const [colors, clothes, dashboard],
      objects: {
        'colors': [
          _o('black', colors, {'name': const TextFieldValue('Black')}),
          _o('beige', colors, {'name': const TextFieldValue('Beige')}),
        ],
        'clothes': [
          piece('h1', 'black', 10, 450, 4.2),
          piece('h2', 'black', 5, 470, 2.1),
          piece('h3', 'beige', 8, 455, 0.9),
        ],
        'dash': [
          _o('d', dashboard, {'fee': const NumberFieldValue(1200)}),
        ],
      },
    );

    test('per-color SUMIF of a formula field matches the hand sums', () {
      final out = derivation.objectsOf('colors');
      expect(_v(out, 'black', 'cost'), 10 * 450 + 5 * 470); // 6850
      expect(_v(out, 'beige', 'cost'), 8 * 455); // 3640
      expect(_v(out, 'black', 'kg'), closeTo(6.3, 1e-9));
    });

    test('dashboard combines totals with a manual constant', () {
      final out = derivation.objectsOf('dash');
      expect(_v(out, 'd', 'units'), 23);
      expect(_v(out, 'd', 'cost'), 10490);
      expect(_v(out, 'd', 'perUnit'), 508.26); // (10490 + 1200) / 23
      expect(_v(out, 'd', 'avg'), 7.5); // (10 + 5) / 2, kg > 1 only
    });
  });

  group('cycles', () {
    test('formulas reading each other are blank', () {
      const c = Collection(
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
            expression: '{a} + 1',
          ),
        ],
      );
      final out = Derivation(
        collections: const [c],
        objects: {
          'c': [_o('x', c, const {})],
        },
      ).objectsOf('c');
      expect(_v(out, 'x', 'a'), isNull);
      expect(_v(out, 'x', 'b'), isNull);
    });

    test('aggregates across collections that loop end', () {
      const a = Collection(
        id: 'a',
        name: 'A',
        fields: [
          CalculatedFieldDefinition(
            id: 'sumB',
            name: 'Sum B',
            declaredOutputType: 'number',
            aggregate: Aggregation(
              source: AggregateSource.all,
              collectionId: 'b',
              op: AggregateOp.sum,
              fieldId: 'sumA',
            ),
          ),
        ],
      );
      const b = Collection(
        id: 'b',
        name: 'B',
        fields: [
          CalculatedFieldDefinition(
            id: 'sumA',
            name: 'Sum A',
            declaredOutputType: 'number',
            aggregate: Aggregation(
              source: AggregateSource.all,
              collectionId: 'a',
              op: AggregateOp.sum,
              fieldId: 'sumB',
            ),
          ),
        ],
      );
      final d = Derivation(
        collections: const [a, b],
        objects: {
          'a': [_o('a1', a, const {})],
          'b': [_o('b1', b, const {})],
        },
      );
      expect(() => d.objectsOf('a'), returnsNormally);
      expect(Derivation.sourcesOf('a', const [a, b]), {'b'});
    });
  });

  test('sourcesOf follows aggregates transitively', () {
    const dash = Collection(
      id: 'dash',
      name: 'D',
      fields: [
        CalculatedFieldDefinition(
          id: 'x',
          name: 'X',
          declaredOutputType: 'number',
          aggregate: Aggregation(
            source: AggregateSource.all,
            collectionId: 'inventory',
            op: AggregateOp.sum,
            fieldId: 'reserved',
          ),
        ),
      ],
    );
    expect(Derivation.sourcesOf('dash', const [dash, _inventory, _orders]), {
      'inventory',
      'orders',
    });
    expect(Derivation.sourcesOf('orders', const [_inventory, _orders]), {
      'inventory',
    });
  });

  test('calculated values format, filter and sort as their output type', () {
    const f = CalculatedFieldDefinition(
      id: 't',
      name: 'Total',
      declaredOutputType: 'number',
      decimalPlaces: 2,
      unitLabel: '₴',
    );
    expect(
      formatFieldValue(f, const CalculatedFieldValue(1234.5)),
      '1,234.50 ₴',
    );
    expect(
      matchesFilter(
        const ViewFilter(fieldId: 't', op: FilterOp.greaterThan, operand: 100),
        f,
        const CalculatedFieldValue(150),
      ),
      isTrue,
    );
    expect(operatorsFor(f), contains(FilterOp.greaterThan));
    const d = CalculatedFieldDefinition(
      id: 'd',
      name: 'Due',
      declaredOutputType: 'date',
    );
    expect(
      formatFieldValue(
        d,
        const CalculatedFieldValue('2026-03-27T00:00:00.000Z'),
      ),
      'Mar 27, 2026',
    );
  });

  test('allocateSequences hands out the next number and keeps given ones', () {
    const c = Collection(
      id: 'c',
      name: 'C',
      fields: [
        AutoNumberFieldDefinition(id: 'no', name: 'No', start: 100),
        AutoNumberFieldDefinition(id: 'ref', name: 'Ref'),
      ],
    );
    final first = allocateSequences(c, const {}, const {});
    expect(first.assigned, {'no': 100, 'ref': 1});
    final next = allocateSequences(c, const {}, {'no': 104, 'ref': 7});
    expect(next.assigned, {'no': 105, 'ref': 8});
    final restored = allocateSequences(
      c,
      const {'no': 120, 'ref': 3},
      {'no': 105, 'ref': 8},
    );
    expect(restored.assigned, isEmpty);
    expect(restored.counters, {'no': 120});
  });
}
