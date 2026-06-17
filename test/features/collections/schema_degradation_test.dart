import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';

/// Epic 03 correctness contract (design §7): schema edits authored in the
/// editor must never corrupt existing object data. Object bytes are never
/// rewritten by this epic; safety rests on the Epic 1 read contract —
/// orphaned values are dropped, missing values become the empty value.
///
/// These tests apply add / remove / reorder / rename to a schema with existing
/// objects and assert each object still decodes with no throw and no
/// corruption, using the domain JSON round-trip directly (the same path the
/// repository uses on read).
void main() {
  final typeRegistry = defaultFieldTypeRegistry();

  Collection baseSchema() => const Collection(
    id: 'c_orders',
    name: 'Orders',
    fields: [
      TextFieldDefinition(id: 'f_title', name: 'Title'),
      NumberFieldDefinition(id: 'f_qty', name: 'Qty'),
      MultiSelectFieldDefinition(
        id: 'f_tags',
        name: 'Tags',
        options: [
          SelectOption(id: 'a', label: 'A'),
          SelectOption(id: 'b', label: 'B'),
        ],
      ),
    ],
  );

  MorkvaObject buildObject(Collection schema) => MorkvaObject.create(
    id: 'o1',
    collection: schema,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 2),
    values: const {
      'f_title': TextFieldValue('Widget order'),
      'f_qty': NumberFieldValue(7),
      'f_tags': MultiSelectFieldValue(['a', 'b']),
    },
  );

  /// Serializes [object], then reads it back against [schema] (the schema the
  /// editor produced). Round-trips the schema through JSON too, mirroring how
  /// the repository persists and reloads it.
  MorkvaObject reread(MorkvaObject object, Collection schema) {
    final schemaJson = schema.toJson();
    final reloadedSchema = Collection.fromJson(schemaJson, typeRegistry);
    final objectJson = object.toJson();
    return MorkvaObject.fromJson(objectJson, reloadedSchema);
  }

  test('baseline object round-trips unchanged', () {
    final schema = baseSchema();
    final object = buildObject(schema);
    final result = reread(object, schema);
    expect(result, equals(object));
  });

  test('add field: existing object reads the new field as empty', () {
    final schema = baseSchema();
    final object = buildObject(schema);

    final edited = schema.copyWith(
      fields: [
        ...schema.fields,
        const DateFieldDefinition(id: 'f_due', name: 'Due'),
      ],
    );

    late MorkvaObject result;
    expect(() => result = reread(object, edited), returnsNormally);
    expect(result.values['f_due'], const DateFieldValue(null));
    // Existing values are intact.
    expect(result.values['f_title'], const TextFieldValue('Widget order'));
    expect(result.values['f_qty'], const NumberFieldValue(7));
  });

  test('remove field: orphaned value is dropped, no throw', () {
    final schema = baseSchema();
    final object = buildObject(schema);

    final edited = schema.copyWith(
      fields: schema.fields.where((f) => f.id != 'f_qty').toList(),
    );

    late MorkvaObject result;
    expect(() => result = reread(object, edited), returnsNormally);
    expect(result.values.containsKey('f_qty'), isFalse);
    expect(result.values['f_title'], const TextFieldValue('Widget order'));
    expect(result.values['f_tags'], const MultiSelectFieldValue(['a', 'b']));
  });

  test('reorder fields: values key off id, not position', () {
    final schema = baseSchema();
    final object = buildObject(schema);

    final reversed = schema.copyWith(fields: schema.fields.reversed.toList());

    final result = reread(object, reversed);
    expect(result.values['f_title'], const TextFieldValue('Widget order'));
    expect(result.values['f_qty'], const NumberFieldValue(7));
    expect(result.values['f_tags'], const MultiSelectFieldValue(['a', 'b']));
  });

  test('rename field (label only, id stable): value preserved', () {
    final schema = baseSchema();
    final object = buildObject(schema);

    final edited = schema.copyWith(
      fields: [
        const TextFieldDefinition(id: 'f_title', name: 'Order Title'),
        const NumberFieldDefinition(id: 'f_qty', name: 'Quantity'),
        const MultiSelectFieldDefinition(
          id: 'f_tags',
          name: 'Labels',
          options: [
            SelectOption(id: 'a', label: 'A'),
            SelectOption(id: 'b', label: 'B'),
          ],
        ),
      ],
    );

    final result = reread(object, edited);
    expect(result.values['f_title'], const TextFieldValue('Widget order'));
    expect(result.values['f_qty'], const NumberFieldValue(7));
  });

  test('combined edits applied in sequence never corrupt or throw', () {
    var schema = baseSchema();
    final object = buildObject(schema);

    // Add a field.
    schema = schema.copyWith(
      fields: [
        ...schema.fields,
        const BooleanFieldDefinition(id: 'f_paid', name: 'Paid'),
      ],
    );
    // Remove qty.
    schema = schema.copyWith(
      fields: schema.fields.where((f) => f.id != 'f_qty').toList(),
    );
    // Reorder (reverse).
    schema = schema.copyWith(fields: schema.fields.reversed.toList());
    // Rename a remaining field's label.
    schema = schema.copyWith(
      fields: [
        for (final f in schema.fields)
          if (f.id == 'f_title')
            const TextFieldDefinition(id: 'f_title', name: 'Renamed')
          else
            f,
      ],
    );

    late MorkvaObject result;
    expect(() => result = reread(object, schema), returnsNormally);

    // Surviving fields keep their values; removed field is gone; added field
    // reads empty.
    expect(result.values['f_title'], const TextFieldValue('Widget order'));
    expect(result.values['f_tags'], const MultiSelectFieldValue(['a', 'b']));
    expect(result.values.containsKey('f_qty'), isFalse);
    expect(result.values['f_paid'], const BooleanFieldValue(null));
  });

  test('removing a select option leaves stored ids untouched on read', () {
    // Removing an option from a multi-select definition does not rewrite
    // objects; the stored ids round-trip verbatim (validation, not decoding,
    // would later flag the now-unknown id — out of scope here).
    final schema = baseSchema();
    final object = buildObject(schema);

    final edited = schema.copyWith(
      fields: [
        for (final f in schema.fields)
          if (f.id == 'f_tags')
            const MultiSelectFieldDefinition(
              id: 'f_tags',
              name: 'Tags',
              options: [SelectOption(id: 'a', label: 'A')],
            )
          else
            f,
      ],
    );

    late MorkvaObject result;
    expect(() => result = reread(object, edited), returnsNormally);
    expect(result.values['f_tags'], const MultiSelectFieldValue(['a', 'b']));
  });
}
