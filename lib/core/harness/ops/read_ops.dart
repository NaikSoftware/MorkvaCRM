import '../api/api_version.dart';
import '../api/capability.dart';
import '../api/envelope.dart';
import '../api/harness_context.dart';
import '../api/operation.dart';
import '../cache/workspace_cache.dart';
import '../input/ref_resolver.dart';
import '../query/aggregate_engine.dart';
import '../query/cache_workspace_reader.dart';
import '../query/query_engine.dart';
import '../query/workspace_digest.dart';
import '../schema/arg_shapes.dart';
import '../schema/json_schema.dart';
import 'registry.dart';

/// Registers the read ops: `workspace.describe`, `collections.get` and
/// `cards.query/page/get/find/aggregate/distinct`.
///
/// They read through [queries] and [aggregates] (which share one
/// `WorkspaceCache` and `ResultStore`). [thread] names the chat thread
/// whose result handles a call stores and pages; the host reads it per call,
/// so switching threads needs no re-registration. Every card read takes
/// `from: "@screen"` (the screen's collection, filters, search and sort).
void registerReadOps(
  OperationRegistry ops, {
  required QueryEngine queries,
  required AggregateEngine aggregates,
  required String Function() thread,
  WorkspaceDigest digest = const WorkspaceDigest(),
}) {
  final cache = queries.cache;
  for (final op in [
    _ReadOp(_describe, (args, ctx) => _describeRun(cache, digest, args, ctx)),
    _ReadOp(
      _collectionsGet,
      (args, ctx) => _getSchema(cache, digest, args, ctx),
    ),
    _ReadOp(
      _cardsQuery,
      (args, ctx) => queries.query(args, ctx, thread: thread()),
    ),
    _ReadOp(
      _cardsPage,
      (args, ctx) => queries.page(args, ctx, thread: thread()),
    ),
    _ReadOp(_cardsGet, queries.get),
    _ReadOp(_cardsFind, (args, ctx) => _find(queries, args, ctx)),
    _ReadOp(
      _cardsAggregate,
      (args, ctx) => aggregates.aggregate(args, ctx, thread: thread()),
    ),
    _ReadOp(_cardsDistinct, aggregates.distinct),
  ]) {
    ops.register(op);
  }
}

typedef _Json = Map<String, Object?>;

/// A read op: the engines resolve refs and check grants themselves, so
/// decoding passes the schema-valid args through.
final class _ReadOp extends Operation<_Json> {
  _ReadOp(this.descriptor, this._run);

  @override
  final OperationDescriptor descriptor;
  final Future<_Json> Function(_Json args, HarnessContext ctx) _run;

  @override
  _Json decode(_Json args, HarnessContext ctx) => args;

  @override
  Future<OpResult> run(_Json args, HarnessContext ctx, HarnessRequest r) async {
    final result = await _run(args, ctx);
    return OpResult(result, truncated: result['truncated'] == true);
  }
}

// -----------------------------------------------------------------------------
// workspace.describe / collections.get

Future<_Json> _describeRun(
  WorkspaceCache cache,
  WorkspaceDigest digest,
  _Json args,
  HarnessContext ctx,
) async {
  await cache.ready;
  final refs = RefResolver(CacheWorkspaceReader(cache), ctx);
  final named = args['collections'] as List?;
  final collections = named == null
      ? refs.visibleCollections
      : {
          for (final (i, ref) in named.indexed)
            refs.collection('$ref', path: 'collections[$i]'),
        }.toList();
  final full = args['detail'] == 'full';
  final result = digest.shaper.fitSchema({
    'apiVersion': kHarnessVersion,
    'today': _isoDay(ctx.today),
    if (ctx.timeZoneName.trim().isNotEmpty)
      'timeZone': digest.shaper.name(ctx.timeZoneName),
    'collections': [
      for (final c in collections)
        digest.describe(
          c,
          all: cache.collections,
          grants: ctx.grants,
          count: cache.current(c.id)?.count,
          full: full,
        ),
    ],
  });
  final n = collections.length;
  return {...result, 'summary': '$n ${n == 1 ? 'collection' : 'collections'}'};
}

Future<_Json> _getSchema(
  WorkspaceCache cache,
  WorkspaceDigest digest,
  _Json args,
  HarnessContext ctx,
) async {
  await cache.ready;
  final refs = RefResolver(CacheWorkspaceReader(cache), ctx);
  final collection = refs.collection(args['collection'] as String);
  final named = args['fields'] as List?;
  final fieldIds = named == null
      ? null
      : {
          for (final (i, ref) in named.indexed)
            refs.field(collection, '$ref', path: 'fields[$i]').id,
        };
  final int count;
  try {
    count = (await cache.read(collection.id)).count;
  } on MissingCollectionException {
    throw HarnessException.of(
      ErrorCode.unknownCollection,
      'Collection "${collection.name}" no longer exists.',
      path: 'collection',
    );
  }
  final result = digest.shaper.fitSchema(
    digest.schema(
      collection,
      all: cache.collections,
      grants: ctx.grants,
      count: count,
      fieldIds: fieldIds,
    ),
  );
  final fields = (result['fields'] as List).length;
  return {
    ...result,
    'summary':
        '${digest.shaper.name(collection.name)}: $fields fields, $count cards',
  };
}

// -----------------------------------------------------------------------------
// cards.find

/// `cards.find`, plus `from: "@screen"`: only the cards the screen shows
/// (its collection, filters and search) are searched.
Future<_Json> _find(QueryEngine queries, _Json args, HarnessContext ctx) {
  if (args['from'] == null) return queries.find(args, ctx);
  if (args['collections'] != null) {
    throw HarnessException.of(
      ErrorCode.invalidArgs,
      'Give "from" or "collections", not both.',
      path: 'collections',
    );
  }
  return queries.withScope(args, ctx, (scope) async {
    final base = queries.compileBase(scope, const {});
    final run = await queries.run(base.spec, ctx);
    final shown = run.ids.toSet();
    final limit = (args['limit'] as int?) ?? 10;
    final labels = run.derived.base.labels;
    final collection = scope.collection;
    final shaper = queries.shaper;
    final hits = [
      for (final hit in labels.search(args['text'] as String))
        if (shown.contains(hit.id))
          {
            'collection': collection.id,
            'id': hit.id,
            'title': shaper.label(labels.labelOf(hit.id)),
            'matchedField': shaper.name(
              collection.fieldById(hit.fieldId)?.name ?? hit.fieldId,
            ),
          },
    ].take(limit).toList();
    return shaper.fit(
      hits.length,
      (k) => {
        'hits': hits.take(k).toList(),
        'searched': [collection.id],
        if (k < hits.length) 'truncated': true,
        'summary':
            '${hits.length} found for '
            '${shaper.label(args['text'] as String).trim()} among the '
            '${run.total} ${shaper.name(collection.name)} on screen',
      },
      budget: shaper.rowBudget,
    );
  });
}

String _isoDay(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

// -----------------------------------------------------------------------------
// Descriptors

const String _screenRef = ScreenRefs.screen;

Map<String, Object?> _from() => JsonSchema.enumOf(const [
  _screenRef,
], description: 'The cards on the user\'s screen, instead of "collection".');

Map<String, Object?> _collection() =>
    refSchema(description: 'A collection id or name (omit with from).');

Map<String, Object?> _fields(int max) => JsonSchema.array(
  fieldRefSchema(),
  maxItems: max,
  description: 'The fields each row shows after its title.',
);

Map<String, Object?> _rowsResult({
  Map<String, Map<String, Object?>> extra = const {},
}) => JsonSchema.object(
  {
    'handle': JsonSchema.string(),
    'total': JsonSchema.integer(),
    'rows': JsonSchema.array(cardSchema()),
    'nextCursor': JsonSchema.string(),
    'truncated': JsonSchema.boolean(),
    'snapshotChanged': JsonSchema.boolean(),
    'hint': JsonSchema.string(),
    'units': JsonSchema.mapOf(JsonSchema.string()),
    'summary': JsonSchema.string(),
    ...extra,
  },
  required: ['handle', 'total', 'rows', 'summary'],
);

Map<String, Object?> _schemaResult() => JsonSchema.object(
  {
    'id': JsonSchema.string(),
    'name': JsonSchema.string(),
    'description': JsonSchema.string(),
    'icon': JsonSchema.string(),
    'count': JsonSchema.integer(),
    'fields': JsonSchema.array({
      'type': 'object',
      'description': 'A field definition (domain JSON) plus operators.',
    }),
    'moreFields': JsonSchema.array(JsonSchema.string()),
    'views': JsonSchema.array({'type': 'object'}),
    'truncated': JsonSchema.boolean(),
    'hint': JsonSchema.string(),
    'summary': JsonSchema.string(),
  },
  required: ['id', 'name', 'fields', 'views', 'summary'],
);

final OperationDescriptor _describe = OperationDescriptor(
  id: 'workspace.describe',
  kind: OpKind.read,
  capability: Capability.schemaRead,
  summary:
      'Lists the collections with their fields (type, options, links, '
      'formulas) and views. detail "full" adds option ids and descriptions.',
  argsSchema: JsonSchema.object({
    'collections': JsonSchema.array(
      refSchema(),
      maxItems: 30,
      description: 'Only these collections.',
    ),
    'detail': JsonSchema.enumOf(const ['digest', 'full']),
  }),
  resultSchema: JsonSchema.object(
    {
      'apiVersion': JsonSchema.string(),
      'today': JsonSchema.string(),
      'timeZone': JsonSchema.string(),
      'collections': JsonSchema.array({'type': 'object'}),
      'truncated': JsonSchema.boolean(),
      'hint': JsonSchema.string(),
      'summary': JsonSchema.string(),
    },
    required: ['apiVersion', 'today', 'collections', 'summary'],
  ),
);

final OperationDescriptor _collectionsGet = OperationDescriptor(
  id: 'collections.get',
  kind: OpKind.read,
  capability: Capability.schemaRead,
  summary:
      'One collection\'s full schema: every field\'s config and filter '
      'operators, formulas in name form, views and the card count.',
  argsSchema: JsonSchema.object(
    {
      'collection': refSchema(),
      'fields': JsonSchema.array(
        refSchema(),
        maxItems: 40,
        description: 'Only these fields.',
      ),
    },
    required: ['collection'],
  ),
  resultSchema: _schemaResult(),
);

final OperationDescriptor _cardsQuery = OperationDescriptor(
  id: 'cards.query',
  kind: OpKind.read,
  capability: Capability.dataRead,
  summary:
      'Finds cards by filters, search and sort and returns a page of rows '
      'plus the total. Use present "table" to show the rows to the user.',
  argsSchema: JsonSchema.object({
    'collection': _collection(),
    'from': _from(),
    'where': whereSchema(),
    'sort': sortSchema(),
    'search': JsonSchema.string(description: 'Words every card must contain.'),
    'fields': _fields(12),
    'view': refSchema(description: 'Start from this view\'s filters and sort.'),
    'limit': JsonSchema.integer(minimum: 1, maximum: 100),
    'meta': JsonSchema.boolean(description: 'Add createdAt / updatedAt.'),
    'present': JsonSchema.enumOf(const ['none', 'table']),
  }),
  resultSchema: _rowsResult(),
);

final OperationDescriptor _cardsPage = OperationDescriptor(
  id: 'cards.page',
  kind: OpKind.read,
  capability: Capability.dataRead,
  summary: 'The next page of an earlier cards.query result.',
  argsSchema: JsonSchema.object(
    {
      'handle': JsonSchema.string(),
      'cursor': JsonSchema.string(description: 'The nextCursor you got.'),
      'fields': _fields(12),
    },
    required: ['handle', 'cursor'],
  ),
  resultSchema: _rowsResult(),
);

final OperationDescriptor _cardsGet = OperationDescriptor(
  id: 'cards.get',
  kind: OpKind.read,
  capability: Capability.dataRead,
  summary:
      'Reads cards by id with calculated values and link titles. "@card" is '
      'the open card, "@selected" the selected ones.',
  argsSchema: JsonSchema.object(
    {
      'collection': _collection(),
      'from': _from(),
      'ids': JsonSchema.array(JsonSchema.string(), minItems: 1, maxItems: 25),
      'fields': _fields(12),
      'meta': JsonSchema.boolean(description: 'Add createdAt / updatedAt.'),
    },
    required: ['ids'],
  ),
  resultSchema: JsonSchema.object(
    {
      'rows': JsonSchema.array(cardSchema()),
      'missing': JsonSchema.array(JsonSchema.string()),
      'truncated': JsonSchema.boolean(),
      'hint': JsonSchema.string(),
      'units': JsonSchema.mapOf(JsonSchema.string()),
      'summary': JsonSchema.string(),
    },
    required: ['rows', 'missing', 'summary'],
  ),
);

final OperationDescriptor _cardsFind = OperationDescriptor(
  id: 'cards.find',
  kind: OpKind.read,
  capability: Capability.dataRead,
  summary:
      'Searches card titles and text across collections. Without '
      'collections it searches the screen\'s and recently read ones.',
  argsSchema: JsonSchema.object(
    {
      'text': JsonSchema.string(),
      'collections': JsonSchema.array(refSchema(), minItems: 1, maxItems: 5),
      'from': _from(),
      'limit': JsonSchema.integer(minimum: 1, maximum: 20),
    },
    required: ['text'],
  ),
  resultSchema: JsonSchema.object(
    {
      'hits': JsonSchema.array(
        JsonSchema.object(
          {
            'collection': JsonSchema.string(),
            'id': JsonSchema.string(),
            'title': JsonSchema.string(),
            'matchedField': JsonSchema.string(),
          },
          required: ['collection', 'id', 'title'],
        ),
      ),
      'searched': JsonSchema.array(JsonSchema.string()),
      'truncated': JsonSchema.boolean(),
      'hint': JsonSchema.string(),
      'summary': JsonSchema.string(),
    },
    required: ['hits', 'searched', 'summary'],
  ),
);

final OperationDescriptor _cardsAggregate = OperationDescriptor(
  id: 'cards.aggregate',
  kind: OpKind.read,
  capability: Capability.dataRead,
  summary:
      'Counts, sums, averages, min or max over matching cards, optionally '
      'grouped by a field or date bucket. Use present to show a table or chart.',
  argsSchema: JsonSchema.object({
    'collection': _collection(),
    'from': _from(),
    'where': whereSchema(),
    'search': JsonSchema.string(description: 'Words every card must contain.'),
    'groupBy': JsonSchema.object(
      {
        'field': fieldRefSchema(),
        'bucket': JsonSchema.enumOf(const [
          'day',
          'week',
          'month',
          'quarter',
          'year',
        ], description: 'For date fields.'),
        'limit': JsonSchema.integer(minimum: 1, maximum: 50),
      },
      required: ['field'],
    ),
    'metrics': JsonSchema.array(
      JsonSchema.object(
        {
          'op': JsonSchema.enumOf(const [
            'count',
            'sum',
            'average',
            'min',
            'max',
          ]),
          'field': fieldRefSchema(description: 'Not for count.'),
        },
        required: ['op'],
      ),
      minItems: 1,
      maxItems: 4,
      description: 'Defaults to a count.',
    ),
    'orderBy': JsonSchema.object({
      'by': JsonSchema.enumOf(const ['key', 'metric']),
      'index': JsonSchema.integer(
        minimum: 0,
        maximum: 3,
        description: 'Which metric.',
      ),
      'dir': JsonSchema.enumOf(const ['asc', 'desc']),
    }),
    'present': JsonSchema.enumOf(const ['none', 'table', 'bar', 'line']),
  }),
  resultSchema: JsonSchema.object(
    {
      'handle': JsonSchema.string(),
      'total': JsonSchema.integer(),
      'metrics': JsonSchema.array(JsonSchema.string()),
      'groups': JsonSchema.array(
        JsonSchema.object({
          'key': anyValueSchema(),
          'label': JsonSchema.string(),
          'count': JsonSchema.integer(),
          'm': JsonSchema.array(
            JsonSchema.anyOf([JsonSchema.number(), JsonSchema.string()]),
          ),
        }),
      ),
      'totals': JsonSchema.array(
        JsonSchema.anyOf([JsonSchema.number(), JsonSchema.string()]),
      ),
      'otherGroups': JsonSchema.integer(),
      'unit': JsonSchema.string(),
      'truncated': JsonSchema.boolean(),
      'hint': JsonSchema.string(),
      'summary': JsonSchema.string(),
    },
    required: ['handle', 'total', 'metrics', 'totals', 'summary'],
  ),
);

final OperationDescriptor _cardsDistinct = OperationDescriptor(
  id: 'cards.distinct',
  kind: OpKind.read,
  capability: Capability.dataRead,
  summary:
      'The distinct values of one field over matching cards, most frequent '
      'first, with counts.',
  argsSchema: JsonSchema.object(
    {
      'collection': _collection(),
      'from': _from(),
      'field': fieldRefSchema(),
      'where': whereSchema(),
      'search': JsonSchema.string(
        description: 'Words every card must contain.',
      ),
      'limit': JsonSchema.integer(minimum: 1, maximum: 50),
    },
    required: ['field'],
  ),
  resultSchema: JsonSchema.object(
    {
      'total': JsonSchema.integer(),
      'values': JsonSchema.array(
        JsonSchema.object({
          'value': anyValueSchema(),
          'label': JsonSchema.string(),
          'count': JsonSchema.integer(),
        }),
      ),
      'otherValues': JsonSchema.integer(),
      'empty': JsonSchema.integer(),
      'truncated': JsonSchema.boolean(),
      'summary': JsonSchema.string(),
    },
    required: ['total', 'values', 'summary'],
  ),
);
