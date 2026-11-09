import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/api/assistant/firestore_thread_repository.dart';
import 'package:morkva_crm/api/assistant/thread_repository.dart';

void main() {
  const workspaceId = 'ws-1';
  const uid = 'u-1';

  late FakeFirebaseFirestore firestore;
  late FirestoreThreadRepository repository;

  CollectionReference<Map<String, dynamic>> threadsOf(String member) =>
      firestore
          .collection('workspaces')
          .doc(workspaceId)
          .collection('members')
          .doc(member)
          .collection('assistantThreads');

  CollectionReference<Map<String, dynamic>> messagesOf(String threadId) =>
      threadsOf(uid).doc(threadId).collection('messages');

  String iso(int minute) =>
      DateTime.utc(2026, 11, 10, 9, minute).toIso8601String();

  Map<String, Object?> threadMeta(int minute, {String title = 'Orders'}) => {
    'title': title,
    'createdAt': iso(0),
    'updatedAt': iso(minute),
    'model': 'gemini-3.5-flash-lite',
    'lastSnippet': 'Done.',
    'tokens': {'prompt': 300, 'output': 67},
    'schema': 1,
  };

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = FirestoreThreadRepository(firestore: firestore)
      ..initialize(workspaceId: workspaceId, uid: uid);
  });

  test('messageDocId pads the seq so ids sort like seqs', () {
    expect(messageDocId(1), 'm_000001');
    expect(messageDocId(42), 'm_000042');
    expect(messageDocId(9).compareTo(messageDocId(10)), lessThan(0));
  });

  test('newThreadId mints distinct ids', () {
    expect(repository.newThreadId(), isNot(repository.newThreadId()));
  });

  group('checkpoint', () {
    test('writes the turn doc and the thread meta under the member', () async {
      await repository.checkpoint(
        't1',
        seq: 1,
        message: {'status': 'done', 'llm': '[]', 'ui': <Object?>[]},
        thread: threadMeta(1),
      );

      final message = await messagesOf('t1').doc('m_000001').get();
      expect(message.data(), {
        'status': 'done',
        'llm': '[]',
        'ui': <Object?>[],
        'seq': 1,
      });
      expect((await threadsOf(uid).doc('t1').get()).data(), threadMeta(1));
    });

    test('the three checkpoints of a turn overwrite one doc', () async {
      await repository.checkpoint(
        't1',
        seq: 3,
        message: {
          'status': 'pending',
          'ui': ['plan'],
        },
        thread: threadMeta(1),
      );
      await repository.checkpoint(
        't1',
        seq: 3,
        message: {
          'status': 'committed',
          'ui': ['plan', 'applied'],
          'journal': {'schema': 1},
        },
      );
      await repository.checkpoint(
        't1',
        seq: 3,
        message: {
          'status': 'done',
          'ui': ['plan', 'applied', 'text'],
        },
        thread: {'updatedAt': iso(2), 'lastSnippet': 'Updated 12 orders'},
      );

      final docs = (await messagesOf('t1').get()).docs;
      expect(docs.map((d) => d.id), ['m_000003']);
      // A whole-doc set: the final checkpoint carries no stale journal.
      expect(docs.single.data(), {
        'status': 'done',
        'ui': ['plan', 'applied', 'text'],
        'seq': 3,
      });
      // The thread meta merges: createdAt and title survive.
      expect((await threadsOf(uid).doc('t1').get()).data(), {
        ...threadMeta(1),
        'updatedAt': iso(2),
        'lastSnippet': 'Updated 12 orders',
      });
    });

    test('the seq argument wins over a seq in the record', () async {
      await repository.checkpoint('t1', seq: 2, message: {'seq': 99});

      expect((await messagesOf('t1').doc('m_000002').get()).data(), {'seq': 2});
    });
  });

  group('loadMessages', () {
    test('returns every turn ordered by seq', () async {
      for (final seq in [3, 1, 12, 2]) {
        await repository.checkpoint('t1', seq: seq, message: {'n': seq});
      }
      await repository.checkpoint('t2', seq: 1, message: {'n': 100});

      final messages = await repository.loadMessages('t1');

      expect(messages.map((m) => m['seq']), [1, 2, 3, 12]);
    });

    test('an unknown thread has no messages', () async {
      expect(await repository.loadMessages('nope'), isEmpty);
    });

    test('llm survives as one string: nested-list args, empty keys and '
        'thought signatures', () async {
      final contents = [
        {
          'role': 'model',
          'parts': [
            {
              'functionCall': {
                'name': 'cards_update',
                'args': {
                  'filters': [
                    ['status', 'is', 'o_pack'],
                    [
                      'due',
                      'between',
                      ['2026-11-01', '2026-11-30'],
                    ],
                  ],
                  'values': {'': 'blank-named field', 'Status': 'Shipped'},
                },
                'id': 'call_1300',
              },
              'thoughtSignature': 'c2lnbmF0dXJl',
            },
          ],
        },
        {
          'role': 'user',
          'parts': [
            {
              'functionResponse': {
                'name': 'cards_update',
                'response': {'summary': 'Planned 12 updates', 'spec': {}},
                'id': 'call_1300',
              },
            },
          ],
        },
      ];

      await repository.checkpoint(
        't1',
        seq: 1,
        message: {'status': 'done', 'llm': jsonEncode(contents)},
      );
      final restored = await repository.loadMessages('t1');

      expect(jsonDecode(restored.single['llm']! as String), contents);
    });
  });

  group('watchThreads', () {
    test('lists the newest 50 by updatedAt, each with its id', () async {
      for (var i = 0; i < 60; i++) {
        await threadsOf(uid).doc('t$i').set(threadMeta(i));
      }

      final threads = await repository.watchThreads().first;

      expect(threads, hasLength(kThreadListLimit));
      expect(threads.first['id'], 't59');
      expect(threads.first['title'], 'Orders');
      expect(threads.last['id'], 't10');
    });

    test('only shows this member\'s threads', () async {
      await threadsOf(uid).doc('mine').set(threadMeta(1));
      await threadsOf('u-other').doc('theirs').set(threadMeta(2));

      final threads = await repository.watchThreads().first;

      expect(threads.map((t) => t['id']), ['mine']);
    });

    test('re-emits when a checkpoint touches a thread', () async {
      await threadsOf(uid).doc('a').set(threadMeta(1, title: 'A'));
      await threadsOf(uid).doc('b').set(threadMeta(2, title: 'B'));
      final emissions = <List<Object?>>[];
      final sub = repository.watchThreads().listen(
        (threads) => emissions.add([for (final t in threads) t['id']]),
      );
      await pumpEventQueue();

      await repository.checkpoint(
        'a',
        seq: 2,
        message: {'status': 'done'},
        thread: {'updatedAt': iso(5)},
      );
      await pumpEventQueue();
      await sub.cancel();

      expect(emissions.first, ['b', 'a']);
      expect(emissions.last, ['a', 'b']);
    });
  });

  test('dropJournal removes only the journal mirror', () async {
    await repository.checkpoint(
      't1',
      seq: 4,
      message: {
        'status': 'done',
        'journal': {'schema': 1, 'journalId': 'j_1'},
      },
    );

    await repository.dropJournal('t1', 4);

    expect((await messagesOf('t1').doc('m_000004').get()).data(), {
      'status': 'done',
      'seq': 4,
    });
  });

  group('deleteThread', () {
    test('deletes the thread and every turn, across batch chunks', () async {
      await threadsOf(uid).doc('t1').set(threadMeta(1));
      for (final range in [(1, 400), (401, 520)]) {
        final batch = firestore.batch();
        for (var seq = range.$1; seq <= range.$2; seq++) {
          batch.set(messagesOf('t1').doc(messageDocId(seq)), {'seq': seq});
        }
        await batch.commit();
      }
      await threadsOf(uid).doc('keep').set(threadMeta(2));
      await messagesOf('keep').doc(messageDocId(1)).set({'seq': 1});

      await repository.deleteThread('t1');

      expect((await threadsOf(uid).doc('t1').get()).exists, isFalse);
      expect((await messagesOf('t1').get()).docs, isEmpty);
      expect((await threadsOf(uid).doc('keep').get()).exists, isTrue);
      expect((await messagesOf('keep').get()).docs, hasLength(1));
    });

    test('a thread without messages is deleted too', () async {
      await threadsOf(uid).doc('t1').set(threadMeta(1));

      await repository.deleteThread('t1');

      expect((await threadsOf(uid).doc('t1').get()).exists, isFalse);
    });
  });

  test('using it before initialize is a StateError', () {
    final unbound = FirestoreThreadRepository(firestore: firestore);

    expect(unbound.newThreadId, throwsStateError);
    expect(() => unbound.watchThreads(), throwsStateError);
  });
}
