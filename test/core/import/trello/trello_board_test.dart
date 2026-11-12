import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/import/trello/trello_board.dart';

void main() {
  final fixture = File(
    'test/core/import/trello/fixtures/sample_board.json',
  ).readAsStringSync();

  group('TrelloBoard.parse', () {
    test('reads the board, its lists, cards, labels and members', () {
      final board = TrelloBoard.parse(fixture);
      expect(board.id, '64a1f0c2b1a2c3d4e5f60001');
      expect(board.name, 'Sales Pipeline');
      expect(board.lists, hasLength(4));
      expect(board.lists.last.pos, 65536, reason: 'a string pos is parsed');
      expect(board.cards, hasLength(6), reason: 'entries without id dropped');
      expect(board.labels.map((l) => l.color), contains('purple_dark'));
      expect(board.members.first.fullName, 'Ann Lee');

      final acme = board.cards.first;
      expect(acme.due, DateTime.utc(2026, 12, 1, 12));
      expect(acme.attachments.map((a) => a.url), contains('https://acme.com'));
      expect(board.cards[3].dateLastActivity, isNull, reason: 'bad date');
    });

    test('reads custom-field values tolerantly', () {
      final board = TrelloBoard.parse(fixture);
      final acme = board.cards[0].customValues;
      final beta = board.cards[1].customValues;
      expect(acme['cf01'], 'Call Tue');
      expect(acme['cf02'], 12500.5);
      expect(acme['cf03'], DateTime.utc(2026, 11, 20, 15));
      expect(acme['cf04'], isTrue, reason: '"true" string');
      expect(acme['cf05'], 'opt2');
      expect(acme.containsKey('cf07'), isFalse, reason: 'blank text = empty');
      expect(beta['cf02'], 7, reason: 'a later NaN does not erase 7');
      expect(beta['cf04'], isTrue, reason: 'boolean true');

      final source = board.customFields.firstWhere((f) => f.id == 'cf05');
      expect(source.options.map((o) => o.text), ['Ads', 'Referral']);
    });

    test('reads checklists and only commentCard actions as comments', () {
      final board = TrelloBoard.parse(fixture);
      expect(board.checklists, hasLength(4));
      final onboarding = board.checklists[1];
      expect(onboarding.items.map((i) => i.complete), [false, true]);
      expect(onboarding.items.first.due, DateTime.utc(2026, 11, 25, 15));

      expect(board.comments, hasLength(4));
      final bob = board.comments[1];
      expect(bob.author, 'bob', reason: 'blank fullName → username');
      expect(bob.cardId, '64a1f0c2b1a2c3d4e5f60301');
      expect(bob.date, DateTime.utc(2026, 11, 4, 8));
    });

    test('a minimal board parses with empty optional parts', () {
      final board = TrelloBoard.parse(
        '{"id":"b1","name":"Tiny","lists":[],"cards":[]}',
      );
      expect(board.labels, isEmpty);
      expect(board.checklists, isEmpty);
      expect(board.comments, isEmpty);
      expect(board.customFields, isEmpty);
    });

    test('keeps the first of entries that repeat an id', () {
      final board = TrelloBoard.parse(
        '{"id":"b1","name":"Tiny","lists":[{"id":"l1","name":"A"},'
        '{"id":"l1","name":"B"}],"cards":[{"id":"c1","name":"x"},'
        '{"id":"c1","name":"y"}]}',
      );
      expect(board.lists.map((l) => l.name), ['A']);
      expect(board.cards.map((c) => c.name), ['x']);
    });

    test('drops dates a Firestore Timestamp cannot hold', () {
      final board = TrelloBoard.parse(
        '{"id":"b1","name":"Tiny","lists":[],"cards":[{"id":"c1",'
        '"due":"+010000-01-01T00:00:00Z","start":"0000-06-01T00:00:00Z",'
        '"dateLastActivity":"9999-12-31T23:59:59Z"}]}',
      );
      final card = board.cards.single;
      expect(card.due, isNull);
      expect(card.start, isNull);
      expect(card.dateLastActivity, DateTime.utc(9999, 12, 31, 23, 59, 59));
    });

    for (final (why, text) in [
      ('invalid JSON', '{"id":'),
      ('not an object', '[1, 2]'),
      ('no id', '{"name":"x","lists":[],"cards":[]}'),
      ('no name', '{"id":"b","lists":[],"cards":[]}'),
      ('no lists', '{"id":"b","name":"x","cards":[]}'),
      ('cards not a list', '{"id":"b","name":"x","lists":[],"cards":{}}'),
    ]) {
      test('rejects $why with a user-facing message', () {
        expect(
          () => TrelloBoard.parse(text),
          throwsA(
            isA<TrelloFormatException>().having(
              (e) => e.message,
              'message',
              "This isn't a Trello board export. "
                  'Use Export as JSON on the board.',
            ),
          ),
        );
      });
    }
  });
}
