import 'package:equatable/equatable.dart';

import 'collection.dart';
import 'field_value.dart';
import 'validation.dart';

/// One item ("card") in a [Collection]: a map of field-id → typed [FieldValue]
/// plus identity and timestamps.
///
/// An object's value map is *normalized* against its collection's schema: it
/// holds exactly one entry per field in the schema (empty values for unset
/// fields). Build objects with [MorkvaObject.create] to get this normalization;
/// [fromJson] applies it on read. This is what makes serialization round-trip
/// identically.
class MorkvaObject extends Equatable {
  const MorkvaObject({
    required this.id,
    required this.collectionId,
    required this.values,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String collectionId;

  /// field-id → value. Normalized to one entry per schema field.
  final Map<String, FieldValue> values;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// Creates an object normalized against [collection]'s schema: every field
  /// gets an entry, defaulting to the field's empty value when [values] omits
  /// it. Timestamps are stored in UTC. Values for ids not in the schema are
  /// dropped.
  factory MorkvaObject.create({
    required String id,
    required Collection collection,
    Map<String, FieldValue> values = const {},
    required DateTime createdAt,
    required DateTime updatedAt,
  }) {
    final normalized = <String, FieldValue>{};
    for (final field in collection.fields) {
      normalized[field.id] = values[field.id] ?? field.emptyValue();
    }
    return MorkvaObject(
      id: id,
      collectionId: collection.id,
      values: normalized,
      createdAt: createdAt.toUtc(),
      updatedAt: updatedAt.toUtc(),
    );
  }

  /// The value for [fieldId], or `null` if absent from the value map.
  FieldValue? operator [](String fieldId) => values[fieldId];

  MorkvaObject copyWith({
    Map<String, FieldValue>? values,
    DateTime? updatedAt,
  }) => MorkvaObject(
    id: id,
    collectionId: collectionId,
    values: values ?? this.values,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  /// Validates every field value against [collection]'s schema.
  ValidationResult validateAgainst(Collection collection) {
    final errors = <ValidationError>[];
    for (final field in collection.fields) {
      final value = values[field.id] ?? field.emptyValue();
      errors.addAll(field.validate(value));
    }
    return ValidationResult(errors);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'collectionId': collectionId,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'values': {
      for (final entry in values.entries) entry.key: entry.value.toJson(),
    },
  };

  /// Reconstructs an object, parsing each value through the matching field
  /// definition in [collection]. Missing values become the field's empty value;
  /// stored values for fields no longer in the schema are dropped (graceful
  /// schema evolution).
  factory MorkvaObject.fromJson(
    Map<String, dynamic> json,
    Collection collection,
  ) {
    final rawValues =
        (json['values'] as Map?)?.cast<String, dynamic>() ?? const {};
    final values = <String, FieldValue>{};
    for (final field in collection.fields) {
      values[field.id] = field.valueFromJson(rawValues[field.id]);
    }
    return MorkvaObject(
      id: json['id'] as String,
      collectionId: json['collectionId'] as String,
      values: values,
      createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
      updatedAt: DateTime.parse(json['updatedAt'] as String).toUtc(),
    );
  }

  @override
  List<Object?> get props => [id, collectionId, values, createdAt, updatedAt];
}
