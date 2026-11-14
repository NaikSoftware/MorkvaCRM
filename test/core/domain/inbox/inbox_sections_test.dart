import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/inbox/inbox.dart';

/// Saturday 2026-11-14, noon local.
final _now = DateTime(2026, 11, 14, 12);
final _today = DateTime(2026, 11, 14);

InboxItem _item(
  String id, {
  InboxKind kind = InboxKind.task,
  DateTime? dueAt,
  bool allDay = false,
  bool done = false,
  DateTime? doneAt,
  DateTime? createdAt,
  InboxLink? link,
}) => InboxItem(
  id: id,
  kind: kind,
  title: id,
  dueAt: dueAt,
  allDay: allDay,
  link: link,
  assigneeUid: 'u1',
  createdBy: 'u1',
  done: done,
  doneAt: doneAt,
  createdAt: createdAt ?? DateTime.utc(2026, 11, 1),
  updatedAt: createdAt ?? DateTime.utc(2026, 11, 1),
);

/// A timed item at local [h]:[m] on 2026-11-[d].
InboxItem _at(String id, int d, int h, [int m = 0, InboxKind? kind]) => _item(
  id,
  kind: kind ?? InboxKind.task,
  dueAt: DateTime(2026, 11, d, h, m).toUtc(),
);

/// An all-day item on 2026-11-[d] (stored as UTC midnight).
InboxItem _allDay(String id, int d, {DateTime? createdAt, InboxKind? kind}) =>
    _item(
      id,
      kind: kind ?? InboxKind.task,
      dueAt: DateTime.utc(2026, 11, d),
      allDay: true,
      createdAt: createdAt,
    );

List<String> _ids(Iterable<InboxItem> items) => [for (final i in items) i.id];

void main() {
  test('runs in the zone the TZ variable names', () {
    if (Platform.environment['TZ'] == 'America/New_York') {
      expect(DateTime(2026, 1, 1).timeZoneOffset, const Duration(hours: -5));
    }
  });

  group('day section', () {
    test('timed by time, then all-day by creation; open items only', () {
      final s = InboxSections.of(
        [
          _allDay('allDay-late', 14, createdAt: DateTime.utc(2026, 11, 5)),
          _at('t-16', 14, 16),
          _allDay('allDay-early', 14, createdAt: DateTime.utc(2026, 11, 2)),
          _at('t-09', 14, 9),
          _at('note-12', 14, 12, 30, InboxKind.note),
          _item('done', dueAt: DateTime(2026, 11, 14, 8).toUtc(), done: true),
          _at('tomorrow', 15, 9),
        ],
        day: _today,
        now: _now,
      );
      expect(_ids(s.day), [
        't-09',
        'note-12',
        't-16',
        'allDay-early',
        'allDay-late',
      ]);
    });

    test('a timed task earlier today stays in the day, not overdue', () {
      final s = InboxSections.of([_at('t', 14, 8)], day: _today, now: _now);
      expect(_ids(s.day), ['t']);
      expect(s.overdue, isEmpty);
    });

    test('an all-day item stored as UTC midnight keeps its calendar day', () {
      // Under New York, toLocal() of 2026-11-20T00:00Z is the 19th, 19:00.
      final item = _allDay('a', 20);
      expect(
        _ids(
          InboxSections.of([item], day: DateTime(2026, 11, 20), now: _now).day,
        ),
        ['a'],
      );
      expect(
        InboxSections.of([item], day: DateTime(2026, 11, 19), now: _now).day,
        isEmpty,
      );
    });

    test('a late-evening timed item belongs to its local day', () {
      final item = _at('t', 20, 23, 30);
      expect(
        _ids(
          InboxSections.of([item], day: DateTime(2026, 11, 20), now: _now).day,
        ),
        ['t'],
      );
    });
  });

  group('overdue', () {
    final items = [
      _allDay('a-10', 10),
      _at('t-12', 12, 18),
      _at('t-13', 13, 23, 59),
      _at('note-past', 12, 9, 0, InboxKind.note),
      _item(
        'done-past',
        dueAt: DateTime(2026, 11, 12, 9).toUtc(),
        done: true,
        doneAt: DateTime(2026, 11, 13, 9).toUtc(),
      ),
    ];

    test('open tasks before today, oldest first, with lateness', () {
      final s = InboxSections.of(items, day: _today, now: _now);
      expect(
        [for (final o in s.overdue) (o.item.id, o.daysLate)],
        [('a-10', 4), ('t-12', 2), ('t-13', 1)],
      );
    });

    test('notes and done tasks are never overdue', () {
      final s = InboxSections.of(items, day: _today, now: _now);
      expect(
        _ids([for (final o in s.overdue) o.item]),
        isNot(anyOf(contains('note-past'), contains('done-past'))),
      );
    });

    test('shown only when the selected day is today', () {
      for (final day in [DateTime(2026, 11, 13), DateTime(2026, 11, 15)]) {
        expect(InboxSections.of(items, day: day, now: _now).overdue, isEmpty);
      }
      // A past day still lists its own open items.
      expect(
        _ids(
          InboxSections.of(items, day: DateTime(2026, 11, 12), now: _now).day,
        ),
        ['note-past', 't-12'],
      );
    });

    test('lateness counts calendar days across a DST change', () {
      final now = DateTime(2026, 3, 9, 1); // the day after US spring-forward
      final s = InboxSections.of(
        [
          _item('d1', dueAt: DateTime(2026, 3, 8, 23).toUtc()),
          _item('d8', dueAt: DateTime.utc(2026, 3, 1), allDay: true),
        ],
        day: DateTime(2026, 3, 9),
        now: now,
      );
      expect(
        [for (final o in s.overdue) (o.item.id, o.daysLate)],
        [('d8', 8), ('d1', 1)],
      );
      expect(daysBetween(DateTime(2026, 3, 8), DateTime(2026, 3, 9)), 1);
      expect(daysBetween(DateTime(2026, 10, 31), DateTime(2026, 11, 2)), 2);
    });
  });

  group('no date', () {
    test('undated open tasks and notes, newest first, on every day', () {
      final items = [
        _item('old-task', createdAt: DateTime.utc(2026, 11, 1)),
        _item(
          'new-note',
          kind: InboxKind.note,
          createdAt: DateTime.utc(2026, 11, 13),
        ),
        _item('mid-task', createdAt: DateTime.utc(2026, 11, 5)),
        _item('done', done: true, doneAt: DateTime.utc(2026, 11, 14, 10)),
      ];
      for (final day in [_today, DateTime(2026, 12, 25)]) {
        expect(_ids(InboxSections.of(items, day: day, now: _now).noDate), [
          'new-note',
          'mid-task',
          'old-task',
        ]);
      }
    });

    test('a note created today is still under No date the next day', () {
      final note = _item(
        'n',
        kind: InboxKind.note,
        createdAt: DateTime(2026, 11, 14, 10).toUtc(),
      );
      final nextDay = DateTime(2026, 11, 15, 9);
      final s = InboxSections.of([note], day: localDay(nextDay), now: nextDay);
      expect(_ids(s.noDate), ['n']);
      expect(s.day, isEmpty);
    });
  });

  group('completed', () {
    final items = [
      _item(
        'overdue-done-today',
        dueAt: DateTime(2026, 11, 10, 9).toUtc(),
        done: true,
        doneAt: DateTime(2026, 11, 14, 9).toUtc(),
      ),
      _item(
        'undated-done-late',
        done: true,
        doneAt: DateTime(2026, 11, 14, 23, 30).toUtc(),
      ),
      _item(
        'today-done-yesterday',
        dueAt: DateTime(2026, 11, 14, 9).toUtc(),
        done: true,
        doneAt: DateTime(2026, 11, 13, 20).toUtc(),
      ),
    ];

    test('done tasks by the local day of doneAt, latest first', () {
      final s = InboxSections.of(items, day: _today, now: _now);
      expect(_ids(s.completed), ['undated-done-late', 'overdue-done-today']);
      expect(s.day, isEmpty);
      expect(
        _ids(
          InboxSections.of(
            items,
            day: DateTime(2026, 11, 13),
            now: _now,
          ).completed,
        ),
        ['today-done-yesterday'],
      );
      expect(
        InboxSections.of(
          items,
          day: DateTime(2026, 11, 10),
          now: _now,
        ).completed,
        isEmpty,
      );
    });
  });

  test('badge: open tasks overdue or due today', () {
    final items = [
      _allDay('overdue', 10),
      _at('today-early', 14, 8),
      _allDay('today', 14),
      _at('tomorrow', 15, 0, 1),
      _at('note-today', 14, 9, 0, InboxKind.note),
      _item('undated'),
      _item(
        'done',
        dueAt: DateTime.utc(2026, 11, 14),
        allDay: true,
        done: true,
      ),
    ];
    expect(inboxBadgeCount(items, _now), 3);
    expect(inboxBadgeCount(const [], _now), 0);
  });

  test('dots: open items per local day, undated left out', () {
    final dots = dotsByDay([
      _allDay('a', 20),
      _at('b', 20, 23),
      _at('note', 21, 9, 0, InboxKind.note),
      _item(
        'done',
        dueAt: DateTime.utc(2026, 11, 21),
        allDay: true,
        done: true,
      ),
      _item('undated'),
    ]);
    expect(dots, {DateTime(2026, 11, 20): 2, DateTime(2026, 11, 21): 1});
  });

  test('open linked count matches collection and card', () {
    const link = InboxLink(collectionId: 'c1', cardId: 'b1', label: '#1');
    const otherCollection = InboxLink(
      collectionId: 'c2',
      cardId: 'b1',
      label: '#1',
    );
    final items = [
      _item('a', link: link),
      _item('b', kind: InboxKind.note, link: link),
      _item('done', link: link, done: true),
      _item('other', link: otherCollection),
      _item('unlinked'),
    ];
    expect(openLinkedCount(items, 'c1', 'b1'), 2);
    expect(openLinkedCount(items, 'c1', 'b2'), 0);
  });

  group('date presets', () {
    test('today and tomorrow are local midnights', () {
      expect(InboxDatePresets.today(DateTime(2026, 11, 14, 23, 59)), _today);
      expect(
        InboxDatePresets.tomorrow(DateTime(2026, 11, 30, 18)),
        DateTime(2026, 12),
      );
      // US DST ends 2026-11-01.
      expect(
        InboxDatePresets.tomorrow(DateTime(2026, 10, 31, 22)),
        DateTime(2026, 11),
      );
    });

    test('next Monday; on a Monday, a week later', () {
      expect(InboxDatePresets.nextMonday(_now), DateTime(2026, 11, 16)); // Sat
      expect(
        InboxDatePresets.nextMonday(DateTime(2026, 11, 15, 9)),
        DateTime(2026, 11, 16),
      ); // Sun
      expect(
        InboxDatePresets.nextMonday(DateTime(2026, 11, 16, 9)),
        DateTime(2026, 11, 23),
      ); // Mon
      expect(
        InboxDatePresets.nextMonday(DateTime(2026, 11, 17, 9)),
        DateTime(2026, 11, 23),
      ); // Tue
    });

    test('allDayDue is UTC midnight of the calendar day', () {
      expect(allDayDue(DateTime(2026, 11, 20, 23)), DateTime.utc(2026, 11, 20));
    });
  });

  test('valid reminders: deduped, at most 3', () {
    expect(validReminders([0, 15, 15, 30, 120]), [0, 15, 30]);
  });

  group('rebaseReminders', () {
    final noon = DateTime(2026, 11, 20, 12);
    final custom = InboxReminders.offsetFor(noon, DateTime(2026, 11, 19, 18));

    test('a moved due moment keeps custom times, presets follow', () {
      final next = DateTime(2026, 11, 22, 12);
      final out = rebaseReminders(
        [InboxReminders.min15, custom],
        from: noon,
        fromAllDay: false,
        to: next,
        toAllDay: false,
      );
      expect(out.first, InboxReminders.min15);
      expect(
        InboxReminders.fireTime(next, out.last),
        DateTime(2026, 11, 19, 18),
      );
    });

    test('timed to all-day drops the timed presets only', () {
      final midnight = DateTime(2026, 11, 20);
      final out = rebaseReminders(
        [InboxReminders.atStart, custom],
        from: noon,
        fromAllDay: false,
        to: midnight,
        toAllDay: true,
      );
      expect(out, hasLength(1));
      expect(
        InboxReminders.fireTime(midnight, out.single),
        DateTime(2026, 11, 19, 18),
      );
    });
  });
}
