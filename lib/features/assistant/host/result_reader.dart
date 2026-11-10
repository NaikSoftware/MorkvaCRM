import '../../../core/domain/domain.dart';
import '../../../core/harness/cache/derived_snapshot.dart';
import '../../../core/harness/cache/result_store.dart';
import '../../../core/harness/harness.dart';
import '../../../core/harness/input/filter_compiler.dart';
import '../../../core/harness/input/screen_line.dart' show describeFilter;
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

  /// A result card's title, from the spec behind [handle] (or [spec]):
  /// "Orders by Status", "Orders where Paid is false", "Orders · 3 shown"
  /// ([total] defaults to the stored result's). Null when the spec or its
  /// collection is unknown. The model keeps the op's own summary.
  String? titleOf({
    String? handle,
    Map<String, Object?>? spec,
    int? total,
    required String thread,
  }) {
    final stored = handle == null ? null : _results.get(handle, thread: thread);
    final json = stored?.spec ?? spec;
    if (json == null) return null;
    try {
      switch (json['kind']) {
        case 'query':
          final query = QuerySpec.fromJson(json);
          final name = _collectionName(query.collectionId);
          if (name == null) return null;
          final where = _where(query);
          if (where != null) return '$name $where';
          final n = total ?? stored?.total;
          // Past [tableRows] the card shows a page of them, not all.
          if (n == null) return name;
          return n <= tableRows ? '$name · $n shown' : '$name · $n cards';
        case 'aggregate':
          final aggregate = AggregateSpec.fromJson(json);
          final query = aggregate.query;
          final collection = queries.cache.collection(query.collectionId);
          if (collection == null) return null;
          final name = _shaper.name(collection.name);
          final by = _groupName(collection, aggregate);
          final head = by == null
              ? '$name · ${aggregate.metrics.map((m) => _metricName(collection, m)).join(', ')}'
              : '$name by $by';
          final where = _where(query);
          return where == null ? head : '$head · $where';
      }
    } on FormatException {
      return null;
    }
    return null;
  }

  /// The steps-chip line of a read that stored [handle]: "Looked at Orders
  /// · filtered 148 → 5 · grouped by Status · summed Total". Null when the
  /// handle is unknown.
  String? stepLine(String handle, {required String thread}) {
    final stored = _results.get(handle, thread: thread);
    if (stored == null) return null;
    try {
      final json = stored.spec;
      final aggregate = json['kind'] == 'aggregate'
          ? AggregateSpec.fromJson(json)
          : null;
      final query = aggregate?.query ?? QuerySpec.fromJson(json);
      final collection = queries.cache.collection(query.collectionId);
      if (collection == null) return null;
      final scanned = queries.cache.current(collection.id)?.count;
      final filtered = query.filters.isNotEmpty || query.search != null;
      final by = aggregate == null ? null : _groupName(collection, aggregate);
      return [
        'Looked at ${_shaper.name(collection.name)}',
        if (filtered)
          scanned == null
              ? 'filtered to ${stored.total}'
              : 'filtered $scanned → ${stored.total}',
        if (by != null) 'grouped by $by',
        for (final m in aggregate?.metrics ?? const <MetricSpec>[])
          if (m.op != AggregateOp.count) _metricVerb(collection, m),
      ].join(' · ');
    } on FormatException {
      return null;
    }
  }

  String? _collectionName(String id) => switch (queries.cache.collection(id)) {
    final c? => _shaper.name(c.name),
    null => null,
  };

  /// "where Paid is false, Status any of [“Packing”]", "matching “melnyk”".
  String? _where(QuerySpec query) {
    final collection = queries.cache.collection(query.collectionId);
    if (collection == null) return null;
    String quote(String text) => '“${_shaper.name(text)}”';
    final clauses = [
      for (final f in query.filters)
        if (filterFieldOf(collection, f.fieldId) case final field?)
          '${_shaper.name(field.name)} '
              '${describeFilter(field, f, quote: quote)}',
    ];
    final search = query.search?.trim();
    final parts = [
      if (clauses.isNotEmpty) 'where ${clauses.join(', ')}',
      if (search != null && search.isNotEmpty) 'matching ${quote(search)}',
    ];
    return parts.isEmpty ? null : parts.join(' ');
  }

  /// "Status", "Created (month)": the group-by field as titles name it.
  String? _groupName(Collection collection, AggregateSpec spec) {
    final group = spec.groupBy;
    if (group == null) return null;
    final field = filterFieldOf(collection, group.fieldId);
    if (field == null) return null;
    final presented = field is CalculatedFieldDefinition
        ? field.outputField
        : field;
    final name = _shaper.name(field.name);
    return presented is DateFieldDefinition
        ? '$name (${group.bucket.name})'
        : name;
  }

  String _metricField(Collection collection, MetricSpec m) => _shaper.name(
    filterFieldOf(collection, m.fieldId ?? '')?.name ?? m.fieldId ?? '',
  );

  /// "count", "sum of Total".
  String _metricName(Collection collection, MetricSpec m) => m.fieldId == null
      ? m.op.name
      : '${m.op.name} of ${_metricField(collection, m)}';

  /// "summed Total", "averaged Price".
  String _metricVerb(Collection collection, MetricSpec m) {
    final field = _metricField(collection, m);
    return switch (m.op) {
      AggregateOp.sum => 'summed $field',
      AggregateOp.average => 'averaged $field',
      AggregateOp.min => 'lowest $field',
      AggregateOp.max => 'highest $field',
      AggregateOp.count => 'counted',
    };
  }

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
