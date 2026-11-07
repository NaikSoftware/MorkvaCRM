import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/features/objects/object_editor_cubit.dart';
import 'package:morkva_crm/features/views/collection_views_cubit.dart';
import 'package:morkva_crm/features/views/collection_views_state.dart';

import '../collections/fake_data_repository.dart';

const _items = Collection(
  id: 'items',
  name: 'Items',
  fields: [
    TextFieldDefinition(id: 'name', name: 'Name'),
    NumberFieldDefinition(id: 'stock', name: 'Stock'),
    CalculatedFieldDefinition(
      id: 'reserved',
      name: 'Reserved',
      declaredOutputType: 'number',
      aggregate: Aggregation(
        source: AggregateSource.linkedFrom,
        collectionId: 'orders',
        referenceFieldId: 'item',
        op: AggregateOp.sum,
        fieldId: 'qty',
      ),
    ),
    CalculatedFieldDefinition(
      id: 'left',
      name: 'Left',
      declaredOutputType: 'number',
      expression: '{stock} - {reserved}',
    ),
  ],
);

const _orders = Collection(
  id: 'orders',
  name: 'Orders',
  fields: [
    AutoNumberFieldDefinition(id: 'no', name: 'No', prefix: '#'),
    TextFieldDefinition(id: 'title', name: 'Title'),
    ReferenceFieldDefinition(
      id: 'item',
      name: 'Item',
      targetCollectionId: 'items',
    ),
    NumberFieldDefinition(id: 'qty', name: 'Qty'),
  ],
);

final _t = DateTime.utc(2026, 4, 1);

MorkvaObject _item(String id, num stock) => MorkvaObject.create(
  id: id,
  collection: _items,
  values: {'stock': NumberFieldValue(stock)},
  createdAt: _t,
  updatedAt: _t,
);

MorkvaObject _order(String id, String item, num qty) => MorkvaObject.create(
  id: id,
  collection: _orders,
  values: {
    'item': ReferenceFieldValue([item]),
    'qty': NumberFieldValue(qty),
  },
  createdAt: _t,
  updatedAt: _t,
);

Object? _cached(MorkvaObject o, String field) =>
    (o[field] as CalculatedFieldValue).cached;

void main() {
  late FakeDataRepository repo;

  setUp(() {
    repo = FakeDataRepository([_items, _orders]);
    repo.seedObjects('items', [_item('a', 10), _item('b', 4)]);
    repo.seedObjects('orders', [
      _order('o1', 'a', 3),
      _order('o2', 'a', 2),
      _order('o3', 'b', 1),
    ]);
  });

  Future<CollectionViewsCubit> open(String id) async {
    final cubit = CollectionViewsCubit(repo, id)..initialize();
    addTearDown(cubit.close);
    await pumpEventQueue();
    return cubit;
  }

  MorkvaObject shown(CollectionViewsCubit c, String id) =>
      (c.state as ViewsReady).objectById(id)!;

  test('derives aggregates from the source collection it watches', () async {
    final cubit = await open('items');
    expect(_cached(shown(cubit, 'a'), 'reserved'), 5);
    expect(_cached(shown(cubit, 'a'), 'left'), 5);
    expect(_cached(shown(cubit, 'b'), 'left'), 3);
  });

  test('recomputes when a linked order changes elsewhere', () async {
    final cubit = await open('items');
    await repo.saveObject(_order('o4', 'b', 3), schema: _orders);
    await pumpEventQueue();
    expect(_cached(shown(cubit, 'b'), 'reserved'), 4);
    expect(_cached(shown(cubit, 'b'), 'left'), 0);
  });

  test('sorts and filters by a calculated field', () async {
    final cubit = await open('items');
    await cubit.setSort(const ViewSort(fieldId: 'left'));
    await pumpEventQueue();
    expect((cubit.state as ViewsReady).objects.map((o) => o.id), ['b', 'a']);
    await cubit.setFilters(const [
      ViewFilter(fieldId: 'left', op: FilterOp.greaterThan, operand: 4),
    ]);
    await pumpEventQueue();
    expect((cubit.state as ViewsReady).objects.map((o) => o.id), ['a']);
  });

  test('deriveFor previews a draft; notes say what fields compute', () async {
    final cubit = await open('items');
    final draft = _item('a', 30);
    expect((cubit.deriveFor(draft)['left'] as CalculatedFieldValue).cached, 25);
    expect(cubit.calculationNotes(), {
      'reserved': 'Sum of Qty of Orders linking here via Item',
      'left': '= {Stock} - {Reserved}',
    });
  });

  test(
    'the editor shows calculated values live as the draft changes',
    () async {
      final cubit = await open('items');
      final editor = ObjectEditorCubit(
        repo,
        _items,
        object: shown(cubit, 'a'),
        derive: cubit.deriveFor,
      );
      addTearDown(editor.close);
      await editor.initialize();
      final left = _items.fieldById('left')!;
      expect((editor.state.valueOf(left) as CalculatedFieldValue).cached, 5);
      editor.change('stock', const NumberFieldValue(12));
      expect((editor.state.valueOf(left) as CalculatedFieldValue).cached, 7);
    },
  );

  test('quick add numbers new orders in sequence', () async {
    final cubit = await open('orders');
    cubit.quickAdd('First');
    await pumpEventQueue();
    cubit.quickAdd('Second');
    await pumpEventQueue();
    final numbers = [
      for (final o in repo.objectsOf('orders'))
        (o['no'] as AutoNumberFieldValue).sequence,
    ];
    expect(numbers, [null, null, null, 1, 2]);
    final second = repo.objectsOf('orders').last;
    expect(formatFieldValue(_orders.fieldById('no')!, second['no']!), '#2');
  });
}
