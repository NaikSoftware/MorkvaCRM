import '../field_definition.dart';
import '../field_value.dart';
import '../validation.dart';

/// Type discriminator for the date / date-time field.
const String kDateFieldType = 'date';

/// A point-in-time field, either a calendar date or a full date-time.
///
/// [includeTime] distinguishes the two modes:
/// * `false` (default) — a calendar date. Values are normalized to **midnight
///   UTC** (year/month/day, time zeroed) on parse so a round-trip is stable and
///   two equal dates compare equal regardless of the source time zone.
/// * `true` — a full date-time, kept at its exact instant in **UTC**.
///
/// All values are stored and compared in UTC. [DateFieldValue] is a dumb holder
/// for whatever [DateTime] it is given; this definition owns normalization,
/// applying it in [valueFromJson]. When constructing values directly (e.g. in
/// tests) build them already-normalized (use `DateTime.utc(...)`) so they match
/// what a JSON round-trip would produce.
///
/// [min]/[max] are optional inclusive bounds. They should be supplied as UTC
/// [DateTime]s; [fromJson] parses them as UTC so definition round-trips are
/// stable.
class DateFieldDefinition extends FieldDefinition {
  const DateFieldDefinition({
    required super.id,
    required super.name,
    super.description,
    super.isRequired,
    this.includeTime = false,
    this.min,
    this.max,
  });

  /// Whether the value carries a time component. Controls value normalization.
  final bool includeTime;

  /// Optional inclusive lower bound (UTC). `null` means unbounded.
  final DateTime? min;

  /// Optional inclusive upper bound (UTC). `null` means unbounded.
  final DateTime? max;

  @override
  String get type => kDateFieldType;

  /// Reconstructs a definition from its JSON map (including the common keys).
  factory DateFieldDefinition.fromJson(Map<String, dynamic> json) {
    final base = readFieldBase(json);
    return DateFieldDefinition(
      id: base.id,
      name: base.name,
      description: base.description,
      isRequired: base.isRequired,
      includeTime: (json['includeTime'] as bool?) ?? false,
      min: _parseInstant(json['min']),
      max: _parseInstant(json['max']),
    );
  }

  @override
  Map<String, dynamic> configToJson() => {
    'includeTime': includeTime,
    if (min != null) 'min': min!.toIso8601String(),
    if (max != null) 'max': max!.toIso8601String(),
  };

  @override
  List<Object?> get configProps => [includeTime, min, max];

  @override
  FieldValue emptyValue() => const DateFieldValue(null);

  @override
  FieldValue valueFromJson(Object? json) {
    final parsed = _parseInstant(json);
    return DateFieldValue(parsed == null ? null : _normalize(parsed));
  }

  @override
  List<ValidationError> validateValue(FieldValue value) {
    final v = value as DateFieldValue;
    final dt = v.value;
    final errors = <ValidationError>[];
    if (dt != null) {
      if (min != null && dt.isBefore(min!)) {
        errors.add(
          ValidationError(
            fieldId: id,
            code: ValidationError.outOfRange,
            message: '$name must be on or after ${min!.toIso8601String()}',
          ),
        );
      }
      if (max != null && dt.isAfter(max!)) {
        errors.add(
          ValidationError(
            fieldId: id,
            code: ValidationError.outOfRange,
            message: '$name must be on or before ${max!.toIso8601String()}',
          ),
        );
      }
    }
    return errors;
  }

  /// Normalizes a parsed instant: always UTC; date-only when [includeTime] is
  /// false (time zeroed to midnight UTC).
  DateTime _normalize(DateTime dt) {
    final utc = dt.toUtc();
    return includeTime ? utc : DateTime.utc(utc.year, utc.month, utc.day);
  }

  /// Parses an ISO-8601 string to a UTC [DateTime]; null/blank/invalid → null.
  ///
  /// The written calendar day must survive regardless of the host machine's
  /// time zone, so a bare date or zone-less date-time (e.g. `2027-01-01` or
  /// `2026-06-15T13:45:30`) is interpreted as a **UTC** wall-clock value — its
  /// components are taken verbatim, with no local→UTC shift. A string that
  /// carries an explicit zone (`Z` or a `±HH:MM` offset) denotes a real instant
  /// and is converted to UTC.
  static DateTime? _parseInstant(Object? raw) {
    if (raw is! String || raw.isEmpty) return null;
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return null;
    // 'Z' suffix: already a UTC instant.
    if (parsed.isUtc) return parsed;
    // Explicit numeric offset: a true instant in some zone → convert to UTC.
    if (_hasExplicitOffset(raw)) return parsed.toUtc();
    // Zone-less: treat the written wall-clock components as UTC directly.
    return DateTime.utc(
      parsed.year,
      parsed.month,
      parsed.day,
      parsed.hour,
      parsed.minute,
      parsed.second,
      parsed.millisecond,
      parsed.microsecond,
    );
  }

  /// Whether an ISO-8601 string carries an explicit numeric zone offset
  /// (`±HH:MM`). The `Z` form is handled separately via [DateTime.isUtc]. Only
  /// the time portion after `T` is inspected, so the date separators are never
  /// mistaken for a negative offset.
  static bool _hasExplicitOffset(String raw) {
    final tIndex = raw.indexOf('T');
    if (tIndex < 0) return false;
    final timePart = raw.substring(tIndex + 1);
    return timePart.contains('+') || timePart.contains('-');
  }
}

/// The value of a [DateFieldDefinition]: an optional [DateTime] (stored in UTC).
class DateFieldValue extends FieldValue {
  const DateFieldValue(this.value);

  final DateTime? value;

  @override
  bool get isEmpty => value == null;

  @override
  Object? toJson() => value?.toIso8601String();

  @override
  List<Object?> get props => [value];
}
