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
import '../api/envelope.dart';
import 'input_errors.dart';
import 'ref_resolver.dart';

/// Strict friendly value → typed [FieldValue], run per field before anything
/// is stored. A wrong type is an error, never a silently blanked field:
///
/// | field | accepts |
/// |---|---|
/// | text | a string; a number is stringified |
/// | number | a JSON number, or a numeric-only string |
/// | boolean | a bool, `true`/`false`/`yes`/`no` |
/// | date | `YYYY-MM-DD`, `today`, `yesterday`, `tomorrow`, `+3d`, `-1w` |
/// | date with time | ISO-8601; zone-less means device-local time |
/// | single / multi select | option ids or labels |
/// | reference | card ids or titles (`@card`, `@selected` too) |
/// | calculated, auto-number | nothing (`read_only_field`) |
/// | file | nothing yet (`unsupported`) |
///
/// `null` (and `''` or `[]`) clears a writable field. Domain rules (required,
/// ranges, max length, one reference) are checked afterwards by
/// [validationDetails].
final class ValueCodec {
  ValueCodec(this.refs);

  final RefResolver refs;

  /// [friendly] as a value of [field] (of [collection]). Throws
  /// [HarnessException] naming [path].
  FieldValue decode(
    Collection collection,
    FieldDefinition field,
    Object? friendly, {
    required String path,
  }) {
    switch (field) {
      case CalculatedFieldDefinition() || AutoNumberFieldDefinition():
        final why = field is AutoNumberFieldDefinition
            ? 'numbered automatically'
            : 'calculated';
        throw HarnessException.of(
          ErrorCode.readOnlyField,
          '"${field.name}" is $why and cannot be set.',
          path: path,
        );
      case FileFieldDefinition():
        throw HarnessException.of(
          ErrorCode.unsupported,
          'Files cannot be attached from here yet; "${field.name}" was not '
          'changed.',
          path: path,
        );
    }
    if (friendly == null ||
        (friendly is String && friendly.isEmpty) ||
        (friendly is List && friendly.isEmpty)) {
      return field.emptyValue();
    }
    return switch (field) {
      TextFieldDefinition() => TextFieldValue(_text(field, friendly, path)),
      NumberFieldDefinition() => NumberFieldValue(
        _number(field, friendly, path),
      ),
      BooleanFieldDefinition() => BooleanFieldValue(
        _bool(field, friendly, path),
      ),
      DateFieldDefinition() => field.valueFromJson(
        _date(field, friendly, path),
      ),
      SingleSelectFieldDefinition(:final options) => SingleSelectFieldValue(
        refs
            .option(
              field.name,
              options,
              _scalar(field, friendly, path),
              path: path,
            )
            .id,
      ),
      MultiSelectFieldDefinition(:final options) => MultiSelectFieldValue(
        _each(field, friendly, path, (ref, at) {
          return refs.option(field.name, options, ref, path: at).id;
        }).toSet().toList(),
      ),
      ReferenceFieldDefinition(:final targetCollectionId) => () {
        final target = refs.collectionById(targetCollectionId, path: path);
        final list = friendly is List ? friendly : [friendly];
        return ReferenceFieldValue(
          refs.cards(
            target,
            [
              for (final (i, r) in list.indexed)
                _scalar(field, r, list.length > 1 ? '$path[$i]' : path),
            ],
            path: path,
            missing: ErrorCode.invalidReference,
          ),
        );
      }(),
      _ => throw HarnessException.of(
        ErrorCode.unsupported,
        '"${field.name}" is a ${field.type} field, which cannot be set from '
        'here.',
        path: path,
      ),
    };
  }

  /// Every entry of [values] (`{fieldRef: friendly}`) decoded against
  /// [collection], keyed by field id. Problems land in [errors] with paths
  /// `<path>.<key as given>`; the entries that failed are left out.
  Map<String, FieldValue> decodeValues(
    Collection collection,
    Map<String, Object?> values, {
    required String path,
    required InputErrors errors,
  }) {
    final out = <String, FieldValue>{};
    final keyOf = <String, String>{};
    for (final MapEntry(:key, :value) in values.entries) {
      final at = '$path.$key';
      final field = errors.guard(() => refs.field(collection, key, path: at));
      if (field == null) continue;
      final earlier = keyOf[field.id];
      if (earlier != null) {
        errors.add(
          ErrorDetail(
            path: at,
            code: ErrorCode.invalidArgs,
            message:
                '"$key" and "$earlier" both name ${field.name}; give it once.',
          ),
        );
        continue;
      }
      keyOf[field.id] = key;
      final decoded = errors.guard(
        () => decode(collection, field, value, path: at),
      );
      if (decoded != null) out[field.id] = decoded;
    }
    return out;
  }

  String _text(FieldDefinition field, Object friendly, String path) =>
      switch (friendly) {
        String() => friendly,
        num() when friendly.isFinite => _plain(friendly),
        _ => throw _wrongType(field, 'text', friendly, path),
      };

  num _number(NumberFieldDefinition field, Object friendly, String path) {
    if (friendly is num) {
      if (friendly.isFinite) return friendly;
      throw _wrongType(field, 'a finite number', friendly, path);
    }
    if (friendly is String) {
      final parsed = parseNumber(friendly);
      if (parsed != null) return parsed;
      final unit = _withUnit.firstMatch(friendly.trim());
      if (unit != null) {
        throw HarnessException.of(
          ErrorCode.wrongType,
          '"${field.name}" takes a number; got "$friendly". Send '
          '${unit[1]} only: the unit is \'${unit[2]}\'.',
          path: path,
        );
      }
    }
    throw _wrongType(field, 'a number', friendly, path);
  }

  bool _bool(FieldDefinition field, Object friendly, String path) {
    if (friendly is bool) return friendly;
    if (friendly is String) {
      switch (friendly.trim().toLowerCase()) {
        case 'true' || 'yes':
          return true;
        case 'false' || 'no':
          return false;
      }
    }
    throw _wrongType(field, 'true or false', friendly, path);
  }

  /// The stored JSON of a date: `YYYY-MM-DD` for a date-only field, a UTC
  /// ISO instant for one with time.
  String _date(DateFieldDefinition field, Object friendly, String path) {
    if (friendly is String) {
      if (!field.includeTime) {
        final day = parseDay(friendly, refs.ctx.today);
        if (day != null) return isoDay(day);
      } else {
        final instant = parseInstant(friendly, refs.ctx.today);
        if (instant != null) return instant.toUtc().toIso8601String();
      }
    }
    throw _wrongType(
      field,
      field.includeTime
          ? 'an ISO date-time (2026-11-10T14:30:00Z; without a zone it is '
                'device-local time)'
          : 'a date: YYYY-MM-DD, today, tomorrow, yesterday, +3d or -1w',
      friendly,
      path,
    );
  }

  String _scalar(FieldDefinition field, Object? friendly, String path) =>
      switch (friendly) {
        String() => friendly,
        num() when friendly.isFinite => _plain(friendly),
        _ => throw _wrongType(field, 'a name or id', friendly, path),
      };

  List<T> _each<T>(
    FieldDefinition field,
    Object friendly,
    String path,
    T Function(String ref, String path) one,
  ) {
    final list = friendly is List ? friendly : [friendly];
    return [
      for (final (i, item) in list.indexed)
        () {
          final at = list.length > 1 ? '$path[$i]' : path;
          return one(_scalar(field, item, at), at);
        }(),
    ];
  }

  HarnessException _wrongType(
    FieldDefinition field,
    String expected,
    Object? got,
    String path,
  ) => HarnessException.of(
    ErrorCode.wrongType,
    '"${field.name}" takes $expected; got ${_show(got)}.',
    path: path,
  );
}

/// [value] as JSON when it is JSON (infinity is not), else as text.
String _show(Object? value) {
  try {
    return jsonEncode(value);
  } on JsonUnsupportedObjectError {
    return '$value';
  }
}

/// [MorkvaObject.validateAgainst] as harness error details, with paths
/// `<path>.<field name>` and the domain codes passed through. With
/// [onlyFieldIds] (an update), errors of untouched fields are dropped, so an
/// old card with an empty required field never blocks an unrelated change.
List<ErrorDetail> validationDetails(
  Collection collection,
  MorkvaObject object, {
  required String path,
  Set<String>? onlyFieldIds,
}) => [
  for (final e in object.validateAgainst(collection).errors)
    if (onlyFieldIds == null || onlyFieldIds.contains(e.fieldId))
      ErrorDetail(
        path: '$path.${collection.fieldById(e.fieldId)?.name ?? e.fieldId}',
        code: ErrorCode.fromWire(e.code) ?? ErrorCode.invalidArgs,
        message: e.message,
      ),
];

/// A numeric-only string (`12`, `-3.5`, `+.5`) as a number: an int when it
/// has no fraction; null for anything else.
num? parseNumber(String text) {
  final t = text.trim();
  if (!_numeric.hasMatch(t)) return null;
  return t.contains('.') ? double.parse(t) : int.parse(t);
}

final RegExp _numeric = RegExp(r'^[+-]?(\d+(\.\d*)?|\.\d+)$');
final RegExp _withUnit = RegExp(r'^([+-]?\d+(?:[.,]\d+)?)\s*([^\d\s].*)$');

/// A calendar day from `YYYY-MM-DD`, `today`, `yesterday`, `tomorrow` or an
/// offset from [today] (`+3d`, `-1w`), as a local-midnight [DateTime]; null
/// when [text] is none of those.
DateTime? parseDay(String text, DateTime today) {
  final t = text.trim().toLowerCase();
  switch (t) {
    case 'today':
      return _day(today, 0);
    case 'yesterday':
      return _day(today, -1);
    case 'tomorrow':
      return _day(today, 1);
  }
  final offset = _offset.firstMatch(t);
  if (offset != null) {
    final n = int.parse(offset[2]!) * (offset[3] == 'w' ? 7 : 1);
    return _day(today, offset[1] == '-' ? -n : n);
  }
  final m = _isoDay.firstMatch(t);
  if (m == null) return null;
  final (y, mo, d) = (int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
  final day = DateTime(y, mo, d);
  // Reject days that roll over (2026-02-30).
  return day.year == y && day.month == mo && day.day == d ? day : null;
}

/// An instant from an ISO-8601 string (a `Z` or `±hh:mm` zone, else
/// device-local time) or a day [parseDay] accepts (its local midnight).
DateTime? parseInstant(String text, DateTime today) {
  final t = text.trim();
  if (_isoInstant.hasMatch(t)) {
    // DateTime.parse rolls 2026-02-30 over to March; refuse it instead.
    return parseDay(t.substring(0, 10), today) == null
        ? null
        : DateTime.tryParse(t);
  }
  return parseDay(t, today);
}

/// [day] as `YYYY-MM-DD` (its year, month and day as given).
String isoDay(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-${_two(day.month)}-'
    '${_two(day.day)}';

// Component arithmetic, never Duration: a DST shift would move midnight.
DateTime _day(DateTime today, int delta) =>
    DateTime(today.year, today.month, today.day + delta);

String _two(int n) => n.toString().padLeft(2, '0');

/// [n] without float noise: `12`, `12.5`.
String _plain(num n) =>
    n is int || n != n.truncateToDouble() ? '$n' : n.toInt().toString();

final RegExp _offset = RegExp(r'^([+-])(\d{1,4})([dw])$');
final RegExp _isoDay = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');
final RegExp _isoInstant = RegExp(
  r'^\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}(:\d{2}(\.\d{1,6})?)?'
  r'(Z|z|[+-]\d{2}:?\d{2})?$',
);
