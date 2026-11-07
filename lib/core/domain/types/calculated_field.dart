import '../calc/aggregation.dart';
import '../field_definition.dart';
import '../field_value.dart';
import '../validation.dart';
import 'boolean_field.dart';
import 'date_field.dart';
import 'number_field.dart';
import 'text_field.dart';

/// Type discriminator for the calculated field.
const String kCalculatedFieldType = 'calculated';

/// A field whose value is derived, never entered: a per-object formula
/// ([expression]), a summary over other objects ([aggregate]) or a field of
/// the referenced object ([lookup]).
///
/// Values are computed on read by `Derivation` and never stored; the
/// [CalculatedFieldValue] it produces holds the JSON form of the result.
/// [declaredOutputType] (the type of the result) drives formatting, filters
/// and sorting through [outputField] / [outputValue].
class CalculatedFieldDefinition extends FieldDefinition {
  const CalculatedFieldDefinition({
    required super.id,
    required super.name,
    super.description,
    super.isRequired,
    required this.declaredOutputType,
    this.expression,
    this.aggregate,
    this.lookup,
    this.lookupTarget,
    this.decimalPlaces,
    this.unitLabel,
  });

  /// The discriminator of the type the calculation yields: `number`, `text`,
  /// `boolean` or `date` (date-only); for a lookup, the shown field's type.
  final String declaredOutputType;

  /// The formula source, field refs stored as `{fieldId}`. Ignored when
  /// [aggregate] is set.
  final String? expression;

  /// The summary this field computes, or null for a formula.
  final Aggregation? aggregate;

  /// The referenced field this field shows; wins over [aggregate].
  final Lookup? lookup;

  /// The field [lookup] shows (as it presents), filled in memory by
  /// [resolveLookups]; never stored.
  final FieldDefinition? lookupTarget;

  /// Display precision of a number result.
  final int? decimalPlaces;

  /// Unit shown after a number result.
  final String? unitLabel;

  bool get isLookup => lookup != null;

  bool get isAggregate => !isLookup && aggregate != null;

  @override
  String get type => kCalculatedFieldType;

  factory CalculatedFieldDefinition.fromJson(Map<String, dynamic> json) {
    final base = readFieldBase(json);
    final aggregate = json['aggregate'];
    return CalculatedFieldDefinition(
      id: base.id,
      name: base.name,
      description: base.description,
      isRequired: base.isRequired,
      declaredOutputType:
          (json['declaredOutputType'] as String?) ?? kNumberFieldType,
      expression: json['expression'] as String?,
      aggregate: aggregate is Map
          ? Aggregation.fromJson(aggregate.cast<String, dynamic>())
          : null,
      lookup: json['lookup'] is Map
          ? Lookup.fromJson((json['lookup'] as Map).cast<String, dynamic>())
          : null,
      decimalPlaces: (json['decimalPlaces'] as num?)?.toInt(),
      unitLabel: json['unitLabel'] as String?,
    );
  }

  static const Object _unset = Object();

  CalculatedFieldDefinition copyWith({
    String? declaredOutputType,
    Object? expression = _unset,
    Object? aggregate = _unset,
    Object? lookup = _unset,
    Object? lookupTarget = _unset,
    Object? decimalPlaces = _unset,
    Object? unitLabel = _unset,
  }) => CalculatedFieldDefinition(
    id: id,
    name: name,
    description: description,
    isRequired: isRequired,
    declaredOutputType: declaredOutputType ?? this.declaredOutputType,
    expression: identical(expression, _unset)
        ? this.expression
        : expression as String?,
    aggregate: identical(aggregate, _unset)
        ? this.aggregate
        : aggregate as Aggregation?,
    lookup: identical(lookup, _unset) ? this.lookup : lookup as Lookup?,
    lookupTarget: identical(lookupTarget, _unset)
        ? this.lookupTarget
        : lookupTarget as FieldDefinition?,
    decimalPlaces: identical(decimalPlaces, _unset)
        ? this.decimalPlaces
        : decimalPlaces as int?,
    unitLabel: identical(unitLabel, _unset)
        ? this.unitLabel
        : unitLabel as String?,
  );

  @override
  Map<String, dynamic> configToJson() => {
    'declaredOutputType': declaredOutputType,
    if (expression != null) 'expression': expression,
    if (aggregate != null) 'aggregate': aggregate!.toJson(),
    if (lookup != null) 'lookup': lookup!.toJson(),
    if (decimalPlaces != null) 'decimalPlaces': decimalPlaces,
    if (unitLabel != null) 'unitLabel': unitLabel,
  };

  @override
  List<Object?> get configProps => [
    declaredOutputType,
    expression,
    aggregate,
    lookup,
    lookupTarget,
    decimalPlaces,
    unitLabel,
  ];

  /// A plain definition of the result's type (same id and name), so display,
  /// filters and sorting treat the value like that type's. A resolved lookup
  /// presents as the field it shows (its options, decimals, unit — and its
  /// id and name, so read ids off this field, not the output).
  FieldDefinition get outputField => switch (declaredOutputType) {
    _ when isLookup && lookupTarget != null => lookupTarget!,
    kNumberFieldType => NumberFieldDefinition(
      id: id,
      name: name,
      decimalPlaces: decimalPlaces,
      unitLabel: unitLabel,
    ),
    kBooleanFieldType => BooleanFieldDefinition(id: id, name: name),
    // shortcut: date results are calendar days only; add an includeTime
    // config when a formula needs to produce instants.
    kDateFieldType => DateFieldDefinition(id: id, name: name),
    _ => TextFieldDefinition(id: id, name: name),
  };

  /// [value] as a value of [outputField].
  FieldValue outputValue(FieldValue value) => outputField.valueFromJson(
    value is CalculatedFieldValue ? value.cached : null,
  );

  @override
  FieldValue emptyValue() => const CalculatedFieldValue(null);

  @override
  FieldValue valueFromJson(Object? json) => CalculatedFieldValue(json);

  /// No validation: the value is derived, never entered.
  @override
  List<ValidationError> validateValue(FieldValue value) =>
      const <ValidationError>[];
}

/// The value of a [CalculatedFieldDefinition]: the derived result in JSON
/// form (num, String, bool, or an ISO date string), or null when blank.
class CalculatedFieldValue extends FieldValue {
  const CalculatedFieldValue(this.cached);

  final Object? cached;

  @override
  bool get isEmpty => cached == null || cached == '';

  @override
  Object? toJson() => cached;

  @override
  List<Object?> get props => [cached];
}

/// [field] and [value] as the type they present as: a calculated field's
/// output type, anything else unchanged.
(FieldDefinition, FieldValue) presentedAs(
  FieldDefinition field,
  FieldValue value,
) => field is CalculatedFieldDefinition
    ? (field.outputField, field.outputValue(value))
    : (field, value);
