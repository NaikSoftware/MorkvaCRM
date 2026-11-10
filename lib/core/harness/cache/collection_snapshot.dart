import '../../domain/domain.dart';
import 'label_index.dart';

/// One emission of a leased collection: its schema, its objects as stored
/// (calculated values not filled) and the generation that names this state.
///
/// Immutable. Indexes are built on first read only, so a burst of snapshots
/// during someone's bulk edit costs nothing until a tool reads one.
final class CollectionSnapshot {
  CollectionSnapshot({
    required this.schema,
    required this.generation,
    required List<MorkvaObject> raw,
  }) : raw = List.unmodifiable(raw);

  CollectionSnapshot._shared(this.schema, this.generation, this.raw);

  /// The collection (lookups resolved) this state is read with.
  final Collection schema;

  /// Unique across the cache: a new emission, a schema change or a
  /// resubscribe gets a new one, so equal generations mean equal data.
  final int generation;

  /// The objects in stored order, decoded against [schema].
  final List<MorkvaObject> raw;

  String get collectionId => schema.id;

  int get count => raw.length;

  Map<String, MorkvaObject>? _byId;
  LabelIndex? _labels;

  /// The objects by id.
  Map<String, MorkvaObject> get byId =>
      _byId ??= {for (final o in raw) o.id: o};

  /// Labels, the title multimap and text search.
  LabelIndex get labels => _labels ??= LabelIndex(schema, raw);

  /// Whether [byId] has been built (for the laziness tests).
  bool get hasById => _byId != null;

  /// Whether [labels] has been built (for the laziness tests).
  bool get hasLabels => _labels != null;

  /// The object [id], or null when it is not in this state.
  MorkvaObject? operator [](String id) => byId[id];

  /// This state read with [schema] (a rename or an option edit, which
  /// needs no re-decode), under [generation].
  CollectionSnapshot withSchema(Collection schema, int generation) =>
      CollectionSnapshot._shared(schema, generation, raw);
}
