import 'package:intl/intl.dart';

import '../../../core/domain/inbox/inbox.dart';
import '../../../l10n/l10n.dart';

/// The date labels take the [locale] to word them in
/// (`Localizations.localeOf(context).toString()`); null is `Intl`'s current
/// one.
DateFormat _format(String pattern, String? locale) {
  final l = locale ?? Intl.getCurrentLocale();
  return _formats.putIfAbsent((l, pattern), () => DateFormat(pattern, l));
}

final _formats = <(String, String), DateFormat>{};

/// "Sat" for calendar day [d].
String weekdayLabel(DateTime d, [String? locale]) =>
    _format('E', locale).format(d);

/// "Sat 14".
String dayLabel(DateTime d, [String? locale]) =>
    _format('E d', locale).format(d);

/// "Sat 14 Nov".
String dayMonthLabel(DateTime d, [String? locale]) =>
    _format('E d MMM', locale).format(d);

/// "November 2026" (the stand-alone month: «листопад 2026»).
String monthLabel(DateTime d, [String? locale]) =>
    _format('LLLL y', locale).format(d);

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

/// A reminder offset as a chip label ("15 min before", "Morning of ·
/// 09:00"), or [short] for row meta and composer chips ("15 min", "09:00").
/// A custom one shows when it fires
/// for local due moment [base]: "Fri 13, 18:00" (short: "18:00" on the due
/// day).
String reminderLabel(
  AppLocalizations l10n,
  int offset, {
  required DateTime? base,
  required bool allDay,
  String? locale,
  bool short = false,
}) {
  if (base == null) return l10n.inboxReminderMinutes(offset);
  final at = InboxReminders.fireTime(base, offset);
  final time = timeLabel(at.hour * 60 + at.minute);
  if (InboxReminders.presetsFor(allDay: allDay).contains(offset)) {
    return switch (offset) {
      InboxReminders.min15 =>
        short ? l10n.inboxReminder15Min : l10n.inboxReminder15MinBefore,
      InboxReminders.min30 =>
        short ? l10n.inboxReminder30Min : l10n.inboxReminder30MinBefore,
      InboxReminders.morningOf =>
        short ? time : '${l10n.inboxReminderMorningOf} · $time',
      _ => l10n.inboxReminderAtStart,
    };
  }
  final sameDay =
      at.year == base.year && at.month == base.month && at.day == base.day;
  return short && sameDay ? time : '${dayLabel(at, locale)}, $time';
}
