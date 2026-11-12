/// Strict readers for the automation docs: every miss is a
/// [FormatException], so a store can treat a malformed doc as absent.
library;

String readString(Map<String, Object?> json, String key) => switch (json[key]) {
  final String s => s,
  _ => throw FormatException('"$key" must be a string'),
};

String? readStringOrNull(Map<String, Object?> json, String key) =>
    json[key] == null ? null : readString(json, key);

bool readBool(Map<String, Object?> json, String key) => switch (json[key]) {
  final bool b => b,
  _ => throw FormatException('"$key" must be a boolean'),
};

/// A whole number; a web number or a VM-decoded `2.0` counts.
int readInt(Map<String, Object?> json, String key) => switch (json[key]) {
  final num n when n.isFinite && n == n.truncateToDouble() => n.toInt(),
  _ => throw FormatException('"$key" must be a whole number'),
};

int? readIntOrNull(Map<String, Object?> json, String key) =>
    json[key] == null ? null : readInt(json, key);

Map<String, Object?> readMap(Map<String, Object?> json, String key) =>
    switch (json[key]) {
      final Map<Object?, Object?> m => m.cast<String, Object?>(),
      _ => throw FormatException('"$key" must be an object'),
    };

Map<String, Object?>? readMapOrNull(Map<String, Object?> json, String key) =>
    json[key] == null ? null : readMap(json, key);

List<String> readStrings(Map<String, Object?> json, String key) =>
    switch (json[key]) {
      final List<Object?> l when l.every((v) => v is String) =>
        List.unmodifiable(l.cast<String>()),
      _ => throw FormatException('"$key" must be a list of strings'),
    };

List<String>? readStringsOrNull(Map<String, Object?> json, String key) =>
    json[key] == null ? null : readStrings(json, key);

T readEnum<T>(
  Map<String, Object?> json,
  String key,
  List<T> values,
  String Function(T) wire,
) {
  final raw = json[key];
  for (final v in values) {
    if (wire(v) == raw) return v;
  }
  throw FormatException('"$key" has an unknown value "$raw"');
}

T? readEnumOrNull<T>(
  Map<String, Object?> json,
  String key,
  List<T> values,
  String Function(T) wire,
) => json[key] == null ? null : readEnum<T>(json, key, values, wire);

/// A [DateTime] (what the stores hand over after converting Timestamps) or
/// an ISO-8601 string, as UTC.
DateTime readDate(Map<String, Object?> json, String key) => switch (json[key]) {
  final DateTime d => d.toUtc(),
  final String s =>
    DateTime.tryParse(s)?.toUtc() ??
        (throw FormatException('"$key" must be a date')),
  _ => throw FormatException('"$key" must be a date'),
};

DateTime? readDateOrNull(Map<String, Object?> json, String key) =>
    json[key] == null ? null : readDate(json, key);

/// [text] cut to [max] UTF-16 units, ending in "…" when cut (never
/// splitting a surrogate pair).
String cutText(String text, int max) {
  if (text.length <= max) return text;
  var end = max - 1;
  final last = text.codeUnitAt(end - 1);
  if (last >= 0xD800 && last <= 0xDBFF) end--;
  return '${text.substring(0, end)}…';
}
