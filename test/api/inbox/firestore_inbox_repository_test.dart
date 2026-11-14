import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/api/automation/firestore_docs.dart';
import 'package:morkva_crm/api/inbox/firestore_inbox_repository.dart';
import 'package:morkva_crm/core/domain/inbox/inbox.dart';

const _wid = 'ws-1';
const _uid = 'u1';
final _clock = DateTime.utc(2026, 11, 14, 12);

InboxItem _item(String id, {String assignee = _uid}) => InboxItem(
  id: id,
  kind: InboxKind.task,
  title: 'Call $id',
  dueAt: DateTime.utc(2026, 11, 20),
  allDay: true,
  reminders: const [InboxReminders.atStart - InboxReminders.dayStart],
  link: const InboxLink(collectionId: 'c1', cardId: 'b1', label: '#1'),
  assigneeUid: assignee,
  createdBy: assignee,
  createdAt: DateTime.utc(2026, 11, 1),
  updatedAt: DateTime.utc(2026, 11, 1),
);

void main() {
  late FakeFirebaseFirestore firestore;
  late FirestoreInboxRepository repo;

  CollectionReference<Map<String, dynamic>> raw() =>
      firestore.collection('workspaces').doc(_wid).collection('inbox');

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repo = FirestoreInboxRepository(firestore: firestore, now: () => _clock)
      ..initialize(workspaceId: _wid, uid: _uid);
  });

  test('throws StateError before initialize', () {
    final unbound = FirestoreInboxRepository(firestore: firestore);
    expect(unbound.watch, throwsStateError);
    expect(unbound.newId, throwsStateError);
  });

  test('create stores the §5 shape with Timestamps', () async {
    await repo.create(_item('i1'));
    final data = (await raw().doc('i1').get()).data()!;
    expect(data['kind'], 'task');
    expect(data['dueAt'], Timestamp.fromDate(DateTime.utc(2026, 11, 20)));
    expect(data['createdAt'], isA<Timestamp>());
    expect(data['doneAt'], isNull);
    expect(data['link'], {'collectionId': 'c1', 'cardId': 'b1', 'label': '#1'});
  });

  test(
    'watch streams my items decoded, others and malformed left out',
    () async {
      await repo.create(_item('mine'));
      await repo.create(_item('theirs', assignee: 'u2'));
      await raw().doc('broken').set({'kind': 'event', 'assigneeUid': _uid});
      await raw()
          .doc('bad-reminders')
          .set(encodeDoc({..._item('x').toJson(), 'reminders': 'soon'}));

      final (:items, :fromCache) = await repo.watch().first;
      expect(fromCache, isFalse);
      expect(
        items.map((i) => i.id),
        unorderedEquals(['mine', 'bad-reminders']),
      );
      expect(items.firstWhere((i) => i.id == 'mine'), _item('mine'));
    },
  );

  test('update writes only the fields plus updatedAt', () async {
    await repo.create(_item('i1'));
    final doneAt = DateTime.utc(2026, 11, 14, 9);
    await repo.update('i1', {'done': true, 'doneAt': doneAt});

    final data = (await raw().doc('i1').get()).data()!;
    expect(data['done'], true);
    expect(data['doneAt'], Timestamp.fromDate(doneAt));
    expect(data['updatedAt'], Timestamp.fromDate(_clock));
    expect(data['title'], 'Call i1');
    final item = (await repo.watch().first).items.single;
    expect(item.doneAt, doneAt);
    expect(item.updatedAt, _clock);
  });

  test('update of a missing item fails', () {
    expect(repo.update('nope', {'done': true}), throwsA(anything));
  });

  test('delete removes the doc; newId is fresh', () async {
    await repo.create(_item('i1'));
    await repo.delete('i1');
    expect((await raw().doc('i1').get()).exists, isFalse);
    expect(repo.newId(), isNot(repo.newId()));
  });
}
