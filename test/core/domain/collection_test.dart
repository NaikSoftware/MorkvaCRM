import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';

void main() {
  group('Collection.copyWith', () {
    const base = Collection(
      id: 'c1',
      name: 'Orders',
      description: 'All customer orders',
      fields: [TextFieldDefinition(id: 'f1', name: 'Title')],
    );

    test('omitting an argument preserves the current value', () {
      final copy = base.copyWith(name: 'Invoices');
      expect(copy.name, 'Invoices');
      expect(copy.id, 'c1');
      expect(copy.description, 'All customer orders');
      expect(copy.fields, base.fields);
    });

    test('an explicit null description clears it', () {
      final copy = base.copyWith(description: null);
      expect(copy.description, isNull);
      // Everything else is preserved.
      expect(copy.id, 'c1');
      expect(copy.name, 'Orders');
      expect(copy.fields, base.fields);
    });

    test('a non-null description replaces it', () {
      final copy = base.copyWith(description: 'Updated');
      expect(copy.description, 'Updated');
    });

    test('overriding fields replaces them, description still preserved', () {
      final copy = base.copyWith(fields: const []);
      expect(copy.fields, isEmpty);
      expect(copy.description, 'All customer orders');
    });
  });
}
