import '../../domain/domain.dart';
import '../api/capability.dart';
import '../api/envelope.dart';
import '../api/harness_context.dart';
import '../cache/derived_snapshot.dart';
import '../cache/result_store.dart';
import '../cache/workspace_cache.dart';
import '../input/filter_compiler.dart';
import '../input/ref_resolver.dart';
import '../schema/arg_shapes.dart';
import 'cache_workspace_reader.dart';
import 'result_shaper.dart';

/// A resolved, re-runnable card query: ids only, every filter validated and
/// relative dates already expanded. Stored as a result handle's spec, so
/// paging and the UI re-run it exactly.
final class QuerySpec {
  const QuerySpec({
    required this.collectionId,
    this.filters = const [],
    this.search,
    this.sort,
    this.orderViewId,
    this.fieldIds = const [],
    this.meta = false,
    this.limit = kDefaultRowLimit,
  });

  /// Throws [FormatException] when [json] is not a query spec.
  factory QuerySpec.fromJson(Map<String, Object?> json) {
    if (json['kind'] != 'query' || json['collectionId'] is! String) {
      throw const FormatException('Not a query spec');
    }
    final sort = json['sort'];
    return QuerySpec(
      collectionId: json['collectionId'] as String,
      filters: [
        for (final f in (json['filters'] as List?) ?? const [])
          ViewFilter.fromJson((f as Map).cast<String, dynamic>()),
      ],
      search: json['search'] as String?,
      sort: sort is Map
          ? ViewSort.fromJson(sort.cast<String, dynamic>())
          : null,
      orderViewId: json['orderViewId'] as String?,
      fieldIds: [
        for (final id in (json['fieldIds'] as List?) ?? const []) id as String,
      ],
      meta: json['meta'] == true,
      limit: (json['limit'] as int?) ?? kDefaultRowLimit,
    );
  }

  final String collectionId;

  /// AND-ed; ids may be [kCreatedAtRef] / [kUpdatedAtRef].
  final List<ViewFilter> filters;

  /// Every whitespace-separated term must occur in a searchable value.
  final String? search;

  /// Null means the manual order of [orderViewId].
  final ViewSort? sort;

  /// The view whose manual order applies without [sort] (and breaks
  /// nothing with it).
  final String? orderViewId;

  /// The fields each row shows after its title.
  final List<String> fieldIds;

  /// Whether rows carry `createdAt` / `updatedAt`.
  final bool meta;

  /// Rows per page.
  final int limit;

  QuerySpec copyWith({
    List<String>? fieldIds,
    bool? meta,
    int? limit,
    ViewSort? sort,
  }) => QuerySpec(
    collectionId: collectionId,
    filters: filters,
    search: search,
    sort: sort ?? this.sort,
    orderViewId: orderViewId,
    fieldIds: fieldIds ?? this.fieldIds,
    meta: meta ?? this.meta,
    limit: limit ?? this.limit,
  );

  Map<String, Object?> toJson() => {
    'kind': 'query',
    'collectionId': collectionId,
    if (filters.isNotEmpty) 'filters': [for (final f in filters) f.toJson()],
    if (search != null) 'search': search,
    if (sort != null) 'sort': sort!.toJson(),
    if (orderViewId != null) 'orderViewId': orderViewId,
    if (fieldIds.isNotEmpty) 'fieldIds': fieldIds,
    if (meta) 'meta': true,
    'limit': limit,
  };
}

/// Rows a page holds unless the caller asks otherwise.
const int kDefaultRowLimit = 20;

/// The most rows a page holds.
const int kMaxRowLimit = 100;

/// The most fields a row projects (besides its title).
const int kMaxRowFields = 12;

/// How many fields a row shows by default after its title.
const int kDefaultRowFields = 5;

/// The matching cards of one [QuerySpec] run, in result order.
final class QueryRun {
  QueryRun({
    required this.spec,
    required this.derived,
    required this.objects,
    required this.scanned,
  });

  final QuerySpec spec;

  /// The state the run read (calculated values on demand).
  final DerivedSnapshot derived;

  /// The matching cards, ordered; with calculated values filled when a
  /// filter, the sort or an extra read touched one.
  final List<MorkvaObject> objects;

  /// How many cards the collection had before filtering.
  final int scanned;

  Collection get collection => derived.schema;

  int get total => objects.length;

  List<String> get ids => [for (final o in objects) o.id];

  /// What a stored result of this run is keyed by.
  Map<String, int> get generations => derived.generations;
}

/// One read call's working set: the collection it reads (leased with the
/// collections its references point at) and the resolvers bound to it.
final class QueryScope {
  QueryScope._({
    required this.ctx,
    required this.collection,
    required this.refs,
    required this.compiler,
    required this.fromScreen,
  });

  final HarnessContext ctx;
  final Collection collection;
  final RefResolver refs;
  final FilterCompiler compiler;

  /// Whether the call said `"from": "@screen"`.
  final bool fromScreen;
}

/// The base of a read call, before projection: what to match and in which
/// order, plus where the defaults come from.
typedef QueryBase = ({
  QuerySpec spec,
  ViewDefinition? view,
  ScreenContext? screen,
});

/// Runs card reads over the [WorkspaceCache]: `cards.query` (filters,
/// search, sort, a page, a projection), `cards.page` from a handle,
/// `cards.get` and `cards.find`. Results are shaped by [shaper] and query
/// results stored in [results] behind a handle.
///
/// Query path: resolve refs and compile filters (never unvalidated), take
/// the derived snapshot, filter (Derivation skipped when no filter or sort
/// reads a calculated field), search the label index, order with
/// `applyView`, store the ordered ids, then project only the page's rows.
///
/// Every call leases its collection and the collections its references
/// point at for the call; the panel or the idle timer keeps them warm.
final class QueryEngine {
  QueryEngine(this.cache, this.results, {this.shaper = const ResultShaper()});

  final WorkspaceCache cache;
  final ResultStore results;
  final ResultShaper shaper;

  // ---------------------------------------------------------------------------
  // Ops

  /// `cards.query`: `{collection | from: "@screen", where?, sort?, search?,
  /// fields?, view?, limit?, meta?}` → `{handle, total, rows, nextCursor?,
  /// truncated?, hint?, units?, summary}`.
  Future<Map<String, Object?>> query(
    Map<String, Object?> args,
    HarnessContext ctx, {
    required String thread,
  }) => withScope(args, ctx, (scope) async {
    final base = compileBase(scope, args);
    final spec = base.spec.copyWith(
      fieldIds: projection(scope, args, view: base.view, screen: base.screen),
      meta: args['meta'] == true,
      limit: _limit(args['limit'], kDefaultRowLimit, kMaxRowLimit),
    );
    return execute(spec, ctx, thread: thread);
  });

  /// Runs [spec], stores its ordered ids under a handle (the same handle
  /// for the same spec over the same data) and returns its first page.
  Future<Map<String, Object?>> execute(
    QuerySpec spec,
    HarnessContext ctx, {
    required String thread,
  }) => _leased(spec.collectionId, ctx, () async {
    final run = await this.run(spec, ctx);
    final stored = results.put(
      thread: thread,
      spec: spec.toJson(),
      generations: run.generations,
      orderedIds: run.ids,
    );
    final name = shaper.name(run.collection.name);
    final filtered = spec.filters.isNotEmpty || spec.search != null;
    return _rows(
      ctx,
      spec,
      run.derived,
      stored.orderedIds,
      handle: stored.handle,
      offset: 0,
      summary: filtered
          ? 'Filtered ${run.scanned} → ${run.total} $name'
          : '${run.total} $name',
    );
  });

  /// `cards.page`: `{handle, cursor, fields?}` → the next page of a stored
  /// query with no recompute while its data is unchanged; when it moved, the
  /// spec re-runs under a new handle and the result says
  /// `snapshotChanged: true`.
  Future<Map<String, Object?>> page(
    Map<String, Object?> args,
    HarnessContext ctx, {
    required String thread,
  }) async {
    final handle = args['handle'];
    if (handle is! String) throw _args('"handle" must be a string.', 'handle');
    final offset = _offset(args['cursor']);
    final stored = results.get(handle, thread: thread);
    if (stored == null) {
      throw HarnessException.of(
        ErrorCode.invalidArgs,
        'Result $handle is gone (results expire); run cards.query again.',
        path: 'handle',
      );
    }
    final QuerySpec spec;
    try {
      spec = QuerySpec.fromJson(stored.spec);
    } on FormatException {
      throw _args('$handle is not a cards.query result.', 'handle');
    }
    await cache.ready;
    final collection = _collection(spec.collectionId, ctx, 'handle');
    return _leased(collection.id, ctx, () async {
      var shown = spec;
      if (args['fields'] case final List refs) {
        final scope = _scope(collection, ctx, fromScreen: false);
        shown = spec.copyWith(fieldIds: _explicitFields(scope, refs));
      }
      var derived = await cache.derive(collection.id, today: ctx.today);
      var current = stored;
      if (!stored.isCurrent(derived.generations)) {
        final run = await this.run(spec, ctx);
        derived = run.derived;
        current = results.put(
          thread: thread,
          spec: stored.spec,
          generations: run.generations,
          orderedIds: run.ids,
        );
      }
      final total = current.total;
      final end = (offset + shown.limit).clamp(0, total);
      final name = shaper.name(collection.name);
      return _rows(
        ctx,
        shown,
        derived,
        current.orderedIds,
        handle: current.handle,
        offset: offset,
        snapshotChanged: !identical(current, stored),
        summary: offset >= total
            ? 'No more $name (total $total)'
            : '$name ${offset + 1}–$end of $total',
      );
    });
  }

  /// `cards.get`: `{collection, ids, fields?, meta?}` → `{rows, missing,
  /// truncated?, summary}`, with calculated values and reference titles.
  /// `@card` / `@selected` name the screen's cards.
  Future<Map<String, Object?>> get(
    Map<String, Object?> args,
    HarnessContext ctx,
  ) => withScope(args, ctx, (scope) async {
    final collection = scope.collection;
    final raw = args['ids'];
    if (raw is! List) throw _args('"ids" must be a list.', 'ids');
    final derived = await cache.derive(collection.id, today: ctx.today);
    final found = <MorkvaObject>[];
    final missing = <String>[];
    final seen = <String>{};
    for (final (i, ref) in raw.indexed) {
      if (ref is! String) throw _args('Ids are strings.', 'ids[$i]');
      final ids = ref.trim().startsWith('@')
          ? scope.refs.cards(collection, [ref], path: 'ids[$i]')
          : [ref];
      for (final id in ids) {
        if (!seen.add(id)) continue;
        final o = derived.base[id];
        o == null ? missing.add(id) : found.add(o);
      }
    }
    final fields = _fields(
      collection,
      args['fields'] is List
          ? _explicitFields(scope, args['fields'] as List)
          : projection(scope, const {}),
    );
    final rows = [
      for (final o in found)
        _card(ctx, derived, o, fields, meta: args['meta'] == true),
    ];
    final name = shaper.name(collection.name);
    return shaper.fit(
      rows.length,
      (k) => {
        'rows': rows.take(k).toList(),
        'missing': missing,
        if (k < rows.length) ...{
          'truncated': true,
          'hint': 'Ask for fewer ids or fewer fields.',
        },
        ..._units(fields),
        'summary': missing.isEmpty
            ? '${found.length} $name'
            : '${found.length} $name, ${missing.length} not found',
      },
      budget: shaper.rowBudget,
    );
  });

  /// `cards.find`: `{text, collections?, limit?}` → `{hits: [{collection,
  /// id, title, matchedField}], searched, summary}`. Without `collections`
  /// it searches the screen's collection and those already held, so it
  /// never leases the whole workspace.
  Future<Map<String, Object?>> find(
    Map<String, Object?> args,
    HarnessContext ctx,
  ) async {
    final text = args['text'];
    if (text is! String || text.trim().isEmpty) {
      throw _args('"text" must be non-blank.', 'text');
    }
    final limit = _limit(args['limit'], 10, 20);
    await cache.ready;
    _checkBound();
    final refs = RefResolver(CacheWorkspaceReader(cache), ctx);
    final List<Collection> targets;
    if (args['collections'] case final List named) {
      targets = [
        for (final (i, ref) in named.indexed)
          refs.collection('$ref', path: 'collections[$i]'),
      ];
    } else {
      final ids = {?ctx.focus?.collectionId, ...cache.liveCollectionIds};
      targets = [
        for (final id in ids)
          if (cache.collection(id) case final c?
              when ctx.grants.allowsCollection(id))
            c,
      ];
    }
    final unique = {for (final c in targets) c.id: c}.values.toList();
    final lease = await _lease(unique.map((c) => c.id));
    try {
      final hits = <Map<String, Object?>>[];
      for (final c in unique) {
        if (hits.length >= limit) break;
        final snapshot = lease.snapshot(c.id);
        for (final hit in snapshot.labels.search(
          text,
          limit: limit - hits.length,
        )) {
          hits.add({
            'collection': c.id,
            'id': hit.id,
            'title': shaper.label(snapshot.labels.labelOf(hit.id)),
            'matchedField': shaper.name(
              c.fieldById(hit.fieldId)?.name ?? hit.fieldId,
            ),
          });
        }
      }
      final names = [for (final c in unique) shaper.name(c.name)].join(', ');
      return shaper.fit(
        hits.length,
        (k) => {
          'hits': hits.take(k).toList(),
          'searched': [for (final c in unique) c.id],
          if (k < hits.length) 'truncated': true,
          if (unique.isEmpty)
            'hint': 'Name the collections to search in "collections".',
          'summary': unique.isEmpty
              ? 'Nothing searched'
              : '${hits.length} found for ${shaper.label(text).trim()} '
                    'in $names',
        },
        budget: shaper.rowBudget,
      );
    } finally {
      lease.release();
    }
  }

  // ---------------------------------------------------------------------------
  // Building blocks (shared with the aggregate engine and the planners)

  /// Resolves the collection [args] read (`collection`, or `from:
  /// "@screen"`), leases it with the collections its references point at,
  /// and runs [body] in that scope.
  Future<T> withScope<T>(
    Map<String, Object?> args,
    HarnessContext ctx,
    Future<T> Function(QueryScope scope) body,
  ) async {
    await cache.ready;
    _checkBound();
    final refs = RefResolver(CacheWorkspaceReader(cache), ctx);
    final from = args['from'];
    final Collection collection;
    if (from != null) {
      if (from != ScreenRefs.screen) {
        throw HarnessException.of(
          ErrorCode.invalidArgs,
          '"from" only takes "${ScreenRefs.screen}".',
          path: 'from',
          candidates: const [ScreenRefs.screen],
        );
      }
      if (args['view'] != null) {
        throw _args('Give "from" or "view", not both.', 'view');
      }
      collection = refs.screenCollection(path: 'from');
      if (args['collection'] case final String ref
          when refs.collection(ref).id != collection.id) {
        throw _args(
          '"$ref" is not the collection on screen; drop "from" or '
              '"collection".',
          'collection',
        );
      }
    } else {
      final ref = args['collection'];
      if (ref is! String) {
        throw _args(
          'Name a "collection" (or use from: "@screen").',
          'collection',
        );
      }
      collection = refs.collection(ref);
    }
    return _leased(
      collection.id,
      ctx,
      () => body(_scope(collection, ctx, fromScreen: from != null)),
    );
  }

  /// What [args] (`where`, `sort`, `search`, `view`, or the screen's query
  /// with `from`) match, ordered, before projection. The screen's own
  /// search and an extra `search` must both match; `sort` replaces the
  /// view's or the screen's sort. Without a view the collection's first
  /// view's sort and manual order apply (the order the user knows).
  QueryBase compileBase(QueryScope scope, Map<String, Object?> args) {
    final collection = scope.collection;
    final where = _list(args['where'], 'where');
    final rawSort = args['sort'];
    if (rawSort != null && rawSort is! Map) {
      throw _args('"sort" is {field, dir}.', 'sort');
    }
    final sort = rawSort == null
        ? null
        : scope.compiler.compileSort(
            collection,
            (rawSort as Map).cast<String, Object?>(),
          );
    final search = args['search'];
    if (search != null && search is! String) {
      throw _args('"search" must be a string.', 'search');
    }

    final QuerySpec spec;
    ViewDefinition? view;
    ScreenContext? screen;
    if (scope.fromScreen) {
      final q = scope.compiler.screenQuery(where: where);
      view = q.view;
      screen = q.screen;
      spec = QuerySpec(
        collectionId: collection.id,
        filters: q.filters,
        search: _joinSearch(q.search, search as String?),
        sort: sort ?? q.sort,
        orderViewId: q.view?.id,
      );
    } else {
      if (args['view'] case final Object ref) {
        if (ref is! String) throw _args('"view" must be a string.', 'view');
        view = scope.refs.view(collection, ref);
      }
      final order = view ?? collection.views.firstOrNull;
      spec = QuerySpec(
        collectionId: collection.id,
        filters: [
          // A view's broken filters pass on screen; they do here too.
          for (final f in view?.filters ?? const <ViewFilter>[])
            if (filterFieldOf(collection, f.fieldId) case final field?
                when filterProblem(field, f) == null)
              f,
          if (where != null) ...scope.compiler.compile(collection, where),
        ],
        search: _joinSearch(null, search as String?),
        sort: sort ?? order?.sort,
        orderViewId: order?.id,
      );
    }
    for (final (i, f) in spec.filters.indexed) {
      checkReadable(scope, f.fieldId, path: 'where[$i]');
    }
    if (spec.sort case final s?) checkReadable(scope, s.fieldId, path: 'sort');
    return (spec: spec, view: view, screen: screen);
  }

  /// The fields rows show: `fields` when given (≤ [kMaxRowFields]), else
  /// up to [kDefaultRowFields] of the screen's columns, the view's fields or
  /// the first view's, the title field and unreadable fields left out.
  List<String> projection(
    QueryScope scope,
    Map<String, Object?> args, {
    ViewDefinition? view,
    ScreenContext? screen,
  }) {
    if (args['fields'] case final List refs) {
      return _explicitFields(scope, refs);
    }
    final c = scope.collection;
    final shown = screen?.visibleFieldIds ?? const <String>[];
    final ids = shown.isNotEmpty
        ? shown
        : (view ?? c.views.firstOrNull ?? ViewDefinition.defaultFor(c.fields))
              .fieldIds;
    final title = c.fields.whereType<TextFieldDefinition>().firstOrNull;
    return [
      for (final id in ids)
        if (c.fieldById(id) case final f?
            when f != title &&
                !readsUngranted(c, f, scope.ctx.grants, cache.collections))
          id,
    ].take(kDefaultRowFields).toList();
  }

  /// Fails with `not_permitted` when reading [fieldId] would reveal data
  /// of a collection outside the caller's grants (a lookup, aggregate or
  /// formula over one).
  void checkReadable(QueryScope scope, String fieldId, {required String path}) {
    final field = scope.collection.fieldById(fieldId);
    if (field == null ||
        !readsUngranted(
          scope.collection,
          field,
          scope.ctx.grants,
          cache.collections,
        )) {
      return;
    }
    throw HarnessException.of(
      ErrorCode.notPermitted,
      '"${field.name}" reads a collection this client may not touch.',
      path: path,
    );
  }

  /// The cards [spec] matches, in its order. Derivation runs only when a
  /// filter, the sort or one of [reads] (group-by and metric field ids) is
  /// calculated. A stored filter on a field that no longer exists fails
  /// (`invalid_filter`) instead of widening the result.
  Future<QueryRun> run(
    QuerySpec spec,
    HarnessContext ctx, {
    Iterable<String> reads = const [],
  }) async {
    final derived = await cache.derive(spec.collectionId, today: ctx.today);
    final collection = derived.schema;
    final filters = [
      for (final f in spec.filters)
        (
          f,
          filterFieldOf(collection, f.fieldId) ??
              (throw HarnessException.of(
                ErrorCode.invalidFilter,
                'A filter reads a field ${collection.name} no longer has; '
                'run the query again.',
                path: 'where',
              )),
        ),
    ];
    final objects = derived.objectsFor({
      for (final f in spec.filters) f.fieldId,
      ?spec.sort?.fieldId,
      ...reads,
    });
    final kept = <MorkvaObject>[];
    for (final (i, o) in objects.indexed) {
      if (i > 0 && i % _yieldEvery == 0) await _yield();
      if (filters.every((p) => matchesFilter(p.$1, p.$2, readValue(o, p.$2)))) {
        kept.add(o);
      }
    }
    var matched = kept;
    if (spec.search case final text?) {
      final hits = {for (final h in derived.base.labels.search(text)) h.id};
      matched = [
        for (final o in kept)
          if (hits.contains(o.id)) o,
      ];
    }
    final sort = spec.sort;
    final order = ViewDefinition(
      id: '@query',
      name: '',
      sort:
          sort != null &&
              (sort.isPseudo || collection.fieldById(sort.fieldId) != null)
          ? sort
          : null,
      manualOrder:
          collection.views
              .where((v) => v.id == spec.orderViewId)
              .firstOrNull
              ?.manualOrder ??
          const [],
    );
    return QueryRun(
      spec: spec,
      derived: derived,
      objects: applyView(collection, order, matched),
      scanned: objects.length,
    );
  }

  /// [field]'s value on [object]: the card's timestamp for a
  /// [metaDateField], else the stored (or, on a derived object, computed)
  /// value.
  static FieldValue readValue(MorkvaObject object, FieldDefinition field) =>
      switch (field.id) {
        kCreatedAtRef => DateFieldValue(object.createdAt),
        kUpdatedAtRef => DateFieldValue(object.updatedAt),
        _ => object[field.id] ?? field.emptyValue(),
      };

  /// The title of card [id] of [collectionId] when the caller may see it
  /// and the cache holds it.
  String? referenceTitle(HarnessContext ctx, String collectionId, String id) {
    if (!ctx.grants.allowsCollection(collectionId)) return null;
    final target = cache.collection(collectionId);
    final object = cache.current(collectionId)?[id];
    return target == null || object == null ? null : cardTitle(target, object);
  }

  // ---------------------------------------------------------------------------

  Map<String, Object?> _rows(
    HarnessContext ctx,
    QuerySpec spec,
    DerivedSnapshot derived,
    List<String> ids, {
    required String handle,
    required int offset,
    required String summary,
    bool snapshotChanged = false,
  }) {
    final fields = _fields(derived.schema, spec.fieldIds);
    final rows = [
      for (final id in ids.skip(offset).take(spec.limit))
        if (derived.base[id] case final o?)
          _card(ctx, derived, o, fields, meta: spec.meta),
    ];
    return shaper.fit(rows.length, (k) {
      final next = offset + k;
      return {
        'handle': handle,
        'total': ids.length,
        'rows': rows.take(k).toList(),
        if (next < ids.length) 'nextCursor': _cursor(next),
        if (k < rows.length) ...{
          'truncated': true,
          'hint':
              'More rows than fit; page with nextCursor, or use '
              'cards.aggregate for totals.',
        },
        if (snapshotChanged) 'snapshotChanged': true,
        ..._units(fields),
        'summary': summary,
      };
    }, budget: shaper.rowBudget);
  }

  Map<String, Object?> _card(
    HarnessContext ctx,
    DerivedSnapshot derived,
    MorkvaObject object,
    List<FieldDefinition> fields, {
    required bool meta,
  }) => shaper.card(
    derived.schema,
    object,
    [for (final f in fields) (f, derived.value(object, f))],
    referenceTitle: (cid, id) => referenceTitle(ctx, cid, id),
    meta: meta,
  );

  Map<String, Object?> _units(List<FieldDefinition> fields) {
    final units = {
      for (final f in fields) shaper.name(f.name): ?shaper.unitOf(f),
    };
    return units.isEmpty ? const {} : {'units': units};
  }

  List<FieldDefinition> _fields(Collection c, List<String> ids) => [
    for (final id in ids) ?c.fieldById(id),
  ];

  List<String> _explicitFields(QueryScope scope, List<Object?> refs) {
    if (refs.length > kMaxRowFields) {
      throw _args('At most $kMaxRowFields fields.', 'fields');
    }
    return [
      for (final (i, ref) in refs.indexed)
        _readableField(scope, '$ref', 'fields[$i]'),
    ];
  }

  String _readableField(QueryScope scope, String ref, String path) {
    final id = scope.refs.field(scope.collection, ref, path: path).id;
    checkReadable(scope, id, path: path);
    return id;
  }

  QueryScope _scope(
    Collection collection,
    HarnessContext ctx, {
    required bool fromScreen,
  }) {
    final refs = RefResolver(CacheWorkspaceReader(cache), ctx);
    return QueryScope._(
      ctx: ctx,
      collection: collection,
      refs: refs,
      compiler: FilterCompiler(refs),
      fromScreen: fromScreen,
    );
  }

  /// The granted collection [id], for a stored spec.
  Collection _collection(String id, HarnessContext ctx, String path) {
    _checkBound();
    return RefResolver(
      CacheWorkspaceReader(cache),
      ctx,
    ).collectionById(id, path: path);
  }

  /// Runs [body] holding [collectionId] and the granted collections its
  /// (presented) reference fields point at, so card refs resolve and
  /// reference titles show.
  Future<T> _leased<T>(
    String collectionId,
    HarnessContext ctx,
    Future<T> Function() body,
  ) async {
    final collection = cache.collection(collectionId);
    final targets = <String>{
      collectionId,
      for (final f in collection?.fields ?? const <FieldDefinition>[])
        if (presentedAs(f, f.emptyValue()).$1
            case ReferenceFieldDefinition(:final targetCollectionId)
            when ctx.grants.allowsCollection(targetCollectionId) &&
                cache.collection(targetCollectionId) != null)
          targetCollectionId,
    };
    final lease = await _lease(targets);
    try {
      return await body();
    } on MissingCollectionException catch (e) {
      throw _missing(e);
    } finally {
      lease.release();
    }
  }

  Future<Lease> _lease(Iterable<String> ids) async {
    try {
      return await cache.lease(ids);
    } on MissingCollectionException catch (e) {
      throw _missing(e);
    }
  }

  void _checkBound() {
    if (cache.workspaceId == null) {
      throw StateError('WorkspaceCache is not initialized.');
    }
  }

  static HarnessException _missing(MissingCollectionException e) =>
      HarnessException.of(
        ErrorCode.unknownCollection,
        'Collection "${e.collectionId}" no longer exists.',
      );

  static String? _joinSearch(String? a, String? b) {
    final text = [a, b].nonNulls.map((s) => s.trim()).join(' ').trim();
    return text.isEmpty ? null : text;
  }

  static List<Object?>? _list(Object? value, String path) {
    if (value == null) return null;
    if (value is! List) throw _args('"$path" must be a list.', path);
    return value;
  }

  static int _limit(Object? value, int fallback, int max) => switch (value) {
    null => fallback,
    int() when value >= 1 && value <= max => value,
    _ => throw _args('"limit" is 1..$max.', 'limit'),
  };

  static String _cursor(int offset) => 'p$offset';

  static int _offset(Object? cursor) {
    final match = cursor is String ? _cursorPattern.firstMatch(cursor) : null;
    if (match == null) {
      throw _args('Pass back the nextCursor you got.', 'cursor');
    }
    return int.parse(match[1]!);
  }

  static final RegExp _cursorPattern = RegExp(r'^p(\d{1,9})$');

  static HarnessException _args(String message, String path) =>
      HarnessException.of(ErrorCode.invalidArgs, message, path: path);
}

/// Items a long loop processes between yields, so a web frame can render.
const int _yieldEvery = 2000;

Future<void> _yield() => Future<void>.value();

/// Whether showing [field] of [owner] reveals data of a collection outside
/// [grants]: a lookup or aggregate over one, or a formula reading such a
/// field. Reference fields themselves show ids only, so they never do (their
/// titles are withheld instead).
bool readsUngranted(
  Collection owner,
  FieldDefinition field,
  Grants grants,
  Iterable<Collection> collections, [
  Set<String>? seen,
]) {
  if (grants.collections == null || field is! CalculatedFieldDefinition) {
    return false;
  }
  final visited = seen ?? <String>{};
  if (!visited.add('${owner.id}/${field.id}')) return false;
  Collection? byId(String? id) =>
      collections.where((c) => c.id == id).firstOrNull;
  bool hidden(Collection? c, String? fieldId) {
    if (c == null) return false;
    if (!grants.allowsCollection(c.id)) return true;
    final f = fieldId == null ? null : c.fieldById(fieldId);
    return f != null && readsUngranted(c, f, grants, collections, visited);
  }

  String? targetOf(String refFieldId) => switch (owner.fieldById(refFieldId)) {
    ReferenceFieldDefinition(:final targetCollectionId) => targetCollectionId,
    _ => null,
  };
  if (field.lookup case final lookup?) {
    return hidden(byId(targetOf(lookup.referenceFieldId)), lookup.fieldId);
  }
  if (field.aggregate case final a?) {
    final source = a.source == AggregateSource.linked
        ? targetOf(a.referenceFieldId ?? '')
        : a.collectionId;
    return hidden(byId(source), a.fieldId);
  }
  final expression = field.expression;
  if (expression == null) return false;
  return formulaFieldIds(
    expression,
    owner.fields,
  ).any((id) => hidden(owner, id));
}
