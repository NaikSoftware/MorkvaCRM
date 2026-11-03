import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';

void main() {
  final registry = defaultFieldTypeRegistry();

  const full = ViewDefinition(
    id: 'v1',
    name: 'Pipeline',
    mode: ViewModeIds.board,
    layoutFieldId: 'stage',
    fieldIds: ['name', 'amount'],
    filters: [
      ViewFilter(fieldId: 'name', op: FilterOp.contains, operand: 'acme'),
      ViewFilter(fieldId: 'stage', op: FilterOp.anyOf, operand: ['o1', 'o2']),
      ViewFilter(fieldId: 'amount', op: FilterOp.isNotEmpty),
    ],
    sort: ViewSort(fieldId: 'amount', ascending: false),
    manualOrder: ['b', 'a'],
    collapsedGroups: ['o2', ViewDefinition.noGroupToken],
  );

  group('ViewDefinition JSON', () {
    test('round-trips every property', () {
      expect(ViewDefinition.fromJson(full.toJson()), full);
    });

    test('ops serialize by name; null operand and sort are omitted', () {
      final json = full.toJson();
      expect((json['filters'] as List)[0]['op'], 'contains');
      expect((json['filters'] as List)[2].containsKey('operand'), isFalse);
      const bare = ViewDefinition(id: 'v', name: 'V');
      expect(bare.toJson().containsKey('sort'), isFalse);
      expect(bare.toJson().containsKey('layoutFieldId'), isFalse);
      expect(bare.toJson().containsKey('collapsedGroups'), isFalse);
      expect(full.toJson()['collapsedGroups'], ['o2', '@none']);
    });

    test('round-trips Firestore-style dynamic lists', () {
      final json = {
        'id': 'v',
        'name': 'V',
        'mode': 'table',
        'fieldIds': <dynamic>['a'],
        'filters': <dynamic>[
          <String, dynamic>{
            'fieldId': 'a',
            'op': 'anyOf',
            'operand': <dynamic>['x'],
          },
        ],
        'manualOrder': <dynamic>['o'],
      };
      final view = ViewDefinition.fromJson(json);
      expect(view.fieldIds, ['a']);
      expect(view.filters.single.operand, ['x']);
      expect(view.manualOrder, ['o']);
    });

    test('unknown filter op is skipped, unknown mode kept verbatim', () {
      final json = full.toJson()
        ..['mode'] = 'gallery'
        ..['filters'] = [
          {'fieldId': 'name', 'op': 'fuzzy', 'operand': 'x'},
          {'fieldId': 'name', 'op': 'isEmpty'},
        ];
      final view = ViewDefinition.fromJson(json);
      expect(view.mode, 'gallery');
      expect(view.filters, [
        const ViewFilter(fieldId: 'name', op: FilterOp.isEmpty),
      ]);
    });

    test('missing optional keys default', () {
      final view = ViewDefinition.fromJson({'id': 'v', 'name': 'V'});
      expect(view.mode, ViewModeIds.table);
      expect(view.fieldIds, isEmpty);
      expect(view.filters, isEmpty);
      expect(view.sort, isNull);
      expect(view.manualOrder, isEmpty);
      expect(view.collapsedGroups, isEmpty);
    });

    test('collapsed groups: the null group is the @none token', () {
      final view = ViewDefinition.fromJson({
        'id': 'v',
        'name': 'V',
        'collapsedGroups': <dynamic>['o2', '@none'],
      });
      expect(view.isGroupCollapsed('o2'), isTrue);
      expect(view.isGroupCollapsed(null), isTrue);
      expect(view.isGroupCollapsed('o1'), isFalse);
      expect(view.reconcile(['name']).collapsedGroups, ['o2', '@none']);
      expect(view.copyWith(name: 'W').collapsedGroups, ['o2', '@none']);
      expect(view, isNot(view.copyWith(collapsedGroups: const [])));
    });
  });

  group('ViewDefinition.copyWith', () {
    test('explicit null clears layoutFieldId and sort; omitting keeps', () {
      expect(full.copyWith(name: 'X').sort, full.sort);
      expect(full.copyWith(name: 'X').layoutFieldId, 'stage');
      expect(full.copyWith(sort: null).sort, isNull);
      expect(full.copyWith(layoutFieldId: null).layoutFieldId, isNull);
    });
  });

  group('ViewDefinition.reconcile', () {
    test('drops references to deleted fields, keeps manualOrder', () {
      final view = full.reconcile(['name', 'other']);
      expect(view.fieldIds, ['name']);
      expect(view.filters.map((f) => f.fieldId), ['name']);
      expect(view.sort, isNull);
      expect(view.layoutFieldId, isNull);
      expect(view.manualOrder, ['b', 'a']);
      expect(view.id, 'v1');
      expect(view.mode, ViewModeIds.board);
    });

    test('keeps pseudo sorts and an intact view unchanged', () {
      final pseudo = full.copyWith(
        sort: const ViewSort(fieldId: ViewSort.updatedAt),
      );
      expect(pseudo.reconcile(const []).sort, pseudo.sort);
      expect(full.reconcile(['name', 'stage', 'amount']), full);
    });

    test('dedupes fieldIds', () {
      const view = ViewDefinition(id: 'v', name: 'V', fieldIds: ['a', 'a']);
      expect(view.reconcile(['a']).fieldIds, ['a']);
    });
  });

  group('ViewDefinition.defaultFor', () {
    test('first text field leads, then 3 others in schema order', () {
      const fields = [
        NumberFieldDefinition(id: 'n', name: 'N'),
        DateFieldDefinition(id: 'd', name: 'D'),
        TextFieldDefinition(id: 't', name: 'T'),
        BooleanFieldDefinition(id: 'b', name: 'B'),
        TextFieldDefinition(id: 't2', name: 'T2'),
      ];
      final view = ViewDefinition.defaultFor(fields);
      expect(view.id, 'all');
      expect(view.name, 'All');
      expect(view.mode, ViewModeIds.table);
      expect(view.fieldIds, ['t', 'n', 'd', 'b']);
      expect(view.filters, isEmpty);
      expect(view.sort, isNull);
    });

    test('without a text field shows the first 4 fields', () {
      const fields = [
        NumberFieldDefinition(id: 'a', name: 'A'),
        NumberFieldDefinition(id: 'b', name: 'B'),
        NumberFieldDefinition(id: 'c', name: 'C'),
        NumberFieldDefinition(id: 'd', name: 'D'),
        NumberFieldDefinition(id: 'e', name: 'E'),
      ];
      expect(ViewDefinition.defaultFor(fields).fieldIds, ['a', 'b', 'c', 'd']);
    });

    test('no fields → empty fieldIds', () {
      expect(ViewDefinition.defaultFor(const []).fieldIds, isEmpty);
    });
  });

  group('Collection.views', () {
    const fields = [
      TextFieldDefinition(id: 'name', name: 'Name'),
      NumberFieldDefinition(id: 'amount', name: 'Amount'),
    ];

    test('legacy doc without views gets the default view', () {
      final legacy = {
        'id': 'c1',
        'name': 'Deals',
        'fields': fields.map((f) => f.toJson()).toList(),
      };
      final collection = Collection.fromJson(legacy, registry);
      expect(collection.views, [ViewDefinition.defaultFor(fields)]);
      expect(collection.views.single.fieldIds, ['name', 'amount']);
    });

    test('empty views list also yields the default view', () {
      final json = const Collection(
        id: 'c1',
        name: 'D',
        fields: fields,
      ).toJson();
      expect(json['views'], isEmpty);
      expect(Collection.fromJson(json, registry).views.single.id, 'all');
    });

    test('round-trips views and reconciles them against fields', () {
      final collection = Collection(
        id: 'c1',
        name: 'Deals',
        fields: fields,
        layout: CardLayout.synthesize(const ['name', 'amount']),
        views: [
          full,
          const ViewDefinition(id: 'v2', name: 'Two'),
        ],
      );
      final restored = Collection.fromJson(collection.toJson(), registry);
      expect(restored.views.map((v) => v.id), ['v1', 'v2']);
      expect(restored.views.first, full.reconcile(const ['name', 'amount']));
      expect(restored.views.first.sort, full.sort);
      expect(restored.views.first.layoutFieldId, isNull);
    });

    test('copyWith keeps or replaces views; views are in props', () {
      const base = Collection(
        id: 'c1',
        name: 'D',
        views: [ViewDefinition(id: 'v', name: 'V')],
      );
      expect(base.copyWith(name: 'E').views, base.views);
      expect(base.copyWith(views: const []).views, isEmpty);
      expect(base == base.copyWith(views: const []), isFalse);
    });
  });
}
