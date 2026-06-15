import '../field_definition.dart';
import '../field_value.dart';
import '../validation.dart';
import 'select_option.dart';

/// Type discriminator for the single-select field.
const String kSingleSelectFieldType = 'single_select';

/// A field whose value is exactly one choice from a fixed [options] set.
///
/// The stored value is the chosen [SelectOption.id] (see [SingleSelectFieldValue]);
/// labels and colors live only on the definition's options. Validation ensures
/// a non-empty value references a known option id.
class SingleSelectFieldDefinition extends FieldDefinition {
  const SingleSelectFieldDefinition({
    required super.id,
    required super.name,
    super.description,
    super.isRequired,
    this.options = const [],
  });

  /// The fixed set of choices. Order is preserved for display.
  final List<SelectOption> options;

  @override
  String get type => kSingleSelectFieldType;

  /// Reconstructs a definition from its JSON map (including the common keys).
  factory SingleSelectFieldDefinition.fromJson(Map<String, dynamic> json) {
    final base = readFieldBase(json);
    final rawOptions = (json['options'] as List<dynamic>?) ?? const [];
    return SingleSelectFieldDefinition(
      id: base.id,
      name: base.name,
      description: base.description,
      isRequired: base.isRequired,
      options: rawOptions
          .map((e) => SelectOption.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  Map<String, dynamic> configToJson() => {
    'options': options.map((o) => o.toJson()).toList(),
  };

  @override
  List<Object?> get configProps => [options];

  @override
  FieldValue emptyValue() => const SingleSelectFieldValue(null);

  @override
  FieldValue valueFromJson(Object? json) =>
      SingleSelectFieldValue(json is String ? json : null);

  @override
  List<ValidationError> validateValue(FieldValue value) {
    final v = value as SingleSelectFieldValue;
    final optionId = v.optionId;
    final errors = <ValidationError>[];
    if (optionId != null && !options.any((o) => o.id == optionId)) {
      errors.add(
        ValidationError(
          fieldId: id,
          code: ValidationError.invalidOption,
          message: '$name has no option "$optionId"',
        ),
      );
    }
    return errors;
  }
}

/// The value of a [SingleSelectFieldDefinition]: an optional [SelectOption.id].
class SingleSelectFieldValue extends FieldValue {
  const SingleSelectFieldValue(this.optionId);

  final String? optionId;

  @override
  bool get isEmpty => optionId == null || optionId!.isEmpty;

  @override
  Object? toJson() => optionId;

  @override
  List<Object?> get props => [optionId];
}
