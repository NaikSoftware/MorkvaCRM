import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/inbox/inbox.dart';

final _created = DateTime.utc(2026, 11, 10, 8);

InboxItem _item({
  InboxKind kind = InboxKind.task,
  DateTime? dueAt,
  bool allDay = false,
  List<int> reminders = const [],
  bool done = false,
}) => InboxItem(
  id: 'i1',
  kind: kind,
  title: 'Call the supplier',
  dueAt: dueAt,
  allDay: allDay,
  reminders: reminders,
  assigneeUid: 'u1',
  createdBy: 'u1',
  done: done,
  createdAt: _created,
  updatedAt: _created,
);

void main() {
  test('runs in the zone the TZ variable names', () {
    if (Platform.environment['TZ'] == 'America/New_York') {
      expect(DateTime(2026, 1, 1).timeZoneOffset, const Duration(hours: -5));
    }
  });

  group('codec', () {
    test('round-trips every field', () {
      final item = InboxItem(
        id: 'i1',
        kind: InboxKind.note,
        title: 'Ship order #1042',
        details: 'Before noon',
        dueAt: DateTime.utc(2026, 11, 20, 14, 30),
        reminders: const [0, 60],
        link: const InboxLink(
          collectionId: 'c_orders',
          cardId: 'b_1',
          label: '#1042',
        ),
        assigneeUid: 'u1',
        createdBy: 'u1',
        done: true,
        doneAt: DateTime.utc(2026, 11, 20, 15),
        createdAt: _created,
        updatedAt: DateTime.utc(2026, 11, 11),
      );
      expect(InboxItem.fromJson('i1', item.toJson()), item);
    });

    test('defaults the optional fields', () {
      final item = InboxItem.fromJson('i1', {
        'kind': 'task',
        'title': 'Bare',
        'assigneeUid': 'u1',
        'createdBy': 'u1',
      });
      expect(item.details, '');
      expect(item.dueAt, isNull);
      expect(item.reminders, isEmpty);
      expect(item.link, isNull);
      expect(item.done, isFalse);
    });

    final valid = _item().toJson();
    for (final (name, patch) in <(String, Map<String, Object?>)>[
      ('unknown kind', {'kind': 'event'}),
      ('missing kind', {'kind': null}),
      ('empty title', {'title': ''}),
      ('non-string title', {'title': 42}),
      ('missing assignee', {'assigneeUid': null}),
      (
        'link without a card id',
        {
          'link': {'collectionId': 'c', 'label': 'x'},
        },
      ),
    ]) {
      test('rejects $name with a FormatException', () {
        expect(
          () => InboxItem.fromJson('i1', {...valid, ...patch}),
          throwsFormatException,
        );
      });
    }

    test('drops reminders that are not a list of numbers', () {
      expect(
        InboxItem.fromJson('i1', {...valid, 'reminders': 'soon'}).reminders,
        isEmpty,
      );
      expect(
        InboxItem.fromJson('i1', {
          ...valid,
          'reminders': [15, 'x', 60.0],
        }).reminders,
        [15, 60],
      );
    });
  });

  group('fireTimes', () {
    test('timed offsets are instants before the due moment', () {
      final item = _item(
        dueAt: DateTime(2026, 11, 20, 15, 30).toUtc(),
        reminders: const [0, 15, 60],
      );
      expect(item.fireTimes, [
        DateTime(2026, 11, 20, 15, 30),
        DateTime(2026, 11, 20, 15, 15),
        DateTime(2026, 11, 20, 14, 30),
      ]);
    });

    test('1 day before keeps the wall-clock time across a DST change', () {
      // US DST starts 2026-03-08: under New York that day has 23 hours.
      final item = _item(
        dueAt: DateTime(2026, 3, 9, 10).toUtc(),
        reminders: const [InboxReminders.day1],
      );
      expect(item.fireTimes, [DateTime(2026, 3, 8, 10)]);
    });

    test('all-day: 09:00 on the day and 09:00 the day before', () {
      final item = _item(
        dueAt: DateTime.utc(2026, 11, 20),
        allDay: true,
        reminders: const [InboxReminders.morningOf, InboxReminders.dayBefore],
      );
      expect(item.fireTimes, [
        DateTime(2026, 11, 20, 9),
        DateTime(2026, 11, 19, 9),
      ]);
    });

    test('none for a done task or an undated item', () {
      expect(
        _item(
          dueAt: DateTime.utc(2026, 11, 20, 9),
          reminders: const [0],
          done: true,
        ).fireTimes,
        isEmpty,
      );
      expect(_item(reminders: const [0]).fireTimes, isEmpty);
    });

    test('a note never counts as done', () {
      final note = _item(
        kind: InboxKind.note,
        dueAt: DateTime(2026, 11, 20, 9).toUtc(),
        reminders: const [0],
        done: true,
      );
      expect(note.fireTimes, [DateTime(2026, 11, 20, 9)]);
    });
  });
}
