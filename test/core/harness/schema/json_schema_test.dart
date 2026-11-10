import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/harness/harness.dart';

List<String> _paths(List<ErrorDetail> problems) => [
  for (final p in problems) p.path,
];

void main() {
  group('JsonSchema.validate', () {
    test('checks every scalar type', () {
      expect(JsonSchema.validate(JsonSchema.string(), 'a'), isEmpty);
      expect(JsonSchema.validate(JsonSchema.string(), 1), hasLength(1));
      expect(JsonSchema.validate(JsonSchema.number(), 1.5), isEmpty);
      expect(JsonSchema.validate(JsonSchema.number(), '1.5'), hasLength(1));
      expect(JsonSchema.validate(JsonSchema.boolean(), false), isEmpty);
      expect(JsonSchema.validate(JsonSchema.boolean(), 'true'), hasLength(1));
      expect(JsonSchema.validate(JsonSchema.integer(), 3), isEmpty);
      expect(JsonSchema.validate(JsonSchema.integer(), 3.5), hasLength(1));
    });

    test('an integer accepts an integral double, as JSON decoders send it', () {
      expect(JsonSchema.validate(JsonSchema.integer(), 20.0), isEmpty);
    });

    test('a number rejects NaN and infinity', () {
      expect(JsonSchema.validate(JsonSchema.number(), double.nan), isNotEmpty);
      expect(
        JsonSchema.validate(JsonSchema.number(), double.infinity),
        isNotEmpty,
      );
    });

    test('a type mismatch names the path and both types', () {
      final schema = JsonSchema.object({'limit': JsonSchema.integer()});
      final problems = JsonSchema.validate(schema, {'limit': '12'});
      expect(problems.single.path, 'limit');
      expect(problems.single.code, ErrorCode.invalidArgs);
      expect(problems.single.message, contains('an integer'));
      expect(problems.single.message, contains('a string'));
    });

    test('enum misses list the allowed values as candidates', () {
      final schema = JsonSchema.enumOf(['asc', 'desc']);
      final problems = JsonSchema.validate(schema, 'up', path: 'sort.dir');
      expect(problems.single.path, 'sort.dir');
      expect(problems.single.candidates, ['asc', 'desc']);
      expect(problems.single.message, contains('"up"'));
    });

    test('minimum and maximum are inclusive', () {
      final schema = JsonSchema.integer(minimum: 1, maximum: 100);
      expect(JsonSchema.validate(schema, 1), isEmpty);
      expect(JsonSchema.validate(schema, 100), isEmpty);
      expect(
        JsonSchema.validate(schema, 0).single.message,
        contains('at least 1'),
      );
      expect(
        JsonSchema.validate(schema, 101).single.message,
        contains('at most 100'),
      );
    });

    test('minItems and maxItems bound arrays', () {
      final schema = JsonSchema.array(
        JsonSchema.string(),
        minItems: 1,
        maxItems: 2,
      );
      expect(JsonSchema.validate(schema, ['a']), isEmpty);
      expect(JsonSchema.validate(schema, <Object?>[]), hasLength(1));
      expect(
        JsonSchema.validate(schema, ['a', 'b', 'c']).single.message,
        contains('at most 2'),
      );
    });

    test('items are checked one by one with indexed paths', () {
      final schema = JsonSchema.object({
        'filters': JsonSchema.array(
          JsonSchema.object(
            {'field': JsonSchema.string()},
            required: ['field'],
          ),
        ),
      });
      final problems = JsonSchema.validate(schema, {
        'filters': [
          {'field': 'Total'},
          {'field': 3},
          <String, Object?>{},
        ],
      });
      expect(_paths(problems), ['filters[1].field', 'filters[2].field']);
      expect(problems.last.message, contains('Missing required'));
    });

    test('a typo under additionalProperties:false is an unknown argument '
        'with the allowed names as candidates', () {
      final schema = JsonSchema.object(
        {'collection': JsonSchema.string(), 'limit': JsonSchema.integer()},
        required: ['collection'],
      );
      final problems = JsonSchema.validate(schema, {'colection': 'Orders'});
      expect(problems, hasLength(2));
      expect(_paths(problems), containsAll(['collection', 'colection']));
      final unknown = problems.firstWhere((p) => p.path == 'colection');
      expect(unknown.candidates, ['collection', 'limit']);
    });

    test('additionalProperties as a schema validates every value of a map', () {
      final schema = JsonSchema.object({
        'values': JsonSchema.mapOf(JsonSchema.number()),
      });
      final problems = JsonSchema.validate(schema, {
        'values': {'Total': 12, 'Qty': 'many'},
      });
      expect(_paths(problems), ['values.Qty']);
    });

    test('an object without additionalProperties accepts unknown keys', () {
      expect(
        JsonSchema.validate(
          {
            'type': 'object',
            'properties': {'a': JsonSchema.string()},
          },
          {'a': 'x', 'b': 1},
        ),
        isEmpty,
      );
    });

    test('an optional property set to null counts as absent', () {
      final schema = JsonSchema.object(
        {'collection': JsonSchema.string(), 'limit': JsonSchema.integer()},
        required: ['collection'],
      );
      expect(
        JsonSchema.validate(schema, {'collection': 'x', 'limit': null}),
        isEmpty,
      );
      expect(_paths(JsonSchema.validate(schema, {'collection': null})), [
        'collection',
      ]);
    });

    test('anyOf passes when one branch matches', () {
      final schema = JsonSchema.anyOf([
        JsonSchema.string(),
        JsonSchema.array(JsonSchema.string()),
      ]);
      expect(JsonSchema.validate(schema, 'x'), isEmpty);
      expect(JsonSchema.validate(schema, ['x', 'y']), isEmpty);
    });

    test('anyOf explains a miss through the branch of the same type', () {
      final schema = JsonSchema.anyOf([
        JsonSchema.object(
          {'ids': JsonSchema.array(JsonSchema.string())},
          required: ['ids'],
        ),
        JsonSchema.string(),
      ]);
      final problems = JsonSchema.validate(schema, {
        'ids': [1],
      }, path: 'target');
      expect(_paths(problems), ['target.ids[0]']);
    });

    test('anyOf with no branch of the value type lists the expected types', () {
      final schema = JsonSchema.anyOf([
        JsonSchema.string(),
        JsonSchema.number(),
      ]);
      final problem = JsonSchema.validate(schema, true, path: 'v').single;
      expect(problem.message, contains('a string or a number'));
      expect(problem.message, contains('a boolean'));
    });

    test('collects every problem in one pass', () {
      final schema = JsonSchema.object({
        'cards': JsonSchema.array(
          JsonSchema.object({'n': JsonSchema.integer()}),
        ),
      });
      final problems = JsonSchema.validate(schema, {
        'cards': [
          for (var i = 0; i < 30; i++) {'n': i.isEven ? i : 'x'},
        ],
      });
      expect(problems, hasLength(15));
    });

    test('works on schemas and values decoded from JSON', () {
      final schema =
          jsonDecode(jsonEncode(JsonSchema.object({'a': JsonSchema.integer()})))
              as Map<String, Object?>;
      final value = jsonDecode('{"a": 1.0, "b": 2}') as Map<String, Object?>;
      expect(_paths(JsonSchema.validate(schema, value)), ['b']);
    });
  });

  group('JsonSchema.check', () {
    test('accepts everything the builders produce', () {
      final schema = JsonSchema.object(
        {
          's': JsonSchema.string(description: 'd'),
          'e': JsonSchema.enumOf(['a']),
          'i': JsonSchema.integer(minimum: 0, maximum: 3),
          'n': JsonSchema.number(minimum: 0.5),
          'b': JsonSchema.boolean(),
          'l': JsonSchema.array(JsonSchema.string(), minItems: 1, maxItems: 4),
          'm': JsonSchema.mapOf(JsonSchema.anyOf([JsonSchema.string()])),
        },
        required: ['s'],
      );
      expect(JsonSchema.check(schema), isEmpty);
    });

    test('rejects keywords outside the subset', () {
      expect(JsonSchema.check({'type': 'string', 'format': 'date'}), [
        '#: unsupported keyword "format"',
      ]);
      expect(
        JsonSchema.check({r'$ref': '#/defs/x'}),
        contains(r'#: unsupported keyword "$ref"'),
      );
    });

    test('rejects malformed schemas with a path to the problem', () {
      expect(JsonSchema.check({'type': 'date'}), [
        '#: unsupported type "date"',
      ]);
      expect(JsonSchema.check(<String, Object?>{}), [
        '#: needs "type" or "anyOf"',
      ]);
      expect(JsonSchema.check({'type': 'array'}), [
        '#: an array needs "items"',
      ]);
      expect(
        JsonSchema.check(
          JsonSchema.object(
            {
              'a': {'type': 'strin'},
            },
            required: ['b'],
          ),
        ),
        [
          '#/properties/a: unsupported type "strin"',
          '#: required "b" is not a property',
        ],
      );
      expect(JsonSchema.check({'type': 'string', 'enum': <Object?>[]}), [
        '#: "enum" must be a non-empty list of scalars',
      ]);
      expect(
        JsonSchema.check({
          'type': 'string',
          'required': ['a'],
        }),
        [
          '#: required "a" is not a property',
          '#: object keywords need type "object"',
        ],
      );
    });
  });
}
