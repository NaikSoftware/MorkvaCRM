import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';

void main() {
  FieldTypeRegistry buildRegistry() {
    final registry = FieldTypeRegistry();
    registry.register(
      kMultiSelectFieldType,
      MultiSelectFieldDefinition.fromJson,
    );
    return registry;
  }

  const options = [
    SelectOption(id: 'red', label: 'Red', color: '#FF0000'),
    SelectOption(id: 'green', label: 'Green'),
    SelectOption(id: 'blue', label: 'Blue', color: '#0000FF'),
  ];

  group('MultiSelectFieldDefinition', () {
    test('JSON round-trip via registry reconstructs an equal definition', () {
      const def = MultiSelectFieldDefinition(
        id: 'colors',
        name: 'Colors',
        description: 'Pick any colors',
        isRequired: true,
        options: options,
      );

      final decoded =
          jsonDecode(jsonEncode(def.toJson())) as Map<String, dynamic>;
      final reconstructed = buildRegistry().definitionFromJson(decoded);

      expect(reconstructed, equals(def));
      expect(reconstructed.type, kMultiSelectFieldType);
    });

    test('round-trips with an empty option set', () {
      const def = MultiSelectFieldDefinition(id: 'tags', name: 'Tags');

      final decoded =
          jsonDecode(jsonEncode(def.toJson())) as Map<String, dynamic>;
      final reconstructed = buildRegistry().definitionFromJson(decoded);

      expect(reconstructed, equals(def));
    });
  });

  group('MultiSelectFieldValue', () {
    const def = MultiSelectFieldDefinition(
      id: 'colors',
      name: 'Colors',
      options: options,
    );

    test('round-trips a list of selected ids, preserving order', () {
      const value = MultiSelectFieldValue(['blue', 'red']);

      final parsed = def.valueFromJson(jsonDecode(jsonEncode(value.toJson())));

      expect(parsed, equals(value));
      expect((parsed as MultiSelectFieldValue).optionIds, ['blue', 'red']);
      expect(parsed.isNotEmpty, isTrue);
    });

    test('null/empty value round-trips to an empty value', () {
      expect(def.valueFromJson(null), equals(def.emptyValue()));
      expect(def.valueFromJson(const []), equals(def.emptyValue()));
      expect(def.emptyValue().isEmpty, isTrue);
      expect(def.emptyValue().toJson(), isEmpty);
    });
  });

  group('validation', () {
    const def = MultiSelectFieldDefinition(
      id: 'colors',
      name: 'Colors',
      options: options,
    );

    test('a selection of known options passes', () {
      expect(
        def.validate(const MultiSelectFieldValue(['red', 'green'])),
        isEmpty,
      );
    });

    test('an unknown option id is rejected as an invalid option', () {
      final errors = def.validate(const MultiSelectFieldValue(['red', 'cyan']));

      expect(errors, hasLength(1));
      expect(errors.single.code, ValidationError.invalidOption);
      expect(errors.single.fieldId, 'colors');
    });

    test('a required empty value is rejected', () {
      const required = MultiSelectFieldDefinition(
        id: 'colors',
        name: 'Colors',
        isRequired: true,
        options: options,
      );

      final errors = required.validate(required.emptyValue());

      expect(errors, hasLength(1));
      expect(errors.single.code, ValidationError.requiredCode);
    });

    test('an empty value when not required passes', () {
      expect(def.validate(def.emptyValue()), isEmpty);
    });
  });
}
