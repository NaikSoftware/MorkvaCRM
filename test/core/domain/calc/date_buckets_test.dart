import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';

const _dateOnly = DateFieldDefinition(id: 'd', name: 'Due');
const _withTime = DateFieldDefinition(id: 't', name: 'At', includeTime: true);

void main() {
  test('bucket names are the wire values', () {
    expect(DateBucket.values.map((b) => b.name), [
      'day',
      'week',
      'month',
      'quarter',
      'year',
    ]);
  });

  group('dateBucketStart', () {
    // Tuesday, Nov 10 2026.
    final day = DateTime(2026, 11, 10);

    test('day, month, quarter and year start at local midnight', () {
      expect(dateBucketStart(day, DateBucket.day), DateTime(2026, 11, 10));
      expect(dateBucketStart(day, DateBucket.month), DateTime(2026, 11));
      expect(dateBucketStart(day, DateBucket.quarter), DateTime(2026, 10));
      expect(dateBucketStart(day, DateBucket.year), DateTime(2026));
      expect(
        dateBucketStart(DateTime(2026, 3, 31), DateBucket.quarter),
        DateTime(2026),
      );
      expect(
        dateBucketStart(DateTime(2026, 6, 30), DateBucket.quarter),
        DateTime(2026, 4),
      );
    });

    test('weeks start on Monday, also across a year boundary', () {
      expect(dateBucketStart(day, DateBucket.week), DateTime(2026, 11, 9));
      // Monday itself and Sunday stay in the same week.
      expect(
        dateBucketStart(DateTime(2026, 11, 9), DateBucket.week),
        DateTime(2026, 11, 9),
      );
      expect(
        dateBucketStart(DateTime(2026, 11, 15), DateBucket.week),
        DateTime(2026, 11, 9),
      );
      // Friday Jan 1 2027 belongs to the week of Monday Dec 28 2026.
      expect(
        dateBucketStart(DateTime(2027), DateBucket.week),
        DateTime(2026, 12, 28),
      );
    });

    test('ignores the time of day', () {
      expect(
        dateBucketStart(DateTime(2026, 11, 10, 23, 59), DateBucket.day),
        DateTime(2026, 11, 10),
      );
    });
  });

  group('dateBucketOf follows calendarDayOf', () {
    test('a date-only field reads its UTC day', () {
      // Stored as UTC midnight: the day must not shift west of UTC.
      final stored = DateTime.utc(2026, 1, 1);
      expect(dateBucketOf(_dateOnly, stored, DateBucket.day), DateTime(2026));
      expect(dateBucketOf(_dateOnly, stored, DateBucket.year), DateTime(2026));
      expect(
        dateBucketOf(_dateOnly, stored, DateBucket.week),
        DateTime(2025, 12, 29),
      );
    });

    test('a field with time reads its local day', () {
      final stored = DateTime(2026, 12, 31, 23, 30).toUtc();
      expect(
        dateBucketOf(_withTime, stored, DateBucket.day),
        DateTime(2026, 12, 31),
      );
      expect(dateBucketOf(_withTime, stored, DateBucket.year), DateTime(2026));
    });
  });

  group('keys and labels', () {
    String key(DateTime day, DateBucket b) =>
        dateBucketKey(dateBucketStart(day, b), b);
    String label(DateTime day, DateBucket b) =>
        dateBucketLabel(dateBucketStart(day, b), b);
    final day = DateTime(2026, 11, 10);

    test('keys', () {
      expect(key(day, DateBucket.day), '2026-11-10');
      expect(key(day, DateBucket.week), '2026-11-09');
      expect(key(day, DateBucket.month), '2026-11');
      expect(key(day, DateBucket.quarter), '2026-Q4');
      expect(key(day, DateBucket.year), '2026');
      expect(key(DateTime(2026, 2, 3), DateBucket.month), '2026-02');
    });

    test('labels', () {
      expect(label(day, DateBucket.day), 'Nov 10, 2026');
      expect(label(day, DateBucket.week), 'Week of Nov 9, 2026');
      expect(label(day, DateBucket.month), 'Nov 2026');
      expect(label(day, DateBucket.quarter), 'Q4 2026');
      expect(label(day, DateBucket.year), '2026');
    });

    test('keys sort chronologically as text', () {
      final days = [
        DateTime(2025, 12, 31),
        DateTime(2026, 2, 1),
        DateTime(2026, 10, 30),
        DateTime(2027, 1, 4),
      ];
      for (final b in DateBucket.values) {
        final keys = [for (final d in days) key(d, b)];
        expect([...keys]..sort(), keys, reason: b.name);
      }
    });
  });
}
