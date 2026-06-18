import 'auto_number_field_editor.dart';
import 'boolean_field_editor.dart';
import 'calculated_field_editor.dart';
import 'date_field_editor.dart';
import 'field_editor.dart';
import 'file_field_editor.dart';
import 'multi_select_field_editor.dart';
import 'number_field_editor.dart';
import 'reference_field_editor.dart';
import 'single_select_field_editor.dart';
import 'text_field_editor.dart';

/// Registers a [FieldEditor] for every built-in field type onto [registry].
///
/// The UI-layer mirror of `registerBuiltInFieldTypes`. Registration order is
/// the type-picker order: the everyday scalar types first, structured types
/// next, then the declared-only computed types last. Adding a field type is one
/// line here — the editor screen and field rows dispatch through the registry
/// and never name a concrete type.
void registerBuiltInFieldEditors(FieldEditorRegistry registry) {
  registry.register(const TextFieldEditor());
  registry.register(const NumberFieldEditor());
  registry.register(const BooleanFieldEditor());
  registry.register(const DateFieldEditor());
  registry.register(const SingleSelectFieldEditor());
  registry.register(const MultiSelectFieldEditor());
  registry.register(const ReferenceFieldEditor());
  registry.register(const FileFieldEditor());
  registry.register(const AutoNumberFieldEditor());
  registry.register(const CalculatedFieldEditor());
}

/// A registry pre-populated with every built-in field editor.
FieldEditorRegistry defaultFieldEditorRegistry() {
  final registry = FieldEditorRegistry();
  registerBuiltInFieldEditors(registry);
  return registry;
}
