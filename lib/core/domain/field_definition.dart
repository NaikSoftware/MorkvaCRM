import 'package:equatable/equatable.dart';

import 'field_value.dart';
import 'validation.dart';

/// Common, parsed base attributes shared by every field definition.
///
/// Field types use [readFieldBase] inside their `fromJson` factories to read
/// the shared envelope keys, then read their own config keys directly.
typedef FieldBase = ({
  String id,
  String name,
  String? description,
  bool isRequired,
});

/// Reads the common field-definition keys from a JSON map.
FieldBase readFieldBase(Map<String, dynamic> json) => (
  id: json['id'] as String,
  name: json['name'] as String,
  description: json['description'] as String?,
  isRequired: (json['required'] as bool?) ?? false,
);

/// Defines one typed slot in a [Collection]'s schema.
///
/// A definition is the *schema*; the per-object data lives in [FieldValue]s.
/// Each concrete field type is self-contained: it serializes its own config,
/// parses and produces its own value type, and validates its own rules. Adding
/// a new field type therefore requires no changes to existing types or to the
/// generic [Collection]/object serialization — only a new subclass plus one
/// registration line (see `FieldTypeRegistry`).
///
/// Subclasses implement [type], [configToJson], [configProps], [valueFromJson],
/// [emptyValue], and [validateValue]. The common envelope ([toJson]), the
/// `required` check ([validate]), and value-equality ([props]) are handled here.
abstract class FieldDefinition extends Equatable {
  const FieldDefinition({
    required this.id,
    required this.name,
    this.description,
    this.isRequired = false,
  });

  /// Stable identifier, unique within a collection. Object values key off this.
  final String id;

  /// Human-readable label.
  final String name;

  /// Optional help text.
  final String? description;

  /// Whether an empty value fails validation.
  final bool isRequired;

  /// The registered type discriminator written as `"type"` in JSON
  /// (e.g. `"text"`, `"number"`). Must be unique per field type.
  String get type;

  /// Per-type configuration, excluding the common envelope keys. Returned map
  /// is merged into [toJson] after the common keys.
  Map<String, dynamic> configToJson();

  /// Per-type properties for value-equality, excluding the common attributes.
  List<Object?> get configProps;

  /// Parses a raw stored JSON value into this field's [FieldValue]. Must accept
  /// `null` (missing value) and return an empty value rather than throwing.
  FieldValue valueFromJson(Object? json);

  /// The empty/default value for this field type.
  FieldValue emptyValue();

  /// Type-specific validation. The generic `required` check is applied by
  /// [validate]; implementations need only validate their own constraints and
  /// may assume non-empty values still pass through here.
  List<ValidationError> validateValue(FieldValue value);

  /// The complete on-disk representation of this definition.
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (description != null) 'description': description,
    'type': type,
    'required': isRequired,
    ...configToJson(),
  };

  /// Validates [value] against this field: the common `required` rule plus the
  /// type-specific rules from [validateValue].
  List<ValidationError> validate(FieldValue value) {
    final errors = <ValidationError>[];
    if (isRequired && value.isEmpty) {
      errors.add(
        ValidationError(
          fieldId: id,
          code: ValidationError.requiredCode,
          message: '$name is required',
        ),
      );
    }
    errors.addAll(validateValue(value));
    return errors;
  }

  @override
  List<Object?> get props => [
    id,
    name,
    description,
    isRequired,
    type,
    ...configProps,
  ];
}
