import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/api/firestore/firestore_value_codec_impl.dart';
import 'package:morkva_crm/core/domain/domain.dart';

void main() {
  const codec = FirestoreValueCodecImpl();

  /// Asserts encode→decode returns a value equal to the original canonical JSON,
  /// and that the decoded value rebuilds the same [FieldValue] via the field.
  void expectRoundTrip(FieldDefinition field, Object? canonicalJson) {
    final encoded = codec.encode(field, canonicalJson);
    final decoded = codec.decode(field, encoded);
    expect(
      field.valueFromJson(decoded),
      equals(field.valueFromJson(canonicalJson)),
      reason: 'value round-trip for ${field.type}',
    );
  }

  group('date field', () {
    const dateOnly = DateFieldDefinition(id: 'd', name: 'Date');
    const dateTime = DateFieldDefinition(
      id: 'dt',
      name: 'When',
      includeTime: true,
    );

    test('encodes ISO-8601 string to a UTC Timestamp', () {
      const iso = '2026-06-15T00:00:00.000Z';
      final encoded = codec.encode(dateOnly, iso);
      expect(encoded, isA<Timestamp>());
      expect(
        (encoded! as Timestamp).toDate().toUtc().toIso8601String(),
        '2026-06-15T00:00:00.000Z',
      );
    });

    test('decodes a Timestamp to an ISO-8601 UTC string', () {
      final ts = Timestamp.fromDate(DateTime.utc(2026, 6, 15, 13, 45, 30));
      final decoded = codec.decode(dateTime, ts);
      expect(decoded, '2026-06-15T13:45:30.000Z');
    });

    test('round-trips a date-only value (includeTime false)', () {
      final value = DateFieldValue(DateTime.utc(2026, 6, 15));
      expectRoundTrip(dateOnly, value.toJson());
    });

    test('round-trips a date-time value (includeTime true)', () {
      final value = DateFieldValue(DateTime.utc(2026, 6, 15, 13, 45, 30, 123));
      expectRoundTrip(dateTime, value.toJson());
    });

    test('date-only normalizes away any time component on round-trip', () {
      // A stored instant with a time component, decoded under a date-only field,
      // must normalize back to midnight UTC.
      final ts = Timestamp.fromDate(DateTime.utc(2026, 6, 15, 9, 30));
      final decoded = codec.decode(dateOnly, ts);
      final rebuilt = dateOnly.valueFromJson(decoded) as DateFieldValue;
      expect(rebuilt.value, DateTime.utc(2026, 6, 15));
    });

    test('null encodes and decodes to null', () {
      expect(codec.encode(dateOnly, null), isNull);
      expect(codec.decode(dateOnly, null), isNull);
    });
  });

  group('pass-through types', () {
    test('text', () {
      const field = TextFieldDefinition(id: 't', name: 'Text');
      expect(codec.encode(field, 'hello'), 'hello');
      expect(codec.decode(field, 'hello'), 'hello');
      expectRoundTrip(field, 'hello');
      expectRoundTrip(field, null);
    });

    test('number', () {
      const field = NumberFieldDefinition(id: 'n', name: 'Number');
      expect(codec.encode(field, 42.5), 42.5);
      expectRoundTrip(field, 42.5);
      expectRoundTrip(field, 7);
      expectRoundTrip(field, null);
    });

    test('boolean', () {
      const field = BooleanFieldDefinition(id: 'b', name: 'Flag');
      expect(codec.encode(field, true), true);
      expectRoundTrip(field, true);
      expectRoundTrip(field, false);
      expectRoundTrip(field, null);
    });

    test('auto_number', () {
      const field = AutoNumberFieldDefinition(id: 'a', name: 'Seq');
      expect(codec.encode(field, 99), 99);
      expectRoundTrip(field, 99);
      expectRoundTrip(field, null);
    });

    test('single_select', () {
      const field = SingleSelectFieldDefinition(
        id: 's',
        name: 'Pick',
        options: [SelectOption(id: 'opt1', label: 'One')],
      );
      expect(codec.encode(field, 'opt1'), 'opt1');
      expectRoundTrip(field, 'opt1');
      expectRoundTrip(field, null);
    });

    test('multi_select', () {
      const field = MultiSelectFieldDefinition(
        id: 'm',
        name: 'Tags',
        options: [
          SelectOption(id: 'a', label: 'A'),
          SelectOption(id: 'b', label: 'B'),
        ],
      );
      final value = ['a', 'b'];
      expect(codec.encode(field, value), value);
      expectRoundTrip(field, value);
      expectRoundTrip(field, const <String>[]);
    });

    test('reference', () {
      const field = ReferenceFieldDefinition(
        id: 'r',
        name: 'Ref',
        targetCollectionId: 'other',
        multiple: true,
      );
      final value = ['id1', 'id2'];
      expect(codec.encode(field, value), value);
      expectRoundTrip(field, value);
    });

    test('file', () {
      const field = FileFieldDefinition(id: 'f', name: 'Files', multiple: true);
      final value = [
        {'id': 'file1', 'name': 'photo.png', 'mimeType': 'image/png'},
        {'id': 'file2', 'name': 'doc.pdf'},
      ];
      expect(codec.encode(field, value), value);
      expectRoundTrip(field, value);
    });

    test('calculated', () {
      const field = CalculatedFieldDefinition(
        id: 'c',
        name: 'Calc',
        declaredOutputType: 'number',
      );
      expect(codec.encode(field, 123), 123);
      expectRoundTrip(field, 123);
      expectRoundTrip(field, 'cached text');
      expectRoundTrip(field, null);
    });
  });
}
