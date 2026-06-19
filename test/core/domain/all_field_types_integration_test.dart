import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';

/// End-to-end proof of the Epic 1 acceptance criteria: a collection using
/// *every* field type round-trips through JSON identically, and validation
/// accepts valid values while rejecting invalid ones across all types.
void main() {
  final registry = defaultFieldTypeRegistry();

  // A collection exercising every built-in field type.
  Collection buildKitchenSink() => Collection(
    id: 'everything',
    name: 'Everything',
    description: 'One object with every field type',
    fields: const [
      TextFieldDefinition(
        id: 'f_text',
        name: 'Text',
        isRequired: true,
        maxLength: 100,
      ),
      NumberFieldDefinition(
        id: 'f_number',
        name: 'Number',
        min: 0,
        max: 1000,
        unitLabel: '₴',
      ),
      BooleanFieldDefinition(id: 'f_bool', name: 'Bool'),
      DateFieldDefinition(id: 'f_date', name: 'Date'),
      DateFieldDefinition(id: 'f_datetime', name: 'When', includeTime: true),
      SingleSelectFieldDefinition(
        id: 'f_single',
        name: 'Stage',
        options: [
          SelectOption(id: 'new', label: 'New', color: '#FF0000'),
          SelectOption(id: 'done', label: 'Done'),
        ],
      ),
      MultiSelectFieldDefinition(
        id: 'f_multi',
        name: 'Tags',
        options: [
          SelectOption(id: 'a', label: 'A'),
          SelectOption(id: 'b', label: 'B'),
        ],
      ),
      ReferenceFieldDefinition(
        id: 'f_ref',
        name: 'Owner',
        targetCollectionId: 'people',
      ),
      ReferenceFieldDefinition(
        id: 'f_refs',
        name: 'Members',
        targetCollectionId: 'people',
        multiple: true,
      ),
      FileFieldDefinition(
        id: 'f_file',
        name: 'Docs',
        multiple: true,
        allowedExtensions: ['pdf', 'png'],
      ),
      AutoNumberFieldDefinition(
        id: 'f_auto',
        name: 'No.',
        prefix: 'INV-',
        padding: 5,
      ),
      CalculatedFieldDefinition(
        id: 'f_calc',
        name: 'Total',
        declaredOutputType: kNumberFieldType,
        expression: 'price * qty',
      ),
    ],
    layout: CardLayout.synthesize([
      'f_text',
      'f_number',
      'f_bool',
      'f_date',
      'f_datetime',
      'f_single',
      'f_multi',
      'f_ref',
      'f_refs',
      'f_file',
      'f_auto',
      'f_calc',
    ]),
  );

  final ts = DateTime.utc(2026, 6, 16, 9, 0, 0, 0, 42);

  MorkvaObject buildPopulated(Collection c) => MorkvaObject.create(
    id: 'o1',
    collection: c,
    createdAt: ts,
    updatedAt: ts,
    values: const {
      'f_text': TextFieldValue('Hello'),
      'f_number': NumberFieldValue(42),
      'f_bool': BooleanFieldValue(true),
      'f_date': DateFieldValue(null),
      'f_single': SingleSelectFieldValue('new'),
      'f_multi': MultiSelectFieldValue(['a', 'b']),
      'f_ref': ReferenceFieldValue(['p1']),
      'f_refs': ReferenceFieldValue(['p1', 'p2']),
      'f_file': FileFieldValue([
        FileAttachment(id: 'd1', name: 'spec.pdf', mimeType: 'application/pdf'),
      ]),
      'f_auto': AutoNumberFieldValue(7),
      'f_calc': CalculatedFieldValue(126),
    },
  );

  test('collection with every field type round-trips identically', () {
    final collection = buildKitchenSink();
    final json =
        jsonDecode(jsonEncode(collection.toJson())) as Map<String, dynamic>;
    final restored = Collection.fromJson(json, registry);
    expect(restored, equals(collection));
  });

  test('object with every field type round-trips identically', () {
    final collection = buildKitchenSink();
    final object = buildPopulated(collection);
    final json =
        jsonDecode(jsonEncode(object.toJson())) as Map<String, dynamic>;
    final restored = MorkvaObject.fromJson(json, collection);
    expect(restored, equals(object));
  });

  test('a fully valid object passes validation', () {
    final collection = buildKitchenSink();
    final result = buildPopulated(collection).validateAgainst(collection);
    expect(result.isValid, isTrue, reason: result.errors.toString());
  });

  test('each field type rejects its invalid value', () {
    final collection = buildKitchenSink();
    final invalid = MorkvaObject.create(
      id: 'bad',
      collection: collection,
      createdAt: ts,
      updatedAt: ts,
      values: const {
        // f_text required → left empty.
        'f_number': NumberFieldValue(5000), // > max
        'f_single': SingleSelectFieldValue('nope'), // invalid option
        'f_multi': MultiSelectFieldValue(['a', 'zzz']), // one invalid option
        'f_ref': ReferenceFieldValue(['x', 'y']), // single ref with 2 ids
        'f_file': FileFieldValue([
          FileAttachment(id: 'd1', name: 'virus.exe'), // bad extension
        ]),
      },
    );
    final result = invalid.validateAgainst(collection);

    expect(result.forField('f_text').single.code, ValidationError.requiredCode);
    expect(result.forField('f_number').single.code, ValidationError.outOfRange);
    expect(
      result.forField('f_single').single.code,
      ValidationError.invalidOption,
    );
    expect(
      result.forField('f_multi').single.code,
      ValidationError.invalidOption,
    );
    expect(result.forField('f_ref').single.code, kTooManyReferencesCode);
    expect(
      result.forField('f_file').single.code,
      FileFieldDefinition.invalidExtension,
    );
  });

  test('every built-in field type is registered', () {
    expect(registry.registeredTypes.toSet(), {
      kTextFieldType,
      kNumberFieldType,
      kBooleanFieldType,
      kDateFieldType,
      kSingleSelectFieldType,
      kMultiSelectFieldType,
      kReferenceFieldType,
      kFileFieldType,
      kAutoNumberFieldType,
      kCalculatedFieldType,
    });
  });
}
