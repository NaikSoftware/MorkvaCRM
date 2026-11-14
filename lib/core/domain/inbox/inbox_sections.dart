import 'inbox_item.dart';

/// An overdue task with how many calendar days late it is ("3 d late").
typedef OverdueItem = ({InboxItem item, int daysLate});

/// The Inbox page's sections for one selected day (spec §3 Day rules).
///
/// Every list holds each item at most once: the day section and [noDate]
/// hold open items only; a done task shows only under [completed], on the
/// local day of its `doneAt`.
final class InboxSections {
  const InboxSections({
    required this.overdue,
    required this.day,
    required this.noDate,
    required this.completed,
  });

  /// [day] is a calendar day (its y/m/d parts are used as given); [now] is
  /// an instant (its local date is today).
  factory InboxSections.of(
    Iterable<InboxItem> items, {
    required DateTime day,
    required DateTime now,
  }) {
    final selected = _date(day);
    final today = localDay(now);
    final overdue = <OverdueItem>[];
    final onDay = <InboxItem>[];
    final noDate = <InboxItem>[];
    final completed = <InboxItem>[];
    for (final item in items) {
      final itemDay = item.day;
      if (!item.isOpen) {
        final doneAt = item.doneAt;
        if (doneAt != null && localDay(doneAt) == selected) {
          completed.add(item);
        }
      } else if (itemDay == null) {
        noDate.add(item);
      } else if (itemDay == selected) {
        onDay.add(item);
      } else if (selected == today && item.isTask && itemDay.isBefore(today)) {
        overdue.add((item: item, daysLate: daysBetween(itemDay, today)));
      }
    }
    overdue.sort(
      (a, b) =>
          a.item.day!.compareTo(b.item.day!).nonZeroOr(_byTime(a.item, b.item)),
    );
    return InboxSections(
      overdue: overdue,
      day: onDay..sort(_byTime),
      noDate: noDate..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
      completed: completed..sort((a, b) => b.doneAt!.compareTo(a.doneAt!)),
    );
  }

  /// Open tasks dated before today, oldest first; empty unless the
  /// selected day is today.
  final List<OverdueItem> overdue;

  /// Open items of the selected day: timed by time, then all-day by
  /// creation.
  final List<InboxItem> day;

  /// Open undated items (tasks and notes), newest first; shown every day.
  final List<InboxItem> noDate;

  /// Tasks done on the selected day (by `doneAt`), latest first.
  final List<InboxItem> completed;
}

int _byTime(InboxItem a, InboxItem b) {
  if (a.allDay != b.allDay) return a.allDay ? 1 : -1;
  if (a.allDay) return a.createdAt.compareTo(b.createdAt);
  return a.dueAt!
      .compareTo(b.dueAt!)
      .nonZeroOr(a.createdAt.compareTo(b.createdAt));
}

extension on int {
  int nonZeroOr(int other) => this != 0 ? this : other;
}

DateTime _date(DateTime d) => DateTime(d.year, d.month, d.day);

/// The local calendar day (local midnight) of instant [t].
DateTime localDay(DateTime t) => _date(t.toLocal());

/// Calendar days from [from] to [to] (their y/m/d parts), DST-safe.
int daysBetween(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

/// An all-day `dueAt` for calendar day [day]: UTC midnight of its y/m/d.
DateTime allDayDue(DateTime day) => DateTime.utc(day.year, day.month, day.day);

/// The sidebar badge: my open tasks overdue or due today.
int inboxBadgeCount(Iterable<InboxItem> items, DateTime now) {
  final today = localDay(now);
  return items.where((i) {
    final day = i.day;
    return i.isTask && i.isOpen && day != null && !day.isAfter(today);
  }).length;
}

/// Open items per local day (keys are local midnights); undated left out.
Map<DateTime, int> dotsByDay(Iterable<InboxItem> items) {
  final dots = <DateTime, int>{};
  for (final i in items) {
    final day = i.day;
    if (i.isOpen && day != null) dots[day] = (dots[day] ?? 0) + 1;
  }
  return dots;
}

/// Open items linked to card [cardId] of [collectionId] (the card button).
int openLinkedCount(
  Iterable<InboxItem> items,
  String collectionId,
  String cardId,
) => items
    .where(
      (i) =>
          i.isOpen &&
          i.link?.collectionId == collectionId &&
          i.link?.cardId == cardId,
    )
    .length;

/// The editor's date presets, as local calendar days (midnights).
abstract final class InboxDatePresets {
  static DateTime today(DateTime now) => localDay(now);

  static DateTime tomorrow(DateTime now) {
    final t = localDay(now);
    return DateTime(t.year, t.month, t.day + 1);
  }

  /// The coming Monday; on a Monday, the one a week later.
  static DateTime nextMonday(DateTime now) {
    final t = localDay(now);
    return DateTime(t.year, t.month, t.day + 8 - t.weekday);
  }
}

/// [reminders] deduplicated, at most [InboxReminders.max].
List<int> validReminders(Iterable<int> reminders) =>
    reminders.toSet().take(InboxReminders.max).toList();

/// [reminders] for a due moment moved from local [from] to [to]: presets
/// follow the due moment (switching timed ↔ all-day keeps the preset:
/// "15 min before" stays 15 min before the start), custom ones keep the
/// date/time the user picked.
List<int> rebaseReminders(
  Iterable<int> reminders, {
  required DateTime from,
  required bool fromAllDay,
  required DateTime to,
  required bool toAllDay,
}) {
  final presets = InboxReminders.presetsFor(allDay: fromAllDay);
  return validReminders([
    for (final r in reminders)
      if (!presets.contains(r))
        InboxReminders.offsetFor(to, InboxReminders.fireTime(from, r))
      else if (fromAllDay == toAllDay)
        r
      else
        toAllDay ? InboxReminders.toAllDay(r) : InboxReminders.toTimed(r),
  ]);
}
