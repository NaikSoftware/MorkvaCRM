import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';

void main() {
  FieldTypeRegistry buildRegistry() {
    final registry = FieldTypeRegistry();
    registry.register(kFileFieldType, FileFieldDefinition.fromJson);
    return registry;
  }

  group('FileFieldDefinition', () {
    test('JSON round-trip via registry reconstructs an equal definition', () {
      const def = FileFieldDefinition(
        id: 'docs',
        name: 'Documents',
        description: 'Supporting files',
        isRequired: true,
        multiple: true,
        allowedExtensions: ['pdf', 'png'],
      );

      final decoded =
          jsonDecode(jsonEncode(def.toJson())) as Map<String, dynamic>;
      final reconstructed = buildRegistry().definitionFromJson(decoded);

      expect(reconstructed, equals(def));
      expect(reconstructed.type, kFileFieldType);
    });

    test('round-trips with only the required keys (no optional config)', () {
      const def = FileFieldDefinition(id: 'file', name: 'File');

      final decoded =
          jsonDecode(jsonEncode(def.toJson())) as Map<String, dynamic>;
      final reconstructed = buildRegistry().definitionFromJson(decoded);

      expect(reconstructed, equals(def));
      expect((reconstructed as FileFieldDefinition).multiple, isFalse);
      expect(reconstructed.allowedExtensions, isNull);
    });

    test('lowercases allowed extensions read from JSON', () {
      const def = FileFieldDefinition(
        id: 'imgs',
        name: 'Images',
        allowedExtensions: ['PNG', 'Jpg'],
      );

      final decoded =
          jsonDecode(jsonEncode(def.toJson())) as Map<String, dynamic>;
      final reconstructed =
          buildRegistry().definitionFromJson(decoded) as FileFieldDefinition;

      expect(reconstructed.allowedExtensions, ['png', 'jpg']);
    });
  });

  group('FileFieldValue', () {
    const def = FileFieldDefinition(id: 'docs', name: 'Documents');

    test('round-trips multiple attachments with optional fields set/unset', () {
      const value = FileFieldValue([
        FileAttachment(
          id: 'a1',
          name: 'report.pdf',
          mimeType: 'application/pdf',
          sizeBytes: 1024,
        ),
        FileAttachment(id: 'a2', name: 'notes.txt'),
      ]);

      final parsed = def.valueFromJson(jsonDecode(jsonEncode(value.toJson())));

      expect(parsed, equals(value));
      final attachments = (parsed as FileFieldValue).attachments;
      expect(attachments, hasLength(2));
      expect(attachments[0].mimeType, 'application/pdf');
      expect(attachments[0].sizeBytes, 1024);
      expect(attachments[1].mimeType, isNull);
      expect(attachments[1].sizeBytes, isNull);
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
    test('a single allowed attachment passes', () {
      const def = FileFieldDefinition(
        id: 'avatar',
        name: 'Avatar',
        allowedExtensions: ['png', 'jpg'],
      );

      final errors = def.validate(
        const FileFieldValue([FileAttachment(id: 'a', name: 'me.PNG')]),
      );

      expect(errors, isEmpty);
    });

    test('more than one attachment on a single-file field is rejected', () {
      const def = FileFieldDefinition(id: 'avatar', name: 'Avatar');

      final errors = def.validate(
        const FileFieldValue([
          FileAttachment(id: 'a', name: 'one.png'),
          FileAttachment(id: 'b', name: 'two.png'),
        ]),
      );

      expect(errors, hasLength(1));
      expect(errors.single.code, FileFieldDefinition.tooManyFiles);
      expect(errors.single.fieldId, 'avatar');
    });

    test('multiple attachments pass when multiple is enabled', () {
      const def = FileFieldDefinition(
        id: 'docs',
        name: 'Documents',
        multiple: true,
      );

      final errors = def.validate(
        const FileFieldValue([
          FileAttachment(id: 'a', name: 'one.png'),
          FileAttachment(id: 'b', name: 'two.png'),
        ]),
      );

      expect(errors, isEmpty);
    });

    test('a disallowed extension is rejected', () {
      const def = FileFieldDefinition(
        id: 'docs',
        name: 'Documents',
        multiple: true,
        allowedExtensions: ['pdf'],
      );

      final errors = def.validate(
        const FileFieldValue([
          FileAttachment(id: 'a', name: 'ok.pdf'),
          FileAttachment(id: 'b', name: 'bad.exe'),
        ]),
      );

      expect(errors, hasLength(1));
      expect(errors.single.code, FileFieldDefinition.invalidExtension);
      expect(errors.single.fieldId, 'docs');
    });

    test('a file with no extension is rejected when extensions restricted', () {
      const def = FileFieldDefinition(
        id: 'docs',
        name: 'Documents',
        allowedExtensions: ['pdf'],
      );

      final errors = def.validate(
        const FileFieldValue([FileAttachment(id: 'a', name: 'README')]),
      );

      expect(errors, hasLength(1));
      expect(errors.single.code, FileFieldDefinition.invalidExtension);
    });

    test('a required empty value is rejected', () {
      const required = FileFieldDefinition(
        id: 'docs',
        name: 'Documents',
        isRequired: true,
      );

      final errors = required.validate(required.emptyValue());

      expect(errors, hasLength(1));
      expect(errors.single.code, ValidationError.requiredCode);
    });

    test('an empty value when not required passes', () {
      const def = FileFieldDefinition(id: 'docs', name: 'Documents');
      expect(def.validate(def.emptyValue()), isEmpty);
    });
  });
}
