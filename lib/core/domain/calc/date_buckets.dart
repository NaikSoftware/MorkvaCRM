import '../types/date_field.dart';
import '../view/field_format.dart';

/// The span a date group-by folds days into. Names are wire values
/// (`groupBy.bucket`), so keep them stable.
enum DateBucket { day, week, month, quarter, year }

/// The first day of the [bucket] that [field]'s stored [value] falls in, as a
/// local-midnight [DateTime] (the same day key [bucketByDay] uses).
///
/// The day itself follows [calendarDayOf]: a date-only field reads its UTC
/// day, a field with time its local day. Weeks start on Monday.
DateTime dateBucketOf(
  DateFieldDefinition field,
  DateTime value,
  DateBucket bucket,
) => dateBucketStart(calendarDayOf(field, value), bucket);

/// The first day of the [bucket] that calendar [day] falls in, as a
/// local-midnight [DateTime]. Only [day]'s year, month and day are read, so
/// pass a calendar day (e.g. from [calendarDayOf]); for an instant such as a
/// card's `createdAt`, pass its local day.
DateTime dateBucketStart(DateTime day, DateBucket bucket) =>
    // Component arithmetic, never Duration: a DST shift would move midnight.
    switch (bucket) {
      DateBucket.day => DateTime(day.year, day.month, day.day),
      DateBucket.week => DateTime(
        day.year,
        day.month,
        day.day - (day.weekday - DateTime.monday),
      ),
      DateBucket.month => DateTime(day.year, day.month),
      DateBucket.quarter => DateTime(day.year, (day.month - 1) ~/ 3 * 3 + 1),
      DateBucket.year => DateTime(day.year),
    };

/// A stable key for the [bucket] starting on [start] (from [dateBucketStart])
/// that sorts chronologically as text: `2026-11-09` for a day or a week (its
/// Monday), `2026-11`, `2026-Q4`, `2026`.
String dateBucketKey(DateTime start, DateBucket bucket) {
  final y = start.year.toString().padLeft(4, '0');
  final m = _two(start.month);
  return switch (bucket) {
    DateBucket.day || DateBucket.week => '$y-$m-${_two(start.day)}',
    DateBucket.month => '$y-$m',
    DateBucket.quarter => '$y-Q${(start.month - 1) ~/ 3 + 1}',
    DateBucket.year => y,
  };
}

/// How the [bucket] starting on [start] reads: `Nov 9, 2026`,
/// `Week of Nov 9, 2026`, `Nov 2026`, `Q4 2026`, `2026`.
String dateBucketLabel(DateTime start, DateBucket bucket) {
  final day = '${_months[start.month - 1]} ${start.day}, ${start.year}';
  return switch (bucket) {
    DateBucket.day => day,
    DateBucket.week => 'Week of $day',
    DateBucket.month => '${_months[start.month - 1]} ${start.year}',
    DateBucket.quarter => 'Q${(start.month - 1) ~/ 3 + 1} ${start.year}',
    DateBucket.year => '${start.year}',
  };
}

// The same short month names formatFieldValue shows dates with.
const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _two(int n) => n.toString().padLeft(2, '0');
