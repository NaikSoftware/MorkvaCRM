import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';

void main() {
  const a = TextFieldDefinition(id: 'a', name: 'A');
  const b = TextFieldDefinition(id: 'b', name: 'B');
  const c = TextFieldDefinition(id: 'c', name: 'C');
  const v1 = ViewDefinition(id: 'v1', name: 'All', fieldIds: ['a']);
  const v2 = ViewDefinition(id: 'v2', name: 'Two', fieldIds: ['a', 'b']);
  const previous = Collection(id: 'x', name: 'X', fields: [a], views: [v1, v2]);

  test('new field is appended to every view, existing order kept', () {
    final next = previous
        .copyWith(fields: [a, b, c])
        .withNewFieldsInViews(previous);
    expect(next.views[0].fieldIds, ['a', 'b', 'c']);
    expect(next.views[1].fieldIds, ['a', 'b', 'c']);
  });

  test('no duplicates and no change without new fields', () {
    expect(previous.withNewFieldsInViews(previous), previous);
    final next = previous
        .copyWith(fields: [a, b])
        .withNewFieldsInViews(previous);
    expect(next.views[1].fieldIds, ['a', 'b']);
  });

  test('removed fields are not re-added', () {
    final prev = previous.copyWith(fields: [a, b]);
    final next = prev.copyWith(fields: [a]).withNewFieldsInViews(prev);
    expect(next.views[0].fieldIds, ['a']);
  });
}
