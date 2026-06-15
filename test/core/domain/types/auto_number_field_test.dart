import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';

void main() {
  FieldTypeRegistry buildRegistry() {
    final registry = FieldTypeRegistry();
    registry.register(kAutoNumberFieldType, AutoNumberFieldDefinition.fromJson);
    return registry;
  }

  group('AutoNumberFieldDefinition', () {
    test('JSON round-trip via registry reconstructs an equal definition', () {
      const def = AutoNumberFieldDefinition(
        id: 'invoice_no',
        name: 'Invoice #',
        description: 'Sequential invoice number',
        prefix: 'INV-',
        padding: 5,
      );

      final decoded =
          jsonDecode(jsonEncode(def.toJson())) as Map<String, dynamic>;
      final reconstructed = buildRegistry().definitionFromJson(decoded);

      expect(reconstructed, equals(def));
      expect(reconstructed.type, kAutoNumberFieldType);
    });

    test('round-trips with only the required keys (no optional config)', () {
      const def = AutoNumberFieldDefinition(id: 'seq', name: 'Sequence');

      final decoded =
          jsonDecode(jsonEncode(def.toJson())) as Map<String, dynamic>;
      final reconstructed = buildRegistry().definitionFromJson(decoded);

      expect(reconstructed, equals(def));
    });
  });

  group('AutoNumberFieldValue', () {
    const def = AutoNumberFieldDefinition(id: 'seq', name: 'Sequence');

    test('round-trips an assigned sequence number', () {
      const value = AutoNumberFieldValue(42);

      final parsed = def.valueFromJson(jsonDecode(jsonEncode(value.toJson())));

      expect(parsed, equals(value));
      expect((parsed as AutoNumberFieldValue).sequence, 42);
      expect(parsed.isNotEmpty, isTrue);
    });

    test('null/empty value round-trips to an empty value', () {
      expect(def.valueFromJson(null), equals(def.emptyValue()));
      expect(def.emptyValue().isEmpty, isTrue);
      expect(def.emptyValue().toJson(), isNull);
    });
  });

  group('validation', () {
    test('no spurious errors for an assigned value', () {
      const def = AutoNumberFieldDefinition(id: 'seq', name: 'Sequence');
      expect(def.validate(const AutoNumberFieldValue(7)), isEmpty);
    });

    test('an unassigned (empty) value passes when not required', () {
      const def = AutoNumberFieldDefinition(id: 'seq', name: 'Sequence');
      expect(def.validate(def.emptyValue()), isEmpty);
    });

    test('a required empty value is reported via definition.validate', () {
      const required = AutoNumberFieldDefinition(
        id: 'seq',
        name: 'Sequence',
        isRequired: true,
      );

      final errors = required.validate(required.emptyValue());

      expect(errors, hasLength(1));
      expect(errors.single.code, ValidationError.requiredCode);
    });
  });
}
