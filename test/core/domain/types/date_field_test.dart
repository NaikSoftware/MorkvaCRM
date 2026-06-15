import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';

void main() {
  group('DateFieldDefinition', () {
    late FieldTypeRegistry registry;

    setUp(() {
      registry = FieldTypeRegistry()
        ..register(kDateFieldType, DateFieldDefinition.fromJson);
    });

    test('definition round-trips through JSON identically', () {
      final definition = DateFieldDefinition(
        id: 'due',
        name: 'Due',
        description: 'Deadline',
        isRequired: true,
        includeTime: true,
        min: DateTime.utc(2020),
        max: DateTime.utc(2030, 12, 31, 23, 59, 59),
      );

      final json =
          jsonDecode(jsonEncode(definition.toJson())) as Map<String, dynamic>;
      final restored = registry.definitionFromJson(json);

      expect(restored, equals(definition));
    });

    test('date-only definition defaults includeTime to false', () {
      final definition = DateFieldDefinition(id: 'd', name: 'Date');
      expect(definition.includeTime, isFalse);

      final json =
          jsonDecode(jsonEncode(definition.toJson())) as Map<String, dynamic>;
      final restored = registry.definitionFromJson(json);
      expect(restored, equals(definition));
    });

    group('value round-trip', () {
      test('null value is empty and round-trips', () {
        final definition = DateFieldDefinition(id: 'd', name: 'Date');
        final empty = definition.emptyValue();
        expect(empty.isEmpty, isTrue);
        expect(empty.toJson(), isNull);

        final restored = definition.valueFromJson(empty.toJson());
        expect(restored, const DateFieldValue(null));
        expect(restored.isEmpty, isTrue);
      });

      test('date-only normalizes to midnight UTC on parse', () {
        final definition = DateFieldDefinition(id: 'd', name: 'Date');
        // A value carrying a time component is normalized to date-only UTC.
        final parsed =
            definition.valueFromJson('2026-06-15T13:45:30.000Z')
                as DateFieldValue;
        expect(parsed.value, DateTime.utc(2026, 6, 15));

        // Round-trip from the normalized representation is stable.
        final again = definition.valueFromJson(parsed.toJson());
        expect(again, parsed);
      });

      test('bare date is read as a UTC calendar date in any time zone', () {
        // Regression: a zone-less date must NOT be shifted through local time,
        // or the calendar day flips on machines with a non-zero UTC offset.
        final definition = DateFieldDefinition(id: 'd', name: 'Date');
        final parsed = definition.valueFromJson('2027-01-01') as DateFieldValue;
        expect(parsed.value, DateTime.utc(2027, 1, 1));
        expect(parsed.value!.isUtc, isTrue);
      });

      test('zone-less date-time is read as a UTC wall-clock value', () {
        final definition = DateFieldDefinition(
          id: 'ts',
          name: 'Timestamp',
          includeTime: true,
        );
        final parsed =
            definition.valueFromJson('2026-06-15T13:45:30') as DateFieldValue;
        expect(parsed.value, DateTime.utc(2026, 6, 15, 13, 45, 30));
      });

      test('date-only normalizes non-UTC input to UTC midnight', () {
        final definition = DateFieldDefinition(id: 'd', name: 'Date');
        // 2026-06-15T01:00:00+05:00 == 2026-06-14T20:00:00Z -> date is the 14th.
        final parsed =
            definition.valueFromJson('2026-06-15T01:00:00+05:00')
                as DateFieldValue;
        expect(parsed.value, DateTime.utc(2026, 6, 14));
      });

      test('date-time preserves the instant in UTC', () {
        final definition = DateFieldDefinition(
          id: 'ts',
          name: 'Timestamp',
          includeTime: true,
        );
        final parsed =
            definition.valueFromJson('2026-06-15T13:45:30.000Z')
                as DateFieldValue;
        expect(parsed.value, DateTime.utc(2026, 6, 15, 13, 45, 30));
        expect(parsed.value!.isUtc, isTrue);

        final again = definition.valueFromJson(parsed.toJson());
        expect(again, parsed);
      });

      test('date-time converts a zoned instant to UTC', () {
        final definition = DateFieldDefinition(
          id: 'ts',
          name: 'Timestamp',
          includeTime: true,
        );
        final parsed =
            definition.valueFromJson('2026-06-15T15:45:30+02:00')
                as DateFieldValue;
        expect(parsed.value, DateTime.utc(2026, 6, 15, 13, 45, 30));
      });
    });

    group('validation', () {
      test('value within bounds passes', () {
        final definition = DateFieldDefinition(
          id: 'd',
          name: 'Date',
          min: DateTime.utc(2026),
          max: DateTime.utc(2026, 12, 31),
        );
        final value = definition.valueFromJson('2026-06-15');
        expect(definition.validate(value), isEmpty);
      });

      test('value before min is rejected as outOfRange', () {
        final definition = DateFieldDefinition(
          id: 'd',
          name: 'Date',
          min: DateTime.utc(2026),
        );
        final value = definition.valueFromJson('2025-12-31');
        final errors = definition.validate(value);
        expect(errors.single.code, ValidationError.outOfRange);
        expect(errors.single.fieldId, 'd');
      });

      test('value after max is rejected as outOfRange', () {
        final definition = DateFieldDefinition(
          id: 'd',
          name: 'Date',
          max: DateTime.utc(2026, 12, 31),
        );
        final value = definition.valueFromJson('2027-01-01');
        final errors = definition.validate(value);
        expect(errors.single.code, ValidationError.outOfRange);
      });

      test('required empty value is rejected', () {
        final definition = DateFieldDefinition(
          id: 'd',
          name: 'Date',
          isRequired: true,
        );
        final errors = definition.validate(definition.emptyValue());
        expect(errors.single.code, ValidationError.requiredCode);
      });

      test('non-required empty value passes', () {
        final definition = DateFieldDefinition(id: 'd', name: 'Date');
        expect(definition.validate(definition.emptyValue()), isEmpty);
      });
    });
  });
}
