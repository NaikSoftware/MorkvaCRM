import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';

const _orders = Collection(
  id: 'orders',
  name: 'Orders',
  fields: [
    TextFieldDefinition(id: 'title', name: 'Title'),
    DateFieldDefinition(id: 'due', name: 'Due'),
    ReferenceFieldDefinition(
      id: 'client',
      name: 'Client',
      targetCollectionId: 'clients',
    ),
    FileFieldDefinition(id: 'files', name: 'Files'),
    SingleSelectFieldDefinition(
      id: 'status',
      name: 'Status',
      options: [SelectOption(id: 'o_new', label: 'New')],
    ),
  ],
);

Collection _with(List<FieldDefinition> fields, {String name = 'Orders'}) =>
    _orders.copyWith(name: name, fields: fields);

List<SchemaIssueCode> _codes(SchemaValidation v) => [
  for (final i in v.issues) i.code,
];

void main() {
  test('a complete schema has no issues', () {
    final v = validateCollectionSchema(
      _orders,
      saved: _orders,
      collectionIds: {'orders', 'clients'},
      strict: true,
    );
    expect(v.issues, isEmpty);
    expect(v.hasBlocking, isFalse);
  });

  test('a blank collection name blocks', () {
    final v = validateCollectionSchema(_with(_orders.fields, name: '  '));
    expect(_codes(v), [SchemaIssueCode.emptyCollectionName]);
    expect(v.hasBlocking, isTrue);
    expect(v.blocking.single.fieldId, isNull);
  });

  test('blank and case-insensitive duplicate field names block', () {
    final v = validateCollectionSchema(
      _with([
        ..._orders.fields,
        const TextFieldDefinition(id: 'f_blank', name: ' '),
        const NumberFieldDefinition(id: 'f_dup', name: ' title '),
      ]),
    );
    expect(_codes(v), [
      SchemaIssueCode.emptyFieldName,
      SchemaIssueCode.duplicateFieldName,
    ]);
    expect(v.blocking.map((i) => i.fieldId), ['f_blank', 'f_dup']);
    expect(v.blocking.last.message, 'Duplicate field name "title"');
  });

  group('type lock', () {
    test('changing the type of a saved field blocks', () {
      final v = validateCollectionSchema(
        _with([
          for (final f in _orders.fields)
            f.id == 'title'
                ? const NumberFieldDefinition(id: 'title', name: 'Title')
                : f,
        ]),
        saved: _orders,
      );
      expect(_codes(v), [SchemaIssueCode.typeLocked]);
      expect(v.blocking.single.fieldId, 'title');
    });

    test('a field that is not saved yet may change type', () {
      const draft = Collection(
        id: 'orders',
        name: 'Orders',
        fields: [NumberFieldDefinition(id: 'f_new', name: 'Qty')],
      );
      final v = validateCollectionSchema(draft, saved: _orders);
      expect(v.issues, isEmpty);
    });

    final flipped = _with([
      for (final f in _orders.fields)
        switch (f) {
          final DateFieldDefinition d => DateFieldDefinition(
            id: d.id,
            name: d.name,
            includeTime: true,
          ),
          final ReferenceFieldDefinition r => ReferenceFieldDefinition(
            id: r.id,
            name: r.name,
            targetCollectionId: r.targetCollectionId,
            multiple: true,
          ),
          final FileFieldDefinition file => FileFieldDefinition(
            id: file.id,
            name: file.name,
            multiple: !file.multiple,
          ),
          _ => f,
        },
    ]);

    test('the editor may flip multiple and includeTime', () {
      expect(validateCollectionSchema(flipped, saved: _orders).issues, isEmpty);
    });

    test('strict mode locks multiple and includeTime like a type', () {
      final v = validateCollectionSchema(
        flipped,
        saved: _orders,
        collectionIds: {'clients'},
        strict: true,
      );
      expect(_codes(v), List.filled(3, SchemaIssueCode.typeLocked));
      expect(v.blocking.map((i) => i.fieldId), ['due', 'client', 'files']);
    });
  });

  group('unfinished select and reference fields', () {
    final unfinished = _with([
      const TextFieldDefinition(id: 'title', name: 'Title'),
      const SingleSelectFieldDefinition(id: 's', name: 'Stage', options: []),
      const MultiSelectFieldDefinition(id: 'm', name: 'Tags', options: []),
      const ReferenceFieldDefinition(
        id: 'r',
        name: 'Owner',
        targetCollectionId: '',
      ),
    ]);

    test('only warn in the editor', () {
      final v = validateCollectionSchema(unfinished);
      expect(_codes(v), [
        SchemaIssueCode.noOptions,
        SchemaIssueCode.noOptions,
        SchemaIssueCode.noTarget,
      ]);
      expect(v.hasBlocking, isFalse);
      expect(v.warnings, hasLength(3));
    });

    test('block in strict mode', () {
      final v = validateCollectionSchema(unfinished, strict: true);
      expect(v.blocking, hasLength(3));
    });

    test('an unknown target is flagged only when collection ids are known', () {
      final ghost = _with([
        const ReferenceFieldDefinition(
          id: 'r',
          name: 'Owner',
          targetCollectionId: 'c_gone',
        ),
        const ReferenceFieldDefinition(
          id: 'self',
          name: 'Parent',
          targetCollectionId: 'orders',
        ),
      ]);
      expect(validateCollectionSchema(ghost, strict: true).issues, isEmpty);
      final v = validateCollectionSchema(
        ghost,
        collectionIds: {'clients'},
        strict: true,
      );
      expect(_codes(v), [SchemaIssueCode.noTarget]);
      expect(v.blocking.single.fieldId, 'r');
    });
  });
}
