import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/features/templates/template_catalog.dart';

/// Serves assets from the repo, like the bundled ones.
class _DiskBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(File(key).readAsBytesSync());
}

/// [node] with every user-facing text blanked: what must not differ between
/// translations (ids, types, formulas, layout, numbers).
Object? _skeleton(Object? node, [String? key]) => switch (node) {
  final Map<String, dynamic> m => {
    for (final e in m.entries)
      e.key: e.key == 'values'
          ? {
              for (final v in (e.value as Map<String, dynamic>).entries)
                v.key: v.value is String ? '' : v.value,
            }
          : _skeleton(e.value, e.key),
  },
  final List<dynamic> l => [for (final e in l) _skeleton(e, key)],
  final String _
      when const {
        'name',
        'description',
        'label',
        'title',
        'unitLabel',
      }.contains(key) =>
    '',
  _ => node,
};

void main() {
  test('Ukrainian templates load in Ukrainian, English otherwise', () async {
    final bundle = _DiskBundle();
    final en = await loadBundledTemplates(bundle, 'en');
    final uk = await loadBundledTemplates(bundle, 'uk');
    final fallback = await loadBundledTemplates(bundle, 'de');
    expect(
      [for (final t in en) t.name],
      ['Orders pipeline', 'Production & materials'],
    );
    expect([for (final t in fallback) t.name], [for (final t in en) t.name]);
    expect(
      [for (final t in uk) t.name],
      ['Воронка замовлень', 'Виробництво й матеріали'],
    );
    expect(uk.first.collectionNames.first, 'Замовлення');
  });

  test('a translation changes only the words', () {
    for (final path in kBundledTemplates) {
      Object? read(String p) => jsonDecode(File(p).readAsStringSync());
      final uk = read(path.replaceFirst('.json', '.uk.json'));
      expect(_skeleton(uk), _skeleton(read(path)), reason: path);
      // And it still builds.
      var n = 0;
      WorkspaceTemplate.fromJson(uk! as Map<String, dynamic>).instantiate(
        defaultFieldTypeRegistry(),
        collectionId: () => 'c${n++}',
        objectId: () => 'o${n++}',
        now: DateTime.utc(2026, 11, 14),
      );
    }
  });
}
