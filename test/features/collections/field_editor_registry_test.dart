import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/features/collections/field_editors/built_in_field_editors.dart';

void main() {
  final typeRegistry = defaultFieldTypeRegistry();
  final editorRegistry = defaultFieldEditorRegistry();

  group('FieldEditorRegistry built-ins', () {
    test('every domain built-in type has a registered editor', () {
      for (final type in typeRegistry.registeredTypes) {
        expect(
          editorRegistry.forType(type),
          isNotNull,
          reason: 'No FieldEditor registered for domain type "$type".',
        );
      }
    });

    test('editor count matches domain type count', () {
      expect(editorRegistry.all.length, typeRegistry.registeredTypes.length);
    });

    test('each editor typeId is registered as a domain type', () {
      for (final editor in editorRegistry.all) {
        expect(
          typeRegistry.isRegistered(editor.typeId),
          isTrue,
          reason: 'Editor "${editor.typeId}" has no matching domain type.',
        );
      }
    });

    test('computed flag set only for auto_number and calculated', () {
      for (final editor in editorRegistry.all) {
        final expectComputed =
            editor.typeId == 'auto_number' || editor.typeId == 'calculated';
        expect(editor.isComputed, expectComputed, reason: editor.typeId);
      }
    });

    test('descriptors are non-empty', () {
      for (final editor in editorRegistry.all) {
        expect(editor.displayLabel, isNotEmpty, reason: editor.typeId);
        expect(editor.description, isNotEmpty, reason: editor.typeId);
      }
    });
  });

  group('createDefault round-trips through the domain JSON', () {
    test('every editor default survives toJson + definitionFromJson', () {
      var fieldNo = 0;
      for (final editor in editorRegistry.all) {
        final id = 'f_${fieldNo++}';
        final original = editor.createDefault(id: id, name: 'Field $id');

        final json = original.toJson();
        final restored = typeRegistry.definitionFromJson(json);

        expect(
          restored,
          equals(original),
          reason: 'Round-trip mismatch for type "${editor.typeId}".',
        );
        expect(restored.type, editor.typeId);
        expect(restored.id, id);
      }
    });

    test('text default is single-line', () {
      final def = const _Editors().text;
      expect(def.multiline, isFalse);
    });

    test('reference default has an empty target', () {
      final def = const _Editors().reference;
      expect(def.targetCollectionId, isEmpty);
    });

    test('calculated default declares text output', () {
      final def = const _Editors().calculated;
      expect(def.declaredOutputType, 'text');
    });
  });
}

/// Convenience accessor for typed defaults used in the focused assertions.
class _Editors {
  const _Editors();

  TextFieldDefinition get text {
    final registry = defaultFieldEditorRegistry();
    return registry.forType('text')!.createDefault(id: 'f', name: 'F')
        as TextFieldDefinition;
  }

  ReferenceFieldDefinition get reference {
    final registry = defaultFieldEditorRegistry();
    return registry.forType('reference')!.createDefault(id: 'f', name: 'F')
        as ReferenceFieldDefinition;
  }

  CalculatedFieldDefinition get calculated {
    final registry = defaultFieldEditorRegistry();
    return registry.forType('calculated')!.createDefault(id: 'f', name: 'F')
        as CalculatedFieldDefinition;
  }
}
