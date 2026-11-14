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

/// A reminder offset as a chip label ("15 min before"), or [short] for
/// row meta and composer chips ("15 min").
String reminderLabel(AppLocalizations l10n, int offset, {bool short = false}) =>
    switch (offset) {
      InboxReminders.atTime => l10n.inboxReminderAtTime,
      InboxReminders.min15 =>
        short ? l10n.inboxReminder15Min : l10n.inboxReminder15MinBefore,
      InboxReminders.hour1 =>
        short ? l10n.inboxReminder1Hour : l10n.inboxReminder1HourBefore,
      InboxReminders.day1 =>
        short ? l10n.inboxReminder1Day : l10n.inboxReminder1DayBefore,
      InboxReminders.morningOf => l10n.inboxReminderMorningOf,
      InboxReminders.dayBefore => l10n.inboxReminderDayBefore,
      _ => l10n.inboxReminderMinutes(offset),
    };
