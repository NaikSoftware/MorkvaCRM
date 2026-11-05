import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';

const _people = Collection(
  id: 'people',
  name: 'People',
  fields: [
    NumberFieldDefinition(id: 'age', name: 'Age'),
    TextFieldDefinition(id: 'name', name: 'Name'),
    TextFieldDefinition(id: 'note', name: 'Note'),
  ],
  views: [
    ViewDefinition(
      id: 'by-age',
      name: 'By age',
      sort: ViewSort(fieldId: 'age'),
      filters: [
        ViewFilter(fieldId: 'age', op: FilterOp.greaterThan, operand: 100),
      ],
    ),
  ],
);

MorkvaObject _person(String id, {String? name, num? age, int day = 1}) =>
    MorkvaObject.create(
      id: id,
      collection: _people,
      values: {
        'name': TextFieldValue(name),
        'age': NumberFieldValue(age),
        'note': const TextFieldValue('ignored'),
      },
      createdAt: DateTime.utc(2026, 1, day),
      updatedAt: DateTime.utc(2026, 1, day),
    );

void main() {
  test('labels by the first text field, in the first view order, '
      'ignoring its filters', () {
    final labels = objectLabels(_people, [
      _person('a', name: 'Ann', age: 40),
      _person('b', name: '  Bob  ', age: 20),
      _person('c', name: 'Cid', age: 30),
    ]);

    expect(labels.keys, ['b', 'c', 'a']);
    expect(labels, {'a': 'Ann', 'b': 'Bob', 'c': 'Cid'});
  });

  test('blank or missing title reads Untitled', () {
    final labels = objectLabels(_people, [
      _person('a', name: '   '),
      _person('b'),
    ]);
    expect(labels, {'a': 'Untitled', 'b': 'Untitled'});
  });

  test('a collection without views or text fields still labels objects', () {
    const bare = Collection(
      id: 'bare',
      name: 'Bare',
      fields: [NumberFieldDefinition(id: 'n', name: 'N')],
    );
    final object = MorkvaObject.create(
      id: 'x',
      collection: bare,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
    expect(objectLabels(bare, [object]), {'x': 'Untitled'});
  });

  test('no objects → no labels', () {
    expect(objectLabels(_people, const []), isEmpty);
  });
}
