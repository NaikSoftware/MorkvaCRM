import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/harness/harness.dart';

import 'ops_fixture.dart';

void main() {
  late OpsHarness h;

  setUp(() => h = OpsHarness());
  tearDown(() => h.dispose());

  group('ui.open', () {
    test('a collection chip carries its id and name', () async {
      final r = await h.ok('ui.open', {'collection': 'orders'});

      expect(r, {
        'shown': true,
        'collectionId': SeedIds.orders,
        'label': 'Orders',
        'summary': 'Linked Orders',
      });
    });

    test('a view chip resolves the view by name', () async {
      final r = await h.ok('ui.open', {
        'collection': 'Orders',
        'view': 'unpaid',
      });

      expect(r['viewId'], 'v_or_unpaid');
      expect(r['label'], 'Orders › Unpaid');
      expect(r.containsKey('cardId'), isFalse);
    });

    test('a card chip resolves a title or @card and is labelled with the '
        'card title', () async {
      final byTitle = await h.ok('ui.open', {
        'collection': 'Clients',
        'card': 'olena bondar',
      });
      expect(byTitle['cardId'], SeedCards.olena);
      expect(byTitle['label'], 'Olena Bondar');

      final open = await h.ok('ui.open', {
        'collection': 'Orders',
        'card': '@card',
      }, focus: unpaidDresses(openCardId: SeedCards.order(1001)));
      expect(open['cardId'], SeedCards.order(1001));
      expect(open['label'], 'Linen dress');
    });

    test('valid filters are echoed for the deep link', () async {
      final where = [
        {'field': 'Status', 'op': 'equals', 'value': 'Packing'},
        {'field': 'Created', 'op': 'after', 'relative': 'this_month'},
      ];

      final r = await h.ok('ui.open', {'collection': 'Orders', 'where': where});

      expect(r['where'], where);
      expect(r['label'], 'Orders (filtered)');
    });

    test('bad refs and filters fail before a chip is posted', () async {
      final view = await h.fails('ui.open', {
        'collection': 'Orders',
        'view': 'Paid',
      });
      expect(view.code, ErrorCode.unknownView);
      expect(view.candidates, ['All', 'Unpaid']);

      final card = await h.fails('ui.open', {
        'collection': 'Orders',
        'card': 'No such order',
      });
      expect(card.code, ErrorCode.unknownObject);

      final filter = await h.fails('ui.open', {
        'collection': 'Orders',
        'where': [
          {'field': 'Item', 'op': 'greaterThan', 'value': 3},
        ],
      });
      expect(filter.code, ErrorCode.invalidFilter);

      final collection = await h.fails('ui.open', {'collection': 'Invoices'});
      expect(collection.code, ErrorCode.unknownCollection);
    });

    test('@card with nothing open, and a missing ui:navigate grant, are '
        'refused', () async {
      final noCard = await h.fails('ui.open', {
        'collection': 'Orders',
        'card': '@card',
      });
      expect(noCard.code, ErrorCode.invalidArgs);

      final denied = await h.fails('ui.open', {
        'collection': 'Orders',
      }, grants: Grants([Capability.dataRead, Capability.schemaRead]));
      expect(denied.code, ErrorCode.notPermitted);
    });
  });
}
