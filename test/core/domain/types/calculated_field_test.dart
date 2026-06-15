import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';

void main() {
  FieldTypeRegistry buildRegistry() {
    final registry = FieldTypeRegistry();
    registry.register(kCalculatedFieldType, CalculatedFieldDefinition.fromJson);
    return registry;
  }

  group('CalculatedFieldDefinition', () {
    test('JSON round-trip via registry reconstructs an equal definition', () {
      const def = CalculatedFieldDefinition(
        id: 'total',
        name: 'Total',
        description: 'Sum of line items',
        declaredOutputType: 'number',
        expression: 'sum(items.amount)',
      );

      final decoded =
          jsonDecode(jsonEncode(def.toJson())) as Map<String, dynamic>;
      final reconstructed = buildRegistry().definitionFromJson(decoded);

      expect(reconstructed, equals(def));
      expect(reconstructed.type, kCalculatedFieldType);
    });

    test('round-trips with only the required keys (no expression)', () {
      const def = CalculatedFieldDefinition(
        id: 'label',
        name: 'Label',
        declaredOutputType: 'text',
      );

      final decoded =
          jsonDecode(jsonEncode(def.toJson())) as Map<String, dynamic>;
      final reconstructed = buildRegistry().definitionFromJson(decoded);

      expect(reconstructed, equals(def));
      expect(
        (reconstructed as CalculatedFieldDefinition).declaredOutputType,
        'text',
      );
      expect(reconstructed.expression, isNull);
    });
  });

  group('CalculatedFieldValue', () {
    const def = CalculatedFieldDefinition(
      id: 'total',
      name: 'Total',
      declaredOutputType: 'number',
    );

    test('round-trips a cached primitive', () {
      const value = CalculatedFieldValue(123.45);

      final parsed = def.valueFromJson(jsonDecode(jsonEncode(value.toJson())));

      expect(parsed, equals(value));
      expect((parsed as CalculatedFieldValue).cached, 123.45);
      expect(parsed.isNotEmpty, isTrue);
    });

    test('round-trips a cached list/map structure', () {
      const value = CalculatedFieldValue({
        'count': 2,
        'labels': ['a', 'b'],
      });

      final parsed = def.valueFromJson(jsonDecode(jsonEncode(value.toJson())));

      expect(parsed, equals(value));
    });

    test('null/empty value round-trips to an empty value', () {
      expect(def.valueFromJson(null), equals(def.emptyValue()));
      expect(def.emptyValue().isEmpty, isTrue);
      expect(def.emptyValue().toJson(), isNull);
    });
  });

  group('validation', () {
    test('no spurious errors for a derived value', () {
      const def = CalculatedFieldDefinition(
        id: 'total',
        name: 'Total',
        declaredOutputType: 'number',
      );
      expect(def.validate(const CalculatedFieldValue(10)), isEmpty);
    });

    test('an empty value passes when not required', () {
      const def = CalculatedFieldDefinition(
        id: 'total',
        name: 'Total',
        declaredOutputType: 'number',
      );
      expect(def.validate(def.emptyValue()), isEmpty);
    });

    test('a required empty value is reported via definition.validate', () {
      const required = CalculatedFieldDefinition(
        id: 'total',
        name: 'Total',
        declaredOutputType: 'number',
        isRequired: true,
      );

      final errors = required.validate(required.emptyValue());

      expect(errors, hasLength(1));
      expect(errors.single.code, ValidationError.requiredCode);
    });
  });
}
