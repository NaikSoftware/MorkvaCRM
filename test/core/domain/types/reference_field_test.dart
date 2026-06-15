import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';

void main() {
  FieldTypeRegistry buildRegistry() {
    final registry = FieldTypeRegistry();
    registry.register(kReferenceFieldType, ReferenceFieldDefinition.fromJson);
    return registry;
  }

  group('ReferenceFieldDefinition', () {
    test('JSON round-trip via registry reconstructs an equal definition', () {
      const def = ReferenceFieldDefinition(
        id: 'owner',
        name: 'Owner',
        description: 'Linked contact',
        isRequired: true,
        targetCollectionId: 'contacts',
        multiple: true,
      );

      final decoded =
          jsonDecode(jsonEncode(def.toJson())) as Map<String, dynamic>;
      final reconstructed = buildRegistry().definitionFromJson(decoded);

      expect(reconstructed, equals(def));
      expect(reconstructed.type, kReferenceFieldType);
    });

    test('round-trips a single-valued reference (multiple defaults false)', () {
      const def = ReferenceFieldDefinition(
        id: 'owner',
        name: 'Owner',
        targetCollectionId: 'contacts',
      );

      final decoded =
          jsonDecode(jsonEncode(def.toJson())) as Map<String, dynamic>;
      final reconstructed = buildRegistry().definitionFromJson(decoded);

      expect(reconstructed, equals(def));
      expect((reconstructed as ReferenceFieldDefinition).multiple, isFalse);
    });
  });

  group('ReferenceFieldValue', () {
    const def = ReferenceFieldDefinition(
      id: 'owner',
      name: 'Owner',
      targetCollectionId: 'contacts',
      multiple: true,
    );

    test('round-trips a list of object ids, preserving order', () {
      const value = ReferenceFieldValue(['c2', 'c1']);

      final parsed = def.valueFromJson(jsonDecode(jsonEncode(value.toJson())));

      expect(parsed, equals(value));
      expect((parsed as ReferenceFieldValue).objectIds, ['c2', 'c1']);
      expect(parsed.isNotEmpty, isTrue);
    });

    test('valueFromJson accepts a JSON list', () {
      final parsed = def.valueFromJson(const ['c1', 'c2']);

      expect(parsed, const ReferenceFieldValue(['c1', 'c2']));
    });

    test('valueFromJson accepts a bare string as a single-element list', () {
      final parsed = def.valueFromJson('c1');

      expect(parsed, const ReferenceFieldValue(['c1']));
      expect((parsed as ReferenceFieldValue).objectIds, ['c1']);
    });

    test('null/empty value round-trips to an empty value', () {
      expect(def.valueFromJson(null), equals(def.emptyValue()));
      expect(def.valueFromJson(const []), equals(def.emptyValue()));
      expect(def.emptyValue().isEmpty, isTrue);
      expect(def.emptyValue().toJson(), isEmpty);
    });
  });

  group('validation', () {
    test('a single reference passes when not multiple', () {
      const def = ReferenceFieldDefinition(
        id: 'owner',
        name: 'Owner',
        targetCollectionId: 'contacts',
      );

      expect(def.validate(const ReferenceFieldValue(['c1'])), isEmpty);
    });

    test('multiple references pass when multiple is true', () {
      const def = ReferenceFieldDefinition(
        id: 'owners',
        name: 'Owners',
        targetCollectionId: 'contacts',
        multiple: true,
      );

      expect(def.validate(const ReferenceFieldValue(['c1', 'c2'])), isEmpty);
    });

    test('a blank reference id is rejected as an invalid reference', () {
      const def = ReferenceFieldDefinition(
        id: 'owner',
        name: 'Owner',
        targetCollectionId: 'contacts',
        multiple: true,
      );

      final errors = def.validate(const ReferenceFieldValue(['c1', '']));

      expect(errors, hasLength(1));
      expect(errors.single.code, ValidationError.invalidReference);
      expect(errors.single.fieldId, 'owner');
    });

    test('more than one reference is rejected when not multiple', () {
      const def = ReferenceFieldDefinition(
        id: 'owner',
        name: 'Owner',
        targetCollectionId: 'contacts',
      );

      final errors = def.validate(const ReferenceFieldValue(['c1', 'c2']));

      expect(errors, hasLength(1));
      expect(errors.single.code, kTooManyReferencesCode);
    });

    test('a required empty value is rejected', () {
      const required = ReferenceFieldDefinition(
        id: 'owner',
        name: 'Owner',
        targetCollectionId: 'contacts',
        isRequired: true,
      );

      final errors = required.validate(required.emptyValue());

      expect(errors, hasLength(1));
      expect(errors.single.code, ValidationError.requiredCode);
    });

    test('an empty value when not required passes', () {
      const def = ReferenceFieldDefinition(
        id: 'owner',
        name: 'Owner',
        targetCollectionId: 'contacts',
      );

      expect(def.validate(def.emptyValue()), isEmpty);
    });
  });
}
