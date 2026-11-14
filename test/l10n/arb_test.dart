import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, String> _messages(String locale) {
  final arb =
      jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync())
          as Map<String, dynamic>;
  return {
    for (final e in arb.entries)
      if (!e.key.startsWith('@')) e.key: e.value as String,
  };
}

final _placeholder = RegExp(r'\{(\w+)[,}]');

Set<String> _placeholders(String message) =>
    _placeholder.allMatches(message).map((m) => m.group(1)!).toSet();

void main() {
  final en = _messages('en');
  final uk = _messages('uk');

  test('Ukrainian translates every English message', () {
    expect(uk.keys.toSet().difference(en.keys.toSet()), isEmpty);
    expect(en.keys.toSet().difference(uk.keys.toSet()), isEmpty);
  });

  test('Ukrainian keeps every placeholder', () {
    expect([
      for (final key in en.keys)
        if (_placeholders(en[key]!).length != _placeholders(uk[key]!).length ||
            !_placeholders(en[key]!).containsAll(_placeholders(uk[key]!)))
          key,
    ], isEmpty);
  });

  test('Ukrainian plurals have one, few, many and other forms', () {
    expect([
      for (final e in uk.entries)
        if (e.value.contains('plural,') &&
            !['one{', 'few{', 'many{', 'other{'].every(e.value.contains))
          e.key,
    ], isEmpty);
  });

  test('Ukrainian uses the typographic apostrophe', () {
    expect([
      for (final e in uk.entries)
        if (e.value.contains("'")) e.key,
    ], isEmpty);
  });
}
