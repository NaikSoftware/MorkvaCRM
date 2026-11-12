import '../../domain/domain.dart';
import 'collection_snapshot.dart';

/// A collection's objects with calculated values, over fixed snapshots of it
/// and of every collection it derives from (`Derivation.sourcesOf`).
///
/// Built by `WorkspaceCache.derive`, which awaits every source first (a
/// missing source would read as "loading" and its aggregates as blanks) and
/// memoizes one instance per `(schemaGeneration, generations, today)`, so
/// every call in a turn shares one [Derivation] and its memo.
///
/// Nothing is derived until asked: a query that touches no calculated field
/// reads [raw] (see [touchesCalculated]); one that only shows calculated
/// fields calls [valueOf] for the page's rows; one that filters, sorts,
/// groups or folds on them reads [objects].
final class DerivedSnapshot {
  DerivedSnapshot({
    required this.base,
    required this.sources,
    required this.collections,
    required this.today,
  });

  /// The collection's own snapshot.
  final CollectionSnapshot base;

  /// The snapshots of every source collection, by id.
  final Map<String, CollectionSnapshot> sources;

  /// Every schema (lookups resolved), so lookups and aggregates resolve.
  final List<Collection> collections;

  /// The day formulas evaluate `TODAY()` against (the turn's start).
  final DateTime today;

  Collection get schema => base.schema;

  String get collectionId => base.collectionId;

  /// The stored objects, calculated values not filled.
  List<MorkvaObject> get raw => base.raw;

  /// The generations this state was derived from, the collection's own
  /// included, by collection id.
  Map<String, int> get generations => {
    collectionId: base.generation,
    for (final s in sources.values) s.collectionId: s.generation,
  };

  Derivation? _derivation;
  List<MorkvaObject>? _objects;

  /// Whether a [Derivation] has been built (for the skip tests).
  bool get hasDerivation => _derivation != null;

  Derivation get _derive => _derivation ??= Derivation(
    collections: collections,
    objects: {
      collectionId: base.raw,
      for (final s in sources.values) s.collectionId: s.raw,
    },
    today: today,
  );

  /// Every object with its calculated values filled; [raw] itself when the
  /// collection has no calculated field. Computed once.
  List<MorkvaObject> get objects =>
      _objects ??= schema.fields.any((f) => f is CalculatedFieldDefinition)
      ? List.unmodifiable(_derive.objectsOf(collectionId))
      : raw;

  /// The value of calculated [field] for [object], computed alone (for a
  /// page of rows) and memoized with everything it read.
  CalculatedFieldValue valueOf(
    MorkvaObject object,
    CalculatedFieldDefinition field,
  ) => _derive.valueOf(schema, object, field);

  /// [substitute] (a card of this collection, e.g. a write's before or
  /// after image) with its calculated values, derived over this state with
  /// the stored card of the same id replaced by it, or added when absent (a
  /// deleted card's before image). Neither a later write to that card nor
  /// its absence leaks in. Null in, null out.
  ///
  /// Builds its own [Derivation]: the shared one's memo is keyed by card id
  /// and would hand back (and keep) the stored card's values.
  MorkvaObject? deriveWith(MorkvaObject? substitute) {
    if (substitute == null) return null;
    final calculated = schema.fields.whereType<CalculatedFieldDefinition>();
    if (calculated.isEmpty) return substitute;
    final derivation = Derivation(
      collections: collections,
      objects: {
        collectionId: [
          for (final o in base.raw)
            if (o.id != substitute.id) o,
          substitute,
        ],
        for (final s in sources.values) s.collectionId: s.raw,
      },
      today: today,
    );
    return substitute.copyWith(
      values: {
        ...substitute.values,
        for (final f in calculated)
          f.id: derivation.valueOf(schema, substitute, f),
      },
    );
  }

  /// [object]'s value of [field]: derived when calculated, stored otherwise.
  FieldValue value(MorkvaObject object, FieldDefinition field) =>
      field is CalculatedFieldDefinition
      ? valueOf(object, field)
      : object[field.id] ?? field.emptyValue();

  /// The objects a query over [fieldIds] (its filters, sort, group-by and
  /// metrics) must read: [raw] when none of them is calculated, so
  /// Derivation is skipped entirely, else [objects].
  List<MorkvaObject> objectsFor(Iterable<String> fieldIds) =>
      touchesCalculated(schema, fieldIds) ? objects : raw;

  /// Whether any of [fieldIds] is a calculated field of [collection].
  static bool touchesCalculated(
    Collection collection,
    Iterable<String> fieldIds,
  ) => fieldIds.any(
    (id) => collection.fieldById(id) is CalculatedFieldDefinition,
  );
}
