import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/core/harness/harness.dart';
import 'package:morkva_crm/core/harness/input/filter_compiler.dart';

import '../fixtures/seed_workspace.dart';
import 'input_fixture.dart';

void main() {
  FilterCompiler compiler({ScreenContext? focus, DateTime? on}) =>
      FilterCompiler(resolver(focus: focus, on: on));

  List<ViewFilter> compile(
    List<Map<String, Object?>> where, {
    Collection? collection,
    DateTime? on,
    ScreenContext? focus,
  }) => compiler(focus: focus, on: on).compile(collection ?? orders, where);

  /// The derived orders that pass every one of [filters].
  List<MorkvaObject> run(List<ViewFilter> filters) {
    final derived = Derivation(
      collections: workspace.collections,
      objects: seed.objects,
      today: seedToday,
    ).objectsOf(SeedIds.orders);
    return [
      for (final o in derived)
        if (filters.every((f) {
          final field = filterFieldOf(orders, f.fieldId)!;
          final value = switch (f.fieldId) {
            kCreatedAtRef => DateFieldValue(o.createdAt),
            kUpdatedAtRef => DateFieldValue(o.updatedAt),
            _ => o[f.fieldId] ?? field.emptyValue(),
          };
          return matchesFilter(f, field, value);
        }))
          o,
    ];
  }

  group('operands', () {
    test('select labels become option ids', () {
      expect(
        compile([
          {
            'field': 'status',
            'op': 'anyOf',
            'value': ['Packing', 'new'],
          },
        ]),
        [
          const ViewFilter(
            fieldId: OrderFields.status,
            op: FilterOp.anyOf,
            operand: [SeedOptions.packing, SeedOptions.statusNew],
          ),
        ],
      );
    });

    test('equals on a select means anyOf; on a boolean isTrue/isFalse', () {
      expect(
        compile([
          {'field': 'Status', 'op': 'equals', 'value': 'Done'},
          {'field': 'Paid', 'op': 'equals', 'value': false},
          {'field': 'Paid', 'op': 'notEquals', 'value': 'no'},
        ]),
        [
          const ViewFilter(
            fieldId: OrderFields.status,
            op: FilterOp.anyOf,
            operand: [SeedOptions.done],
          ),
          const ViewFilter(fieldId: OrderFields.paid, op: FilterOp.isFalse),
          const ViewFilter(fieldId: OrderFields.paid, op: FilterOp.isTrue),
        ],
      );
    });

    test('numbers accept numeric strings; auto-numbers their prefix', () {
      expect(
        compile([
          {'field': 'Price', 'op': 'greaterThan', 'value': '2000'},
          {'field': 'No', 'op': 'equals', 'value': '#1005'},
        ]),
        [
          const ViewFilter(
            fieldId: OrderFields.price,
            op: FilterOp.greaterThan,
            operand: 2000,
          ),
          const ViewFilter(
            fieldId: OrderFields.no,
            op: FilterOp.equals,
            operand: 1005,
          ),
        ],
      );
    });

    test('references take titles, ids and @card', () {
      final onOlena = ScreenContext(
        page: ScreenPage.card,
        collectionId: SeedIds.clients,
        openCardId: SeedCards.olena,
      );
      final filters = compile([
        {
          'field': 'Client',
          'op': 'anyOf',
          'value': ['@card', 'Taras Melnyk'],
        },
      ], focus: onOlena);
      expect(filters.single.operand, [SeedCards.olena, SeedCards.taras]);
      expect(run(filters), isNotEmpty);
      expect(
        run(filters).every((o) {
          final ids = (o[OrderFields.client]! as ReferenceFieldValue).objectIds;
          return ids.contains(SeedCards.olena) || ids.contains(SeedCards.taras);
        }),
        isTrue,
      );
    });

    test('calculated fields filter as their output type', () {
      final filters = compile([
        {'field': 'Total', 'op': 'greaterThan', 'value': 5000},
        {'field': 'Client city', 'op': 'anyOf', 'value': 'Kyiv'},
      ]);
      expect(filters[1].operand, [SeedOptions.kyiv]);
      final hits = run(filters);
      expect(hits, isNotEmpty);
      for (final o in hits) {
        expect(
          (o[OrderFields.total]! as CalculatedFieldValue).cached,
          greaterThan(5000),
        );
      }
    });
  });

  group('invalid filters', () {
    test('greaterThan on text lists the ops that apply', () {
      final error = errorOf(
        () => compile([
          {'field': 'Item', 'op': 'greaterThan', 'value': 'a'},
        ]),
      );
      expect(error.code, ErrorCode.invalidFilter);
      expect(error.path, 'where[0].op');
      expect(error.candidates, [
        'contains',
        'notContains',
        'equals',
        'isEmpty',
        'isNotEmpty',
      ]);
    });

    test('a blank or missing operand is refused, never widened', () {
      for (final value in ['', '   ', null]) {
        expect(
          () => compile([
            {'field': 'Item', 'op': 'contains', 'value': ?value},
          ]),
          throwsHarness(ErrorCode.invalidFilter, path: 'where[0].value'),
        );
      }
      expect(
        () => compile([
          {'field': 'Status', 'op': 'anyOf', 'value': <String>[]},
        ]),
        throwsHarness(ErrorCode.invalidFilter),
      );
    });

    test('wrong-typed operands are invalid_filter', () {
      expect(
        () => compile([
          {'field': 'Price', 'op': 'lessThan', 'value': 'cheap'},
        ]),
        throwsHarness(ErrorCode.invalidFilter, message: 'a number'),
      );
      expect(
        () => compile([
          {'field': 'Created', 'op': 'after', 'value': 'last spring'},
        ]),
        throwsHarness(ErrorCode.invalidFilter, message: 'YYYY-MM-DD'),
      );
    });

    test('every bad filter is reported at once', () {
      final error = errorOf(
        () => compile([
          {'field': 'Totl', 'op': 'greaterThan', 'value': 1},
          {'field': 'Status', 'op': 'anyOf', 'value': 'Lost'},
          {'field': 'Paid', 'op': 'isTrue'},
        ]),
      );
      expect(error.details!.map((d) => (d.path, d.code)), [
        ('where[0].field', ErrorCode.unknownField),
        ('where[1].value', ErrorCode.unknownOption),
      ]);
    });
  });

  group('dates', () {
    test('a day word keeps its op and counts from today', () {
      expect(
        compile([
          {'field': 'Created', 'op': 'onDay', 'value': 'yesterday'},
          {'field': 'Created', 'op': 'before', 'relative': 'today'},
        ]),
        [
          const ViewFilter(
            fieldId: OrderFields.created,
            op: FilterOp.onDay,
            operand: '2026-11-09',
          ),
          const ViewFilter(
            fieldId: OrderFields.created,
            op: FilterOp.before,
            operand: '2026-11-10',
          ),
        ],
      );
    });

    List<Object?> range(String relative, {int? n, DateTime? on}) => [
      for (final f in compile([
        {'field': 'Created', 'op': 'onDay', 'relative': relative, 'n': ?n},
      ], on: on))
        (f.op.name, f.operand),
    ];

    test('ranges become an exclusive after/before pair', () {
      // 2026-11-10 is a Tuesday.
      expect(range('this_month'), [
        ('after', '2026-10-31'),
        ('before', '2026-12-01'),
      ]);
      expect(range('this_week'), [
        ('after', '2026-11-08'),
        ('before', '2026-11-16'),
      ]);
      expect(range('last_week'), [
        ('after', '2026-11-01'),
        ('before', '2026-11-09'),
      ]);
      expect(range('last_n_days', n: 7), [
        ('after', '2026-11-03'),
        ('before', '2026-11-11'),
      ]);
      expect(range('next_n_days', n: 3), [
        ('after', '2026-11-09'),
        ('before', '2026-11-13'),
      ]);
      expect(range('this_year'), [
        ('after', '2025-12-31'),
        ('before', '2027-01-01'),
      ]);
    });

    test('a different today moves the ranges', () {
      final jan = DateTime(2026, 1, 15);
      expect(range('last_month', on: jan), [
        ('after', '2025-11-30'),
        ('before', '2026-01-01'),
      ]);
      expect(range('this_month', on: DateTime(2028, 2, 10)), [
        ('after', '2028-01-31'),
        ('before', '2028-03-01'),
      ]);
    });

    test('before / after a range mean before its start, after its end', () {
      expect(
        compile([
          {'field': 'Created', 'op': 'before', 'relative': 'this_month'},
          {'field': 'Created', 'op': 'after', 'relative': 'last_month'},
        ]).map((f) => f.operand),
        ['2026-11-01', '2026-10-31'],
      );
    });

    test('this_month matches exactly the orders created this month', () {
      final filters = compile([
        {'field': 'Created', 'op': 'onDay', 'relative': 'this_month'},
      ]);
      final expected = seed.orderCards.where((o) {
        final d = (o[OrderFields.created]! as DateFieldValue).value;
        return d != null && d.year == 2026 && d.month == 11;
      });
      expect(expected, isNotEmpty);
      expect(run(filters).map((o) => o.id), expected.map((o) => o.id));
    });

    test('relative misuse is refused', () {
      expect(
        () => compile([
          {'field': 'Created', 'op': 'isEmpty', 'relative': 'this_month'},
        ]),
        throwsHarness(ErrorCode.invalidFilter, path: 'where[0].op'),
      );
      expect(
        () => compile([
          {
            'field': 'Created',
            'op': 'onDay',
            'relative': 'today',
            'value': '2026-11-01',
          },
        ]),
        throwsHarness(ErrorCode.invalidArgs, message: 'not both'),
      );
      expect(
        () => compile([
          {'field': 'Created', 'op': 'onDay', 'relative': 'last_n_days'},
        ]),
        throwsHarness(ErrorCode.invalidArgs, path: 'where[0].n'),
      );
      expect(
        () => compile([
          {'field': 'Created', 'op': 'onDay', 'relative': 'today', 'n': 2},
        ]),
        throwsHarness(ErrorCode.invalidArgs, path: 'where[0].n'),
      );
      expect(
        () => compile([
          {'field': 'Item', 'op': 'contains', 'relative': 'today'},
        ]),
        throwsHarness(ErrorCode.invalidFilter, path: 'where[0].relative'),
      );
    });

    test('@createdAt takes day ops and relative dates, never isEmpty', () {
      final filters = compile([
        {
          'field': '@createdAt',
          'op': 'onDay',
          'relative': 'last_n_days',
          'n': 3,
        },
      ]);
      expect(filters.first.fieldId, kCreatedAtRef);
      final hits = run(filters);
      expect(hits, isNotEmpty);
      for (final o in hits) {
        final day = DateTime(
          o.createdAt.toLocal().year,
          o.createdAt.toLocal().month,
          o.createdAt.toLocal().day,
        );
        expect(day.isAfter(DateTime(2026, 11, 7)), isTrue);
      }
      expect(
        () => compile([
          {'field': '@updatedAt', 'op': 'isEmpty'},
        ]),
        throwsHarness(ErrorCode.invalidFilter),
      );
    });
  });

  test('compileSort resolves the field and direction', () {
    final c = compiler();
    expect(
      c.compileSort(orders, {'field': 'total', 'dir': 'desc'}),
      const ViewSort(fieldId: OrderFields.total, ascending: false),
    );
    expect(
      c.compileSort(orders, {'field': '@updatedAt', 'dir': 'asc'}),
      const ViewSort(fieldId: kUpdatedAtRef),
    );
  });

  group('filterProblem', () {
    final paid = orders.fieldById(OrderFields.paid)!;
    final item = orders.fieldById(OrderFields.item)!;

    test('is null for a filter that really filters', () {
      expect(
        filterProblem(
          paid,
          const ViewFilter(fieldId: OrderFields.paid, op: FilterOp.isFalse),
        ),
        isNull,
      );
    });

    test('names what matchesFilter would ignore', () {
      expect(
        filterProblem(
          item,
          const ViewFilter(fieldId: OrderFields.item, op: FilterOp.contains),
        ),
        contains('needs a value'),
      );
      expect(
        filterProblem(
          item,
          const ViewFilter(
            fieldId: OrderFields.item,
            op: FilterOp.greaterThan,
            operand: 'a',
          ),
        ),
        contains('does not apply'),
      );
    });
  });

  group('screenQuery', () {
    ScreenContext unpaid({List<ViewFilter>? filters}) => ScreenContext(
      page: ScreenPage.collection,
      collectionId: SeedIds.orders,
      viewId: 'v_or_unpaid',
      viewName: 'Unpaid',
      mode: 'board',
      filters:
          filters ??
          const [
            ViewFilter(fieldId: OrderFields.paid, op: FilterOp.isFalse),
            // Half-typed on screen: the page ignores it, so does @screen.
            ViewFilter(
              fieldId: OrderFields.status,
              op: FilterOp.anyOf,
              operand: <String>[],
            ),
          ],
      search: 'linen',
      sort: const ViewSort(fieldId: OrderFields.total, ascending: false),
      shownCount: 6,
    );

    test('is the screen filters, search and sort plus the extra where', () {
      final q = compiler(focus: unpaid()).screenQuery(
        where: [
          {'field': 'Status', 'op': 'anyOf', 'value': 'Packing'},
        ],
      );
      expect(q.collection.id, SeedIds.orders);
      expect(q.view?.name, 'Unpaid');
      expect(q.search, 'linen');
      expect(
        q.sort,
        const ViewSort(fieldId: OrderFields.total, ascending: false),
      );
      expect(q.filters, [
        const ViewFilter(fieldId: OrderFields.paid, op: FilterOp.isFalse),
        const ViewFilter(
          fieldId: OrderFields.status,
          op: FilterOp.anyOf,
          operand: [SeedOptions.packing],
        ),
      ]);
      expect(q.screen.shownCount, 6);
    });

    test('nothing on screen is invalid_args', () {
      expect(
        () => compiler().screenQuery(),
        throwsHarness(
          ErrorCode.invalidArgs,
          path: 'from',
          message: 'Nothing is on screen to refer to.',
        ),
      );
      expect(
        () => compiler(
          focus: ScreenContext(page: ScreenPage.settings),
        ).screenQuery(path: 'target.screen'),
        throwsHarness(ErrorCode.invalidArgs, path: 'target.screen'),
      );
    });

    test('a screen filter on a deleted field fails instead of widening', () {
      final stale = unpaid(
        filters: const [ViewFilter(fieldId: 'f_gone', op: FilterOp.isNotEmpty)],
      );
      expect(
        () => compiler(focus: stale).screenQuery(),
        throwsHarness(ErrorCode.invalidFilter),
      );
    });

    test('an ungranted screen collection is not_permitted', () {
      final refs = resolver(
        focus: unpaid(),
        grants: Grants(Capability.values, collections: [SeedIds.clients]),
      );
      expect(
        () => FilterCompiler(refs).screenQuery(),
        throwsHarness(ErrorCode.notPermitted),
      );
    });
  });
}
