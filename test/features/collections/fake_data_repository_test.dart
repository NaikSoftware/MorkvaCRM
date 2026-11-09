import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/api/data/data_repository.dart';
import 'package:morkva_crm/core/domain/domain.dart';

import 'fake_data_repository.dart';

// The batch contract of the shared fake, which the harness commit tests rely
// on to behave like FirestoreDataRepository.
void main() {
  const orders = Collection(
    id: 'orders',
    name: 'Orders',
    fields: [
      AutoNumberFieldDefinition(id: 'no', name: 'No', start: 10),
      TextFieldDefinition(id: 'client', name: 'Client'),
      NumberFieldDefinition(id: 'qty', name: 'Qty'),
      CalculatedFieldDefinition(
        id: 'twice',
        name: 'Twice',
        declaredOutputType: 'number',
        expression: '{qty} * 2',
      ),
    ],
  );
  const schemas = {'orders': orders};

  MorkvaObject order(String id, {int? no}) => MorkvaObject.create(
    id: id,
    collection: orders,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
    values: {
      'client': const TextFieldValue('Ada'),
      'qty': const NumberFieldValue(2),
      if (no != null) 'no': AutoNumberFieldValue(no),
    },
  );

  late FakeDataRepository repo;

  setUp(() {
    repo = FakeDataRepository(const [orders]);
    repo.seedObjects('orders', [order('a', no: 1), order('b', no: 2)]);
  });

  MorkvaObject stored(String id) =>
      repo.objectsOf('orders').singleWhere((o) => o.id == id);

  test('an update merges only the touched keys from domain JSON', () async {
    final result = await repo.saveObjectsBatch([
      const ObjectUpdate(
        collectionId: 'orders',
        id: 'a',
        values: {'qty': 5, 'twice': 99},
      ),
    ], schemas: schemas);

    expect(result.written, ['a']);
    expect(repo.batchCalls, 1);
    expect(stored('a')['qty'], const NumberFieldValue(5));
    expect(stored('a')['client'], const TextFieldValue('Ada'));
    expect(stored('a')['twice'], isNot(const CalculatedFieldValue(99)));
  });

  test('a missing update target fails its whole chunk, writing none of '
      'it', () async {
    final result = await repo.saveObjectsBatch([
      const ObjectUpdate(collectionId: 'orders', id: 'a', values: {'qty': 7}),
      const ObjectUpdate(collectionId: 'orders', id: 'gone', values: {}),
    ], schemas: schemas);

    expect(result.written, isEmpty);
    expect(result.failed, {'a': 'not-found', 'gone': 'not-found'});
    expect(stored('a')['qty'], const NumberFieldValue(2));
  });

  test('creates are numbered past the counter; a carried number is '
      'kept', () async {
    await repo.saveObjectsBatch([
      ObjectCreate(order('c')),
      ObjectCreate(order('d', no: 4)),
      const ObjectDelete(collectionId: 'orders', id: 'b'),
    ], schemas: schemas);

    expect(stored('c')['no'], const AutoNumberFieldValue(10));
    expect(stored('d')['no'], const AutoNumberFieldValue(4));
    expect(repo.objectsOf('orders').map((o) => o.id), ['a', 'c', 'd']);
  });

  test('batchWriteError fails the chunks it names', () async {
    var calls = 0;
    repo.batchWriteError = (chunk) => calls++ == 0 ? 'unavailable' : null;

    final failed = await repo.saveObjectsBatch([
      const ObjectDelete(collectionId: 'orders', id: 'a'),
    ], schemas: schemas);
    final retried = await repo.saveObjectsBatch([
      const ObjectDelete(collectionId: 'orders', id: 'a'),
    ], schemas: schemas);

    expect(failed.failed, {'a': 'unavailable'});
    expect(retried.written, ['a']);
  });

  test('batchNeverCompletes applies the writes but never acks', () async {
    repo.batchNeverCompletes = true;
    var completed = false;

    repo
        .saveObjectsBatch([
          const ObjectDelete(collectionId: 'orders', id: 'a'),
        ], schemas: schemas)
        .then((_) => completed = true)
        .ignore();
    await pumpEventQueue();

    expect(repo.objectsOf('orders').map((o) => o.id), ['b']);
    expect(completed, isFalse);
  });

  test('updateCollection and updateViews apply to the stored copy', () async {
    const extra = TextFieldDefinition(id: 'extra', name: 'Extra');
    await repo.updateCollection(
      'orders',
      (server) => server.copyWith(fields: [...server.fields, extra]),
    );
    await repo.updateViews(
      'orders',
      (server) => [...server, const ViewDefinition(id: 'v2', name: 'Two')],
    );

    final saved = (await repo.getCollection('orders'))!;
    expect(saved.fieldById('extra'), extra);
    expect(saved.views.last.id, 'v2');
    expect(repo.saveCount, 1);
    expect(repo.saveViewsCount, 1);
    await expectLater(
      repo.updateCollection('nope', (c) => c),
      throwsStateError,
    );
  });
}
