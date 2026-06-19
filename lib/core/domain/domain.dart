/// MorkvaCRM core domain model — the universal "collections of objects with
/// typed fields" engine. Pure Dart, no UI and no persistence: every later epic
/// renders or stores these types.
library;

export 'built_in_field_types.dart';
export 'card_layout.dart';
export 'collection.dart';
export 'field_definition.dart';
export 'field_type_registry.dart';
export 'field_value.dart';
export 'morkva_object.dart';
export 'validation.dart';
// Field types.
export 'types/auto_number_field.dart';
export 'types/boolean_field.dart';
export 'types/calculated_field.dart';
export 'types/date_field.dart';
export 'types/file_field.dart';
export 'types/multi_select_field.dart';
export 'types/number_field.dart';
export 'types/reference_field.dart';
export 'types/select_option.dart';
export 'types/single_select_field.dart';
export 'types/text_field.dart';
