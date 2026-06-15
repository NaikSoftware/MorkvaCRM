import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';

void main() {
  FieldTypeRegistry buildRegistry() {
    final registry = FieldTypeRegistry();
    registry.register(kNumberFieldType, NumberFieldDefinition.fromJson);
    return registry;
  }

  group('NumberFieldDefinition', () {
    test('JSON round-trip via registry reconstructs an equal definition', () {
      const def = NumberFieldDefinition(
        id: 'price',
        name: 'Price',
        description: 'Unit price',
        isRequired: true,
        decimalPlaces: 2,
        unitLabel: r'$',
        min: 0,
        max: 1000,
      );

      final decoded =
          jsonDecode(jsonEncode(def.toJson())) as Map<String, dynamic>;
      final reconstructed = buildRegistry().definitionFromJson(decoded);

      expect(reconstructed, equals(def));
      expect(reconstructed.type, kNumberFieldType);
    });

    test('round-trips with only the required keys (no optional config)', () {
      const def = NumberFieldDefinition(id: 'qty', name: 'Quantity');

      final decoded =
          jsonDecode(jsonEncode(def.toJson())) as Map<String, dynamic>;
      final reconstructed = buildRegistry().definitionFromJson(decoded);

      expect(reconstructed, equals(def));
    });
  });

  group('NumberFieldValue', () {
    test('round-trips an int, preserving its type', () {
      const def = NumberFieldDefinition(id: 'qty', name: 'Quantity');
      const value = NumberFieldValue(42);

      final parsed = def.valueFromJson(jsonDecode(jsonEncode(value.toJson())));

      expect(parsed, equals(value));
      expect((parsed as NumberFieldValue).value, isA<int>());
      expect(parsed.isNotEmpty, isTrue);
    });

    test('round-trips a double, preserving its type', () {
      const def = NumberFieldDefinition(id: 'weight', name: 'Weight');
      const value = NumberFieldValue(3.5);

      final parsed = def.valueFromJson(jsonDecode(jsonEncode(value.toJson())));

      expect(parsed, equals(value));
      expect((parsed as NumberFieldValue).value, isA<double>());
    });

    test('null/empty value round-trips to an empty value', () {
      const def = NumberFieldDefinition(id: 'qty', name: 'Quantity');

      expect(def.valueFromJson(null), equals(def.emptyValue()));
      expect(def.emptyValue().isEmpty, isTrue);
      expect(def.emptyValue().toJson(), isNull);
    });
  });

  group('validation', () {
    const def = NumberFieldDefinition(
      id: 'score',
      name: 'Score',
      min: 0,
      max: 100,
    );

    test('a value within range passes', () {
      expect(def.validate(const NumberFieldValue(50)), isEmpty);
    });

    test('a value below min is rejected as out of range', () {
      final errors = def.validate(const NumberFieldValue(-1));

      expect(errors, hasLength(1));
      expect(errors.single.code, ValidationError.outOfRange);
      expect(errors.single.fieldId, 'score');
    });

    test('a value above max is rejected as out of range', () {
      final errors = def.validate(const NumberFieldValue(101));

      expect(errors, hasLength(1));
      expect(errors.single.code, ValidationError.outOfRange);
    });

    test('a required empty value is rejected', () {
      const required = NumberFieldDefinition(
        id: 'qty',
        name: 'Quantity',
        isRequired: true,
      );

      final errors = required.validate(required.emptyValue());

      expect(errors, hasLength(1));
      expect(errors.single.code, ValidationError.requiredCode);
    });

    test('an empty value with no bounds and not required passes', () {
      expect(def.validate(def.emptyValue()), isEmpty);
    });
  });
}
