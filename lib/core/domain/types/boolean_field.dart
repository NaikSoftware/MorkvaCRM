import '../field_definition.dart';
import '../field_value.dart';
import '../validation.dart';

/// Type discriminator for the boolean field.
const String kBooleanFieldType = 'boolean';

/// A boolean (true/false) field holding an optional [bool].
///
/// Follows the reference shape established by `TextFieldDefinition`. It carries
/// no type-specific config and has no type-specific validation rules — the
/// generic `required` check (an unset value is empty) is handled by the base.
class BooleanFieldDefinition extends FieldDefinition {
  const BooleanFieldDefinition({
    required super.id,
    required super.name,
    super.description,
    super.isRequired,
  });

  @override
  String get type => kBooleanFieldType;

  /// Reconstructs a definition from its JSON map (including the common keys).
  factory BooleanFieldDefinition.fromJson(Map<String, dynamic> json) {
    final base = readFieldBase(json);
    return BooleanFieldDefinition(
      id: base.id,
      name: base.name,
      description: base.description,
      isRequired: base.isRequired,
    );
  }

  @override
  Map<String, dynamic> configToJson() => const {};

  @override
  List<Object?> get configProps => const [];

  @override
  FieldValue emptyValue() => const BooleanFieldValue(null);

  @override
  FieldValue valueFromJson(Object? json) =>
      BooleanFieldValue(json is bool ? json : null);

  @override
  List<ValidationError> validateValue(FieldValue value) {
    // No type-specific rules; the `required` check is applied by the base.
    return const [];
  }
}

/// The value of a [BooleanFieldDefinition]: an optional [bool].
class BooleanFieldValue extends FieldValue {
  const BooleanFieldValue(this.value);

  final bool? value;

  @override
  bool get isEmpty => value == null;

  @override
  Object? toJson() => value;

  @override
  List<Object?> get props => [value];
}
