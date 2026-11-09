import 'package:equatable/equatable.dart';

import '../view/view_definition.dart';

/// Which objects an [Aggregation] summarizes, relative to the object that
/// owns the field.
enum AggregateSource {
  /// Objects of [Aggregation.collectionId] whose reference field
  /// [Aggregation.referenceFieldId] points at this object (reverse lookup).
  linkedFrom,

  /// The objects this object's own reference field
  /// [Aggregation.referenceFieldId] points at.
  linked,

  /// Every object of [Aggregation.collectionId] (e.g. for a dashboard).
  all,
}

/// How the summarized objects fold into one value.
enum AggregateOp {
  count,
  sum,
  average,
  min,
  max;

  String get label => switch (this) {
    count => 'Count',
    sum => 'Sum',
    average => 'Average',
    min => 'Min',
    max => 'Max',
  };

  /// Whether the op reads a field (count only counts objects).
  bool get needsField => this != count;
}

/// A cross-object summary: [op] over [fieldId] of the objects [source]
/// selects that pass every one of [filters] (AND).
class Aggregation extends Equatable {
  const Aggregation({
    required this.source,
    required this.collectionId,
    this.referenceFieldId,
    this.op = AggregateOp.count,
    this.fieldId,
    this.filters = const [],
  });

  final AggregateSource source;

  /// The collection whose objects are summarized. For [AggregateSource.linked]
  /// it is the reference field's target (kept for display; the field decides).
  final String collectionId;

  /// The reference field: on [collectionId] for [AggregateSource.linkedFrom],
  /// on this collection for [AggregateSource.linked]; null for `all`.
  final String? referenceFieldId;

  final AggregateOp op;

  /// The summarized field of [collectionId]; null for [AggregateOp.count].
  final String? fieldId;

  final List<ViewFilter> filters;

  static const Object _unset = Object();

  Aggregation copyWith({
    AggregateSource? source,
    String? collectionId,
    Object? referenceFieldId = _unset,
    AggregateOp? op,
    Object? fieldId = _unset,
    List<ViewFilter>? filters,
  }) => Aggregation(
    source: source ?? this.source,
    collectionId: collectionId ?? this.collectionId,
    referenceFieldId: identical(referenceFieldId, _unset)
        ? this.referenceFieldId
        : referenceFieldId as String?,
    op: op ?? this.op,
    fieldId: identical(fieldId, _unset) ? this.fieldId : fieldId as String?,
    filters: filters ?? this.filters,
  );

  Map<String, dynamic> toJson() => {
    'source': source.name,
    'collectionId': collectionId,
    if (referenceFieldId != null) 'referenceFieldId': referenceFieldId,
    'op': op.name,
    if (fieldId != null) 'fieldId': fieldId,
    if (filters.isNotEmpty) 'filters': [for (final f in filters) f.toJson()],
  };

  /// Unknown source/op names fall back to `all` / `count`; unknown filter ops
  /// are skipped (like views), so newer configs still load.
  factory Aggregation.fromJson(Map<String, dynamic> json) => Aggregation(
    source:
        AggregateSource.values.asNameMap()[json['source']] ??
        AggregateSource.all,
    collectionId: (json['collectionId'] as String?) ?? '',
    referenceFieldId: json['referenceFieldId'] as String?,
    op: AggregateOp.values.asNameMap()[json['op']] ?? AggregateOp.count,
    fieldId: json['fieldId'] as String?,
    filters: [
      for (final raw in (json['filters'] as List?) ?? const [])
        if (raw is Map && FilterOp.values.asNameMap().containsKey(raw['op']))
          ViewFilter.fromJson(raw.cast<String, dynamic>()),
    ],
  );

  @override
  List<Object?> get props => [
    source,
    collectionId,
    referenceFieldId,
    op,
    fieldId,
    filters,
  ];
}

/// Shows field [fieldId] of the object this object's (single) reference
/// field [referenceFieldId] points at, keeping that field's type.
class Lookup extends Equatable {
  const Lookup({required this.referenceFieldId, this.fieldId});

  final String referenceFieldId;

  /// The field of the referenced collection shown; null until picked.
  final String? fieldId;

  Map<String, dynamic> toJson() => {
    'referenceFieldId': referenceFieldId,
    if (fieldId != null) 'fieldId': fieldId,
  };

  factory Lookup.fromJson(Map<String, dynamic> json) => Lookup(
    referenceFieldId: (json['referenceFieldId'] as String?) ?? '',
    fieldId: json['fieldId'] as String?,
  );

  @override
  List<Object?> get props => [referenceFieldId, fieldId];
}

/// Folds [values] with [op]: the one fold behind calculated aggregates and
/// the assistant's metrics, so the two can never disagree.
///
/// [count] is the number of [values] (nulls included: one per object).
/// [sum] adds the numbers and ignores everything else (0 when none);
/// [average] is null when there are no numbers. [min] / [max] compare the
/// non-null values, so they also work on dates; null when there are none.
Object? foldAggregate(AggregateOp op, Iterable<Object?> values) {
  switch (op) {
    case AggregateOp.count:
      return values.length;
    case AggregateOp.sum:
      return values.whereType<num>().fold<num>(0, (s, v) => s + v);
    case AggregateOp.average:
      final nums = values.whereType<num>().toList();
      return nums.isEmpty
          ? null
          : nums.fold<num>(0, (s, v) => s + v) / nums.length;
    case AggregateOp.min || AggregateOp.max:
      final present = values.nonNulls;
      if (present.isEmpty) return null;
      return present.reduce((x, y) {
        final c = (x as Comparable).compareTo(y);
        return (op == AggregateOp.min ? c <= 0 : c >= 0) ? x : y;
      });
  }
}
