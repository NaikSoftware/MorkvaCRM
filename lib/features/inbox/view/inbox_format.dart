import '../../../core/domain/inbox/inbox.dart';

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// "Sat" for calendar day [d].
String weekdayLabel(DateTime d) => _weekdays[d.weekday - 1];

/// "Sat 14".
String dayLabel(DateTime d) => '${weekdayLabel(d)} ${d.day}';

/// "Sat 14 Nov".
String dayMonthLabel(DateTime d) =>
    '${dayLabel(d)} ${_months[d.month - 1].substring(0, 3)}';

/// "November 2026".
String monthLabel(DateTime d) => '${_months[d.month - 1]} ${d.year}';

/// "09:30" for [minutes] after midnight.
String timeLabel(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
    '${(minutes % 60).toString().padLeft(2, '0')}';

/// A timed item's local time of day in minutes, or null when all-day or
/// undated.
int? itemMinutes(InboxItem item) {
  final due = item.dueAt;
  if (due == null || item.allDay) return null;
  final l = due.toLocal();
  return l.hour * 60 + l.minute;
}

/// A reminder offset as a chip label ("15 min before"), or [short] for
/// row meta and composer chips ("15 min").
String reminderLabel(int offset, {bool short = false}) => switch (offset) {
  InboxReminders.atTime => 'At time',
  InboxReminders.min15 => short ? '15 min' : '15 min before',
  InboxReminders.hour1 => short ? '1 h' : '1 h before',
  InboxReminders.day1 => short ? '1 day' : '1 day before',
  InboxReminders.morningOf => 'Morning of',
  InboxReminders.dayBefore => 'Day before',
  _ => '$offset min',
};
