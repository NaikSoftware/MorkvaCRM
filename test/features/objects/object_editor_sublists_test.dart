import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/features/collections/util/id_generator.dart';
import 'package:morkva_crm/features/objects/object_editor_cubit.dart';

import '../collections/fake_data_repository.dart';

const _orders = Collection(
  id: 'orders',
  name: 'Orders',
  fields: [TextFieldDefinition(id: 'customer', name: 'Customer')],
);

const _items = Collection(
  id: 'items',
  name: 'Order items',
  fields: [
    TextFieldDefinition(id: 'what', name: 'What'),
    CalculatedFieldDefinition(
      id: 'customer',
      name: 'Customer',
      declaredOutputType: kTextFieldType,
      lookup: Lookup(referenceFieldId: 'order', fieldId: 'customer'),
    ),
    ReferenceFieldDefinition(
      id: 'order',
      name: 'Order',
      targetCollectionId: 'orders',
    ),
    BooleanFieldDefinition(id: 'done', name: 'Done'),
  ],
);

final _t = DateTime.utc(2026, 11, 7);

MorkvaObject _o(String id, Collection c, Map<String, FieldValue> values) =>
    MorkvaObject.create(
      id: id,
      collection: c,
      values: values,
      createdAt: _t,
      updatedAt: _t,
    );

MorkvaObject _item(String id, String what, String order) => _o(id, _items, {
  'what': TextFieldValue(what),
  'order': ReferenceFieldValue([order]),
});

class _FixedIds extends IdGenerator {
  @override
  String objectId() => 'new1';
}

void main() {
  late FakeDataRepository repo;
  final order = _o('o1', _orders, {'customer': const TextFieldValue('Olena')});

  setUp(() {
    repo = FakeDataRepository([_orders, _items])
      ..seedObjects('orders', [order])
      ..seedObjects('items', [
        _item('i1', 'Hoodie', 'o1'),
        _item('i2', 'T-shirt', 'o1'),
        _item('i3', 'Elsewhere', 'o2'),
      ]);
  });

  Future<ObjectEditorCubit> open({MorkvaObject? object}) async {
    final cubit = ObjectEditorCubit(
      repo,
      _orders,
      object: object,
      idGenerator: _FixedIds(),
      clock: () => _t,
    );
    await cubit.initialize();
    await pumpEventQueue();
    return cubit;
  }

  test('lists the items linking to the object, per reference', () async {
    final cubit = await open(object: order);
    final sublist = cubit.state.sublists.single;
    expect(sublist.collection.id, 'items');
    expect(sublist.via.id, 'order');
    expect([for (final i in sublist.items!) i.id], ['i1', 'i2']);
    await cubit.close();
  });

  test('ticking an item writes only that field and the list follows', () async {
    final cubit = await open(object: order);
    final sublist = cubit.state.sublists.single;
    final hoodie = sublist.items!.first;
    expect(
      await cubit.setChildValue(
        sublist,
        hoodie,
        'done',
        const BooleanFieldValue(true),
      ),
      isTrue,
    );
    await pumpEventQueue();
    final stored = repo.objectsOf('items').firstWhere((o) => o.id == 'i1');
    expect(stored['done'], const BooleanFieldValue(true));
    expect(stored['what'], const TextFieldValue('Hoodie'));
    expect(
      cubit.state.sublists.single.items!.first['done'],
      const BooleanFieldValue(true),
    );
    await cubit.close();
  });

  test(
    'new items link to the new object and are dropped if discarded',
    () async {
      final cubit = await open();
      final sublist = cubit.state.sublists.single;
      expect(sublist.items, isEmpty);
      expect(cubit.prefillFor(sublist), {
        'order': const ReferenceFieldValue(['new1']),
      });
      // The child form saved an item linked to the unsaved order.
      await repo.saveObject(_item('i9', 'Cap', 'new1'), schema: _items);
      cubit.childAdded(sublist, 'i9');
      await pumpEventQueue();
      expect(
        [for (final i in cubit.state.sublists.single.items!) i.id],
        ['i9'],
      );
      expect(cubit.state.hasUnsavedChanges, isTrue);

      await cubit.close();
      await pumpEventQueue();
      expect(repo.objectsOf('items').any((o) => o.id == 'i9'), isFalse);
    },
  );

  test('items added to a new object stay once it is saved', () async {
    final cubit = await open();
    final sublist = cubit.state.sublists.single;
    await repo.saveObject(_item('i9', 'Cap', 'new1'), schema: _items);
    cubit.childAdded(sublist, 'i9');
    cubit.change('customer', const TextFieldValue('Taras'));
    expect(await cubit.save(), isTrue);
    await cubit.close();
    await pumpEventQueue();
    expect(repo.objectsOf('items').any((o) => o.id == 'i9'), isTrue);
    expect(repo.objectsOf('orders').any((o) => o.id == 'new1'), isTrue);
  });

  test('deleting an item removes it from the list', () async {
    final cubit = await open(object: order);
    final sublist = cubit.state.sublists.single;
    expect(await cubit.deleteChild(sublist, sublist.items!.first), isTrue);
    await pumpEventQueue();
    expect([for (final i in cubit.state.sublists.single.items!) i.id], ['i2']);
    await cubit.close();
  });

  test('a collection nothing links to has no sublists', () async {
    final cubit = ObjectEditorCubit(
      repo,
      _items,
      object: _item('i1', 'x', 'o1'),
    );
    await cubit.initialize();
    await pumpEventQueue();
    expect(cubit.state.sublists, isEmpty);
    await cubit.close();
  });

  test('items show and preview lookups of the object as edited', () async {
    final cubit = await open(object: order);
    final sublist = cubit.state.sublists.single;
    expect(
      sublist.items!.first['customer'],
      const CalculatedFieldValue('Olena'),
    );
    cubit.change('customer', const TextFieldValue('Olena K.'));
    final draft = _item('i7', 'Scarf', 'o1');
    expect(cubit.deriveChild(sublist, draft), {
      'customer': const CalculatedFieldValue('Olena K.'),
    });
    expect(
      cubit.state.sublists.single.items!.first['customer'],
      const CalculatedFieldValue('Olena K.'),
    );
    await cubit.close();
  });
}
