import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/core/harness/input/ref_resolver.dart';
import 'package:morkva_crm/features/views/view_link.dart';

import 'views_fixtures.dart';

void main() {
  final workspace = StaticWorkspace(
    [deals, companies],
    {
      'deals': sampleDeals(),
      'companies': [
        company('k1', 'Zeta Corp', 0),
        company('k2', 'Alpha Ltd', 1),
      ],
    },
  );
  final today = DateTime(2026, 11, 10);

  List<ViewFilter>? parse(String param) => parseLinkFilter(
    param,
    collection: deals,
    workspace: workspace,
    today: today,
  );

  group('collectionLink', () {
    test('puts only the given parameters in the query', () {
      expect(collectionLink('deals'), '/collections/deals');
      expect(
        collectionLink('deals', view: 'board', card: 'd1'),
        '/collections/deals?view=board&card=d1',
      );
    });

    test('a filter round-trips through the link', () {
      final link = Uri.parse(
        collectionLink(
          'deals',
          where: [
            {'field': 'Stage', 'op': 'anyOf', 'value': 'Won'},
          ],
        ),
      );
      final filter = link.queryParameters['filter']!;
      expect(filter, isNot(contains('=')));
      expect(parse(filter), [
        const ViewFilter(
          fieldId: 'stage',
          op: FilterOp.anyOf,
          operand: ['won'],
        ),
      ]);
    });
  });

  group('parseLinkFilter', () {
    test('compiles names, labels and card titles to ids', () {
      final filters = parse(
        encodeLinkFilter([
          {'field': 'Amount', 'op': 'greaterThan', 'value': 100},
          {'field': 'Company', 'op': 'equals', 'value': 'Zeta Corp'},
        ]),
      );
      expect(filters, [
        const ViewFilter(
          fieldId: 'amount',
          op: FilterOp.greaterThan,
          operand: 100,
        ),
        // `equals` on a reference reads as `anyOf`.
        const ViewFilter(
          fieldId: 'company',
          op: FilterOp.anyOf,
          operand: ['k1'],
        ),
      ]);
    });

    test('a relative date expands from today', () {
      final filters = parse(
        encodeLinkFilter([
          {'field': 'Due', 'op': 'before', 'value': 'today'},
        ]),
      );
      expect(filters, [
        const ViewFilter(
          fieldId: 'due',
          op: FilterOp.before,
          operand: '2026-11-10',
        ),
      ]);
    });

    test('rejects what is not a valid filter list', () {
      expect(parse(''), isNull);
      expect(parse('not base64 !!'), isNull);
      expect(parse(base64Url.encode(utf8.encode('{"a":1}'))), isNull);
      expect(parse(encodeLinkFilter([])), isNull);
      // An unknown field, an op the field doesn't take, a missing value.
      expect(
        parse(
          encodeLinkFilter([
            {'field': 'Nope', 'op': 'isEmpty'},
          ]),
        ),
        isNull,
      );
      expect(
        parse(
          encodeLinkFilter([
            {'field': 'Amount', 'op': 'contains', 'value': 'x'},
          ]),
        ),
        isNull,
      );
      expect(
        parse(
          encodeLinkFilter([
            {'field': 'Name', 'op': 'contains'},
          ]),
        ),
        isNull,
      );
    });

    test('one bad filter fails the whole link', () {
      expect(
        parse(
          encodeLinkFilter([
            {'field': 'Stage', 'op': 'anyOf', 'value': 'Won'},
            {'field': 'Stage', 'op': 'anyOf', 'value': 'Nope'},
          ]),
        ),
        isNull,
      );
    });

    test('rejects card timestamps, which views cannot filter on', () {
      expect(
        parse(
          encodeLinkFilter([
            {'field': '@createdAt', 'op': 'after', 'value': '2026-01-01'},
          ]),
        ),
        isNull,
      );
    });

    test('rejects a parameter over 4 KB', () {
      final big = encodeLinkFilter([
        for (var i = 0; i < 80; i++)
          {'field': 'Name', 'op': 'contains', 'value': 'x' * 40},
      ]);
      expect(big.length, greaterThan(maxLinkFilterBytes * 4 ~/ 3));
      expect(parse(big), isNull);
    });
  });
}
