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

    test('icon: omitting preserves, null clears, value replaces', () {
      const withIcon = Collection(id: 'c1', name: 'Orders', icon: 'truck');
      expect(withIcon.copyWith(name: 'X').icon, 'truck'); // preserved
      expect(withIcon.copyWith(icon: null).icon, isNull); // cleared
      expect(withIcon.copyWith(icon: 'cart').icon, 'cart'); // replaced
    });
  });

  group('Collection icon serialization', () {
    final registry = defaultFieldTypeRegistry();

    test('toJson omits icon when null and round-trips when set', () {
      const noIcon = Collection(id: 'c1', name: 'Orders');
      expect(noIcon.toJson().containsKey('icon'), isFalse);

      const withIcon = Collection(id: 'c1', name: 'Orders', icon: 'truck');
      final json = withIcon.toJson();
      expect(json['icon'], 'truck');
      expect(Collection.fromJson(json, registry).icon, 'truck');
    });

    test('fromJson tolerates a missing icon key (legacy doc)', () {
      final legacy = {'id': 'c1', 'name': 'Orders', 'fields': const []};
      expect(Collection.fromJson(legacy, registry).icon, isNull);
    });
  });

  group('Collection layout', () {
    final registry = defaultFieldTypeRegistry();
    const fields = [
      TextFieldDefinition(id: 'f1', name: 'Title'),
      TextFieldDefinition(id: 'f2', name: 'Notes'),
    ];

    test('fromJson synthesizes a default layout for a legacy doc', () {
      final legacy = {
        'id': 'c1',
        'name': 'Orders',
        'fields': fields.map((f) => f.toJson()).toList(),
      };
      final layout = Collection.fromJson(legacy, registry).layout;
      expect(layout.fieldIds.toList(), ['f1', 'f2']);
      expect(layout.sections.length, 1);
    });

    test('toJson/fromJson round-trips an explicit layout', () {
      final collection = Collection(
        id: 'c1',
        name: 'Orders',
        fields: fields,
        layout: CardLayout(sections: [
          LayoutSection(id: 's1', title: 'Main', rows: [
            LayoutRow(id: 'r1', cells: [
              LayoutCell(fieldId: 'f1', span: 3),
              LayoutCell(fieldId: 'f2', span: 9),
            ]),
          ]),
        ]),
      );
      final restored = Collection.fromJson(collection.toJson(), registry);
      expect(restored.layout, collection.layout);
    });

    test('fromJson reconciles a stored layout against current fields', () {
      // Layout references f1 only; fields also include f2 → f2 appended.
      final json = {
        'id': 'c1',
        'name': 'Orders',
        'fields': fields.map((f) => f.toJson()).toList(),
        'layout': {
          'sections': [
            {
              'id': 's1',
              'collapsed': false,
              'rows': [
                {'id': 'r1', 'cells': [{'fieldId': 'f1', 'span': 12}]},
              ],
            },
          ],
        },
      };
      final layout = Collection.fromJson(json, registry).layout;
      expect(layout.fieldIds.toList(), ['f1', 'f2']);
    });
  });
}
