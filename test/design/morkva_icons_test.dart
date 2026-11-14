import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/design/morkva_icons.dart';

void main() {
  test('no Material Icons left in lib/ (use MorkvaIcons)', () {
    final material = RegExp(r'(?<![A-Za-z0-9_$.])Icons\.[a-z]');
    final offenders = [
      for (final f in Directory('lib').listSync(recursive: true))
        if (f is File && f.path.endsWith('.dart'))
          for (final (i, line) in f.readAsLinesSync().indexed)
            if (material.hasMatch(line)) '${f.path}:${i + 1}',
    ];
    expect(offenders, isEmpty, reason: 'run python3 tool/icons/migrate.py');
  });

  test('every icon has its own code point, matching codepoints.json', () {
    final json =
        jsonDecode(File('tool/icons/codepoints.json').readAsStringSync())
            as Map<String, dynamic>;
    final all = MorkvaIcons.all;
    expect(all.keys.toSet(), json.keys.toSet());
    for (final MapEntry(:key, :value) in all.entries) {
      expect(value.codePoint, json[key], reason: key);
      expect(value.fontFamily, 'MorkvaIcons', reason: key);
    }
    expect(all.values.map((i) => i.codePoint).toSet(), hasLength(all.length));
  });
}
