import '../field_definition.dart';
import '../field_value.dart';
import '../validation.dart';

/// Type discriminator for the calculated field.
const String kCalculatedFieldType = 'calculated';

/// A field whose value is derived from a formula rather than entered.
///
/// **Scope (Epic 1): TYPE, DECLARED OUTPUT TYPE & FORMULA PLACEHOLDER ONLY.**
/// This declares the field type, the discriminator of the type it produces
/// ([declaredOutputType]), and the raw, uncomputed formula ([expression]). The
/// actual COMPUTATION — parsing the expression, resolving referenced fields or
/// cards, evaluating, and refreshing the cached value — belongs to **Epic 6**.
/// Here the cached result is only stored and round-tripped; nothing in this
/// type evaluates anything.
///
/// Follows the reference shape established by `TextFieldDefinition`.
class CalculatedFieldDefinition extends FieldDefinition {
  const CalculatedFieldDefinition({
    required super.id,
    required super.name,
    super.description,
    super.isRequired,
    required this.declaredOutputType,
    this.expression,
  });

  /// The discriminator of the field type this calculation yields (e.g.
  /// `'number'`, `'text'`). Lets consumers format/interpret the cached value.
  final String declaredOutputType;

  /// The formula source, stored uncomputed. Evaluation is deferred to Epic 6.
  final String? expression;

  @override
  String get type => kCalculatedFieldType;

  /// Reconstructs a definition from its JSON map (including the common keys).
  factory CalculatedFieldDefinition.fromJson(Map<String, dynamic> json) {
    final base = readFieldBase(json);
    return CalculatedFieldDefinition(
      id: base.id,
      name: base.name,
      description: base.description,
      isRequired: base.isRequired,
      declaredOutputType: json['declaredOutputType'] as String,
      expression: json['expression'] as String?,
    );
  }

  @override
  Map<String, dynamic> configToJson() => {
    'declaredOutputType': declaredOutputType,
    if (expression != null) 'expression': expression,
  };

  @override
  List<Object?> get configProps => [declaredOutputType, expression];

  @override
  FieldValue emptyValue() => const CalculatedFieldValue(null);

  @override
  FieldValue valueFromJson(Object? json) => CalculatedFieldValue(json);

  /// No validation: the value is derived by the engine (Epic 6), never entered.
  @override
  List<ValidationError> validateValue(FieldValue value) =>
      const <ValidationError>[];
}

/// The value of a [CalculatedFieldDefinition]: the last-derived result.
///
/// [cached] is a JSON-compatible primitive, list, or map (whatever the
/// [CalculatedFieldDefinition.declaredOutputType] produces), stored verbatim
/// until Epic 6 recomputes it.
class CalculatedFieldValue extends FieldValue {
  const CalculatedFieldValue(this.cached);

  final Object? cached;

  @override
  bool get isEmpty => cached == null;

  @override
  Object? toJson() => cached;

  @override
  List<Object?> get props => [cached];
}
