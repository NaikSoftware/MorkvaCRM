import 'package:equatable/equatable.dart';

import 'card_layout.dart';
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
    this.icon,
    this.fields = const [],
    this.layout = const CardLayout(),
  });

  final String id;
  final String name;
  final String? description;

  /// Stable key into the curated collection-icon catalog (e.g. `"truck"`), or
  /// `null` when the user has not chosen one (renders the default glyph). A key
  /// rather than a raw glyph so it serializes cleanly and survives icon-font
  /// changes; unknown keys fall back to the default at render time.
  final String? icon;

  /// The ordered field schema. Order is significant (UI render order).
  final List<FieldDefinition> fields;

  /// The presentation layout (sections → rows → cells) over [fields].
  /// Pure presentation; reconciled against [fields] on load.
  final CardLayout layout;

  /// The field with [fieldId], or `null` if the schema has no such field.
  FieldDefinition? fieldById(String fieldId) {
    for (final field in fields) {
      if (field.id == fieldId) return field;
    }
    return null;
  }

  /// Sentinel default for [copyWith]'s nullable [description], so passing an
  /// explicit `null` clears it while omitting the argument preserves it.
  static const Object _unset = Object();

  /// Returns a copy with the given overrides.
  ///
  /// [description] uses a sentinel default so `copyWith(description: null)`
  /// actually clears the description, while omitting it preserves the current
  /// value (a plain `?? this.description` could never null an existing value).
  Collection copyWith({
    String? id,
    String? name,
    Object? description = _unset,
    Object? icon = _unset,
    List<FieldDefinition>? fields,
    CardLayout? layout,
  }) => Collection(
    id: id ?? this.id,
    name: name ?? this.name,
    description: identical(description, _unset)
        ? this.description
        : description as String?,
    icon: identical(icon, _unset) ? this.icon : icon as String?,
    fields: fields ?? this.fields,
    layout: layout ?? this.layout,
  );

  Map<String, dynamic> toJson() => {
    'schemaVersion': kCollectionSchemaVersion,
    'id': id,
    'name': name,
    if (description != null) 'description': description,
    if (icon != null) 'icon': icon,
    'fields': fields.map((f) => f.toJson()).toList(),
    'layout': layout.toJson(),
  };

  /// Reconstructs a collection, resolving each field definition through
  /// [registry]. Unknown top-level keys are tolerated (forward compatibility).
  factory Collection.fromJson(
    Map<String, dynamic> json,
    FieldTypeRegistry registry,
  ) {
    final rawFields = (json['fields'] as List?) ?? const [];
    final fields = rawFields
        .cast<Map<String, dynamic>>()
        .map(registry.definitionFromJson)
        .toList();
    final fieldIds = fields.map((f) => f.id).toList();
    final rawLayout = json['layout'] as Map<String, dynamic>?;
    final layout = rawLayout == null
        ? CardLayout.synthesize(fieldIds)
        : CardLayout.fromJson(rawLayout).reconcile(fieldIds);
    return Collection(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      icon: json['icon'] as String?,
      fields: fields,
      layout: layout,
    );
  }

  @override
  List<Object?> get props => [id, name, description, icon, fields, layout];
}
