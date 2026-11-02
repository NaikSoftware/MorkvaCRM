import 'package:flutter/painting.dart';

/// Parses a `#RRGGBB` string (a select option's colour) into a [Color];
/// falls back to grey on malformed input so a bad stored value never crashes.
Color colorFromHex(String hex) {
  final cleaned = hex.replaceAll('#', '').trim();
  final value = int.tryParse(cleaned, radix: 16);
  if (value == null || cleaned.length != 6) return const Color(0xFF9E9E9E);
  return Color(0xFF000000 | value);
}
