import 'package:equatable/equatable.dart';

/// The polymorphic value held by an [object]'s field.
///
/// Each [FieldDefinition] type pairs with exactly one [FieldValue] subtype.
/// A value knows how to report emptiness and serialize itself to a
/// JSON-compatible representation; parsing back is the responsibility of the
/// owning field definition (which holds the type information).
///
/// Subtypes MUST be immutable and value-equal (extend [Equatable] via this
/// base). A missing/unset value is represented by an empty instance, never by
/// a `null` [FieldValue].
abstract class FieldValue extends Equatable {
  const FieldValue();

  /// Whether this value is considered empty/unset for required-field checks.
  bool get isEmpty;

  bool get isNotEmpty => !isEmpty;

  /// A JSON-serializable representation (primitive, list, or map). May be
  /// `null` when the value is empty.
  Object? toJson();
}
