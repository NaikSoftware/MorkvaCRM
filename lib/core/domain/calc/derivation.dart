import '../collection.dart';
import '../field_definition.dart';
import '../field_value.dart';
import '../morkva_object.dart';
import '../types/auto_number_field.dart';
import '../types/boolean_field.dart';
import '../types/calculated_field.dart';
import '../types/date_field.dart';
import '../types/multi_select_field.dart';
import '../types/number_field.dart';
import '../types/reference_field.dart';
import '../types/single_select_field.dart';
import '../types/text_field.dart';
import '../view/field_format.dart';
import '../view/view_query.dart';
import 'aggregation.dart';
import 'formula.dart';
import 'lookups.dart';

/// Fills calculated values for objects of a set of collections.
///
/// Build one per snapshot of the data: values are memoized per (object,
/// field), so each is computed once however many others read it. A field that
/// reads itself — directly, through other formulas, or through another
/// collection's aggregate — is blank instead of looping. Objects of a
/// collection missing from [objects] count as still loading: aggregates over
/// them are blank, not 0.
class Derivation {
  Derivation({
    required Iterable<Collection> collections,
    required Map<String, List<MorkvaObject>> objects,
    DateTime? today,
  }) : _collections = {for (final c in collections) c.id: c},
       _objects = objects,
       _today = today;

  final Map<String, Collection> _collections;
  final Map<String, List<MorkvaObject>> _objects;
  final DateTime? _today;

  final Map<(String, String), Object?> _memo = {};

  /// Lookup values as their shown field's JSON (an option id, not its label).
  final Map<(String, String), Object?> _lookupJson = {};
  final Set<(String, String)> _inProgress = {};
  final Map<String, CompiledFormula?> _formulas = {};
  final Map<(String, String), Map<String, List<MorkvaObject>>> _incoming = {};
  final Map<String, Map<String, MorkvaObject>> _byId = {};

  static const Object _blank = Object();

  /// The objects of [collectionId] with every calculated value filled; the
  /// raw objects when it has no calculated fields. Empty when not loaded.
  List<MorkvaObject> objectsOf(String collectionId) {
    final raw = _objects[collectionId] ?? const [];
    final collection = _collections[collectionId];
    if (collection == null) return raw;
    final calculated = collection.fields
        .whereType<CalculatedFieldDefinition>()
        .toList();
    if (calculated.isEmpty) return raw;
    return [
      for (final o in raw)
        o.copyWith(
          values: {
            ...o.values,
            for (final f in calculated) f.id: valueOf(collection, o, f),
          },
        ),
    ];
  }

  /// The value of [field] for [object] of [collection].
  CalculatedFieldValue valueOf(
    Collection collection,
    MorkvaObject object,
    CalculatedFieldDefinition field,
  ) {
    final derived = _derived(collection, object, field);
    return CalculatedFieldValue(
      field.isLookup ? _lookupJson[(object.id, field.id)] : _toJson(derived),
    );
  }

  /// The collections whose objects deriving [collectionId] reads (itself
  /// excluded), following aggregates transitively.
  static Set<String> sourcesOf(
    String collectionId,
    Iterable<Collection> collections,
  ) {
    final byId = {for (final c in collections) c.id: c};
    final seen = <String>{collectionId};
    final queue = [collectionId];
    while (queue.isNotEmpty) {
      final collection = byId[queue.removeLast()];
      if (collection == null) continue;
      for (final f
          in collection.fields.whereType<CalculatedFieldDefinition>()) {
        final source = f.isLookup
            ? _referenceTarget(collection, f.lookup!.referenceFieldId)
            : _sourceCollectionId(collection, f.aggregate);
        if (source != null && seen.add(source)) queue.add(source);
      }
    }
    return seen..remove(collectionId);
  }

  static String? _sourceCollectionId(Collection owner, Aggregation? a) =>
      switch (a?.source) {
        null => null,
        AggregateSource.linked => _referenceTarget(
          owner,
          a!.referenceFieldId ?? '',
        ),
        _ => a!.collectionId,
      };

  static String? _referenceTarget(Collection owner, String fieldId) =>
      switch (owner.fieldById(fieldId)) {
        ReferenceFieldDefinition(:final targetCollectionId) =>
          targetCollectionId,
        _ => null,
      };

  // ---------------------------------------------------------------------------

  /// A formula-typed value (num / String / bool / UTC-day DateTime) or null.
  Object? _derived(
    Collection collection,
    MorkvaObject object,
    CalculatedFieldDefinition field,
  ) {
    final key = (object.id, field.id);
    final memo = _memo[key];
    if (memo != null) return identical(memo, _blank) ? null : memo;
    if (!_inProgress.add(key)) return null; // a cycle
    Object? result;
    try {
      final aggregate = field.aggregate;
      result = field.isLookup
          ? _lookup(collection, object, field)
          : aggregate == null
          ? _formula(
              collection,
              field,
            )?.evaluate((id) => _read(collection, object, id), today: _today)
          : _aggregate(collection, object, aggregate);
    } finally {
      _inProgress.remove(key);
    }
    _memo[key] = result ?? _blank;
    return result;
  }

  CompiledFormula? _formula(Collection c, CalculatedFieldDefinition f) =>
      _formulas.putIfAbsent(
        '${c.id}/${f.id}',
        () =>
            compileFormula(f.expression ?? '', c.fields, selfId: f.id).formula,
      );

  /// [fieldId] of [object] as a formula reads it.
  Object? _read(Collection collection, MorkvaObject object, String fieldId) {
    final field = collection.fieldById(fieldId);
    if (field == null) return null;
    if (field is CalculatedFieldDefinition) {
      return _derived(collection, object, field);
    }
    return formulaValueOf(field, object[fieldId] ?? field.emptyValue());
  }

  /// A stored value as a formula reads it.
  static Object? formulaValueOf(FieldDefinition field, FieldValue value) =>
      switch ((field, value)) {
        (_, NumberFieldValue(:final value)) => value,
        (_, AutoNumberFieldValue(:final sequence)) => sequence,
        (_, TextFieldValue(:final text)) =>
          text == null || text.isEmpty ? null : text,
        (_, BooleanFieldValue(:final value)) => value,
        (final DateFieldDefinition f, DateFieldValue(value: final dt?)) =>
          _utcDay(calendarDayOf(f, dt)),
        (
          SingleSelectFieldDefinition(:final options),
          SingleSelectFieldValue(:final optionId),
        ) =>
          options.where((o) => o.id == optionId).firstOrNull?.label,
        (MultiSelectFieldDefinition(), MultiSelectFieldValue()) =>
          switch (formatFieldValue(field, value)) {
            '' => null,
            final text => text,
          },
        _ => null,
      };

  static DateTime _utcDay(DateTime d) => DateTime.utc(d.year, d.month, d.day);

  /// The looked-up value as a formula reads it; its JSON goes to
  /// [_lookupJson]. Blank while the target collection is loading.
  // shortcut: a multiple reference shows its first linked object; offer
  // "joined" values if lookups over multi-links are wanted.
  Object? _lookup(
    Collection owner,
    MorkvaObject object,
    CalculatedFieldDefinition field,
  ) {
    final config = field.lookup!;
    final target =
        _collections[_referenceTarget(owner, config.referenceFieldId) ?? ''];
    final ref = object[config.referenceFieldId];
    if (target == null || ref is! ReferenceFieldValue) return null;
    final all = _objects[target.id];
    final id = ref.objectIds.firstOrNull;
    if (all == null || id == null) return null;
    final linked = _byId.putIfAbsent(
      target.id,
      () => {for (final o in all) o.id: o},
    )[id];
    final shown = target.fieldById(config.fieldId ?? '');
    if (linked == null || shown == null || !isLookupable(shown)) return null;
    if (shown is CalculatedFieldDefinition) {
      final value = valueOf(target, linked, shown);
      _lookupJson[(object.id, field.id)] = value.cached;
      return _derived(target, linked, shown);
    }
    final value = linked[shown.id] ?? shown.emptyValue();
    _lookupJson[(object.id, field.id)] = value.isEmpty ? null : value.toJson();
    return formulaValueOf(shown, value);
  }

  Object? _aggregate(Collection owner, MorkvaObject object, Aggregation a) {
    final source = _collections[_sourceCollectionId(owner, a) ?? ''];
    if (source == null) return null;
    final all = _objects[source.id];
    if (all == null) return null; // still loading
    final List<MorkvaObject> picked;
    switch (a.source) {
      case AggregateSource.all:
        picked = all;
      case AggregateSource.linked:
        final ref = object[a.referenceFieldId ?? ''];
        final byId = _byId.putIfAbsent(
          source.id,
          () => {for (final o in all) o.id: o},
        );
        picked = [
          if (ref is ReferenceFieldValue)
            for (final id in ref.objectIds) ?byId[id],
        ];
      case AggregateSource.linkedFrom:
        final refField = source.fieldById(a.referenceFieldId ?? '');
        if (refField is! ReferenceFieldDefinition ||
            refField.targetCollectionId != owner.id) {
          return null;
        }
        picked = _incomingIndex(source, refField)[object.id] ?? const [];
    }

    final filters = [
      for (final f in a.filters)
        if (source.fieldById(f.fieldId) case final field?) (f, field),
    ];
    final kept = filters.isEmpty
        ? picked
        : [
            for (final o in picked)
              if (filters.every(
                (pair) =>
                    matchesFilter(pair.$1, pair.$2, _value(source, o, pair.$2)),
              ))
                o,
          ];

    if (a.op == AggregateOp.count) return kept.length;
    final field = source.fieldById(a.fieldId ?? '');
    if (field == null) return null;
    final values = [for (final o in kept) ?_aggregatable(source, o, field)];
    switch (a.op) {
      case AggregateOp.sum:
        return values.whereType<num>().fold<num>(0, (s, v) => s + v);
      case AggregateOp.average:
        final nums = values.whereType<num>().toList();
        return nums.isEmpty
            ? null
            : nums.fold<num>(0, (s, v) => s + v) / nums.length;
      case AggregateOp.min || AggregateOp.max:
        if (values.isEmpty) return null;
        return values.reduce((x, y) {
          final c = (x as Comparable).compareTo(y);
          return (a.op == AggregateOp.min ? c <= 0 : c >= 0) ? x : y;
        });
      case AggregateOp.count:
        return kept.length;
    }
  }

  /// The source objects of [refField] by the id each points at; built once.
  Map<String, List<MorkvaObject>> _incomingIndex(
    Collection source,
    ReferenceFieldDefinition refField,
  ) => _incoming.putIfAbsent((source.id, refField.id), () {
    final index = <String, List<MorkvaObject>>{};
    for (final o in _objects[source.id] ?? const <MorkvaObject>[]) {
      final ref = o[refField.id];
      if (ref is! ReferenceFieldValue) continue;
      for (final id in ref.objectIds.toSet()) {
        (index[id] ??= []).add(o);
      }
    }
    return index;
  });

  /// [field] of [object] as a [FieldValue], derived when calculated.
  FieldValue _value(Collection c, MorkvaObject object, FieldDefinition field) =>
      field is CalculatedFieldDefinition
      ? valueOf(c, object, field)
      : object[field.id] ?? field.emptyValue();

  /// A number or day an aggregate folds, or null.
  Object? _aggregatable(Collection c, MorkvaObject o, FieldDefinition field) {
    final v = field is CalculatedFieldDefinition
        ? _derived(c, o, field)
        : formulaValueOf(field, o[field.id] ?? field.emptyValue());
    return v is num || v is DateTime ? v : null;
  }

  static Object? _toJson(Object? v) => v is DateTime ? v.toIso8601String() : v;
}

/// The formula fields of [owner] that lead from [fieldId] back to itself
/// ("Total", "Tax", "Total"), or null when its formula has no such loop.
List<String>? formulaCycle(Collection owner, String fieldId) {
  Set<String> readsOf(String id) => switch (owner.fieldById(id)) {
    CalculatedFieldDefinition(aggregate: null, :final expression?) =>
      formulaFieldIds(expression, owner.fields),
    _ => const {},
  };
  final path = <String>[fieldId];
  final seen = <String>{};
  bool walk(String id) {
    for (final next in readsOf(id)) {
      path.add(next);
      if (next == fieldId) return true;
      if (seen.add(next) && walk(next)) return true;
      path.removeLast();
    }
    return false;
  }

  if (!walk(fieldId)) return null;
  return [for (final id in path) owner.fieldById(id)?.name ?? id];
}

/// The type an aggregation yields: number, or date for min/max of a date.
String aggregateOutputType(
  Aggregation a,
  Collection owner,
  Iterable<Collection> collections,
) {
  if (a.op != AggregateOp.min && a.op != AggregateOp.max) {
    return kNumberFieldType;
  }
  final sourceId = Derivation._sourceCollectionId(owner, a);
  final source = sourceId == owner.id
      ? owner
      : collections.where((c) => c.id == sourceId).firstOrNull;
  final field = source?.fieldById(a.fieldId ?? '');
  final isDate =
      field is DateFieldDefinition ||
      (field is CalculatedFieldDefinition &&
          field.declaredOutputType == kDateFieldType);
  return isDate ? kDateFieldType : kNumberFieldType;
}
