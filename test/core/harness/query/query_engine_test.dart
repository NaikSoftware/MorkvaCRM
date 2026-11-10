import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/core/harness/harness.dart';
import 'package:morkva_crm/core/harness/query/query_engine.dart';
import 'package:morkva_crm/core/harness/query/result_shaper.dart';

import 'query_fixture.dart';

Matcher throwsHarness(ErrorCode code, {String? path}) => throwsA(
  isA<HarnessException>()
      .having((e) => e.error.code, 'code', code)
      .having((e) => e.error.path, 'path', path ?? anything),
);

void main() {
  late QueryHarness h;

  setUp(() => h = QueryHarness(SeedWorkspace()));
  tearDown(() => h.dispose());

  List<MorkvaObject> orders() => h.derived(SeedIds.orders);

  group('cards.query', () {
    test(
      'a plain query pages the collection with the default projection',
      () async {
        final r = await h.query({'collection': 'orders'});

        expect(r['total'], 24);
        expect(r['rows'], hasLength(20));
        expect(r['nextCursor'], 'p20');
        expect(r['summary'], '24 Orders');
        expect(r['units'], {'Total': '₴'});
        // The first view sorts by Created, newest first: #1001 is today's.
        final first = (r['rows']! as List).first as Map;
        expect(first['id'], SeedCards.order(1001));
        expect(first['title'], 'Linen dress');
        final v = first['v']! as Map;
        // Title (Item) plus the first view's next 5 fields, by name.
        expect(v.keys, containsAll(['No', 'Client', 'Status', 'Total']));
        expect(v.keys, isNot(contains('Item')));
        expect(v['No'], '#1001');
        expect(v['Client'], [
          {'id': SeedCards.olena, 'title': 'Olena Bondar'},
        ]);
        expect(v['Status'], isA<String>());
        expect(r.containsKey('truncated'), isFalse);
      },
    );

    test('where filters by labels, AND-ed, and narrows the total', () async {
      final r = await h.query({
        'collection': 'Orders',
        'where': [
          {'field': 'Status', 'op': 'equals', 'value': 'packing'},
          {'field': 'Paid', 'op': 'isFalse'},
        ],
        'limit': 100,
      });

      final expected = where(
        orders(),
        (o) =>
            (o[OrderFields.status] as SingleSelectFieldValue).optionId ==
                SeedOptions.packing &&
            (o[OrderFields.paid] as BooleanFieldValue).value != true,
      );
      expect(r['total'], expected.length);
      expect(idsOf(r['rows']).toSet(), expected.toSet());
      expect(r['summary'], 'Filtered 24 → ${expected.length} Orders');
    });

    test('a @createdAt filter narrows (never widens) the result', () async {
      final r = await h.query({
        'collection': 'Orders',
        'where': [
          {'field': '@createdAt', 'op': 'onDay', 'value': 'today'},
        ],
      });

      final expected = where(orders(), (o) {
        final day = o.createdAt.toLocal();
        return DateTime(day.year, day.month, day.day) == today;
      });
      expect(expected, isNotEmpty);
      expect(expected.length, lessThan(24));
      expect(idsOf(r['rows']).toSet(), expected.toSet());
    });

    test('relative dates expand from the context day', () async {
      final r = await h.query({
        'collection': 'Orders',
        'where': [
          {'field': 'Created', 'op': 'onDay', 'relative': 'this_month'},
        ],
        'limit': 100,
      });
      final expected = where(orders(), (o) {
        final d = (o[OrderFields.created] as DateFieldValue).value!.toUtc();
        return d.year == 2026 && d.month == 11;
      });
      expect(idsOf(r['rows']).toSet(), expected.toSet());
    });

    test('filters and sorts on a calculated field derive values', () async {
      final r = await h.query({
        'collection': 'Orders',
        'where': [
          {'field': 'Total', 'op': 'greaterThan', 'value': 4000},
        ],
        'sort': {'field': 'Total', 'dir': 'desc'},
        'fields': ['Total'],
        'limit': 100,
      });

      final expected =
          orders()
              .where((o) => (numberOf(o, OrderFields.total) ?? 0) > 4000)
              .toList()
            ..sort(
              (a, b) => numberOf(
                b,
                OrderFields.total,
              )!.compareTo(numberOf(a, OrderFields.total)!),
            );
      expect(r['total'], expected.length);
      final totals = [
        for (final row in r['rows']! as List)
          ((row as Map)['v'] as Map)['Total'],
      ];
      expect(totals, [
        for (final o in expected) numberOf(o, OrderFields.total),
      ]);
    });

    test('a query that reads no calculated field skips Derivation', () async {
      await h.query({
        'collection': 'Orders',
        'where': [
          {
            'field': 'Status',
            'op': 'anyOf',
            'value': ['New'],
          },
        ],
        'fields': ['Status', 'Paid'],
      });
      final derived = await h.cache.derive(SeedIds.orders, today: today);
      expect(derived.hasDerivation, isFalse);
    });

    test('search keeps only cards whose text holds every term', () async {
      final r = await h.query({
        'collection': 'Orders',
        'search': 'linen',
        'limit': 100,
      });
      final snapshot = h.cache.current(SeedIds.orders)!;
      final hits = {for (final hit in snapshot.labels.search('linen')) hit.id};
      expect(hits, isNotEmpty);
      expect(idsOf(r['rows']).toSet(), hits);
    });

    test('a view starts from its filters and sort; sort replaces it', () async {
      final unpaid = where(
        orders(),
        (o) => (o[OrderFields.paid] as BooleanFieldValue).value != true,
      );
      final r = await h.query({
        'collection': 'Orders',
        'view': 'unpaid',
        'limit': 100,
      });
      expect(idsOf(r['rows']).toSet(), unpaid.toSet());
      // The Unpaid view's fields: Item (title), Client, Total, Created.
      final v = ((r['rows']! as List).first as Map)['v'] as Map;
      expect(v.keys.toSet(), containsAll(['Client', 'Created']));
      expect(v.containsKey('Status'), isFalse);

      final asc = await h.query({
        'collection': 'Orders',
        'view': 'Unpaid',
        'sort': {'field': 'No', 'dir': 'asc'},
        'limit': 100,
      });
      final ids = idsOf(asc['rows']);
      expect(ids, [...ids]..sort());
    });

    test('meta adds the timestamps', () async {
      final r = await h.query({
        'collection': 'Orders',
        'meta': true,
        'limit': 1,
      });
      final row = (r['rows']! as List).single as Map;
      final card = h.seed.card(SeedIds.orders, row['id'] as String);
      expect(row['createdAt'], isoInstant(card.createdAt));
      expect(row['updatedAt'], isoInstant(card.updatedAt));
    });

    test('display values: labels, days, ISO instants, raw numbers', () async {
      final r = await h.query({
        'collection': 'Orders',
        'where': [
          {'field': 'No', 'op': 'equals', 'value': '#1001'},
        ],
        'fields': ['Tags', 'Created', 'Delivery slot', 'Price', 'Paid'],
      });
      final o = h.seed.card(SeedIds.orders, SeedCards.order(1001));
      final v = ((r['rows']! as List).single as Map)['v'] as Map;
      expect(v['Tags'], ['Gift']);
      final created = (o[OrderFields.created] as DateFieldValue).value!;
      expect(v['Created'], created.toUtc().toIso8601String().substring(0, 10));
      expect(v['Price'], (o[OrderFields.price] as NumberFieldValue).value);
      expect(v['Paid'], isA<bool>());
      if (o[OrderFields.delivery] case DateFieldValue(value: final dt?)) {
        expect(v['Delivery slot'], isoInstant(dt));
      }
      expect(r['units'], {'Price': '₴'});
    });

    test('a repeated query reuses its handle', () async {
      final a = await h.query({'collection': 'Orders'});
      final b = await h.query({'collection': 'orders'});
      expect(b['handle'], a['handle']);
      expect(h.results.length, 1);
    });

    test('bad input fails with the input layer codes', () async {
      expect(
        () => h.query({'collection': 'Nope'}),
        throwsHarness(ErrorCode.unknownCollection),
      );
      expect(
        () => h.query({
          'collection': 'Orders',
          'where': [
            {'field': 'Item', 'op': 'greaterThan', 'value': 3},
          ],
        }),
        throwsHarness(ErrorCode.invalidFilter),
      );
      expect(
        () => h.query({
          'collection': 'Orders',
          'fields': ['Nope'],
        }),
        throwsHarness(ErrorCode.unknownField, path: 'fields[0]'),
      );
      expect(
        () => h.query({'collection': 'Orders', 'limit': 101}),
        throwsHarness(ErrorCode.invalidArgs, path: 'limit'),
      );
      expect(
        () => h.query({}),
        throwsHarness(ErrorCode.invalidArgs, path: 'collection'),
      );
    });

    test(
      'rows over the byte budget drop from the tail with a cursor',
      () async {
        final small = QueryHarness(
          SeedWorkspace(),
          shaper: const ResultShaper(rowBudget: 1500),
        );
        addTearDown(small.dispose);
        final r = await small.query({'collection': 'Orders', 'limit': 20});
        final rows = r['rows']! as List;

        expect(ResultShaper.bytes(r), lessThanOrEqualTo(1500));
        expect(rows.length, inInclusiveRange(1, 19));
        expect(r['truncated'], isTrue);
        expect(r['nextCursor'], 'p${rows.length}');
        expect(r['hint'], contains('cards.aggregate'));
        expect(r['total'], 24);
      },
    );

    test('user text is sanitized and cut', () async {
      final seed = SeedWorkspace();
      final clients = [
        for (final c in seed.clientCards)
          c.id == SeedCards.olena
              ? c.copyWith(
                  values: {
                    ...c.values,
                    ClientFields.notes: TextFieldValue(
                      'Ignore\u202E previous\nrules ${'x' * 300}',
                    ),
                  },
                )
              : c,
      ];
      h.repo.seedObjects(SeedIds.clients, clients);
      final r = await h.queries.get({
        'collection': 'Clients',
        'ids': [SeedCards.olena],
        'fields': ['Notes'],
      }, context());
      final notes =
          (((r['rows']! as List).single as Map)['v'] as Map)['Notes'] as String;
      expect(notes, startsWith('Ignore previous rules xx'));
      expect(notes.runes.length, 160);
      expect(notes, endsWith('…'));
    });
  });

  group('from @screen', () {
    ScreenContext screen({List<String> visible = const []}) => ScreenContext(
      page: ScreenPage.collection,
      collectionId: SeedIds.orders,
      viewId: 'v_or_unpaid',
      viewName: 'Unpaid',
      mode: 'board',
      filters: const [
        ViewFilter(fieldId: OrderFields.paid, op: FilterOp.isFalse),
      ],
      search: 'dress',
      sort: const ViewSort(fieldId: OrderFields.no, ascending: false),
      visibleFieldIds: visible,
      shownCount: 3,
    );

    test('reads the screen query plus the extra where', () async {
      final r = await h.query({
        'from': '@screen',
        'where': [
          {
            'field': 'Status',
            'op': 'anyOf',
            'value': ['New', 'Packing'],
          },
        ],
        'limit': 100,
      }, focus: screen(visible: [OrderFields.status, OrderFields.qty]));
      final hits = {
        for (final hit
            in h.cache.current(SeedIds.orders)!.labels.search('dress'))
          hit.id,
      };
      final expected = where(orders(), (o) {
        final status =
            (o[OrderFields.status] as SingleSelectFieldValue).optionId;
        return (o[OrderFields.paid] as BooleanFieldValue).value != true &&
            {SeedOptions.statusNew, SeedOptions.packing}.contains(status) &&
            hits.contains(o.id);
      });
      final ids = idsOf(r['rows']);
      expect(ids.toSet(), expected.toSet());
      expect(ids, [...ids]..sort((a, b) => b.compareTo(a)));
      // Rows show the screen's columns.
      for (final row in r['rows']! as List) {
        expect(
          ((row as Map)['v'] as Map).keys,
          everyElement(isIn(['Status', 'Qty'])),
        );
      }
    });

    test('a search arg must match on top of the screen search', () async {
      final r = await h.query({
        'from': '@screen',
        'search': 'nothing-like-this',
        'limit': 100,
      }, focus: screen());
      expect(r['total'], 0);
    });

    test(
      'nothing on screen, or a conflicting collection, is invalid_args',
      () async {
        expect(
          () => h.query({'from': '@screen'}),
          throwsHarness(ErrorCode.invalidArgs, path: 'from'),
        );
        expect(
          () => h.query({
            'from': '@screen',
            'collection': 'Clients',
          }, focus: screen()),
          throwsHarness(ErrorCode.invalidArgs, path: 'collection'),
        );
        expect(
          () => h.query({'from': '@here'}, focus: screen()),
          throwsHarness(ErrorCode.invalidArgs, path: 'from'),
        );
        expect(
          () => h.query({'from': '@screen', 'view': 'All'}, focus: screen()),
          throwsHarness(ErrorCode.invalidArgs, path: 'view'),
        );
      },
    );
  });

  group('cards.page', () {
    test('pages a handle without recomputing', () async {
      final first = await h.query({'collection': 'Orders', 'limit': 10});
      final second = await h.queries.page(
        {'handle': first['handle'], 'cursor': first['nextCursor']},
        context(),
        thread: thread,
      );
      final third = await h.queries.page(
        {'handle': first['handle'], 'cursor': second['nextCursor']},
        context(),
        thread: thread,
      );

      expect(second['handle'], first['handle']);
      expect(second['summary'], 'Orders 11–20 of 24');
      expect(third['rows'], hasLength(4));
      expect(third.containsKey('nextCursor'), isFalse);
      final all = [
        ...idsOf(first['rows']),
        ...idsOf(second['rows']),
        ...idsOf(third['rows']),
      ];
      expect(all.toSet(), hasLength(24));
      expect(second.containsKey('snapshotChanged'), isFalse);
    });

    test('re-runs the spec under a new handle when the data moved', () async {
      final first = await h.query({
        'collection': 'Orders',
        'where': [
          {
            'field': 'Status',
            'op': 'anyOf',
            'value': ['Done'],
          },
        ],
        'limit': 1,
      });
      // Someone marks every order Done.
      h.repo.seedObjects(SeedIds.orders, [
        for (final o in h.seed.orderCards)
          o.copyWith(
            values: {
              ...o.values,
              OrderFields.status: const SingleSelectFieldValue(
                SeedOptions.done,
              ),
            },
          ),
      ]);
      await pumpEventQueue();
      final next = await h.queries.page(
        {'handle': first['handle'], 'cursor': 'p1'},
        context(),
        thread: thread,
      );

      expect(next['snapshotChanged'], isTrue);
      expect(next['handle'], isNot(first['handle']));
      expect(next['total'], 24);
    });

    test('fields override the projection for one page', () async {
      final first = await h.query({'collection': 'Orders', 'limit': 5});
      final next = await h.queries.page(
        {
          'handle': first['handle'],
          'cursor': 'p5',
          'fields': ['Qty'],
        },
        context(),
        thread: thread,
      );
      for (final row in next['rows']! as List) {
        expect(((row as Map)['v'] as Map).keys, ['Qty']);
      }
    });

    test('an unknown handle, a foreign thread or a bad cursor fails', () async {
      final first = await h.query({'collection': 'Orders'});
      expect(
        () => h.queries.page(
          {'handle': 'h_404', 'cursor': 'p20'},
          context(),
          thread: thread,
        ),
        throwsHarness(ErrorCode.invalidArgs, path: 'handle'),
      );
      expect(
        () => h.queries.page(
          {'handle': first['handle'], 'cursor': 'p20'},
          context(),
          thread: 'other',
        ),
        throwsHarness(ErrorCode.invalidArgs, path: 'handle'),
      );
      expect(
        () => h.queries.page(
          {'handle': first['handle'], 'cursor': '20'},
          context(),
          thread: thread,
        ),
        throwsHarness(ErrorCode.invalidArgs, path: 'cursor'),
      );
    });
  });

  group('cards.get', () {
    test('returns rows with calculated values and the missing ids', () async {
      final r = await h.queries.get({
        'collection': 'Clients',
        'ids': [SeedCards.olena, 'b_cl_gone', SeedCards.olena],
        'fields': ['Order count', 'Paid revenue', 'Referred by'],
      }, context());

      expect(idsOf(r['rows']), [SeedCards.olena]);
      expect(r['missing'], ['b_cl_gone']);
      final olena = h
          .derived(SeedIds.clients)
          .firstWhere((c) => c.id == SeedCards.olena);
      final v = ((r['rows']! as List).single as Map)['v'] as Map;
      expect(v['Order count'], numberOf(olena, ClientFields.orderCount));
      expect(r['summary'], '1 Clients, 1 not found');
    });

    test('@card names the open card', () async {
      final r = await h.queries.get(
        {
          'collection': 'Orders',
          'ids': ['@card'],
        },
        context(
          focus: ScreenContext(
            page: ScreenPage.card,
            collectionId: SeedIds.orders,
            openCardId: SeedCards.order(1003),
          ),
        ),
      );
      expect(idsOf(r['rows']), [SeedCards.order(1003)]);
    });
  });

  group('cards.find', () {
    test('searches the named collections', () async {
      final r = await h.queries.find({
        'text': 'linen',
        'collections': ['Fabrics', 'Orders'],
        'limit': 20,
      }, context());
      final hits = (r['hits']! as List).cast<Map>();
      expect(hits, isNotEmpty);
      expect(hits.first['collection'], SeedIds.fabrics);
      expect(hits.first['matchedField'], isA<String>());
      expect(r['searched'], [SeedIds.fabrics, SeedIds.orders]);
    });

    test(
      'without collections it searches the screen and held ones only',
      () async {
        final r = await h.queries.find(
          {'text': 'linen'},
          context(
            focus: ScreenContext(
              page: ScreenPage.collection,
              collectionId: SeedIds.fabrics,
            ),
          ),
        );
        expect(r['searched'], [SeedIds.fabrics]);
        expect(h.repo.watchObjectsCalls.containsKey(SeedIds.clients), isFalse);
      },
    );

    test('nothing to search says so', () async {
      final r = await h.queries.find({'text': 'linen'}, context());
      expect(r['hits'], isEmpty);
      expect(r['hint'], contains('collections'));
    });
  });

  group('grants', () {
    final ordersOnly = Grants(Capability.values, collections: [SeedIds.orders]);

    test(
      'references into an ungranted collection show ids, no titles',
      () async {
        final r = await h.query({
          'collection': 'Orders',
          'fields': ['Client'],
          'limit': 1,
        }, grants: ordersOnly);
        final v = ((r['rows']! as List).single as Map)['v'] as Map;
        expect(v['Client'], [
          {'id': SeedCards.olena},
        ]);
      },
    );

    test('lookups into an ungranted collection are not readable', () async {
      final r = await h.query({
        'collection': 'Orders',
        'view': 'All',
      }, grants: ordersOnly);
      expect(r['rows'], isNotEmpty);
      expect(
        () => h.query({
          'collection': 'Orders',
          'fields': ['Client city'],
        }, grants: ordersOnly),
        throwsHarness(ErrorCode.notPermitted, path: 'fields[0]'),
      );
      expect(
        () => h.query({
          'collection': 'Orders',
          'where': [
            {'field': 'Fabric price', 'op': 'greaterThan', 'value': 1},
          ],
        }, grants: ordersOnly),
        throwsHarness(ErrorCode.notPermitted),
      );
    });
  });

  group('QuerySpec', () {
    test('round-trips through JSON', () {
      const spec = QuerySpec(
        collectionId: SeedIds.orders,
        filters: [
          ViewFilter(
            fieldId: OrderFields.status,
            op: FilterOp.anyOf,
            operand: [SeedOptions.done],
          ),
          ViewFilter(
            fieldId: '@createdAt',
            op: FilterOp.after,
            operand: '2026-11-01',
          ),
        ],
        search: 'linen',
        sort: ViewSort(fieldId: OrderFields.total, ascending: false),
        orderViewId: 'all',
        fieldIds: [OrderFields.total],
        meta: true,
        limit: 7,
      );
      final json =
          jsonDecode(jsonEncode(spec.toJson())) as Map<String, Object?>;
      expect(QuerySpec.fromJson(json).toJson(), spec.toJson());
    });

    test('a stored filter on a deleted field fails instead of widening', () {
      expect(
        () => h.queries.run(
          const QuerySpec(
            collectionId: SeedIds.orders,
            filters: [ViewFilter(fieldId: 'f_gone', op: FilterOp.isNotEmpty)],
          ),
          context(),
        ),
        throwsHarness(ErrorCode.invalidFilter),
      );
    });
  });
}
