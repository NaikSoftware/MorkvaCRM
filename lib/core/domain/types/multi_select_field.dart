import '../field_definition.dart';
import '../field_value.dart';
import '../validation.dart';
import 'select_option.dart';

/// Type discriminator for the multi-select / tags field.
const String kMultiSelectFieldType = 'multi_select';

/// A field whose value is a set of choices drawn from a fixed [options] list
/// (rendered as tags/chips).
///
/// Follows the reference shape established by `TextFieldDefinition`: the
/// definition serializes its own config ([options]), parses/produces a matching
/// [MultiSelectFieldValue], and validates its own rule — every selected id must
/// reference a known option. Order of selected ids is preserved as authored.
class MultiSelectFieldDefinition extends FieldDefinition {
  const MultiSelectFieldDefinition({
    required super.id,
    required super.name,
    super.description,
    super.isRequired,
    this.options = const [],
  });

  /// The fixed set of selectable options. Selected values store [SelectOption.id].
  final List<SelectOption> options;

  @override
  String get type => kMultiSelectFieldType;

  /// Reconstructs a definition from its JSON map (including the common keys).
  factory MultiSelectFieldDefinition.fromJson(Map<String, dynamic> json) {
    final base = readFieldBase(json);
    final rawOptions = json['options'] as List<dynamic>? ?? const [];
    return MultiSelectFieldDefinition(
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
  FieldValue emptyValue() => const MultiSelectFieldValue();

  @override
  FieldValue valueFromJson(Object? json) {
    if (json is List) {
      return MultiSelectFieldValue(json.whereType<String>().toList());
    }
    return const MultiSelectFieldValue();
  }

  @override
  List<ValidationError> validateValue(FieldValue value) {
    final v = value as MultiSelectFieldValue;
    final validIds = options.map((o) => o.id).toSet();
    final errors = <ValidationError>[];
    for (final optionId in v.optionIds) {
      if (!validIds.contains(optionId)) {
        errors.add(
          ValidationError(
            fieldId: id,
            code: ValidationError.invalidOption,
            message: '"$optionId" is not a valid option for $name',
          ),
        );
      }
    }
    return errors;
  }
}

/// The value of a [MultiSelectFieldDefinition]: the ids of the selected options.
class MultiSelectFieldValue extends FieldValue {
  const MultiSelectFieldValue([this.optionIds = const []]);

  /// The selected [SelectOption.id]s, in authored order.
  final List<String> optionIds;

  @override
  bool get isEmpty => optionIds.isEmpty;

  @override
  Object? toJson() => optionIds;

  @override
  List<Object?> get props => [optionIds];
}
