import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';

void main() {
  group('TextFieldDefinition', () {
    FieldTypeRegistry registryWith() =>
        FieldTypeRegistry()
          ..register(kTextFieldType, TextFieldDefinition.fromJson);

    test('definition round-trips through JSON identically', () {
      const definition = TextFieldDefinition(
        id: 'body',
        name: 'Body',
        description: 'The note body',
        isRequired: true,
        multiline: true,
        maxLength: 500,
      );
      final json =
          jsonDecode(jsonEncode(definition.toJson())) as Map<String, dynamic>;
      final restored = registryWith().definitionFromJson(json);
      expect(restored, equals(definition));
    });

    test('value round-trips, including the empty case', () {
      const definition = TextFieldDefinition(id: 't', name: 'T');
      for (final raw in ['hello', '', null]) {
        final value = definition.valueFromJson(raw);
        final back = definition.valueFromJson(
          jsonDecode(jsonEncode(value.toJson())),
        );
        expect(back, equals(value));
      }
      expect(definition.valueFromJson(null), const TextFieldValue(null));
    });

    test('valueFromJson tolerates a wrong-typed value without throwing', () {
      const definition = TextFieldDefinition(id: 't', name: 'T');
      // A stored integer (e.g. from a migration) must not crash parsing.
      expect(definition.valueFromJson(42), const TextFieldValue(null));
    });

    group('validation', () {
      test('maxLength rejects an over-long value', () {
        const definition = TextFieldDefinition(
          id: 't',
          name: 'Title',
          maxLength: 3,
        );
        final errors = definition.validate(const TextFieldValue('abcd'));
        expect(errors.single.code, ValidationError.tooLong);
        expect(errors.single.fieldId, 't');
      });

      test('maxLength accepts a value at the limit', () {
        const definition = TextFieldDefinition(
          id: 't',
          name: 'Title',
          maxLength: 3,
        );
        expect(definition.validate(const TextFieldValue('abc')), isEmpty);
      });

      test('required rejects empty, accepts non-empty', () {
        const definition = TextFieldDefinition(
          id: 't',
          name: 'Title',
          isRequired: true,
        );
        expect(
          definition.validate(definition.emptyValue()).single.code,
          ValidationError.requiredCode,
        );
        expect(definition.validate(const TextFieldValue('x')), isEmpty);
      });

      test('an empty string counts as empty for the required check', () {
        const definition = TextFieldDefinition(
          id: 't',
          name: 'Title',
          isRequired: true,
        );
        expect(
          definition.validate(const TextFieldValue('')).single.code,
          ValidationError.requiredCode,
        );
      });
    });
  });
}
