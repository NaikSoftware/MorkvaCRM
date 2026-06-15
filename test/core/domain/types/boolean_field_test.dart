import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';

void main() {
  FieldTypeRegistry buildRegistry() {
    final registry = FieldTypeRegistry();
    registry.register(kBooleanFieldType, BooleanFieldDefinition.fromJson);
    return registry;
  }

  group('BooleanFieldDefinition', () {
    test('JSON round-trip via registry reconstructs an equal definition', () {
      const def = BooleanFieldDefinition(
        id: 'active',
        name: 'Active',
        description: 'Whether the record is active',
        isRequired: true,
      );

      final decoded =
          jsonDecode(jsonEncode(def.toJson())) as Map<String, dynamic>;
      final reconstructed = buildRegistry().definitionFromJson(decoded);

      expect(reconstructed, equals(def));
      expect(reconstructed.type, kBooleanFieldType);
    });

    test('round-trips with only the required keys', () {
      const def = BooleanFieldDefinition(id: 'flag', name: 'Flag');

      final decoded =
          jsonDecode(jsonEncode(def.toJson())) as Map<String, dynamic>;
      final reconstructed = buildRegistry().definitionFromJson(decoded);

      expect(reconstructed, equals(def));
    });
  });

  group('BooleanFieldValue', () {
    const def = BooleanFieldDefinition(id: 'active', name: 'Active');

    test('round-trips true and false', () {
      for (final value in const [
        BooleanFieldValue(true),
        BooleanFieldValue(false),
      ]) {
        final parsed = def.valueFromJson(
          jsonDecode(jsonEncode(value.toJson())),
        );
        expect(parsed, equals(value));
        expect(parsed.isNotEmpty, isTrue);
      }
    });

    test('null/empty value round-trips to an empty value', () {
      expect(def.valueFromJson(null), equals(def.emptyValue()));
      expect(def.emptyValue().isEmpty, isTrue);
      expect(def.emptyValue().toJson(), isNull);
    });
  });

  group('validation', () {
    const def = BooleanFieldDefinition(id: 'active', name: 'Active');

    test('any concrete value passes', () {
      expect(def.validate(const BooleanFieldValue(true)), isEmpty);
      expect(def.validate(const BooleanFieldValue(false)), isEmpty);
    });

    test('an empty value passes when not required', () {
      expect(def.validate(def.emptyValue()), isEmpty);
    });

    test('a required empty value is rejected', () {
      const required = BooleanFieldDefinition(
        id: 'agree',
        name: 'Agree',
        isRequired: true,
      );

      final errors = required.validate(required.emptyValue());

      expect(errors, hasLength(1));
      expect(errors.single.code, ValidationError.requiredCode);
    });
  });
}
