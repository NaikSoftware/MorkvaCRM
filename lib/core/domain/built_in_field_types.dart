import 'field_type_registry.dart';
import 'types/auto_number_field.dart';
import 'types/boolean_field.dart';
import 'types/calculated_field.dart';
import 'types/date_field.dart';
import 'types/file_field.dart';
import 'types/multi_select_field.dart';
import 'types/number_field.dart';
import 'types/reference_field.dart';
import 'types/single_select_field.dart';
import 'types/text_field.dart';

/// Registers all field types that ship with the engine onto [registry].
///
/// Enabling a new built-in field type is exactly one line here — existing types
/// and the generic serialization are untouched, demonstrating the type system's
/// openness for extension.
void registerBuiltInFieldTypes(FieldTypeRegistry registry) {
  registry.register(kTextFieldType, TextFieldDefinition.fromJson);
  registry.register(kNumberFieldType, NumberFieldDefinition.fromJson);
  registry.register(kBooleanFieldType, BooleanFieldDefinition.fromJson);
  registry.register(kDateFieldType, DateFieldDefinition.fromJson);
  registry.register(
    kSingleSelectFieldType,
    SingleSelectFieldDefinition.fromJson,
  );
  registry.register(kMultiSelectFieldType, MultiSelectFieldDefinition.fromJson);
  registry.register(kReferenceFieldType, ReferenceFieldDefinition.fromJson);
  registry.register(kFileFieldType, FileFieldDefinition.fromJson);
  registry.register(kAutoNumberFieldType, AutoNumberFieldDefinition.fromJson);
  registry.register(kCalculatedFieldType, CalculatedFieldDefinition.fromJson);
}

/// A registry pre-populated with every built-in field type.
FieldTypeRegistry defaultFieldTypeRegistry() {
  final registry = FieldTypeRegistry();
  registerBuiltInFieldTypes(registry);
  return registry;
}
