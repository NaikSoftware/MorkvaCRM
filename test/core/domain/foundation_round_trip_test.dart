import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';

void main() {
  group('Foundation contract (Collection + Object + Text)', () {
    final registry = defaultFieldTypeRegistry();

    Collection buildCollection() => const Collection(
          id: 'c1',
          name: 'Notes',
          description: 'A simple collection',
          fields: [
            TextFieldDefinition(
              id: 'title',
              name: 'Title',
              isRequired: true,
              maxLength: 80,
            ),
            TextFieldDefinition(
              id: 'body',
              name: 'Body',
              multiline: true,
            ),
          ],
        );

    test('collection round-trips through JSON identically', () {
      final collection = buildCollection();
      final json = jsonDecode(jsonEncode(collection.toJson()))
          as Map<String, dynamic>;
      final restored = Collection.fromJson(json, registry);
      expect(restored, equals(collection));
    });

    test('object round-trips through JSON identically', () {
      final collection = buildCollection();
      final created = DateTime.utc(2026, 6, 15, 10, 30, 0, 0, 123);
      final object = MorkvaObject.create(
        id: 'o1',
        collection: collection,
        values: const {'title': TextFieldValue('Hello')},
        createdAt: created,
        updatedAt: created,
      );

      final json =
          jsonDecode(jsonEncode(object.toJson())) as Map<String, dynamic>;
      final restored = MorkvaObject.fromJson(json, collection);

      expect(restored, equals(object));
      // Unset fields are normalized to empty values, not dropped.
      expect(restored['body'], const TextFieldValue(null));
    });

    test('required validation rejects empty and accepts filled', () {
      final collection = buildCollection();
      final created = DateTime.utc(2026, 6, 15);

      final invalid = MorkvaObject.create(
        id: 'o1',
        collection: collection,
        createdAt: created,
        updatedAt: created,
      ).validateAgainst(collection);
      expect(invalid.isValid, isFalse);
      expect(invalid.forField('title').single.code,
          ValidationError.requiredCode);

      final valid = MorkvaObject.create(
        id: 'o2',
        collection: collection,
        values: const {'title': TextFieldValue('Ok')},
        createdAt: created,
        updatedAt: created,
      ).validateAgainst(collection);
      expect(valid.isValid, isTrue);
    });

    test('registry rejects unknown field types', () {
      final empty = FieldTypeRegistry();
      expect(
        () => empty.definitionFromJson({'type': 'text', 'id': 'x', 'name': 'X'}),
        throwsA(isA<FieldTypeException>()),
      );
    });
  });
}
