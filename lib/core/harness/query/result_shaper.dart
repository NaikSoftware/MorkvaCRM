import 'dart:convert';

import '../../domain/collection.dart';
import '../../domain/field_definition.dart';
import '../../domain/field_value.dart';
import '../../domain/morkva_object.dart';
import '../../domain/types/auto_number_field.dart';
import '../../domain/types/boolean_field.dart';
import '../../domain/types/calculated_field.dart';
import '../../domain/types/date_field.dart';
import '../../domain/types/file_field.dart';
import '../../domain/types/multi_select_field.dart';
import '../../domain/types/number_field.dart';
import '../../domain/types/reference_field.dart';
import '../../domain/types/single_select_field.dart';
import '../../domain/types/text_field.dart';
import '../../domain/view/field_format.dart';
import '../input/screen_line.dart';
import '../input/value_codec.dart';

/// The title of referenced card [id] of collection [collectionId], or null
/// when it may not or cannot be shown (an ungranted or unloaded collection).
typedef ReferenceTitle = String? Function(String collectionId, String id);

/// Turns read results into what the model receives: values in display form
/// keyed by field name, user strings sanitized and cut, and every result
/// held to a byte budget (rows 4 KB, aggregates 8 KB, schemas 16 KB of
/// JSON) by dropping from the tail, never silently.
///
/// Display form: option labels; references as `[{id, title}]`; date-only
/// values `YYYY-MM-DD`, date-times ISO with the device offset; numbers raw
/// (the caller states units once per result); auto-numbers as shown
/// (`#1042`); empty values omitted (null).
final class ResultShaper {
  const ResultShaper({
    this.rowBudget = 4096,
    this.aggregateBudget = 8192,
    this.schemaBudget = 16384,
    this.textMax = 160,
    this.labelMax = 80,
    this.nameMax = 60,
  });

  /// Bytes of JSON a row result (`cards.query/page/get/find/distinct`) may
  /// take.
  final int rowBudget;

  /// Bytes of JSON an aggregate (or a plan) may take.
  final int aggregateBudget;

  /// Bytes of JSON a schema result (`collections.get`, a full describe) may
  /// take.
  final int schemaBudget;

  /// Characters of a text value.
  final int textMax;

  /// Characters of a label: a card title, an option label, a group label.
  final int labelMax;

  /// Characters of a field or collection name.
  final int nameMax;

  /// [text] stripped of control, bidi and zero-width characters, runs of
  /// whitespace folded to one space and cut to [textMax].
  String text(String text) => _clean(text, textMax);

  /// [text] sanitized and cut to [labelMax].
  String label(String text) => _clean(text, labelMax);

  /// [text] sanitized and cut to [nameMax].
  String name(String text) => _clean(text, nameMax);

  /// The card's title (its first text field, `Untitled` when blank: the
  /// label the app shows), sanitized.
  String title(Collection collection, MorkvaObject object) =>
      label(cardTitle(collection, object));

  /// [value] of [field] in display form, or null when empty. A calculated
  /// field shows as its output type.
  Object? value(
    FieldDefinition field,
    FieldValue value, {
    ReferenceTitle? referenceTitle,
  }) {
    if (value.isEmpty) return null;
    final (f, v) = presentedAs(field, value);
    if (v.isEmpty) return null;
    switch ((f, v)) {
      case (_, TextFieldValue(:final text?)):
        return this.text(text);
      case (_, NumberFieldValue(value: final n?)):
        return cleanNumber(n);
      case (AutoNumberFieldDefinition(), AutoNumberFieldValue()):
        return formatFieldValue(f, v);
      case (_, BooleanFieldValue(value: final b?)):
        return b;
      case (final DateFieldDefinition d, DateFieldValue(value: final dt?)):
        return d.includeTime ? isoInstant(dt) : isoDay(calendarDayOf(d, dt));
      case (
        SingleSelectFieldDefinition(:final options),
        SingleSelectFieldValue(:final optionId),
      ):
        final option = options.where((o) => o.id == optionId).firstOrNull;
        return option == null ? null : label(option.label);
      case (
        MultiSelectFieldDefinition(:final options),
        MultiSelectFieldValue(:final optionIds),
      ):
        final labels = [
          for (final o in options)
            if (optionIds.contains(o.id)) label(o.label),
        ];
        return labels.isEmpty ? null : labels;
      case (
        ReferenceFieldDefinition(:final targetCollectionId),
        ReferenceFieldValue(:final objectIds),
      ):
        return [
          for (final id in objectIds.toSet())
            {
              'id': id,
              if (referenceTitle?.call(targetCollectionId, id)
                  case final title?)
                'title': label(title),
            },
        ];
      case (_, FileFieldValue(:final attachments)):
        return [for (final a in attachments) label(a.name)];
    }
    final shown = formatFieldValue(f, v);
    return shown.isEmpty ? null : text(shown);
  }

  /// The unit a number-presenting [field] carries, or null.
  String? unitOf(FieldDefinition field) {
    final shown = field is CalculatedFieldDefinition
        ? field.outputField
        : field;
    final unit = shown is NumberFieldDefinition ? shown.unitLabel : null;
    return unit == null || unit.trim().isEmpty ? null : name(unit);
  }

  /// One card as the model reads it: `{id, title, v: {Field name: value}}`
  /// with empty values left out, plus the timestamps (ISO) when [meta].
  Map<String, Object?> card(
    Collection collection,
    MorkvaObject object,
    Iterable<(FieldDefinition, FieldValue)> values, {
    ReferenceTitle? referenceTitle,
    bool meta = false,
  }) {
    final v = <String, Object?>{};
    for (final (field, value) in values) {
      final shown = this.value(field, value, referenceTitle: referenceTitle);
      if (shown != null) v[name(field.name)] = shown;
    }
    return {
      'id': object.id,
      'title': title(collection, object),
      if (v.isNotEmpty) 'v': v,
      if (meta) 'createdAt': isoInstant(object.createdAt),
      if (meta) 'updatedAt': isoInstant(object.updatedAt),
    };
  }

  /// The largest result [build] makes, for `0..count` kept items, that fits
  /// [budget] bytes of JSON; `build(count)` when it fits as is. [build]
  /// marks the cut itself (`truncated`, a cursor, a hint) when given fewer
  /// than [count] items. With nothing fitting, `build(0)`.
  Map<String, Object?> fit(
    int count,
    Map<String, Object?> Function(int kept) build, {
    required int budget,
  }) {
    final whole = build(count);
    if (bytes(whole) <= budget || count == 0) return whole;
    // Size grows with kept items, so binary-search the largest fit.
    var lo = 0;
    var hi = count - 1;
    Map<String, Object?>? best;
    while (lo <= hi) {
      final mid = (lo + hi) ~/ 2;
      final candidate = build(mid);
      if (bytes(candidate) <= budget) {
        best = candidate;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return best ?? build(0);
  }

  /// A schema result (`collections.get`, or `workspace.describe` with
  /// `collections: [...]`) cut to [schemaBudget], in this order: every
  /// field's `operators` dropped, then option ids beyond the first 20 per
  /// field (labels kept), then trailing fields, whose names move to
  /// `moreFields` so no field goes unnamed. A cut result carries
  /// `truncated: true` and a hint.
  Map<String, Object?> fitSchema(Map<String, Object?> result) {
    if (bytes(result) <= schemaBudget) return result;
    final out = _copy(result) as Map<String, Object?>;
    final owners = [
      if (out['fields'] is List) out,
      if (out['collections'] case final List cs)
        for (final c in cs)
          if (c is Map<String, Object?> && c['fields'] is List) c,
    ];
    Iterable<Map<String, Object?>> fieldsOf(Map<String, Object?> owner) =>
        (owner['fields'] as List).whereType<Map<String, Object?>>();
    out['truncated'] = true;
    out['hint'] = 'Call collections.get with the fields you need.';

    for (final owner in owners) {
      for (final f in fieldsOf(owner)) {
        f.remove('operators');
      }
    }
    if (bytes(out) <= schemaBudget) return out;

    for (final owner in owners) {
      for (final f in fieldsOf(owner)) {
        if (f['options'] case final List options when options.length > 20) {
          f['options'] = [
            ...options.take(20),
            for (final o in options.skip(20))
              o is Map ? ({...o}..remove('id')) : o,
          ];
        }
      }
    }
    if (bytes(out) <= schemaBudget) return out;

    // Drop whole fields from the end of the last collection backwards.
    for (final owner in owners.reversed) {
      final fields = owner['fields'] as List;
      final names = <Object?>[];
      while (fields.isNotEmpty && bytes(out) > schemaBudget) {
        final dropped = fields.removeLast();
        names.insert(0, dropped is Map ? dropped['name'] : null);
        owner['moreFields'] = names;
      }
      if (bytes(out) <= schemaBudget) break;
    }
    return out;
  }

  /// [text] through `sanitizeName`, skipped (it runs two regexes) when
  /// [text] is already clean: short enough, single-spaced, untrimmed-free
  /// and without control, invisible or unusual space characters.
  static String _clean(String text, int max) =>
      _isClean(text, max) ? text : sanitizeName(text, max: max);

  static bool _isClean(String text, int max) {
    if (text.isEmpty || text.length > max) return false;
    var space = true; // no leading space
    for (final c in text.codeUnits) {
      if (c == 0x20) {
        if (space) return false;
        space = true;
        continue;
      }
      space = false;
      if (c < 0x20 ||
          (c >= 0x7F && c <= 0xA0) ||
          c == 0xAD ||
          c == 0x61C ||
          c == 0x1680 ||
          c == 0x180E ||
          (c >= 0x2000 && c <= 0x206F) ||
          c == 0x3000 ||
          c == 0xFEFF) {
        return false;
      }
    }
    return !space; // no trailing space
  }

  /// The size of [json] as UTF-8 JSON.
  static int bytes(Object? json) => utf8.encode(jsonEncode(json)).length;

  static Object? _copy(Object? json) => switch (json) {
    Map() => {for (final e in json.entries) '${e.key}': _copy(e.value)},
    List() => [for (final v in json) _copy(v)],
    _ => json,
  };
}

/// [object]'s title: its first text field trimmed, `Untitled` when blank or
/// when the collection has no text field (the `objectLabels` rule).
String cardTitle(Collection collection, MorkvaObject object) {
  final titleField = collection.fields
      .whereType<TextFieldDefinition>()
      .firstOrNull;
  return switch (object[titleField?.id ?? '']) {
    TextFieldValue(:final text?) when text.trim().isNotEmpty => text.trim(),
    _ => 'Untitled',
  };
}

/// [n] as JSON can carry it: null when not finite, a double rounded to 12
/// significant digits (so a sum of prices shows `0.3`, not
/// `0.30000000000000004`).
num? cleanNumber(num n) {
  if (n is int) return n;
  if (!n.isFinite) return null;
  return double.parse(n.toStringAsPrecision(12));
}

/// [instant] as ISO 8601 in the device's zone with its offset
/// (`2026-11-10T14:30:00+02:00`): the zone the user reads times in, and
/// the one `calendarDayOf` uses.
String isoInstant(DateTime instant) {
  final local = instant.toLocal();
  final offset = local.timeZoneOffset;
  final sign = offset.isNegative ? '-' : '+';
  final minutes = offset.inMinutes.abs();
  String two(int n) => n.toString().padLeft(2, '0');
  final base = local.toIso8601String().split('.').first;
  return '$base$sign${two(minutes ~/ 60)}:${two(minutes % 60)}';
}
