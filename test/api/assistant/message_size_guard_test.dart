import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/api/assistant/message_size_guard.dart';
import 'package:morkva_crm/api/assistant/thread_repository.dart';

const _oneMiB = 1024 * 1024;

/// One turn of [rounds] model rounds with [parallel] calls each. Every
/// persisted response carries [responseBytes] of spec; the turn's plan
/// deletes [deletes] cards whose before-images (≈[beforeBytes] each) sit in
/// the journal mirror.
AssistantRecord _turn({
  int rounds = 8,
  int parallel = 4,
  int deletes = 200,
  int responseBytes = 200,
  int beforeBytes = 400,
}) {
  final contents = <Object?>[
    {
      'role': 'user',
      'parts': [
        {'text': 'Delete every cancelled order from last year'},
      ],
    },
  ];
  for (var r = 1; r <= rounds; r++) {
    contents
      ..add({
        'role': 'model',
        'parts': [
          for (var c = 0; c < parallel; c++)
            {
              'functionCall': {
                'name': 'cards_query',
                'args': {
                  'collection': 'Orders',
                  'where': [
                    {'field': 'Status', 'op': 'is', 'value': 'Cancelled'},
                  ],
                },
                'id': 'call_r${r}_$c',
              },
              if (c == 0) 'thoughtSignature': 'c2ln' * 40,
            },
        ],
      })
      ..add({
        'role': 'user',
        'parts': [
          for (var c = 0; c < parallel; c++)
            {
              'functionResponse': {
                'name': 'cards_query',
                'response': {
                  'summary': 'round $r call $c: 200 cards',
                  'spec': {'blob': 'x' * responseBytes},
                },
                'id': 'call_r${r}_$c',
              },
            },
        ],
      });
  }
  final ids = [for (var i = 0; i < deletes; i++) 'b_card_$i'];
  return {
    'seq': 3,
    'createdAt': '2026-11-10T09:30:00.000Z',
    'status': 'committed',
    'llm': jsonEncode(contents),
    'ui': [
      {'schema': 1, 'type': 'user', 'text': 'Delete every cancelled order'},
      {
        'schema': 1,
        'type': 'plan',
        'planId': 'p_1',
        'status': 'applied',
        'plan': {
          'summary': 'Delete $deletes orders',
          'items': [
            for (final id in ids) {'id': id, 'kind': 'card.delete'},
          ],
        },
      },
      {
        'schema': 1,
        'type': 'applied',
        'receipt': {'planId': 'p_1', 'applied': ids, 'summary': 'Deleted'},
      },
    ],
    'journal': {
      'schema': 1,
      'journalId': 'j_1',
      'planId': 'p_1',
      'items': [
        for (final id in ids)
          {
            'kind': 'card.delete',
            'collectionId': 'c_orders',
            'id': id,
            'before': {
              'createdAt': '2026-01-01T00:00:00.000Z',
              'values': {'f_note': 'n' * beforeBytes, 'f_total': 120.5},
            },
          },
      ],
    },
    'usage': {'prompt': 41000, 'output': 900},
  };
}

/// The function responses of [record]'s `llm`, in order.
List<Map<String, Object?>> _responses(AssistantRecord record) => [
  for (final content in jsonDecode(record['llm']! as String) as List)
    for (final part in (content as Map)['parts'] as List)
      if ((part as Map)['functionResponse'] case final Map call)
        (call['response'] as Map).cast<String, Object?>(),
];

void main() {
  group('firestoreDocSize', () {
    test('counts per the Firestore size rules', () {
      // 32 doc + 'a'(2)+'xy'(3) + 'n'(2)+8 + 'b'(2)+1 + 'z'(2)+1
      // + 'l'(2)+[1-byte bool, 'q'(2)] + 'm'(2)+{'k'(2)+'é'(3)}
      expect(
        firestoreDocSize({
          'a': 'xy',
          'n': 12,
          'b': true,
          'z': null,
          'l': [false, 'q'],
          'm': {'k': 'é'},
        }),
        32 + 5 + 10 + 3 + 3 + 5 + 7,
      );
    });
  });

  group('fitMessageToBudget', () {
    test('a doc within budget is returned untouched', () {
      final record = _turn(rounds: 2, deletes: 3);

      final fitted = fitMessageToBudget(record);

      expect(identical(fitted.record, record), isTrue);
      expect(fitted.fits, isTrue);
      expect(fitted.elidedRounds, 0);
      expect(fitted.journalDropped, isFalse);
      expect(fitted.bytes, firestoreDocSize(record));
    });

    test('an 8-round, 4-parallel, 200-delete turn stays under 1 MiB and '
        'within the 700 KB budget', () {
      final record = _turn();

      final fitted = fitMessageToBudget(record);

      expect(fitted.fits, isTrue);
      expect(fitted.bytes, lessThanOrEqualTo(kMessageDocBudgetBytes));
      expect(utf8.encode(jsonEncode(fitted.record)).length, lessThan(_oneMiB));
      expect(fitted.journalDropped, isFalse);
    });

    test('over budget, the oldest rounds are elided first and the journal '
        'is kept when that suffices', () {
      // 32 responses × 20 KB ≈ 640 KB of llm + ≈ 90 KB journal.
      final record = _turn(responseBytes: 20 * 1024);
      expect(firestoreDocSize(record), greaterThan(kMessageDocBudgetBytes));

      final fitted = fitMessageToBudget(record);

      expect(fitted.fits, isTrue);
      expect(fitted.bytes, lessThanOrEqualTo(kMessageDocBudgetBytes));
      expect(fitted.journalDropped, isFalse);
      expect(fitted.record['journal'], record['journal']);
      expect(fitted.elidedRounds, inInclusiveRange(1, 7));

      final responses = _responses(fitted.record);
      final elided = fitted.elidedRounds * 4;
      expect(responses.take(elided), [
        for (var i = 0; i < elided; i++)
          {
            'elided': true,
            'summary': 'round ${i ~/ 4 + 1} call ${i % 4}: 200 cards',
          },
      ]);
      // The newest round keeps its full persisted response.
      expect(responses.last['spec'], isNotNull);
      // Calls, ids and thought signatures are never touched.
      final original = jsonDecode(record['llm']! as String) as List;
      final shrunk = jsonDecode(fitted.record['llm']! as String) as List;
      for (var i = 0; i < original.length; i++) {
        if ((original[i] as Map)['role'] == 'model') {
          expect(shrunk[i], original[i]);
        }
      }
    });

    test('the input record is not mutated', () {
      final record = _turn(responseBytes: 20 * 1024);
      final llm = record['llm'];

      fitMessageToBudget(record);

      expect(record['llm'], same(llm));
      expect(record.containsKey('journal'), isTrue);
    });

    test('when eliding every round is not enough, the journal is dropped', () {
      // ≈ 800 KB of delete before-images.
      final record = _turn(beforeBytes: 4000);

      final fitted = fitMessageToBudget(record);

      expect(fitted.journalDropped, isTrue);
      expect(fitted.record.containsKey('journal'), isFalse);
      expect(fitted.elidedRounds, 8);
      expect(fitted.fits, isTrue);
      expect(fitted.record['ui'], record['ui']);
    });

    test('an unreadable llm string skips straight to the journal', () {
      final record = {..._turn(beforeBytes: 4000), 'llm': 'not json'};

      final fitted = fitMessageToBudget(record);

      expect(fitted.record['llm'], 'not json');
      expect(fitted.elidedRounds, 0);
      expect(fitted.journalDropped, isTrue);
    });

    test('reports a doc that still does not fit', () {
      final record = {..._turn(), 'ui': 'u' * (kMessageDocBudgetBytes + 1)};

      final fitted = fitMessageToBudget(record);

      expect(fitted.fits, isFalse);
      expect(fitted.journalDropped, isTrue);
      expect(fitted.bytes, greaterThan(kMessageDocBudgetBytes));
    });
  });
}
