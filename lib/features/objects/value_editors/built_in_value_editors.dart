import 'boolean_value_editor.dart';
import 'date_value_editor.dart';
import 'field_value_editor.dart';
import 'number_value_editor.dart';
import 'read_only_value_editors.dart';
import 'reference_value_editor.dart';
import 'select_value_editors.dart';
import 'text_value_editor.dart';

/// Registers a [FieldValueEditor] for every built-in field type that has one.
/// Adding a type is one line here; the form dispatches through the registry.
/// Types without a line (file, until its epic task) get the read-only fallback.
void registerBuiltInValueEditors(FieldValueEditorRegistry registry) {
  registry.register(const TextValueEditor());
  registry.register(const NumberValueEditor());
  registry.register(const BooleanValueEditor());
  registry.register(const DateValueEditor());
  registry.register(const SingleSelectValueEditor());
  registry.register(const MultiSelectValueEditor());
  registry.register(const ReferenceValueEditor());
  registry.register(const AutoNumberValueEditor());
  registry.register(const CalculatedValueEditor());
}

/// A registry pre-populated with every built-in value editor.
FieldValueEditorRegistry defaultValueEditorRegistry() {
  final registry = FieldValueEditorRegistry();
  registerBuiltInValueEditors(registry);
  return registry;
}
