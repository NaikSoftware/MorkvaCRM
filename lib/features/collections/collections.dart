/// Epic 03 — Collection Management. Single import for the collections feature:
/// the field-editor registry, the list surface, and the schema editor.
///
/// `import 'package:morkva_crm/features/collections/collections.dart';`
library;

// Field-editor registry (UI-side parallel to the domain FieldTypeRegistry).
export 'field_editors/field_editor.dart';
export 'field_editors/built_in_field_editors.dart';

// Collections list surface (the Home body).
export 'list/collections_list_cubit.dart';
export 'list/collections_list_state.dart';
export 'list/collections_list_view.dart';

// Collection schema editor (/collections/:id).
export 'editor/collection_editor_cubit.dart';
export 'editor/collection_editor_state.dart';
export 'editor/collection_editor_page.dart';
