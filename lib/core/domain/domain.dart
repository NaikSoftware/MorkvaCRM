/// MorkvaCRM core domain model — the universal "collections of objects with
/// typed fields" engine. Pure Dart, no UI and no persistence: every later epic
/// renders or stores these types.
library;

export 'built_in_field_types.dart';
export 'collection.dart';
export 'field_definition.dart';
export 'field_type_registry.dart';
export 'field_value.dart';
export 'morkva_object.dart';
export 'validation.dart';
// Field types.
export 'types/select_option.dart';
export 'types/text_field.dart';
