import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/automation/card_shaper.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/core/harness/harness.dart';

import '../harness/query/query_fixture.dart';

void main() {
  late QueryHarness q;
  late CardShaper shaper;
  final order = SeedCards.order(1001);

  setUp(() {
    q = QueryHarness(SeedWorkspace());
    shaper = CardShaper(q.cache);
  });
  tearDown(() => q.dispose());

  Grants grants({bool read = true, Iterable<String>? collections}) => Grants([
    Capability.schemaRead,
    if (read) Capability.dataRead,
    Capability.dataWrite,
  ], collections: collections);

  test('a card is keyed by field id with names, calculated values and '
      'reference titles under full grants', () async {
    final card = (await shaper.current(
      SeedIds.orders,
      order,
      grants(),
      today: today,
    ))!;
    expect(card['id'], order);
    expect(card['collectionId'], SeedIds.orders);
    final values = card['values']! as Map<String, Object?>;
    final fields = card['fields']! as Map<String, Object?>;
    expect(fields[OrderFields.item], 'Item');
    expect(values[OrderFields.item], card['title']);
    expect(values, contains(OrderFields.total));
    expect(values, contains(OrderFields.clientCity));
    expect(values[OrderFields.client], [
      {'id': SeedCards.olena, 'title': 'Olena Bondar'},
    ]);
    // Values JSON-safe (dates as strings).
    expect(values[OrderFields.created], isA<String>());
  });

  test(
    'reference titles show for a target that is no calculation source',
    () async {
      final fabric = q.seed.fabricCards.firstWhere(
        (f) =>
            f[FabricFields.supplier] is ReferenceFieldValue &&
            (f[FabricFields.supplier]! as ReferenceFieldValue)
                .objectIds
                .isNotEmpty,
      );
      expect(q.cache.current(SeedIds.clients), isNull, reason: 'not held yet');
      final card = (await shaper.current(
        SeedIds.fabrics,
        fabric.id,
        grants(),
        today: today,
      ))!;
      final supplier =
          (card['values']! as Map)[FabricFields.supplier]! as List<Object?>;
      expect((supplier.single! as Map)['title'], isA<String>());
    },
  );

  test('calculated values reading an ungranted collection and reference '
      'titles outside the grants are withheld', () async {
    final card = (await shaper.current(
      SeedIds.orders,
      order,
      grants(collections: [SeedIds.orders]),
      today: today,
    ))!;
    final values = card['values']! as Map<String, Object?>;
    final fields = card['fields']! as Map<String, Object?>;
    for (final hidden in [
      OrderFields.clientCity,
      OrderFields.fabricPrice,
      OrderFields.margin,
    ]) {
      expect(values, isNot(contains(hidden)), reason: hidden);
      expect(fields, isNot(contains(hidden)), reason: hidden);
    }
    expect(values, contains(OrderFields.total), reason: 'reads only Orders');
    expect(values[OrderFields.client], [
      {'id': SeedCards.olena},
    ]);
  });

  test(
    'without data:read ctx.card is a CardRef and the images are null',
    () async {
      final noRead = grants(read: false);
      expect(
        await shaper.current(SeedIds.orders, order, noRead, today: today),
        {'id': order, 'collectionId': SeedIds.orders},
      );
      final orders = q.collection(SeedIds.orders);
      final stored = q.seed.orderCards.first;
      expect(await shaper.card(orders, stored, noRead), {
        'id': stored.id,
        'collectionId': SeedIds.orders,
      });
      expect(await shaper.image(orders, stored, noRead), isNull);
      expect(await shaper.image(orders, stored, grants()), isNotNull);
    },
  );

  test('a collection outside the grants, a missing card or collection and a '
      'null image give null', () async {
    expect(
      await shaper.current(
        SeedIds.orders,
        order,
        grants(collections: [SeedIds.clients]),
        today: today,
      ),
      isNull,
    );
    expect(
      await shaper.current(SeedIds.orders, 'b_gone', grants(), today: today),
      isNull,
    );
    expect(
      await shaper.current('c_gone', order, grants(), today: today),
      isNull,
    );
    expect(
      await shaper.image(q.collection(SeedIds.orders), null, grants()),
      isNull,
    );
  });

  test(
    'an event image shows its own derived values, not the stored card',
    () async {
      final derived = await q.cache.derive(SeedIds.orders, today: today);
      final stored = derived.base[order]!;
      final image = derived.deriveWith(
        stored.copyWith(
          values: {
            ...stored.values,
            OrderFields.price: const NumberFieldValue(100),
            OrderFields.qty: const NumberFieldValue(3),
          },
        ),
      );
      final card = (await shaper.card(derived.schema, image, grants()))!;
      expect((card['values']! as Map)[OrderFields.total], 300);
    },
  );
}
