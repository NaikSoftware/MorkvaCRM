import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';

/// Epic 7 acceptance: the shipped templates rebuild the owner's spreadsheet
/// and Trello setups as plain data, and their numbers come out right.
WorkspaceTemplate _load(String name) => WorkspaceTemplate.fromJson(
  jsonDecode(File('assets/templates/$name.json').readAsStringSync())
      as Map<String, dynamic>,
);

/// Instantiates [template] and derives everything, keyed by template id
/// (`@orders`) → objects keyed by template object id (`@o1`).
Map<String, Map<String, MorkvaObject>> _derive(WorkspaceTemplate template) {
  var c = 0, o = 0;
  final built = template.instantiate(
    defaultFieldTypeRegistry(),
    collectionId: () => 'c${c++}',
    objectId: () => 'b${o++}',
    now: DateTime.utc(2026, 11, 7),
  );
  final collections = resolveLookups(built.collections);
  final objects = <String, List<MorkvaObject>>{
    for (final col in collections)
      col.id: [
        for (final obj in built.objects)
          if (obj.collectionId == col.id) obj,
      ],
  };
  final derivation = Derivation(collections: collections, objects: objects);
  final collectionKeys = [for (final j in template.collections) j['id']];
  final objectKeys = [for (final j in template.objects) j['id']];
  return {
    for (final (i, col) in collections.indexed)
      collectionKeys[i] as String: {
        for (final derived in derivation.objectsOf(col.id))
          objectKeys[int.parse(derived.id.substring(1))] as String: derived,
      },
  };
}

Object? _v(MorkvaObject o, String field) => switch (o[field]) {
  CalculatedFieldValue(:final cached) => cached,
  NumberFieldValue(:final value) => value,
  final other => other,
};

void main() {
  group('production & materials (the spreadsheet)', () {
    final data = _derive(_load('production_materials'));
    final black = data['@colours']!['@black']!;
    final olive = data['@colours']!['@olive']!;
    final summary = data['@summary']!['@s1']!;

    test('per colour: pieces, spend and material cost per piece', () {
      expect(_v(black, 'made'), 28);
      expect(_v(black, 'spent'), 8400);
      expect(_v(black, 'costPerPiece'), 300);
      expect(_v(olive, 'costPerPiece'), 525); // (4,800 + 450) / 10
    });

    test('balance: bought − sewn × per piece − written off', () {
      expect(_v(black, 'fabricLeft'), closeTo(5.4, 1e-9)); // 25 − 28 × 0.7
      expect(_v(black, 'piecesLeft'), 7);
      expect(_v(olive, 'fabricLeft'), closeTo(7.5, 1e-9)); // 15 − 7 − 0.5
      expect(_v(olive, 'piecesLeft'), 10);
      expect(_v(black, 'ribLeft'), closeTo(0.6, 1e-9)); // 2 − 28 × 0.05
      expect(_v(olive, 'ribLeft'), closeTo(0.5, 1e-9));
    });

    test('an empty kg-per-piece shows blank, not the raw purchase', () {
      final template = _load('production_materials');
      final raw = template.objects.firstWhere((o) => o['id'] == '@black');
      (raw['values'] as Map).remove('fabricPerPiece');
      final black = _derive(template)['@colours']!['@black']!;
      expect(_v(black, 'fabricLeft'), isNull);
      expect(_v(black, 'piecesLeft'), isNull);
    });

    test('roll-up: true cost and margin of a piece', () {
      expect(_v(summary, 'spent'), 13650);
      expect(_v(summary, 'made'), 38);
      expect(_v(summary, 'materialPerPiece'), closeTo(359.21, 1e-9));
      expect(_v(summary, 'trueCost'), closeTo(769.21, 1e-9));
      expect(_v(summary, 'margin'), closeTo(1030.79, 1e-9));
    });
  });

  group('orders pipeline (the Trello boards)', () {
    final template = _load('orders_pipeline');
    final data = _derive(template);

    test('stock reserves and sells itself from order items', () {
      final blackM = data['@inventory']!['@k1']!;
      // Olena's order (ordered) reserves 1; Iryna's (shipped) sold 2.
      expect(_v(blackM, 'reserved'), 1);
      expect(_v(blackM, 'sold'), 2);
      expect(_v(blackM, 'available'), 7);
      final oliveL = data['@inventory']!['@k2']!;
      expect(_v(oliveL, 'reserved'), 1); // in progress
      expect(_v(oliveL, 'available'), 4);
    });

    test('items show their stock item and order status by lookup', () {
      final item = data['@items']!['@i1']!;
      expect(_v(item, 'garment'), 'hoodie');
      expect(_v(item, 'size'), 'm');
      expect(_v(item, 'colour'), 'black');
      expect(_v(item, 'orderStatus'), 'ordered');
    });

    test('orders count their items and the done ones', () {
      final olena = data['@orders']!['@o1']!;
      expect(_v(olena, 'itemCount'), 3);
      expect(_v(olena, 'itemsDone'), 0);
      expect(_v(data['@orders']!['@o3']!, 'itemsDone'), 2);
    });

    test('boards group by status and by size', () {
      final collections = template
          .instantiate(
            defaultFieldTypeRegistry(),
            collectionId: () => 'x',
            objectId: () => 'y',
            now: DateTime.utc(2026),
          )
          .collections;
      final delivery = collections[0].layout.sections.last;
      expect(delivery.title, 'Delivery & payment');
      expect(delivery.collapsed, isTrue);
      expect(collections[0].views.first.mode, ViewModeIds.board);
      expect(collections[0].views.first.layoutFieldId, 'status');
      expect(
        collections[2].views.where((v) => v.mode == ViewModeIds.board),
        everyElement(
          isA<ViewDefinition>().having(
            (v) => v.layoutFieldId,
            'groups by',
            'size',
          ),
        ),
      );
    });
  });

  test('ids are fresh per import and every link follows them', () {
    final template = _load('orders_pipeline');
    var n = 0;
    final built = template.instantiate(
      defaultFieldTypeRegistry(),
      collectionId: () => 'col${n++}',
      objectId: () => 'obj${n++}',
      now: DateTime.utc(2026),
    );
    final json = jsonEncode([
      for (final c in built.collections) c.toJson(),
      for (final o in built.objects)
        o.values.map((k, v) => MapEntry(k, v.toJson())),
    ]);
    expect(json, isNot(contains('@')));
    final items = built.collections[1];
    final sku = items.fieldById('sku')! as ReferenceFieldDefinition;
    expect(sku.targetCollectionId, built.collections[2].id);
  });

  test('template data never needs domain words in the engine', () {
    final hits = Process.runSync('grep', [
      '-rliE',
      'hoodie|t-shirt|embroider|ribbing',
      'lib',
    ]);
    expect((hits.stdout as String).trim(), isEmpty);
  });
}
