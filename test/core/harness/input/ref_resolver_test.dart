import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/harness/harness.dart';
import 'package:morkva_crm/core/harness/input/ref_resolver.dart';

import '../fixtures/seed_workspace.dart';
import 'input_fixture.dart';

void main() {
  group('collections', () {
    test('resolve by id or by name, case-insensitively', () {
      final refs = resolver();
      expect(refs.collection(SeedIds.orders).name, 'Orders');
      expect(refs.collection('  orders ').id, SeedIds.orders);
    });

    test('a typo gets unknown_collection with a suggestion', () {
      final error = errorOf(() => resolver().collection('Ordrs'));
      expect(error.code, ErrorCode.unknownCollection);
      expect(error.message, contains('Did you mean "Orders"?'));
      expect(error.candidates, containsAll(['Orders', 'Clients', 'Fabrics']));
      expect(error.path, 'collection');
    });

    test('collections outside the grants are invisible', () {
      final refs = resolver(
        grants: Grants(Capability.values, collections: [SeedIds.orders]),
      );
      final error = errorOf(() => refs.collection('Clients'));
      expect(error.code, ErrorCode.unknownCollection);
      expect(error.candidates, ['Orders']);
      expect(refs.visibleCollections.map((c) => c.id), [SeedIds.orders]);
    });

    test('reaching an ungranted collection by id is not_permitted', () {
      final refs = resolver(
        grants: Grants(Capability.values, collections: [SeedIds.orders]),
      );
      expect(
        () => refs.collectionById(SeedIds.clients),
        throwsHarness(ErrorCode.notPermitted),
      );
      expect(
        () => refs.collectionById('c_gone'),
        throwsHarness(ErrorCode.unknownCollection),
      );
    });
  });

  group('fields, views and options', () {
    test('fields resolve by id, name and the timestamp refs', () {
      final refs = resolver();
      expect(refs.field(orders, 'total').id, OrderFields.total);
      expect(refs.field(orders, OrderFields.paid).name, 'Paid');
      expect(refs.fieldIdOrMeta(orders, '@createdAt'), '@createdAt');
      expect(refs.fieldIdOrMeta(orders, 'Delivery slot'), OrderFields.delivery);
    });

    test('an unknown field names the nearest ones', () {
      final error = errorOf(
        () => resolver().field(orders, 'Totl', path: 'where[0].field'),
      );
      expect(error.code, ErrorCode.unknownField);
      expect(error.message, 'No field "Totl" in Orders. Did you mean "Total"?');
      expect(error.candidates, contains('Total'));
      expect(error.candidates!.length, lessThanOrEqualTo(3));
      expect(error.path, 'where[0].field');
      expect(error.hint, contains('collections.get'));
    });

    test('views resolve by name; a miss lists them all', () {
      final refs = resolver();
      expect(refs.view(orders, 'unpaid').id, 'v_or_unpaid');
      final error = errorOf(() => refs.view(orders, 'Late'));
      expect(error.code, ErrorCode.unknownView);
      expect(error.candidates, ['All', 'Unpaid']);
    });

    test('options resolve by label or id; a miss lists every label', () {
      final refs = resolver();
      final status = refs.field(orders, 'Status') as dynamic;
      expect(
        refs.option('Status', status.options, ' PACKING ').id,
        SeedOptions.packing,
      );
      expect(
        refs.option('Status', status.options, SeedOptions.done).label,
        'Done',
      );
      final error = errorOf(
        () => refs.option('Status', status.options, 'Lost'),
      );
      expect(error.code, ErrorCode.unknownOption);
      expect(error.candidates, ['New', 'Packing', 'Shipped', 'Done']);
      expect(error.hint, contains('addOptions'));
    });
  });

  group('cards', () {
    test('resolve by id, title or auto-number as shown', () {
      final refs = resolver();
      expect(refs.card(clients, SeedCards.olena), SeedCards.olena);
      expect(refs.card(clients, 'olena bondar'), SeedCards.olena);
      expect(refs.card(orders, '#1005'), SeedCards.order(1005));
    });

    test('two cards with one title are an ambiguous_reference', () {
      final error = errorOf(() => resolver().card(clients, 'Anna Koval'));
      expect(error.code, ErrorCode.ambiguousReference);
      expect(error.candidates, [
        {'id': SeedCards.annaKyiv, 'title': 'Anna Koval'},
        {'id': SeedCards.annaOdesa, 'title': 'Anna Koval'},
      ]);
    });

    test('a miss suggests the nearest titles with their ids', () {
      final error = errorOf(() => resolver().card(clients, 'Olena Bondr'));
      expect(error.code, ErrorCode.unknownObject);
      expect(
        error.candidates,
        contains(equals({'id': SeedCards.olena, 'title': 'Olena Bondar'})),
      );
    });

    test('several refs keep their order and drop repeats', () {
      expect(
        resolver().cards(clients, [
          'Taras Melnyk',
          SeedCards.olena,
          'taras melnyk',
        ]),
        [SeedCards.taras, SeedCards.olena],
      );
    });

    test('turn-local aliases resolve to their card', () {
      final refs = resolver(aliases: {'@c1': SeedCards.ivan});
      expect(refs.card(clients, '@c1'), SeedCards.ivan);
      expect(
        () => refs.card(clients, '@c2'),
        throwsHarness(ErrorCode.unknownObject),
      );
    });
  });

  group('screen refs', () {
    ScreenContext onOrders({String? open, List<String> selected = const []}) =>
        ScreenContext(
          page: ScreenPage.collection,
          collectionId: SeedIds.orders,
          viewId: 'v_or_unpaid',
          openCardId: open,
          selectedIds: selected,
        );

    test('@card is the open card', () {
      final refs = resolver(focus: onOrders(open: SeedCards.order(1003)));
      expect(refs.card(orders, '@card'), SeedCards.order(1003));
    });

    test('@card with nothing on screen or no open card is invalid_args', () {
      expect(
        () => resolver().card(orders, '@card'),
        throwsHarness(
          ErrorCode.invalidArgs,
          message: 'Nothing is on screen to refer to.',
        ),
      );
      expect(
        () => resolver(focus: onOrders()).card(orders, '@card'),
        throwsHarness(ErrorCode.invalidArgs, message: 'No card is open'),
      );
    });

    test('@card in another collection than the screen is refused', () {
      final refs = resolver(focus: onOrders(open: SeedCards.order(1003)));
      expect(
        () => refs.card(clients, '@card', path: 'values.Client'),
        throwsHarness(
          ErrorCode.invalidArgs,
          path: 'values.Client',
          message: '@card is in Orders, not in Clients.',
        ),
      );
    });

    test('a deleted open card is unknown_object', () {
      final refs = resolver(focus: onOrders(open: 'b_or_gone'));
      expect(
        () => refs.card(orders, '@card'),
        throwsHarness(ErrorCode.unknownObject),
      );
    });

    test('@selected expands to every selected card', () {
      final selected = [SeedCards.order(1002), SeedCards.order(1004)];
      final refs = resolver(focus: onOrders(selected: selected));
      expect(refs.cards(orders, ['@selected', '#1001']), [
        ...selected,
        SeedCards.order(1001),
      ]);
      expect(
        () => refs.card(orders, '@selected'),
        throwsHarness(ErrorCode.invalidArgs, message: 'means 2 cards'),
      );
      expect(
        () => resolver(focus: onOrders()).cards(orders, ['@selected']),
        throwsHarness(ErrorCode.invalidArgs, message: 'Nothing is selected'),
      );
    });

    test('screen() needs a collection on screen', () {
      expect(
        () => resolver(focus: ScreenContext(page: ScreenPage.home)).screen(),
        throwsHarness(ErrorCode.invalidArgs, path: 'from'),
      );
      final refs = resolver(focus: onOrders());
      expect(refs.screenCollection().id, SeedIds.orders);
    });
  });

  test('nearest ranks prefix and substring hits before edit distance', () {
    // "Plot" is 2 edits from "tot", "Notes" 3.
    expect(nearest('tot', ['Notes', 'Plot', 'Qty', 'Total'], 3), [
      'Total',
      'Plot',
      'Notes',
    ]);
    expect(nearest('zzzz', ['Total', 'Qty'], 3), isEmpty);
  });
}
