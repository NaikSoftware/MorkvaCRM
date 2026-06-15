import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';

void main() {
  group('SingleSelectFieldDefinition', () {
    late FieldTypeRegistry registry;

    setUp(() {
      registry = FieldTypeRegistry()
        ..register(
          kSingleSelectFieldType,
          SingleSelectFieldDefinition.fromJson,
        );
    });

    const options = [
      SelectOption(id: 'low', label: 'Low'),
      SelectOption(id: 'med', label: 'Medium', color: '#FFAA00'),
      SelectOption(id: 'high', label: 'High', color: '#FF0000'),
    ];

    test('definition round-trips through JSON identically', () {
      const definition = SingleSelectFieldDefinition(
        id: 'priority',
        name: 'Priority',
        description: 'How urgent',
        isRequired: true,
        options: options,
      );

      final json =
          jsonDecode(jsonEncode(definition.toJson())) as Map<String, dynamic>;
      final restored = registry.definitionFromJson(json);

      expect(restored, equals(definition));
    });

    test('definition with no options round-trips', () {
      const definition = SingleSelectFieldDefinition(id: 'p', name: 'Pick');
      final json =
          jsonDecode(jsonEncode(definition.toJson())) as Map<String, dynamic>;
      final restored = registry.definitionFromJson(json);
      expect(restored, equals(definition));
    });

    group('value round-trip', () {
      const definition = SingleSelectFieldDefinition(
        id: 'priority',
        name: 'Priority',
        options: options,
      );

      test('null value is empty and round-trips', () {
        final empty = definition.emptyValue();
        expect(empty.isEmpty, isTrue);
        expect(empty.toJson(), isNull);

        final restored = definition.valueFromJson(empty.toJson());
        expect(restored, const SingleSelectFieldValue(null));
      });

      test('selected option id round-trips', () {
        final value =
            definition.valueFromJson('high') as SingleSelectFieldValue;
        expect(value.optionId, 'high');
        expect(value.isEmpty, isFalse);
        expect(value.toJson(), 'high');

        final again = definition.valueFromJson(value.toJson());
        expect(again, value);
      });
    });

    group('validation', () {
      const definition = SingleSelectFieldDefinition(
        id: 'priority',
        name: 'Priority',
        options: options,
      );

      test('known option passes', () {
        expect(
          definition.validate(const SingleSelectFieldValue('med')),
          isEmpty,
        );
      });

      test('unknown option is rejected as invalidOption', () {
        final errors = definition.validate(
          const SingleSelectFieldValue('urgent'),
        );
        expect(errors.single.code, ValidationError.invalidOption);
        expect(errors.single.fieldId, 'priority');
      });

      test('required empty value is rejected', () {
        const required = SingleSelectFieldDefinition(
          id: 'priority',
          name: 'Priority',
          isRequired: true,
          options: options,
        );
        final errors = required.validate(required.emptyValue());
        expect(errors.single.code, ValidationError.requiredCode);
      });

      test('non-required empty value passes', () {
        expect(definition.validate(definition.emptyValue()), isEmpty);
      });
    });
  });
}
