import '../../domain/domain.dart';
import '../api/envelope.dart';
import '../api/harness_context.dart';
import '../cache/result_store.dart';
import '../cache/workspace_cache.dart';
import '../input/filter_compiler.dart';
import '../input/value_codec.dart';
import '../schema/arg_shapes.dart';
import 'query_engine.dart';
import 'result_shaper.dart';

/// The most groups (and distinct values) a result lists.
const int kMaxGroups = 50;

/// The most metrics one aggregate folds.
const int kMaxMetrics = 4;

/// One metric: [op] over [fieldId] (null for a plain count; may be
/// [kCreatedAtRef] / [kUpdatedAtRef] for min / max).
typedef MetricSpec = ({AggregateOp op, String? fieldId});

/// The group-by of an aggregate: [fieldId] (or a timestamp), dates folded
/// into [bucket], at most [limit] groups listed.
typedef GroupSpec = ({String fieldId, DateBucket bucket, int limit});

/// How groups are ordered: by their natural key order, or by metric
/// [index]; [descending] flips it.
typedef OrderSpec = ({bool byMetric, int index, bool descending});

/// A resolved, re-runnable aggregate (ids only), stored as its handle's
/// spec.
final class AggregateSpec {
  const AggregateSpec({
    required this.query,
    required this.metrics,
    this.groupBy,
    this.orderBy,
  });

  /// Throws [FormatException] when [json] is not an aggregate spec.
  factory AggregateSpec.fromJson(Map<String, Object?> json) {
    final query = json['query'];
    final metrics = json['metrics'];
    if (json['kind'] != 'aggregate' || query is! Map || metrics is! List) {
      throw const FormatException('Not an aggregate spec');
    }
    final group = json['groupBy'];
    final order = json['orderBy'];
    return AggregateSpec(
      query: QuerySpec.fromJson(query.cast<String, Object?>()),
      metrics: [
        for (final m in metrics.cast<Map<Object?, Object?>>())
          (
            op:
                AggregateOp.values.asNameMap()[m['op']] ??
                (throw FormatException('Unknown op ${m['op']}')),
            fieldId: m['fieldId'] as String?,
          ),
      ],
      groupBy: group is Map
          ? (
              fieldId: group['fieldId'] as String,
              bucket:
                  DateBucket.values.asNameMap()[group['bucket']] ??
                  DateBucket.day,
              limit: (group['limit'] as int?) ?? kMaxGroups,
            )
          : null,
      orderBy: order is Map
          ? (
              byMetric: order['by'] == 'metric',
              index: (order['index'] as int?) ?? 0,
              descending: order['dir'] == 'desc',
            )
          : null,
    );
  }

  /// What is folded (its projection, sort and limit are unused).
  final QuerySpec query;
  final List<MetricSpec> metrics;
  final GroupSpec? groupBy;

  /// Null means the default order (see [AggregateEngine]).
  final OrderSpec? orderBy;

  Map<String, Object?> toJson() => {
    'kind': 'aggregate',
    'query': query.toJson(),
    'metrics': [
      for (final m in metrics)
        {'op': m.op.name, if (m.fieldId != null) 'fieldId': m.fieldId},
    ],
    if (groupBy case final g?)
      'groupBy': {
        'fieldId': g.fieldId,
        'bucket': g.bucket.name,
        'limit': g.limit,
      },
    if (orderBy case final o?)
      'orderBy': {
        'by': o.byMetric ? 'metric' : 'key',
        'index': o.index,
        'dir': o.descending ? 'desc' : 'asc',
      },
  };
}

/// `cards.aggregate` and `cards.distinct` over the [WorkspaceCache], on the
/// query path of a [QueryEngine] (same refs, filters, `from: "@screen"` and
/// leases).
///
/// Group-by works for every field kind, a calculated field grouping as the
/// type it presents as:
/// - single select: one group per option, in option order, empty options
///   kept (bounded, and "Done: 0" is an answer); an unknown option counts as
///   empty;
/// - multi select and references: exploded, so a card counts once in each
///   of its groups; references group by the linked card's title in the
///   target's display order, empty reference groups left out (one per
///   target card would flood the result);
/// - dates and `@createdAt` / `@updatedAt`: `date_buckets.dart` (`bucket`,
///   default `day`) in calendar order;
/// - boolean: Yes, No, then empty;
/// - numbers and auto-numbers: exact value, ascending;
/// - text and files: exact value (file name), most cards first ("top 50").
///
/// Cards with no value form a `No <field>` group (key null), last in the
/// default order. Metrics fold with the shared `foldAggregate` over values
/// pre-filtered to `num` / `DateTime` (as calculated aggregates do), so the
/// assistant's numbers never drift from calculated fields: sum ignores
/// blanks (0 when none), average is null when empty, min / max also take
/// dates. `totals` fold every matched card, not just the listed groups.
final class AggregateEngine {
  AggregateEngine(this.queries);

  final QueryEngine queries;

  WorkspaceCache get cache => queries.cache;
  ResultStore get results => queries.results;
  ResultShaper get shaper => queries.shaper;

  /// `cards.aggregate`: `{collection | from: "@screen", where?, search?,
  /// groupBy?: {field, bucket?, limit?}, metrics: [{op, field?}],
  /// orderBy?: {by: key|metric, index?, dir?}}` → `{handle, total,
  /// metrics, groups?, totals, otherGroups?, unit?, truncated?, summary}`.
  Future<Map<String, Object?>> aggregate(
    Map<String, Object?> args,
    HarnessContext ctx, {
    required String thread,
  }) => queries.withScope(args, ctx, (scope) async {
    final base = queries.compileBase(scope, args);
    final metrics = _metrics(scope, args['metrics']);
    final spec = AggregateSpec(
      query: _unordered(base.spec),
      metrics: metrics,
      groupBy: _groupBy(scope, args['groupBy']),
      orderBy: _orderBy(args['orderBy'], metrics.length),
    );
    return execute(spec, ctx, thread: thread);
  });

  /// Runs [spec] and stores it under a handle (the matched card ids, and
  /// the unbudgeted result as its `groups`, which charts render from).
  Future<Map<String, Object?>> execute(
    AggregateSpec spec,
    HarnessContext ctx, {
    required String thread,
  }) async {
    final full = await compute(spec, ctx);
    final run = full.run;
    final stored = results.put(
      thread: thread,
      spec: spec.toJson(),
      generations: run.generations,
      orderedIds: run.ids,
      groups: full.result,
    );
    final groups = (full.result['groups'] as List?) ?? const [];
    final other = (full.result['otherGroups'] as int?) ?? 0;
    return shaper.fit(groups.length, (k) {
      final cut = groups.length - k;
      return {
        'handle': stored.handle,
        ...full.result,
        if (spec.groupBy != null) 'groups': groups.take(k).toList(),
        if (other + cut > 0) 'otherGroups': other + cut,
        if (cut > 0) ...{
          'truncated': true,
          'hint': 'Narrow with where or lower groupBy.limit.',
        },
        'summary': full.result['summary'],
      };
    }, budget: shaper.aggregateBudget);
  }

  /// [spec]'s full result (no handle, no byte budget) and the run behind it.
  Future<({QueryRun run, Map<String, Object?> result})> compute(
    AggregateSpec spec,
    HarnessContext ctx,
  ) async {
    final group = spec.groupBy;
    final run = await queries.run(
      spec.query,
      ctx,
      reads: [?group?.fieldId, for (final m in spec.metrics) ?m.fieldId],
    );
    final collection = run.collection;
    final metrics = [
      for (final m in spec.metrics)
        (
          op: m.op,
          read: _reader(collection, m),
          instant: m.fieldId == kCreatedAtRef || m.fieldId == kUpdatedAtRef,
        ),
    ];
    List<Object?> fold(List<MorkvaObject> objects) => [
      for (final m in metrics)
        _json(
          foldAggregate(m.op, [for (final o in objects) m.read(o)]),
          instant: m.instant,
        ),
    ];

    final labels = [for (final m in spec.metrics) _metricLabel(collection, m)];
    final name = shaper.name(collection.name);
    final filtered = spec.query.filters.isNotEmpty || spec.query.search != null;
    final head = filtered
        ? 'Filtered ${run.scanned} → ${run.total} $name'
        : '${run.total} $name';
    final unit = _unit(collection, spec.metrics);
    final result = <String, Object?>{'total': run.total, 'metrics': labels};
    var summary = '$head · ${labels.join(', ')}';
    if (group != null) {
      final field =
          filterFieldOf(collection, group.fieldId) ??
          (throw HarnessException.of(
            ErrorCode.unknownField,
            'The group-by field is gone from ${collection.name}; '
            'run the aggregate again.',
            path: 'groupBy.field',
          ));
      final grouped = await _group(ctx, field, group.bucket, run.objects);
      _order(grouped, field, spec.orderBy, fold);
      final listed = grouped.take(group.limit).toList();
      result['groups'] = [
        for (final g in listed)
          {
            'key': g.key,
            'label': g.label,
            'count': g.objects.length,
            'm': g.metrics ?? fold(g.objects),
          },
      ];
      if (grouped.length > listed.length) {
        result['otherGroups'] = grouped.length - listed.length;
      }
      final by = _isDate(field) ? ' (${group.bucket.name})' : '';
      summary += ' by ${shaper.name(field.name)}$by: ${grouped.length} groups';
    }
    result['totals'] = fold(run.objects);
    if (unit != null) result['unit'] = unit;
    result['summary'] = summary;
    return (run: run, result: result);
  }

  /// `cards.distinct`: `{collection | from: "@screen", field, where?,
  /// search?, limit?}` → `{total, values: [{value, label, count}],
  /// otherValues?, empty?, truncated?, summary}`, most frequent first;
  /// cards with no value are counted in `empty`, not listed.
  Future<Map<String, Object?>> distinct(
    Map<String, Object?> args,
    HarnessContext ctx,
  ) => queries.withScope(args, ctx, (scope) async {
    final base = queries.compileBase(scope, args);
    final ref = args['field'];
    if (ref is! String) throw _args('"field" must be a string.', 'field');
    final fieldId = scope.refs.fieldIdOrMeta(scope.collection, ref);
    queries.checkReadable(scope, fieldId, path: 'field');
    final limit = switch (args['limit']) {
      null => kMaxGroups,
      final int n when n >= 1 && n <= kMaxGroups => n,
      _ => throw _args('"limit" is 1..$kMaxGroups.', 'limit'),
    };
    final run = await queries.run(_unordered(base.spec), ctx, reads: [fieldId]);
    final field = filterFieldOf(run.collection, fieldId)!;
    final grouped = await _group(ctx, field, DateBucket.day, run.objects);
    final empty = grouped.where((g) => g.key == null).firstOrNull;
    final values = grouped.where((g) => g.key != null).toList()
      ..sort(
        (a, b) => a.objects.length != b.objects.length
            ? b.objects.length - a.objects.length
            : _compare(a.order, b.order),
      );
    final listed = [
      for (final g in values.take(limit))
        {'value': g.key, 'label': g.label, 'count': g.objects.length},
    ];
    final name = shaper.name(run.collection.name);
    return shaper.fit(listed.length, (k) {
      final other = values.length - k;
      return {
        'total': run.total,
        'values': listed.take(k).toList(),
        if (other > 0) 'otherValues': other,
        if (empty != null && empty.objects.isNotEmpty)
          'empty': empty.objects.length,
        if (k < listed.length) 'truncated': true,
        'summary':
            '${values.length} distinct ${shaper.name(field.name)} values '
            'over ${run.total} $name',
      };
    }, budget: shaper.rowBudget);
  });

  // ---------------------------------------------------------------------------

  List<MetricSpec> _metrics(QueryScope scope, Object? raw) {
    if (raw == null) return const [(op: AggregateOp.count, fieldId: null)];
    if (raw is! List || raw.isEmpty || raw.length > kMaxMetrics) {
      throw _args('"metrics" lists 1..$kMaxMetrics {op, field?}.', 'metrics');
    }
    return [for (final (i, m) in raw.indexed) _metric(scope, m, 'metrics[$i]')];
  }

  MetricSpec _metric(QueryScope scope, Object? raw, String path) {
    if (raw is! Map) throw _args('A metric is {op, field?}.', path);
    final op = AggregateOp.values.asNameMap()[raw['op']];
    if (op == null) {
      throw HarnessException.of(
        ErrorCode.invalidArgs,
        'There is no metric op "${raw['op']}".',
        path: '$path.op',
        candidates: [for (final o in AggregateOp.values) o.name],
      );
    }
    final ref = raw['field'];
    // A count counts cards; a field adds nothing to it.
    if (op == AggregateOp.count) return (op: op, fieldId: null);
    if (ref is! String) {
      throw _args('${op.name} needs a "field".', '$path.field');
    }
    final c = scope.collection;
    final fieldId = scope.refs.fieldIdOrMeta(c, ref, path: '$path.field');
    final dates = op == AggregateOp.min || op == AggregateOp.max;
    bool fits(FieldDefinition f) => switch (_presented(f)) {
      NumberFieldDefinition() || AutoNumberFieldDefinition() => true,
      DateFieldDefinition() => dates,
      _ => false,
    };
    final field = filterFieldOf(c, fieldId)!;
    if (!fits(field)) {
      throw HarnessException.of(
        ErrorCode.invalidArgs,
        '${op.name} needs a number${dates ? ' or date' : ''} field; '
        '"${field.name}" is not one.',
        path: '$path.field',
        candidates: [
          for (final f in c.fields)
            if (fits(f)) f.name,
          if (dates) ...[kCreatedAtRef, kUpdatedAtRef],
        ],
      );
    }
    queries.checkReadable(scope, fieldId, path: '$path.field');
    return (op: op, fieldId: fieldId);
  }

  GroupSpec? _groupBy(QueryScope scope, Object? raw) {
    if (raw == null) return null;
    if (raw is! Map) throw _args('"groupBy" is {field, bucket?}.', 'groupBy');
    final ref = raw['field'];
    if (ref is! String) {
      throw _args('"field" must be a string.', 'groupBy.field');
    }
    final c = scope.collection;
    final fieldId = scope.refs.fieldIdOrMeta(c, ref, path: 'groupBy.field');
    queries.checkReadable(scope, fieldId, path: 'groupBy.field');
    final field = filterFieldOf(c, fieldId)!;
    final bucketName = raw['bucket'];
    final bucket = DateBucket.values.asNameMap()[bucketName];
    if (bucketName != null && bucket == null) {
      throw HarnessException.of(
        ErrorCode.invalidArgs,
        'There is no bucket "$bucketName".',
        path: 'groupBy.bucket',
        candidates: [for (final b in DateBucket.values) b.name],
      );
    }
    if (bucket != null && !_isDate(field)) {
      throw _args(
        'bucket goes with date fields; "${field.name}" is not one.',
        'groupBy.bucket',
      );
    }
    final limit = switch (raw['limit']) {
      null => kMaxGroups,
      final int n when n >= 1 && n <= kMaxGroups => n,
      _ => throw _args('"limit" is 1..$kMaxGroups.', 'groupBy.limit'),
    };
    return (fieldId: fieldId, bucket: bucket ?? DateBucket.day, limit: limit);
  }

  OrderSpec? _orderBy(Object? raw, int metricCount) {
    if (raw == null) return null;
    if (raw is! Map) {
      throw _args('"orderBy" is {by: key|metric, index?, dir?}.', 'orderBy');
    }
    final by = raw['by'] ?? 'key';
    if (by != 'key' && by != 'metric') {
      throw _args('"by" is key or metric.', 'orderBy.by');
    }
    final index = raw['index'] ?? 0;
    if (index is! int || index < 0 || index >= metricCount) {
      throw _args(
        '"index" points into metrics (0..${metricCount - 1}).',
        'orderBy.index',
      );
    }
    final dir = raw['dir'] ?? (by == 'metric' ? 'desc' : 'asc');
    if (dir != 'asc' && dir != 'desc') {
      throw _args('"dir" is asc or desc.', 'orderBy.dir');
    }
    return (byMetric: by == 'metric', index: index, descending: dir == 'desc');
  }

  /// Buckets [objects] by [field] (see the class doc), groups in natural
  /// order with `No <field>` last; empty select options kept.
  Future<List<_Group>> _group(
    HarnessContext ctx,
    FieldDefinition field,
    DateBucket bucket,
    List<MorkvaObject> objects,
  ) async {
    final presented = _presented(field);
    final groups = <Object?, _Group>{};
    if (presented is SingleSelectFieldDefinition) {
      for (final (i, o) in presented.options.indexed) {
        groups[o.id] = _Group(o.id, shaper.label(o.label), i);
      }
    }
    final keys = _keyer(ctx, field, bucket);
    final none = _Group(null, shaper.name('No ${field.name}'), null);
    for (final (i, o) in objects.indexed) {
      if (i > 0 && i % 2000 == 0) await Future<void>.value();
      final cardKeys = keys(o);
      if (cardKeys.isEmpty) {
        none.objects.add(o);
        continue;
      }
      for (final k in cardKeys) {
        (groups[k.key] ??= _Group(k.key, k.label, k.order)).objects.add(o);
      }
    }
    return [
      ...groups.values.toList()..sort((a, b) => _compare(a.order, b.order)),
      if (none.objects.isNotEmpty) none,
    ];
  }

  /// Orders [groups] in place: by metric, by key, or (no [order]) by key
  /// except text and files, which list the most cards first. `No <field>`
  /// stays last unless ordering by a metric.
  void _order(
    List<_Group> groups,
    FieldDefinition field,
    OrderSpec? order,
    List<Object?> Function(List<MorkvaObject>) fold,
  ) {
    final sign = (order?.descending ?? false) ? -1 : 1;
    int byKey(_Group a, _Group b) {
      if (a.key == null || b.key == null) {
        return a.key == null ? (b.key == null ? 0 : 1) : -1;
      }
      return _compare(a.order, b.order) * sign;
    }

    if (order == null) {
      final presented = _presented(field);
      if (presented is TextFieldDefinition ||
          presented is FileFieldDefinition) {
        groups.sort((a, b) {
          if (a.key == null || b.key == null) return byKey(a, b);
          final c = b.objects.length - a.objects.length;
          return c != 0 ? c : byKey(a, b);
        });
      }
      return;
    }
    if (!order.byMetric) {
      groups.sort(byKey);
      return;
    }
    for (final g in groups) {
      g.metrics = fold(g.objects);
    }
    groups.sort((a, b) {
      final va = a.metrics![order.index];
      final vb = b.metrics![order.index];
      if (va == null || vb == null) {
        return va == null ? (vb == null ? byKey(a, b) : 1) : -1;
      }
      final c = _compare(va, vb) * sign;
      return c != 0 ? c : byKey(a, b);
    });
  }

  /// The group keys of a card for [field]: none when empty.
  List<({Object key, String label, Object? order})> Function(MorkvaObject)
  _keyer(HarnessContext ctx, FieldDefinition field, DateBucket bucket) {
    if (field.id == kCreatedAtRef || field.id == kUpdatedAtRef) {
      return (o) {
        final at = field.id == kCreatedAtRef ? o.createdAt : o.updatedAt;
        return [_dateKey(dateBucketStart(at.toLocal(), bucket), bucket)];
      };
    }
    final presented = _presented(field);
    // Display order and titles of the linked cards, when they may show.
    Map<String, ({String label, int rank})>? linked;
    if (presented case ReferenceFieldDefinition(
      :final targetCollectionId,
    ) when ctx.grants.allowsCollection(targetCollectionId)) {
      final labels = cache.current(targetCollectionId)?.labels.labels;
      if (labels != null) {
        linked = {
          for (final (i, e) in labels.entries.indexed)
            e.key: (label: shaper.label(e.value), rank: i),
        };
      }
    }
    return (o) {
      final (f, v) = presentedAs(field, o[field.id] ?? field.emptyValue());
      if (v.isEmpty) return const [];
      switch ((f, v)) {
        case (
          SingleSelectFieldDefinition(:final options),
          SingleSelectFieldValue(:final optionId),
        ):
          final i = options.indexWhere((x) => x.id == optionId);
          return i < 0
              ? const []
              : [
                  (
                    key: optionId!,
                    label: shaper.label(options[i].label),
                    order: i,
                  ),
                ];
        case (
          MultiSelectFieldDefinition(:final options),
          MultiSelectFieldValue(:final optionIds),
        ):
          return [
            for (final (i, x) in options.indexed)
              if (optionIds.contains(x.id))
                (key: x.id, label: shaper.label(x.label), order: i),
          ];
        case (
          ReferenceFieldDefinition(:final multiple),
          ReferenceFieldValue(:final objectIds),
        ):
          final ids = multiple ? objectIds.toSet() : objectIds.take(1);
          return [
            for (final id in ids)
              if (linked == null)
                (key: id, label: id, order: id)
              else if (linked[id] case final hit?)
                (key: id, label: hit.label, order: hit.rank),
          ];
        case (final DateFieldDefinition d, DateFieldValue(value: final dt?)):
          return [_dateKey(dateBucketOf(d, dt, bucket), bucket)];
        case (_, BooleanFieldValue(value: final b?)):
          return [(key: b, label: b ? 'Yes' : 'No', order: b ? 0 : 1)];
        case (_, NumberFieldValue(value: final n?)) when n.isFinite:
          return [(key: n, label: formatFieldValue(f, v), order: n)];
        case (_, AutoNumberFieldValue(sequence: final n?)):
          return [(key: n, label: formatFieldValue(f, v), order: n)];
        case (_, TextFieldValue(:final text?)):
          return [
            (key: text, label: shaper.label(text), order: text.toLowerCase()),
          ];
        case (_, FileFieldValue(:final attachments)):
          return [
            for (final name in {for (final a in attachments) a.name})
              (key: name, label: shaper.label(name), order: name.toLowerCase()),
          ];
      }
      return const [];
    };
  }

  static ({Object key, String label, Object? order}) _dateKey(
    DateTime start,
    DateBucket bucket,
  ) => (
    key: dateBucketKey(start, bucket),
    label: dateBucketLabel(start, bucket),
    order: start,
  );

  /// Reads [m]'s value from a card as `foldAggregate` takes it: `num` or
  /// `DateTime`, anything else null (the `Derivation._aggregatable` rule).
  Object? Function(MorkvaObject) _reader(Collection c, MetricSpec m) {
    final id = m.fieldId;
    if (id == null) return (_) => null;
    if (id == kCreatedAtRef) return (o) => o.createdAt;
    if (id == kUpdatedAtRef) return (o) => o.updatedAt;
    final field =
        c.fieldById(id) ??
        (throw HarnessException.of(
          ErrorCode.unknownField,
          'A metric field is gone from ${c.name}; run the aggregate again.',
          path: 'metrics',
        ));
    return (o) {
      final (f, v) = presentedAs(field, o[id] ?? field.emptyValue());
      final value = Derivation.formulaValueOf(f, v);
      return value is num || value is DateTime ? value : null;
    };
  }

  String _metricLabel(Collection c, MetricSpec m) {
    final id = m.fieldId;
    if (id == null) return m.op.name;
    final name = filterFieldOf(c, id)?.name ?? id;
    return '${m.op.name} ${shaper.name(name)}';
  }

  /// The unit every numeric metric shares, or null.
  String? _unit(Collection c, List<MetricSpec> metrics) {
    final units = <String?>{
      for (final m in metrics)
        if (m.fieldId case final id?)
          if (c.fieldById(id) case final f?
              when _presented(f) is! DateFieldDefinition)
            shaper.unitOf(f),
    };
    return units.length == 1 ? units.single : null;
  }

  /// A metric value as JSON: numbers cleaned, a card timestamp ([instant])
  /// ISO, any other date `YYYY-MM-DD` (field values fold as UTC-midnight
  /// days, as in formulas).
  static Object? _json(Object? value, {required bool instant}) =>
      switch (value) {
        num() => cleanNumber(value),
        DateTime() when instant => isoInstant(value),
        DateTime() => isoDay(value.toUtc()),
        _ => value,
      };

  /// [spec]'s matching part only: folding needs no order, and dropping it
  /// spares a sort (and a derivation, when it sorts by a calculated field).
  static QuerySpec _unordered(QuerySpec spec) => QuerySpec(
    collectionId: spec.collectionId,
    filters: spec.filters,
    search: spec.search,
  );

  static bool _isDate(FieldDefinition field) =>
      _presented(field) is DateFieldDefinition;

  static FieldDefinition _presented(FieldDefinition f) =>
      f is CalculatedFieldDefinition ? f.outputField : f;

  static int _compare(Object? a, Object? b) {
    if (a == null || b == null) return a == null ? (b == null ? 0 : 1) : -1;
    if (a is num && b is num) return a.compareTo(b);
    if (a is DateTime && b is DateTime) return a.compareTo(b);
    return '$a'.compareTo('$b');
  }

  static HarnessException _args(String message, String path) =>
      HarnessException.of(ErrorCode.invalidArgs, message, path: path);
}

final class _Group {
  _Group(this.key, this.label, this.order);

  /// Option id, card id, bucket key, value; null for `No <field>`.
  final Object? key;
  final String label;

  /// Natural sort key.
  final Object? order;
  final List<MorkvaObject> objects = [];

  /// Folded metrics, once ordering by a metric needed them.
  List<Object?>? metrics;
}
