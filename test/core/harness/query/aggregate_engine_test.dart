import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/core/harness/harness.dart';
import 'package:morkva_crm/core/harness/input/value_codec.dart';
import 'package:morkva_crm/core/harness/query/aggregate_engine.dart';
import 'package:morkva_crm/core/harness/query/result_shaper.dart';

import 'query_fixture.dart';

Matcher throwsHarness(ErrorCode code, {String? path}) => throwsA(
  isA<HarnessException>()
      .having((e) => e.error.code, 'code', code)
      .having((e) => e.error.path, 'path', path ?? anything),
);

List<Map<Object?, Object?>> groupsOf(Map<String, Object?> r) =>
    (r['groups']! as List).cast<Map<Object?, Object?>>();

Map<Object?, Map<Object?, Object?>> byKey(Map<String, Object?> r) => {
  for (final g in groupsOf(r)) g['key']: g,
};

void main() {
  late QueryHarness h;

  setUp(() => h = QueryHarness(SeedWorkspace()));
  tearDown(() => h.dispose());

  List<MorkvaObject> orders() => h.derived(SeedIds.orders);

  String? statusOf(MorkvaObject o) =>
      (o[OrderFields.status] as SingleSelectFieldValue).optionId;

  test('count and sum by status: option order, every option, totals', () async {
    final r = await h.aggregate({
      'collection': 'Orders',
      'groupBy': {'field': 'Status'},
      'metrics': [
        {'op': 'count'},
        {'op': 'sum', 'field': 'Total'},
      ],
    });

    final options = [
      SeedOptions.statusNew,
      SeedOptions.packing,
      SeedOptions.shipped,
      SeedOptions.done,
    ];
    expect([for (final g in groupsOf(r)) g['key']], options);
    for (final g in groupsOf(r)) {
      final members = orders().where((o) => statusOf(o) == g['key']);
      final sum = foldAggregate(AggregateOp.sum, [
        for (final o in members) numberOf(o, OrderFields.total),
      ]);
      expect(g['count'], members.length, reason: '${g['label']}');
      expect(g['m'], [members.length, cleanNumber(sum! as num)]);
    }
    final total = foldAggregate(AggregateOp.sum, [
      for (final o in orders()) numberOf(o, OrderFields.total),
    ]);
    expect(r['total'], 24);
    expect(r['totals'], [24, cleanNumber(total! as num)]);
    expect(r['metrics'], ['count', 'sum Total']);
    expect(r['unit'], '₴');
    expect(r['summary'], '24 Orders · count, sum Total by Status: 4 groups');
  });

  test('metrics without groupBy fold every matched card', () async {
    final r = await h.aggregate({
      'collection': 'Orders',
      'where': [
        {'field': 'Paid', 'op': 'isTrue'},
      ],
      'metrics': [
        {'op': 'average', 'field': 'Price'},
        {'op': 'min', 'field': 'Created'},
        {'op': 'max', 'field': '@createdAt'},
      ],
    });
    final paid = orders()
        .where((o) => (o[OrderFields.paid] as BooleanFieldValue).value == true)
        .toList();
    final avg = foldAggregate(AggregateOp.average, [
      for (final o in paid) numberOf(o, OrderFields.price),
    ]);
    final minDay = paid
        .map((o) => (o[OrderFields.created] as DateFieldValue).value!.toUtc())
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final maxAt = paid
        .map((o) => o.createdAt)
        .reduce((a, b) => a.isAfter(b) ? a : b);

    expect(r.containsKey('groups'), isFalse);
    expect(r['total'], paid.length);
    expect(r['totals'], [
      cleanNumber(avg! as num),
      isoDay(minDay),
      isoInstant(maxAt),
    ]);
    // Dates carry no unit; the one numeric metric's unit is the result's.
    expect(r['unit'], '₴');
  });

  test(
    'sum by month over a calculated metric matches the calculated path',
    () async {
      final r = await h.aggregate({
        'collection': 'Orders',
        'groupBy': {'field': 'Created', 'bucket': 'month'},
        'metrics': [
          {'op': 'sum', 'field': 'Total'},
        ],
      });
      final created =
          h.collection(SeedIds.orders).fieldById(OrderFields.created)!
              as DateFieldDefinition;
      final expected = <String, List<MorkvaObject>>{};
      for (final o in orders()) {
        final dt = (o[OrderFields.created] as DateFieldValue).value!;
        final key = dateBucketKey(
          dateBucketOf(created, dt, DateBucket.month),
          DateBucket.month,
        );
        (expected[key] ??= []).add(o);
      }
      final keys = expected.keys.toList()..sort();
      expect([for (final g in groupsOf(r)) g['key']], keys);
      for (final g in groupsOf(r)) {
        final members = expected[g['key']]!;
        expect(g['count'], members.length);
        expect(g['m'], [
          cleanNumber(
            foldAggregate(AggregateOp.sum, [
                  for (final o in members) numberOf(o, OrderFields.total),
                ])!
                as num,
          ),
        ]);
      }
      expect(
        groupsOf(r).first['label'],
        matches(RegExp(r'^[A-Z][a-z]{2} 2026$')),
      );
    },
  );

  test(
    'multi-select explodes: a card counts once in each of its tags',
    () async {
      final r = await h.aggregate({
        'collection': 'Orders',
        'groupBy': {'field': 'Tags'},
      });
      List<String> tags(MorkvaObject o) =>
          (o[OrderFields.tags] as MultiSelectFieldValue).optionIds;
      final groups = byKey(r);
      for (final key in [
        SeedOptions.gift,
        SeedOptions.urgent,
        SeedOptions.repeat,
      ]) {
        expect(
          groups[key]!['count'],
          orders().where((o) => tags(o).contains(key)).length,
        );
      }
      final none = groupsOf(r).last;
      expect(none['key'], isNull);
      expect(none['label'], 'No Tags');
      expect(none['count'], orders().where((o) => tags(o).isEmpty).length);
    },
  );

  test(
    'a reference groups by linked titles; empty groups are left out',
    () async {
      final r = await h.aggregate({
        'collection': 'Orders',
        'groupBy': {'field': 'Client'},
      });
      final groups = groupsOf(r);
      expect(groups.every((g) => (g['count']! as int) > 0), isTrue);
      expect(
        groups.where((g) => g['key'] == SeedCards.nadiya),
        isEmpty,
        reason: 'Nadiya has no orders',
      );
      expect(byKey(r)[SeedCards.olena]!['label'], 'Olena Bondar');
      expect(groups.last['key'], isNull);
      expect(groups.last['label'], 'No Client');
      final noClient = orders().where(
        (o) => (o[OrderFields.client] as ReferenceFieldValue).objectIds.isEmpty,
      );
      expect(groups.last['count'], noClient.length);
      expect(groups.fold<int>(0, (s, g) => s + (g['count']! as int)), 24);
    },
  );

  test('boolean groups are Yes, No, then empty', () async {
    final r = await h.aggregate({
      'collection': 'Orders',
      'groupBy': {'field': 'Paid'},
    });
    final labels = [for (final g in groupsOf(r)) g['label']];
    expect(labels.take(2), ['Yes', 'No']);
    expect(
      byKey(r)[true]!['count'],
      orders()
          .where(
            (o) => (o[OrderFields.paid] as BooleanFieldValue).value == true,
          )
          .length,
    );
  });

  test('text groups by exact value, most cards first', () async {
    final r = await h.aggregate({
      'collection': 'Orders',
      'groupBy': {'field': 'Item'},
    });
    final counts = [for (final g in groupsOf(r)) g['count']! as int];
    expect(counts, [...counts]..sort((a, b) => b - a));
    expect(byKey(r)['Linen dress']!['count'], 3);
  });

  test(
    'a lookup groups as the type it shows (Client city as a select)',
    () async {
      final r = await h.aggregate({
        'collection': 'Orders',
        'groupBy': {'field': 'Client city'},
      });
      final keys = [for (final g in groupsOf(r)) g['key']];
      expect(keys.take(5), [
        SeedOptions.kyiv,
        SeedOptions.lviv,
        SeedOptions.odesa,
        SeedOptions.kharkiv,
        SeedOptions.dnipro,
      ]);
      expect(groupsOf(r).fold<int>(0, (s, g) => s + (g['count']! as int)), 24);
    },
  );

  test('@createdAt groups by local day by default', () async {
    final r = await h.aggregate({
      'collection': 'Orders',
      'groupBy': {'field': '@createdAt'},
    });
    final days = <String>{
      for (final o in orders()) isoDay(o.createdAt.toLocal()),
    };
    expect([for (final g in groupsOf(r)) g['key']], days.toList()..sort());
  });

  test('orderBy metric with a limit reports the rest as otherGroups', () async {
    final r = await h.aggregate({
      'collection': 'Orders',
      'groupBy': {'field': 'Client', 'limit': 3},
      'metrics': [
        {'op': 'sum', 'field': 'Total'},
      ],
      'orderBy': {'by': 'metric'},
    });
    final all = await h.aggregate({
      'collection': 'Orders',
      'groupBy': {'field': 'Client'},
      'metrics': [
        {'op': 'sum', 'field': 'Total'},
      ],
    });
    final sums = [
      for (final g in groupsOf(all)) (g['m']! as List).single! as num,
    ]..sort((a, b) => b.compareTo(a));
    expect([
      for (final g in groupsOf(r)) (g['m']! as List).single,
    ], sums.take(3));
    expect(r['otherGroups'], groupsOf(all).length - 3);
  });

  test('from @screen aggregates what is shown', () async {
    final r = await h.aggregate(
      {
        'from': '@screen',
        'metrics': [
          {'op': 'count'},
        ],
      },
      focus: ScreenContext(
        page: ScreenPage.collection,
        collectionId: SeedIds.orders,
        filters: const [
          ViewFilter(fieldId: OrderFields.paid, op: FilterOp.isFalse),
        ],
      ),
    );
    final unpaid = orders().where(
      (o) => (o[OrderFields.paid] as BooleanFieldValue).value != true,
    );
    expect(r['totals'], [unpaid.length]);
  });

  test('bad metrics and group-bys fail with candidates', () async {
    expect(
      () => h.aggregate({
        'collection': 'Orders',
        'metrics': [
          {'op': 'sum', 'field': 'Item'},
        ],
      }),
      throwsA(
        isA<HarnessException>()
            .having((e) => e.error.path, 'path', 'metrics[0].field')
            .having((e) => e.error.candidates, 'candidates', contains('Total')),
      ),
    );
    expect(
      () => h.aggregate({
        'collection': 'Orders',
        'metrics': [
          {'op': 'median', 'field': 'Total'},
        ],
      }),
      throwsHarness(ErrorCode.invalidArgs, path: 'metrics[0].op'),
    );
    expect(
      () => h.aggregate({
        'collection': 'Orders',
        'metrics': [
          {'op': 'sum'},
        ],
      }),
      throwsHarness(ErrorCode.invalidArgs, path: 'metrics[0].field'),
    );
    expect(
      () => h.aggregate({
        'collection': 'Orders',
        'groupBy': {'field': 'Status', 'bucket': 'month'},
      }),
      throwsHarness(ErrorCode.invalidArgs, path: 'groupBy.bucket'),
    );
    expect(
      () => h.aggregate({
        'collection': 'Orders',
        'groupBy': {'field': 'Status'},
        'orderBy': {'by': 'metric', 'index': 2},
      }),
      throwsHarness(ErrorCode.invalidArgs, path: 'orderBy.index'),
    );
  });

  test('the handle stores the full result for charts', () async {
    final r = await h.aggregate({
      'collection': 'Orders',
      'groupBy': {'field': 'Status'},
    });
    final stored = h.results.get(r['handle']! as String)!;
    expect(stored.orderedIds, hasLength(24));
    expect((stored.groups! as Map)['groups'], r['groups']);
    final spec = AggregateSpec.fromJson(
      jsonDecode(jsonEncode(stored.spec)) as Map<String, Object?>,
    );
    expect(spec.toJson(), stored.spec);
  });

  test('groups over the byte budget are cut and counted', () async {
    final small = QueryHarness(
      SeedWorkspace(),
      shaper: const ResultShaper(aggregateBudget: 700),
    );
    addTearDown(small.dispose);
    final r = await small.aggregate({
      'collection': 'Orders',
      'groupBy': {'field': 'Created'},
    });
    final full = await h.aggregate({
      'collection': 'Orders',
      'groupBy': {'field': 'Created'},
    });
    expect(ResultShaper.bytes(r), lessThanOrEqualTo(700));
    expect(r['truncated'], isTrue);
    expect(
      groupsOf(r).length + (r['otherGroups']! as int),
      groupsOf(full).length,
    );
  });

  group('cards.distinct', () {
    test('lists values most frequent first, empties counted apart', () async {
      final r = await h.aggregates.distinct({
        'collection': 'Orders',
        'field': 'Client',
      }, context());
      final values = (r['values']! as List).cast<Map>();
      final counts = [for (final v in values) v['count']! as int];
      expect(counts, [...counts]..sort((a, b) => b - a));
      expect(values.every((v) => v['value'] != null), isTrue);
      expect(r['empty'], 1);
      expect(counts.fold<int>(0, (s, c) => s + c) + (r['empty']! as int), 24);
    });

    test('a select lists its used options with labels', () async {
      final r = await h.aggregates.distinct({
        'collection': 'Orders',
        'field': 'Status',
        'where': [
          {'field': 'Paid', 'op': 'isTrue'},
        ],
      }, context());
      for (final v in (r['values']! as List).cast<Map>()) {
        expect(v['label'], isIn(['New', 'Packing', 'Shipped', 'Done']));
      }
      expect(r['summary'], contains('distinct Status values'));
    });
  });
}
