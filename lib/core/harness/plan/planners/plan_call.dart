import '../../../domain/domain.dart';
import '../../../domain/ids.dart';
import '../../api/envelope.dart';
import '../../api/harness_context.dart';
import '../../api/operation.dart';
import '../../cache/workspace_cache.dart';
import '../../input/filter_compiler.dart';
import '../../input/ref_resolver.dart';
import '../../input/value_codec.dart';
import '../../query/cache_workspace_reader.dart';
import '../../query/query_engine.dart';
import '../../query/result_shaper.dart';
import '../../schema/json_schema.dart';
import '../plan.dart';
import '../plan_store.dart';
import '../planning_overlay.dart';

/// What the plan ops run on. The host builds one per session and passes it
/// to `registerPlanOps` and `registerViewOps`.
final class PlanServices {
  PlanServices({
    required this.cache,
    required this.queries,
    required this.store,
    required this.registry,
    IdGenerator? ids,
  }) : ids = ids ?? IdGenerator();

  final WorkspaceCache cache;

  /// Resolves `where` and `{screen: true}` targets (leases and grant checks
  /// included).
  final QueryEngine queries;
  final PlanStore store;

  /// Field types a spec may name; builds field definitions from JSON.
  final FieldTypeRegistry registry;
  final IdGenerator ids;
}

/// A plan op: validates its args against the turn's [PlanningOverlay] and
/// adds items to it, writing nothing.
///
/// The call is planned on a staged layer and merged only when the whole call
/// validated, so a failing call leaves the overlay as it was; the failure is
/// recorded so `plans.seal` returns it (and no plan).
abstract class PlanOperation extends Operation<Map<String, Object?>> {
  PlanOperation(this.services);

  final PlanServices services;

  @override
  Map<String, Object?> decode(Map<String, Object?> args, HarnessContext ctx) =>
      args;

  /// Plans [args] into [call]; throws [HarnessException] when they do not
  /// validate.
  Future<void> plan(Map<String, Object?> args, PlanCall call);

  /// Whether this op must be the only one of its plan.
  bool get standalone => false;

  @override
  Future<OpResult> run(
    Map<String, Object?> args,
    HarnessContext ctx,
    HarnessRequest request,
  ) async {
    final turnId = ctx.turnId;
    if (turnId == null) {
      throw HarnessException.of(
        ErrorCode.notPermitted,
        '${descriptor.id} plans a change and needs a turn; open one with '
        'Harness.openTurn.',
        path: 'turnId',
      );
    }
    await services.cache.ready;
    final overlay = services.store.overlay(
      ctx.actor,
      turnId,
      grants: ctx.grants,
      base: CacheWorkspaceReader(services.cache),
      now: ctx.now,
    );
    try {
      if (standalone && overlay.callIds.isNotEmpty ||
          overlay.pending.deletesCollection) {
        throw HarnessException.of(
          ErrorCode.invalidArgs,
          'Send collections.delete on its own, with no other change in the '
          'same turn.',
        );
      }
      final staged = overlay.stage();
      final call = PlanCall(
        services,
        ctx,
        request.callId,
        staged,
        firstItem: overlay.itemCount + 1,
      );
      await plan(args, call);
      if (call.changes.items.isEmpty) {
        throw HarnessException.of(
          ErrorCode.invalidArgs,
          'Nothing would change. ${call.changes.notes.take(3).join(' ')}'
              .trim(),
        );
      }
      overlay.accept(request.callId, staged);
      return OpResult({
        'status': 'planned',
        'planId': overlay.planId,
        'itemCount': call.changes.items.length,
        'summary': call.changes.titles.join(' · '),
        if (call.changes.warnings.isNotEmpty)
          'warnings': [for (final w in call.changes.warnings) w.toJson()],
        if (call.changes.notes.isNotEmpty)
          'notes': call.changes.notes.take(kCompactPlanNotes).toList(),
      });
    } on HarnessException catch (e) {
      overlay.fail(request.callId, e.error);
      rethrow;
    } catch (e) {
      overlay.fail(
        request.callId,
        HarnessError(
          code: ErrorCode.internal,
          message: 'Unexpected error in ${descriptor.id}: $e',
        ),
      );
      rethrow;
    }
  }
}

/// The result every plan op returns: the turn's plan id and what this call
/// added. The change itself is shown to the user once the turn is sealed.
Map<String, Object?> planCallResultSchema() => JsonSchema.object(
  {
    'status': JsonSchema.enumOf(const ['planned']),
    'planId': JsonSchema.string(),
    'itemCount': JsonSchema.integer(minimum: 1),
    'summary': JsonSchema.string(),
    'warnings': JsonSchema.array(
      JsonSchema.object({
        'code': JsonSchema.string(),
        'message': JsonSchema.string(),
      }),
    ),
    'notes': JsonSchema.array(JsonSchema.string()),
  },
  required: ['status', 'planId', 'itemCount', 'summary'],
);

/// One plan call's working set: the staged overlay it reads and writes, the
/// resolvers bound to it and the helpers every planner shares.
final class PlanCall {
  PlanCall(
    this.services,
    this.ctx,
    this.callId,
    this.view, {
    required int firstItem,
  }) : _nextItem = firstItem;

  final PlanServices services;
  final HarnessContext ctx;
  final String callId;

  /// The workspace with the turn's and this call's pending changes.
  final OverlayReader view;

  int _nextItem;

  /// This call's own pending changes (merged into the turn on success).
  PendingChanges get changes => view.layers.last;

  IdGenerator get ids => services.ids;

  static const ResultShaper shaper = ResultShaper();

  /// A resolver over [view] with every `@c1` card ref minted so far. Card
  /// title indexes are cached per resolver, so take a new one after adding
  /// cards.
  RefResolver resolver() =>
      RefResolver(view, ctx, cardAliases: view.cardAliases);

  /// The next plan item id (`i4`).
  String nextItemId() => 'i${_nextItem++}';

  /// The visible collection [ref] names: an id, a name, or an `@x` ref of a
  /// collection planned in this turn.
  Collection collection(String ref, {String path = 'collection'}) {
    final refs = resolver();
    final alias = view.collectionAlias(ref);
    if (alias != null) return refs.collectionById(alias, path: path);
    if (ref.trim().startsWith('@') && ref.trim() != '@screen') {
      throw HarnessException.of(
        ErrorCode.unknownCollection,
        'No collection was created as "$ref" in this turn.',
        path: path,
        hint: 'Use the ref given in collections.create, or a name.',
      );
    }
    return refs.collection(ref, path: path);
  }

  /// The current (pending) schema of [collectionId].
  Collection schemaOf(String collectionId) =>
      view.collection(collectionId) ??
      (throw HarnessException.of(
        ErrorCode.unknownCollection,
        'Collection "$collectionId" no longer exists.',
      ));

  /// Runs [body] holding a lease on [collectionIds] and the collections
  /// they read (reference targets, calculation sources), the ones the cache
  /// knows and the caller may touch. Pending new collections need none.
  Future<T> leased<T>(
    Iterable<String> collectionIds,
    Future<T> Function() body,
  ) async {
    final cache = services.cache;
    final all = view.collections;
    final ids = <String>{};
    for (final id in collectionIds) {
      ids.add(id);
      final c = all.where((c) => c.id == id).firstOrNull;
      if (c == null) continue;
      for (final f in c.fields) {
        if (presentedAs(f, f.emptyValue()).$1 case ReferenceFieldDefinition(
          :final targetCollectionId,
        )) {
          ids.add(targetCollectionId);
        }
      }
      ids.addAll(Derivation.sourcesOf(id, all));
    }
    final lease = await _lease([
      for (final id in ids)
        if (cache.collection(id) != null && ctx.grants.allowsCollection(id)) id,
    ]);
    try {
      return await body();
    } on MissingCollectionException catch (e) {
      throw _missing(e);
    } finally {
      lease.release();
    }
  }

  Future<Lease> _lease(List<String> ids) async {
    try {
      return await services.cache.lease(ids);
    } on MissingCollectionException catch (e) {
      throw _missing(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Recording

  void add(PlanItem item) => changes.items.add(item);

  void note(String text) => changes.notes.add(text);

  void warn(String code, String message) =>
      changes.warnings.add(PlanWarning(code, message));

  void title(String text) => changes.titles.add(text);

  /// The planned items a change in [collectionId] needs: the collection's
  /// create, the adds of [fieldIds], and the creates of the cards
  /// [cardIds] (`(collectionId, id)`) it links to.
  List<String> dependencies(
    String collectionId, {
    Iterable<String> fieldIds = const [],
    Iterable<(String, String)> cardIds = const [],
  }) {
    final fields = fieldIds.toSet();
    final cards = cardIds.toSet();
    return [
      for (final item in view.items)
        if (switch (item) {
          CreateCollectionItem(:final collection) =>
            collection.id == collectionId,
          AddFieldItem(:final field) =>
            item.collectionId == collectionId && fields.contains(field.id),
          CreateCardItem(:final object) => cards.contains((
            object.collectionId,
            object.id,
          )),
          _ => false,
        })
          item.itemId,
    ];
  }

  /// The planned items new or changed [field] of [owner] needs: [owner]'s
  /// create, the creates of the collections it links to or reads, and the
  /// adds of the fields its formula, lookup or aggregate reads. [reserved]
  /// holds item ids this call minted but has not added yet: a collection id
  /// → its create, a `(collectionId, fieldId)` → its add.
  List<String> fieldDependencies(
    Collection owner,
    FieldDefinition field, {
    Map<Object, String> reserved = const {},
  }) {
    final collections = {owner.id};
    final fields = <(String, String)>{};
    String? target(String? fieldId) => switch (owner.fieldById(fieldId ?? '')) {
      ReferenceFieldDefinition(:final targetCollectionId) => targetCollectionId,
      _ => null,
    };
    switch (field) {
      case ReferenceFieldDefinition(:final targetCollectionId):
        collections.add(targetCollectionId);
      case CalculatedFieldDefinition(:final expression?):
        for (final id in formulaFieldIds(expression, owner.fields)) {
          fields.add((owner.id, id));
        }
      case CalculatedFieldDefinition(:final lookup?):
        fields.add((owner.id, lookup.referenceFieldId));
        if (target(lookup.referenceFieldId) case final t?) {
          collections.add(t);
          if (lookup.fieldId case final f?) fields.add((t, f));
        }
      case CalculatedFieldDefinition(:final aggregate?):
        // The reference lives on the owner for `linked`, on the source for
        // `linkedFrom` (see Aggregation.referenceFieldId).
        final linked = aggregate.source == AggregateSource.linked;
        final source = linked
            ? target(aggregate.referenceFieldId)
            : aggregate.collectionId;
        if (aggregate.referenceFieldId case final r?) {
          fields.add((linked ? owner.id : aggregate.collectionId, r));
        }
        if (source != null) {
          collections.add(source);
          for (final id in [
            aggregate.fieldId,
            for (final f in aggregate.filters) f.fieldId,
          ]) {
            if (id != null) fields.add((source, id));
          }
        }
      default:
        break;
    }
    return {
      for (final item in view.items)
        if (switch (item) {
          CreateCollectionItem(:final collection) => collections.contains(
            collection.id,
          ),
          AddFieldItem(field: final added) => fields.contains((
            item.collectionId,
            added.id,
          )),
          _ => false,
        })
          item.itemId,
      for (final c in collections) ?reserved[c],
      for (final f in fields) ?reserved[f],
    }.toList();
  }

  /// The pending cards a [value] of [field] links to, as
  /// `(collectionId, id)`.
  Iterable<(String, String)> linkedCards(
    FieldDefinition field,
    FieldValue value,
  ) => switch ((field, value)) {
    (
      ReferenceFieldDefinition(:final targetCollectionId),
      ReferenceFieldValue(:final objectIds),
    ) =>
      [
        for (final id in objectIds)
          if (view.isCreated(targetCollectionId, id)) (targetCollectionId, id),
      ],
    _ => const [],
  };

  // ---------------------------------------------------------------------------
  // Display text (harness-written, user strings sanitized)

  /// `#1042 · Iryna Melnyk`: the first auto-number as shown (when assigned)
  /// and the title.
  String cardLabel(Collection collection, MorkvaObject object) {
    final title = cardTitle(collection, object);
    final number = collection.fields
        .whereType<AutoNumberFieldDefinition>()
        .map((f) => object[f.id])
        .where((v) => v != null && v.isNotEmpty)
        .firstOrNull;
    final numberField = collection.fields
        .whereType<AutoNumberFieldDefinition>()
        .firstOrNull;
    final head = number == null || numberField == null
        ? null
        : formatFieldValue(numberField, number);
    return shaper.label(head == null ? title : '$head · $title');
  }

  /// [value] of [field] as the app shows it, or null when empty. Reference
  /// values show their cards' titles.
  String? valueText(FieldDefinition field, FieldValue value) {
    if (value.isEmpty) return null;
    final (f, v) = presentedAs(field, value);
    var labels = const <String, String>{};
    if (f case ReferenceFieldDefinition(:final targetCollectionId)) {
      final target = view.collection(targetCollectionId);
      if (target != null && ctx.grants.allowsCollection(target.id)) {
        labels = objectLabels(target, view.objectsOf(target.id));
      }
    }
    final text = formatFieldValue(f, v, referenceLabels: labels);
    return text.isEmpty ? null : shaper.label(text);
  }

  /// [name] sanitized and cut for a title or label.
  String name(String name) => shaper.name(name);

  /// `"Orders"` as a quoted, sanitized name for titles.
  String quoted(String name) => '“${shaper.name(name)}”';

  /// `3 orders`, `1 order`: a count of [collection]'s cards for titles.
  String cards(Collection collection, int n) {
    final plural = shaper.name(collection.name).toLowerCase();
    final singular = plural.length > 1 && plural.endsWith('s')
        ? plural.substring(0, plural.length - 1)
        : plural;
    return '$n ${n == 1 ? singular : plural}';
  }

  /// A value codec over a fresh [resolver].
  ValueCodec codec() => ValueCodec(resolver());

  /// A filter compiler over a fresh [resolver].
  FilterCompiler compiler() => FilterCompiler(resolver());

  static HarnessException _missing(MissingCollectionException e) =>
      HarnessException.of(
        ErrorCode.unknownCollection,
        'Collection "${e.collectionId}" no longer exists.',
      );
}

/// `invalid_args` at [path].
HarnessException invalidArgs(String message, {String? path, String? hint}) =>
    HarnessException.of(ErrorCode.invalidArgs, message, path: path, hint: hint);

/// [value] as a list of [T]; `invalid_args` otherwise.
List<T> listArg<T>(Object? value, String path) {
  if (value == null) return const [];
  if (value is! List || value.any((e) => e is! T)) {
    throw invalidArgs('"$path" must be a list.', path: path);
  }
  return value.cast<T>();
}

/// [value] as a JSON object; `invalid_args` otherwise.
Map<String, Object?> mapArg(Object? value, String path) {
  if (value is! Map) {
    throw invalidArgs('"$path" must be an object.', path: path);
  }
  return value.cast<String, Object?>();
}
