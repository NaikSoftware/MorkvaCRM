import '../../../core/domain/domain.dart';
import '../../../core/harness/cache/derived_snapshot.dart';
import '../../../core/harness/cache/result_store.dart';
import '../../../core/harness/harness.dart';
import '../../../core/harness/input/filter_compiler.dart';
import '../../../core/harness/query/aggregate_engine.dart';
import '../../../core/harness/query/query_engine.dart';
import '../../../core/harness/query/result_shaper.dart';
import '../bloc/chat_item.dart';

/// Turns a stored harness result (a handle, or its persisted spec after a
/// reload) into the table and chart read-models the chat renders. Rows and
/// numbers come from the workspace data, never from the model.
///
/// A live handle whose data is unchanged renders its own ordered ids, so the
/// table shows exactly the result the model saw; otherwise the spec re-runs.
final class ResultReader {
  ResultReader({required this.queries, required this.aggregates});

  final QueryEngine queries;
  final AggregateEngine aggregates;

  /// Rows a table card holds ("Showing 20 of 148").
  static const int tableRows = 20;

  /// Columns a table card shows: the title plus five fields.
  static const int tableColumns = 6;

  static const ResultShaper _shaper = ResultShaper();

  ResultStore get _results => queries.results;

  /// The spec behind [handle] while [thread] holds it.
  Map<String, Object?>? specOf(String handle, {required String thread}) =>
      _results.get(handle, thread: thread)?.spec;

  /// The table for [handle] (or, once it is gone, [spec]); null when neither
  /// can be read any more (a deleted collection, a field gone).
  Future<ResultTable?> table({
    String? handle,
    Map<String, Object?>? spec,
    required HarnessContext ctx,
    required String thread,
  }) async {
    final stored = handle == null ? null : _results.get(handle, thread: thread);
    final json = stored?.spec ?? spec;
    if (json == null) return null;
    try {
      return switch (json['kind']) {
        'query' => await _queryTable(QuerySpec.fromJson(json), stored, ctx),
        'aggregate' => await _aggregateTable(
          AggregateSpec.fromJson(json),
          stored,
          ctx,
        ),
        _ => null,
      };
    } on HarnessException {
      return null;
    } on FormatException {
      return null;
    }
  }

  /// The chart for an aggregate [handle] (or [spec]); null for anything
  /// else or when it cannot be read any more.
  Future<ResultChart?> chart({
    String? handle,
    Map<String, Object?>? spec,
    required HarnessContext ctx,
    required String thread,
  }) async {
    final stored = handle == null ? null : _results.get(handle, thread: thread);
    final json = stored?.spec ?? spec;
    if (json == null || json['kind'] != 'aggregate') return null;
    try {
      final aggregate = AggregateSpec.fromJson(json);
      final result = await _aggregateResult(aggregate, stored, ctx);
      final labels = (result['metrics'] as List?) ?? const [];
      final unit = result['unit'] as String?;
      final partialKey = _currentBucketKey(aggregate, ctx);
      return ResultChart(
        collectionId: aggregate.query.collectionId,
        metricLabel: [
          if (labels.isNotEmpty) '${labels.first}',
          ?unit,
        ].join(', '),
        points: [
          for (final g in _groups(result))
            ChartPoint(
              '${g['label'] ?? g['key'] ?? ''}',
              _number(_metrics(g).firstOrNull),
              partial: partialKey != null && g['key'] == partialKey,
            ),
        ],
      );
    } on HarnessException {
      return null;
    } on FormatException {
      return null;
    }
  }

  // ---------------------------------------------------------------------------

  Future<ResultTable> _queryTable(
    QuerySpec spec,
    StoredResult? stored,
    HarnessContext ctx,
  ) => queries.withStored(spec.collectionId, ctx, () async {
    var derived = await queries.cache.derive(
      spec.collectionId,
      today: ctx.today,
    );
    List<String> ids;
    if (stored != null && stored.isCurrent(derived.generations)) {
      ids = stored.orderedIds;
    } else {
      final run = await queries.run(spec, ctx);
      derived = run.derived;
      ids = run.ids;
    }
    final collection = derived.schema;
    final title = collection.fields
        .whereType<TextFieldDefinition>()
        .firstOrNull;
    final fields = [
      for (final id in spec.fieldIds)
        if (id != title?.id) ?collection.fieldById(id),
    ].take(tableColumns - 1).toList();
    final objects = [for (final id in ids) ?derived.base[id]];
    final numeric = [for (final f in fields) _isNumeric(f)];
    final hasTotals = objects.length > 1 && numeric.any((n) => n);
    return ResultTable(
      collectionId: collection.id,
      columns: [
        ResultColumn(_shaper.name(title?.name ?? collection.name)),
        for (final (i, f) in fields.indexed)
          ResultColumn(_shaper.name(f.name), numeric: numeric[i]),
      ],
      rows: [
        for (final o in objects.take(tableRows))
          ResultRow(
            cardId: o.id,
            cells: [
              _shaper.title(collection, o),
              for (final f in fields) _cell(ctx, derived, o, f),
            ],
          ),
      ],
      totalCount: objects.length,
      totals: hasTotals
          ? [
              'Total',
              for (final (i, f) in fields.indexed)
                numeric[i] ? _sum(derived, objects, f) : '',
            ]
          : null,
    );
  });

  Future<ResultTable> _aggregateTable(
    AggregateSpec spec,
    StoredResult? stored,
    HarnessContext ctx,
  ) async {
    final result = await _aggregateResult(spec, stored, ctx);
    final labels = [for (final l in (result['metrics'] as List?) ?? []) '$l'];
    final unit = result['unit'] as String?;
    final collection = queries.cache.collection(spec.query.collectionId);
    final groupField = switch (spec.groupBy?.fieldId) {
      final id? when collection != null => filterFieldOf(collection, id),
      _ => null,
    };
    final groups = _groups(result);
    final format = NumberFieldDefinition(id: '', name: '', unitLabel: unit);
    String figure(Object? value) => switch (_number(value)) {
      final n? => formatFieldValue(format, NumberFieldValue(n)),
      null => value is String ? value : '',
    };
    return ResultTable(
      collectionId: spec.query.collectionId,
      columns: [
        ResultColumn(
          groupField == null ? 'All' : _shaper.name(groupField.name),
        ),
        for (final l in labels) ResultColumn(l, numeric: true),
      ].take(tableColumns).toList(),
      rows: [
        if (spec.groupBy == null)
          ResultRow(
            cells: [
              'All',
              for (final v in _list(result['totals'])) figure(v),
            ].take(tableColumns).toList(),
          ),
        for (final g in groups)
          ResultRow(
            cells: [
              '${g['label'] ?? g['key'] ?? ''}',
              for (final v in _metrics(g)) figure(v),
            ].take(tableColumns).toList(),
          ),
      ],
      totalCount: spec.groupBy == null ? 1 : groups.length,
      totals: spec.groupBy == null || groups.length < 2
          ? null
          : [
              'Total',
              for (final v in _list(result['totals'])) figure(v),
            ].take(tableColumns).toList(),
    );
  }

  /// The unbudgeted aggregate result: the stored one while current, else a
  /// re-run.
  Future<Map<String, Object?>> _aggregateResult(
    AggregateSpec spec,
    StoredResult? stored,
    HarnessContext ctx,
  ) async {
    if (stored?.groups case final Map<String, Object?> groups) {
      final current = queries.cache.generationsOf(stored!.generations.keys);
      if (stored.isCurrent(current)) return groups;
    }
    return (await aggregates.compute(spec, ctx)).result;
  }

  /// The key of the date bucket today falls in, when [spec] groups by a
  /// date: that bar is drawn as a partial period.
  String? _currentBucketKey(AggregateSpec spec, HarnessContext ctx) {
    final group = spec.groupBy;
    final collection = queries.cache.collection(spec.query.collectionId);
    if (group == null || collection == null) return null;
    final field = filterFieldOf(collection, group.fieldId);
    final presented = field is CalculatedFieldDefinition
        ? field.outputField
        : field;
    if (presented is! DateFieldDefinition) return null;
    return dateBucketKey(
      dateBucketStart(ctx.today, group.bucket),
      group.bucket,
    );
  }

  String _cell(
    HarnessContext ctx,
    DerivedSnapshot derived,
    MorkvaObject object,
    FieldDefinition field,
  ) {
    final value = derived.value(object, field);
    final shown = field is CalculatedFieldDefinition
        ? field.outputField
        : field;
    final labels = <String, String>{};
    if ((shown, value) case (
      ReferenceFieldDefinition(:final targetCollectionId),
      ReferenceFieldValue(:final objectIds),
    )) {
      for (final id in objectIds) {
        if (queries.referenceTitle(ctx, targetCollectionId, id)
            case final title?) {
          labels[id] = title;
        }
      }
    }
    return _shaper.label(
      formatFieldValue(field, value, referenceLabels: labels),
    );
  }

  String _sum(
    DerivedSnapshot derived,
    List<MorkvaObject> objects,
    FieldDefinition field,
  ) {
    final shown = field is CalculatedFieldDefinition
        ? field.outputField
        : field;
    final total = foldAggregate(AggregateOp.sum, [
      for (final o in objects) ?_numberOf(derived.value(o, field)),
    ]);
    if (total is! num || shown is! NumberFieldDefinition) return '';
    return formatFieldValue(shown, NumberFieldValue(total));
  }

  static bool _isNumeric(FieldDefinition field) =>
      (field is CalculatedFieldDefinition ? field.outputField : field)
          is NumberFieldDefinition;

  static num? _numberOf(FieldValue value) => switch (value) {
    NumberFieldValue(value: final n?) when n.isFinite => n,
    CalculatedFieldValue() => switch (value.toJson()) {
      final num n when n.isFinite => n,
      _ => null,
    },
    _ => null,
  };

  static List<Map<String, Object?>> _groups(Map<String, Object?> result) => [
    for (final g in _list(result['groups']))
      if (g is Map) g.cast<String, Object?>(),
  ];

  static List<Object?> _metrics(Map<String, Object?> group) =>
      _list(group['m']);

  static List<Object?> _list(Object? value) => value is List ? value : const [];

  static double? _number(Object? value) =>
      value is num && value.isFinite ? value.toDouble() : null;
}
