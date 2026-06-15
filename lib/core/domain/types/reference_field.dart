import '../field_definition.dart';
import '../field_value.dart';
import '../validation.dart';

/// Type discriminator for the reference field.
const String kReferenceFieldType = 'reference';

/// Validation code for a single-reference field that received more than one id.
const String kTooManyReferencesCode = 'too_many_references';

/// A field that links to one or more objects in another collection.
///
/// Follows the reference shape established by `TextFieldDefinition`: the
/// definition serializes its own config ([targetCollectionId], [multiple]),
/// parses/produces a matching [ReferenceFieldValue], and validates its own
/// rules.
///
/// The value always stores a *list* of referenced object ids; a single
/// reference is simply a list of length ≤ 1. Validation here is purely
/// structural — ids must be non-empty strings, and a non-[multiple] field may
/// hold at most one id. Verifying that a referenced object actually EXISTS in
/// the target collection is deferred to Epic 6 (cross-collection integrity) and
/// is intentionally not performed here.
class ReferenceFieldDefinition extends FieldDefinition {
  const ReferenceFieldDefinition({
    required super.id,
    required super.name,
    super.description,
    super.isRequired,
    required this.targetCollectionId,
    this.multiple = false,
  });

  /// The id of the collection whose objects this field references.
  final String targetCollectionId;

  /// Whether the field may reference more than one object.
  final bool multiple;

  @override
  String get type => kReferenceFieldType;

  /// Reconstructs a definition from its JSON map (including the common keys).
  factory ReferenceFieldDefinition.fromJson(Map<String, dynamic> json) {
    final base = readFieldBase(json);
    return ReferenceFieldDefinition(
      id: base.id,
      name: base.name,
      description: base.description,
      isRequired: base.isRequired,
      targetCollectionId: json['targetCollectionId'] as String,
      multiple: (json['multiple'] as bool?) ?? false,
    );
  }

  @override
  Map<String, dynamic> configToJson() => {
    'targetCollectionId': targetCollectionId,
    'multiple': multiple,
  };

  @override
  List<Object?> get configProps => [targetCollectionId, multiple];

  @override
  FieldValue emptyValue() => const ReferenceFieldValue();

  @override
  FieldValue valueFromJson(Object? json) {
    if (json is List) {
      return ReferenceFieldValue(json.whereType<String>().toList());
    }
    if (json is String) {
      return ReferenceFieldValue([json]);
    }
    return const ReferenceFieldValue();
  }

  @override
  List<ValidationError> validateValue(FieldValue value) {
    final v = value as ReferenceFieldValue;
    final errors = <ValidationError>[];
    for (final objectId in v.objectIds) {
      if (objectId.isEmpty) {
        errors.add(
          ValidationError(
            fieldId: id,
            code: ValidationError.invalidReference,
            message: '$name contains a blank reference',
          ),
        );
      }
    }
    if (!multiple && v.objectIds.length > 1) {
      errors.add(
        ValidationError(
          fieldId: id,
          code: kTooManyReferencesCode,
          message: '$name may reference at most one object',
        ),
      );
    }
    return errors;
  }
}

/// The value of a [ReferenceFieldDefinition]: the ids of the referenced objects.
///
/// Always a list, regardless of whether the field is single- or multi-valued.
class ReferenceFieldValue extends FieldValue {
  const ReferenceFieldValue([this.objectIds = const []]);

  /// The referenced object ids, in authored order.
  final List<String> objectIds;

  @override
  bool get isEmpty => objectIds.isEmpty;

  @override
  Object? toJson() => objectIds;

  @override
  List<Object?> get props => [objectIds];
}
