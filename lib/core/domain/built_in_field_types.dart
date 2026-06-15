import 'field_type_registry.dart';
import 'types/text_field.dart';

/// Registers all field types that ship with the engine onto [registry].
///
/// Enabling a new built-in field type is exactly one line here — existing types
/// and the generic serialization are untouched, demonstrating the type system's
/// openness for extension.
void registerBuiltInFieldTypes(FieldTypeRegistry registry) {
  registry.register(kTextFieldType, TextFieldDefinition.fromJson);
  // Additional built-in field types are registered below as they are added.
}

/// A registry pre-populated with every built-in field type.
FieldTypeRegistry defaultFieldTypeRegistry() {
  final registry = FieldTypeRegistry();
  registerBuiltInFieldTypes(registry);
  return registry;
}
