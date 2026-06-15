import '../field_definition.dart';
import '../field_value.dart';
import '../validation.dart';

/// Type discriminator for the number field.
const String kNumberFieldType = 'number';

/// A numeric field holding an optional [num] (int or double).
///
/// Follows the reference shape established by `TextFieldDefinition`: the
/// definition serializes its own config ([decimalPlaces], [unitLabel], [min],
/// [max]), parses/produces a matching [NumberFieldValue], and validates its own
/// range rules. [decimalPlaces] and [unitLabel] are display hints and are not
/// validated.
class NumberFieldDefinition extends FieldDefinition {
  const NumberFieldDefinition({
    required super.id,
    required super.name,
    super.description,
    super.isRequired,
    this.decimalPlaces,
    this.unitLabel,
    this.min,
    this.max,
  });

  /// Display precision (number of fractional digits). Pure UI hint.
  final int? decimalPlaces;

  /// Optional unit label shown next to the value (e.g. `kg`, `$`). UI hint.
  final String? unitLabel;

  /// Optional inclusive lower bound.
  final num? min;

  /// Optional inclusive upper bound.
  final num? max;

  @override
  String get type => kNumberFieldType;

  /// Reconstructs a definition from its JSON map (including the common keys).
  factory NumberFieldDefinition.fromJson(Map<String, dynamic> json) {
    final base = readFieldBase(json);
    return NumberFieldDefinition(
      id: base.id,
      name: base.name,
      description: base.description,
      isRequired: base.isRequired,
      decimalPlaces: json['decimalPlaces'] as int?,
      unitLabel: json['unitLabel'] as String?,
      min: json['min'] as num?,
      max: json['max'] as num?,
    );
  }

  @override
  Map<String, dynamic> configToJson() => {
    if (decimalPlaces != null) 'decimalPlaces': decimalPlaces,
    if (unitLabel != null) 'unitLabel': unitLabel,
    if (min != null) 'min': min,
    if (max != null) 'max': max,
  };

  @override
  List<Object?> get configProps => [decimalPlaces, unitLabel, min, max];

  @override
  FieldValue emptyValue() => const NumberFieldValue(null);

  @override
  FieldValue valueFromJson(Object? json) =>
      NumberFieldValue(json is num ? json : null);

  @override
  List<ValidationError> validateValue(FieldValue value) {
    final v = value as NumberFieldValue;
    final number = v.value;
    final errors = <ValidationError>[];
    if (number != null) {
      if (min != null && number < min!) {
        errors.add(
          ValidationError(
            fieldId: id,
            code: ValidationError.outOfRange,
            message: '$name must be at least $min',
          ),
        );
      }
      if (max != null && number > max!) {
        errors.add(
          ValidationError(
            fieldId: id,
            code: ValidationError.outOfRange,
            message: '$name must be at most $max',
          ),
        );
      }
    }
    return errors;
  }
}

/// The value of a [NumberFieldDefinition]: an optional [num].
///
/// Preserves the int-vs-double distinction of its source: an `int` stays an
/// `int`, a `double` stays a `double`.
class NumberFieldValue extends FieldValue {
  const NumberFieldValue(this.value);

  final num? value;

  @override
  bool get isEmpty => value == null;

  @override
  Object? toJson() => value;

  @override
  List<Object?> get props => [value];
}
