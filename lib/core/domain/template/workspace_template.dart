import '../collection.dart';
import '../field_type_registry.dart';
import '../morkva_object.dart';

/// A ready-made set of collections (with their views and calculations) and
/// sample objects, written in the engine's own JSON. A template is data: the
/// app knows nothing about what it models.
///
/// Inside a template, every collection and object id starts with `@` (e.g.
/// `@orders`, `@o1`). [instantiate] swaps each for a fresh id wherever it
/// appears — reference targets, aggregates, reference values, view orders —
/// so the same template can be added any number of times.
class WorkspaceTemplate {
  const WorkspaceTemplate({
    required this.id,
    required this.name,
    required this.description,
    this.icon,
    required this.collections,
    this.objects = const [],
  });

  final String id;
  final String name;
  final String description;

  /// A collection icon id (see `collection_icons.dart`).
  final String? icon;

  /// Collection JSON, as stored.
  final List<Map<String, dynamic>> collections;

  /// Sample objects: `{id, collectionId, values}`, values as stored.
  final List<Map<String, dynamic>> objects;

  List<String> get collectionNames => [
    for (final c in collections) c['name'] as String,
  ];

  factory WorkspaceTemplate.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> maps(Object? raw) => [
      for (final m in (raw as List?) ?? const []) (m as Map).cast(),
    ];
    final template = WorkspaceTemplate(
      id: json['id'] as String,
      name: json['name'] as String,
      description: (json['description'] as String?) ?? '',
      icon: json['icon'] as String?,
      collections: maps(json['collections']),
      objects: maps(json['objects']),
    );
    for (final id in [
      for (final c in template.collections) c['id'],
      for (final o in template.objects) o['id'],
    ]) {
      if (id is! String || !id.startsWith('@')) {
        throw FormatException('Template ids must start with "@": $id');
      }
    }
    return template;
  }

  /// The collections and objects to write, with fresh ids from
  /// [collectionId] / [objectId], created at [now].
  ({List<Collection> collections, List<MorkvaObject> objects}) instantiate(
    FieldTypeRegistry registry, {
    required String Function() collectionId,
    required String Function() objectId,
    required DateTime now,
  }) {
    final ids = <String, String>{
      for (final c in collections) c['id'] as String: collectionId(),
      for (final o in objects) o['id'] as String: objectId(),
    };
    Object? swap(Object? node) => switch (node) {
      final String s => ids[s] ?? s,
      final List<Object?> l => [for (final e in l) swap(e)],
      final Map<Object?, Object?> m => {
        for (final e in m.entries) e.key as String: swap(e.value),
      },
      _ => node,
    };
    final built = [
      for (final c in collections)
        Collection.fromJson(
          (swap(c)! as Map).cast<String, dynamic>(),
          registry,
        ),
    ];
    final byId = {for (final c in built) c.id: c};
    final stamp = now.toUtc().toIso8601String();
    return (
      collections: built,
      objects: [
        for (final o in objects)
          () {
            final json = (swap(o)! as Map).cast<String, dynamic>();
            final collection = byId[json['collectionId']];
            if (collection == null) {
              throw FormatException('Unknown collection ${o['collectionId']}');
            }
            return MorkvaObject.fromJson({
              ...json,
              'createdAt': stamp,
              'updatedAt': stamp,
            }, collection);
          }(),
      ],
    );
  }
}
