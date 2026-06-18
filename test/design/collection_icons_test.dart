import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/design/collection_icons.dart';

void main() {
  group('CollectionIcons.byKey', () {
    test('null resolves to the fallback glyph', () {
      expect(CollectionIcons.byKey(null), CollectionIcons.fallback);
    });

    test('unknown/retired key resolves to the fallback glyph', () {
      expect(CollectionIcons.byKey('definitely-not-a-key'),
          CollectionIcons.fallback);
    });

    test('a known key resolves to its icon', () {
      final truck =
          CollectionIcons.all.firstWhere((o) => o.key == 'truck');
      expect(CollectionIcons.byKey('truck'), truck.icon);
    });
  });

  test('catalog keys are unique', () {
    final keys = CollectionIcons.all.map((o) => o.key).toList();
    expect(keys.toSet(), hasLength(keys.length));
  });

  test('every catalog glyph is a const IconData (tree-shake safe)', () {
    for (final option in CollectionIcons.all) {
      expect(option.icon, isA<IconData>());
    }
  });
}
