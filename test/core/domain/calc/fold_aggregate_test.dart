import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';

// An Orders collection plus a dashboard that summarizes all of its orders with
// every op, so the calculated-field path can be checked against foldAggregate.
const _orders = Collection(
  id: 'orders',
  name: 'Orders',
  fields: [
    NumberFieldDefinition(id: 'amount', name: 'Amount'),
    DateFieldDefinition(id: 'due', name: 'Due'),
  ],
);

CalculatedFieldDefinition _calc(AggregateOp op, String? fieldId, String type) =>
    CalculatedFieldDefinition(
      id: '${op.name}_${fieldId ?? 'all'}',
      name: '${op.label} ${fieldId ?? ''}',
      declaredOutputType: type,
      aggregate: Aggregation(
        source: AggregateSource.all,
        collectionId: 'orders',
        op: op,
        fieldId: fieldId,
      ),
    );

final _dashboard = Collection(
  id: 'dash',
  name: 'Dashboard',
  fields: [
    for (final op in AggregateOp.values)
      if (op.needsField) _calc(op, 'amount', 'number'),
    _calc(AggregateOp.count, null, 'number'),
    _calc(AggregateOp.min, 'due', 'date'),
    _calc(AggregateOp.max, 'due', 'date'),
  ],
);

final _t = DateTime.utc(2026, 11, 1);

MorkvaObject _o(String id, Collection c, Map<String, FieldValue> values) =>
    MorkvaObject.create(
      id: id,
      collection: c,
      values: values,
      createdAt: _t,
      updatedAt: _t,
    );

void main() {
  group('foldAggregate', () {
    test('count counts every value, nulls included (one per card)', () {
      expect(foldAggregate(AggregateOp.count, [1, null, 'x']), 3);
      expect(foldAggregate(AggregateOp.count, const []), 0);
    });

    test('sum adds numbers only and is 0 when there are none', () {
      expect(foldAggregate(AggregateOp.sum, [2, 3.5, null, 'x']), 5.5);
      expect(foldAggregate(AggregateOp.sum, const []), 0);
      expect(foldAggregate(AggregateOp.sum, [null, 'x']), 0);
    });

    test('average is null with no numbers, else the mean of the numbers', () {
      expect(foldAggregate(AggregateOp.average, [2, 4, null]), 3);
      expect(foldAggregate(AggregateOp.average, const []), isNull);
      expect(foldAggregate(AggregateOp.average, [null]), isNull);
    });

    test('min and max skip nulls and work on numbers and dates', () {
      expect(foldAggregate(AggregateOp.min, [5, null, -2, 7]), -2);
      expect(foldAggregate(AggregateOp.max, [5, null, -2, 7]), 7);
      final early = DateTime.utc(2026, 1, 5);
      final late = DateTime.utc(2026, 3, 1);
      expect(foldAggregate(AggregateOp.min, [late, null, early]), early);
      expect(foldAggregate(AggregateOp.max, [late, null, early]), late);
      expect(foldAggregate(AggregateOp.min, [null]), isNull);
      expect(foldAggregate(AggregateOp.max, const []), isNull);
    });
  });

  group('parity with calculated aggregates', () {
    final orders = [
      _o('o1', _orders, {
        'amount': const NumberFieldValue(120),
        'due': DateFieldValue(DateTime.utc(2026, 11, 20)),
      }),
      _o('o2', _orders, {'amount': const NumberFieldValue(30.5)}),
      _o('o3', _orders, {'due': DateFieldValue(DateTime.utc(2026, 10, 2))}),
      _o('o4', _orders, {
        'amount': const NumberFieldValue(-4),
        'due': DateFieldValue(DateTime.utc(2027, 1, 9)),
      }),
    ];

    Object? derived(String fieldId, List<MorkvaObject> data) {
      final dash = _o('d', _dashboard, const {});
      final field = _dashboard.fieldById(fieldId)! as CalculatedFieldDefinition;
      return Derivation(
        collections: [_orders, _dashboard],
        objects: {
          'orders': data,
          'dash': [dash],
        },
      ).valueOf(_dashboard, dash, field).cached;
    }

    // What the assistant folds: each card's value as a formula reads it.
    Object? folded(AggregateOp op, String fieldId, List<MorkvaObject> data) {
      final field = _orders.fieldById(fieldId)!;
      final out = foldAggregate(op, [
        for (final o in data)
          Derivation.formulaValueOf(field, o[fieldId] ?? field.emptyValue()),
      ]);
      return out is DateTime ? out.toIso8601String() : out;
    }

    for (final (name, withCards) in [
      ('with cards', true),
      ('with no cards', false),
    ]) {
      test('every op agrees $name', () {
        final list = withCards ? orders : <MorkvaObject>[];
        for (final op in AggregateOp.values.where((op) => op.needsField)) {
          expect(
            derived('${op.name}_amount', list),
            folded(op, 'amount', list),
            reason: op.name,
          );
        }
        for (final op in [AggregateOp.min, AggregateOp.max]) {
          expect(
            derived('${op.name}_due', list),
            folded(op, 'due', list),
            reason: '${op.name} of a date',
          );
        }
        expect(derived('count_all', list), list.length);
      });
    }

    test('known values', () {
      expect(derived('sum_amount', orders), 146.5);
      expect(derived('average_amount', orders), closeTo(48.833, 0.001));
      expect(derived('min_due', orders), '2026-10-02T00:00:00.000Z');
      expect(derived('max_due', orders), '2027-01-09T00:00:00.000Z');
    });
  });
}
