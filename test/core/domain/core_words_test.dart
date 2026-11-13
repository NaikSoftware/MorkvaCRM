import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:morkva_crm/core/domain/domain.dart';

/// Core text follows `Intl.defaultLocale` and [CoreWords.current], which the
/// app sets from its locale.
void main() {
  const date = DateFieldDefinition(id: 'd', name: 'Due');
  const done = BooleanFieldDefinition(id: 'b', name: 'Done');
  const ref = ReferenceFieldDefinition(
    id: 'r',
    name: 'Client',
    targetCollectionId: 'c',
  );
  const status = SingleSelectFieldDefinition(
    id: 's',
    name: 'Status',
    options: [SelectOption(id: 'a', label: 'Open')],
  );
  final nov9 = DateTime.utc(2026, 11, 9);

  test('English by default', () {
    expect(formatFieldValue(date, DateFieldValue(nov9)), 'Nov 9, 2026');
    expect(formatFieldValue(done, const BooleanFieldValue(true)), 'Yes');
    expect(
      formatFieldValue(ref, const ReferenceFieldValue(['x', 'y'])),
      '2 linked',
    );
    final start = DateTime(2026, 11, 9);
    expect(dateBucketLabel(start, DateBucket.day), 'Nov 9, 2026');
    expect(dateBucketLabel(start, DateBucket.week), 'Week of Nov 9, 2026');
    expect(dateBucketLabel(DateTime(2026, 11), DateBucket.month), 'Nov 2026');
    expect(dateBucketLabel(DateTime(2026, 10), DateBucket.quarter), 'Q4 2026');
    expect(dateBucketLabel(DateTime(2026), DateBucket.year), '2026');
    expect(ViewDefinition.defaultFor(const [date]).name, 'All');
  });

  group('in Ukrainian', () {
    setUp(() async {
      await initializeDateFormatting('uk');
      Intl.defaultLocale = 'uk';
      CoreWords.current = CoreWords(
        untitled: 'Без назви',
        yes: 'Так',
        no: 'Ні',
        linkedCount: (n) => 'пов’язаних: $n',
        noValueGroup: (field) => '$field: не вказано',
        weekOf: (day) => 'Тиждень з $day',
        defaultViewName: 'Усі',
      );
      addTearDown(() {
        Intl.defaultLocale = null;
        CoreWords.current = const CoreWords();
      });
    });

    test('a date reads with the genitive month', () {
      expect(
        formatFieldValue(date, DateFieldValue(nov9)),
        '9 лист. 2026\u202fр.',
      );
      expect(
        formatFieldValue(
          const DateFieldDefinition(id: 'd', name: 'Due', includeTime: true),
          DateFieldValue(DateTime(2026, 5, 3, 14, 5)),
        ),
        '3 трав. 2026\u202fр. 14:05',
      );
    });

    test('a month group reads with the nominative month', () {
      // Stand-alone month (LLL), not the genitive of a full date.
      expect(
        dateBucketLabel(DateTime(2026, 11), DateBucket.month),
        'лист. 2026',
      );
      expect(
        dateBucketLabel(DateTime(2026, 11, 9), DateBucket.week),
        'Тиждень з 9 лист. 2026\u202fр.',
      );
      expect(
        dateBucketLabel(DateTime(2026, 10), DateBucket.quarter),
        '4-й кв. 2026',
      );
    });

    test('fallbacks and default names use the swapped words', () {
      expect(formatFieldValue(done, const BooleanFieldValue(false)), 'Ні');
      expect(
        formatFieldValue(ref, const ReferenceFieldValue(['x'])),
        'пов’язаних: 1',
      );
      expect(groupObjects(status, const []).last.label, 'Status: не вказано');
      expect(ViewDefinition.defaultFor(const [date]).name, 'Усі');
      final collection = Collection(
        id: 'c',
        name: 'Clients',
        fields: const [TextFieldDefinition(id: 't', name: 'Name')],
      );
      final blank = MorkvaObject(
        id: 'o',
        collectionId: 'c',
        values: const {},
        createdAt: nov9,
        updatedAt: nov9,
      );
      expect(objectLabels(collection, [blank]), {'o': 'Без назви'});
    });
  });
}
