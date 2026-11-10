import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/core/harness/harness.dart';
import 'package:morkva_crm/design/collection_icons.dart';

void main() {
  final registry = defaultFieldTypeRegistry();
  final spec = fieldSpecSchema(registry.registeredTypes);

  List<ErrorDetail> validate(Map<String, Object?> value) => [
    ...JsonSchema.validate(spec, value, path: 'fields[0]'),
    ...checkFieldSpec(value, path: 'fields[0]'),
  ];

  group('fieldSpecSchema', () {
    test('the type enum is every registered field type', () {
      final types = (spec['properties']! as Map)['type'] as Map;
      expect(types['enum'], registry.registeredTypes.toList());
    });

    test('every registered built-in type has config keys', () {
      expect(kFieldConfigKeys.keys, containsAll(registry.registeredTypes));
    });

    test('a type unknown to the harness is left out of the enum', () {
      final types =
          (fieldSpecSchema([
                    ...registry.registeredTypes,
                    'signature',
                  ])['properties']!
                  as Map)['type']
              as Map;
      expect(types['enum'], isNot(contains('signature')));
    });

    test('is inside the supported subset', () {
      expect(JsonSchema.check(spec), isEmpty);
    });

    test('accepts a spec of each type', () {
      final specs = <Map<String, Object?>>[
        {'name': 'Notes', 'type': 'text', 'multiline': true, 'maxLength': 500},
        {
          'name': 'Price',
          'type': 'number',
          'decimalPlaces': 2,
          'unitLabel': 'USD',
          'min': 0,
        },
        {'name': 'Paid', 'type': 'boolean', 'required': true},
        {
          'name': 'Due',
          'type': 'date',
          'includeTime': false,
          'min': '2026-01-01',
        },
        {
          'name': 'Status',
          'type': 'single_select',
          'options': [
            'New',
            {'label': 'Done', 'color': '#2E7D32'},
          ],
        },
        {
          'name': 'Tags',
          'type': 'multi_select',
          'options': ['VIP'],
        },
        {
          'ref': '@client',
          'name': 'Client',
          'type': 'reference',
          'target': '@x',
        },
        {
          'name': 'Docs',
          'type': 'file',
          'multiple': true,
          'allowedExtensions': ['pdf'],
        },
        {'name': 'No', 'type': 'auto_number', 'prefix': '#', 'padding': 4},
        {'name': 'Total', 'type': 'calculated', 'formula': '{Price} * {Qty}'},
        {
          'name': 'Spent',
          'type': 'calculated',
          'aggregate': {
            'source': 'linkedFrom',
            'collection': 'Orders',
            'referenceField': 'Client',
            'op': 'sum',
            'field': 'Total',
            'where': [
              {'field': 'Status', 'op': 'equals', 'value': 'Done'},
            ],
          },
        },
        {
          'name': 'City',
          'type': 'calculated',
          'lookup': {'via': 'Client', 'field': 'City'},
        },
      ];
      for (final s in specs) {
        expect(validate(s), isEmpty, reason: '$s');
      }
    });

    test('rejects a config key of another type, listing the right ones', () {
      final problem = validate({
        'name': 'Qty',
        'type': 'number',
        'options': ['a'],
      }).single;
      expect(problem.path, 'fields[0].options');
      expect(problem.candidates, ['decimalPlaces', 'unitLabel', 'min', 'max']);
    });

    test('a boolean takes no config', () {
      expect(
        validate({
          'name': 'Paid',
          'type': 'boolean',
          'multiline': true,
        }).single.message,
        contains('takes no config'),
      );
    });

    test('min and max follow the field type', () {
      expect(
        validate({'name': 'Qty', 'type': 'number', 'min': '3'}).single.path,
        'fields[0].min',
      );
      expect(
        validate({'name': 'Due', 'type': 'date', 'max': 'soon'}).single.path,
        'fields[0].max',
      );
    });

    test('a calculated field needs exactly one source', () {
      expect(
        validate({'name': 'X', 'type': 'calculated'}).single.message,
        contains('needs one of'),
      );
      expect(
        validate({
          'name': 'X',
          'type': 'calculated',
          'formula': '1',
          'lookup': {'via': 'Client'},
        }).single.message,
        contains('only one of'),
      );
    });

    test('an unknown type and an unknown key fail the schema', () {
      final problems = validate({'name': 'X', 'type': 'money', 'colour': 1});
      expect(
        problems.map((p) => p.path),
        containsAll(['fields[0].type', 'fields[0].colour']),
      );
    });
  });

  group('collection icons', () {
    test('match the design catalog exactly', () {
      expect(kCollectionIconIds, [
        for (final option in CollectionIcons.all) option.key,
      ]);
    });

    test('an unknown icon fails with every icon id as candidates', () {
      final problem = JsonSchema.validate(
        collectionIconSchema(),
        'rocket',
      ).single;
      expect(problem.candidates, kCollectionIconIds);
    });
  });

  group('arg shapes', () {
    test('are inside the supported subset', () {
      for (final schema in [
        refSchema(),
        fieldRefSchema(),
        anyValueSchema(),
        filterSchema(),
        whereSchema(),
        sortSchema(),
        valuesSchema(),
        targetSchema(),
        cardSchema(),
      ]) {
        expect(JsonSchema.check(schema), isEmpty, reason: '$schema');
      }
    });

    test('the filter op enum is every FilterOp (15)', () {
      final op = (filterSchema()['properties']! as Map)['op'] as Map;
      expect(op['enum'], hasLength(15));
      expect(op['enum'], [for (final o in FilterOp.values) o.name]);
    });

    test('where is never empty', () {
      expect(JsonSchema.validate(whereSchema(), <Object?>[]), hasLength(1));
      expect(
        JsonSchema.validate(whereSchema(), [
          {'field': '@createdAt', 'op': 'after', 'relative': 'this_month'},
        ]),
        isEmpty,
      );
    });

    test('a target is ids or where, nothing else', () {
      final target = targetSchema();
      expect(
        JsonSchema.validate(target, {
          'ids': ['b_1'],
        }),
        isEmpty,
      );
      expect(
        JsonSchema.validate(target, {
          'where': [
            {
              'field': 'Status',
              'op': 'anyOf',
              'value': ['New', 'Done'],
            },
          ],
        }),
        isEmpty,
      );
      expect(JsonSchema.validate(target, {'all': true}), isNotEmpty);
      expect(JsonSchema.validate(target, {'where': <Object?>[]}), isNotEmpty);
    });

    test('values is a free-form map of friendly values', () {
      expect(
        JsonSchema.validate(valuesSchema(), {
          'Total': 12.5,
          'Paid': true,
          'Tags': ['VIP', 'New'],
          'Due': '2026-11-10',
        }),
        isEmpty,
      );
      expect(
        JsonSchema.validate(valuesSchema(), {
          'Client': {'id': 'b_1'},
        }).single.path,
        'Client',
      );
    });
  });
}
