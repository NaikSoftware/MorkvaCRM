import 'package:equatable/equatable.dart';

import 'field_definition.dart';
import 'field_type_registry.dart';

/// The on-disk schema version for a serialized collection. Written into every
/// collection JSON so the model can evolve while staying forward-compatible:
/// readers tolerate unknown keys and may branch on this version.
const int kCollectionSchemaVersion = 1;

/// A named set of objects sharing an ordered field schema.
///
/// The collection is purely the *schema and identity*; object data lives in
/// [MorkvaObject]. The collection knows nothing about any business domain — it
/// is a list of typed [FieldDefinition]s.
class Collection extends Equatable {
  const Collection({
    required this.id,
    required this.name,
    this.description,
    this.fields = const [],
  });

  final String id;
  final String name;
  final String? description;

  /// The ordered field schema. Order is significant (UI render order).
  final List<FieldDefinition> fields;

  /// The field with [fieldId], or `null` if the schema has no such field.
  FieldDefinition? fieldById(String fieldId) {
    for (final field in fields) {
      if (field.id == fieldId) return field;
    }
    return null;
  }

  Collection copyWith({
    String? id,
    String? name,
    String? description,
    List<FieldDefinition>? fields,
  }) => Collection(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description ?? this.description,
    fields: fields ?? this.fields,
  );

  Map<String, dynamic> toJson() => {
    'schemaVersion': kCollectionSchemaVersion,
    'id': id,
    'name': name,
    if (description != null) 'description': description,
    'fields': fields.map((f) => f.toJson()).toList(),
  };

  /// Reconstructs a collection, resolving each field definition through
  /// [registry]. Unknown top-level keys are tolerated (forward compatibility).
  factory Collection.fromJson(
    Map<String, dynamic> json,
    FieldTypeRegistry registry,
  ) {
    final rawFields = (json['fields'] as List?) ?? const [];
    return Collection(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      fields: rawFields
          .cast<Map<String, dynamic>>()
          .map(registry.definitionFromJson)
          .toList(),
    );
  }

  @override
  List<Object?> get props => [id, name, description, fields];
}
