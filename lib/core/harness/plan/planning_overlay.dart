import '../../domain/domain.dart';
import '../api/capability.dart';
import '../api/envelope.dart';
import '../input/ref_resolver.dart';
import 'plan.dart';

/// What some plan calls would change, without writing it: collection drafts
/// (new or edited schemas, as stored, lookups unresolved), created, updated
/// and deleted cards, the `@` refs minted for them, and the items, notes,
/// warnings and titles that describe it.
///
/// One instance holds a turn's merged calls; another stages one call on top
/// of it and is merged in only when the whole call validated.
final class PendingChanges {
  /// Collection id → draft schema (new or edited).
  final Map<String, Collection> drafts = {};

  /// Collections a call creates (also in [drafts]).
  final Set<String> newCollections = {};

  /// Collection id → card id → the card after its pending update.
  final Map<String, Map<String, MorkvaObject>> updated = {};

  /// Collection id → cards a call creates, in order.
  final Map<String, List<MorkvaObject>> created = {};

  /// Collection id → card ids a call deletes.
  final Map<String, Set<String>> deleted = {};

  /// `@x` → collection id, from `collections.create`.
  final Map<String, String> collectionAliases = {};

  /// `@c1` → card id, from `cards.create` / seed cards.
  final Map<String, String> cardAliases = {};

  final List<PlanItem> items = [];
  final List<PlanWarning> warnings = [];
  final List<String> notes = [];

  /// One short title per call (`Set Status to Shipped · 3 orders`).
  final List<String> titles = [];

  /// Whether a call plans `collections.delete` (always its own plan).
  bool deletesCollection = false;

  int _version = 0;

  /// Bumped by every mutation through this class's methods; readers memoize
  /// on it.
  int get version => _version;

  void putDraft(Collection draft, {bool isNew = false}) {
    drafts[draft.id] = draft;
    if (isNew) newCollections.add(draft.id);
    _version++;
  }

  void putCreated(MorkvaObject object) {
    (created[object.collectionId] ??= []).add(object);
    _version++;
  }

  /// Replaces a created card (seed cards get their values after every
  /// card's id is known).
  void replaceCreated(MorkvaObject object) {
    final list = created[object.collectionId]!;
    list[list.indexWhere((o) => o.id == object.id)] = object;
    _version++;
  }

  void putUpdated(MorkvaObject object) {
    (updated[object.collectionId] ??= {})[object.id] = object;
    _version++;
  }

  void putDeleted(String collectionId, String id) {
    (deleted[collectionId] ??= {}).add(id);
    _version++;
  }

  /// Appends everything [other] holds (a staged call that validated).
  void merge(PendingChanges other) {
    drafts.addAll(other.drafts);
    newCollections.addAll(other.newCollections);
    for (final e in other.updated.entries) {
      (updated[e.key] ??= {}).addAll(e.value);
    }
    for (final e in other.created.entries) {
      final mine = created[e.key] ??= [];
      for (final o in e.value) {
        final at = mine.indexWhere((m) => m.id == o.id);
        if (at < 0) {
          mine.add(o);
        } else {
          mine[at] = o;
        }
      }
    }
    for (final e in other.deleted.entries) {
      (deleted[e.key] ??= {}).addAll(e.value);
    }
    collectionAliases.addAll(other.collectionAliases);
    cardAliases.addAll(other.cardAliases);
    items.addAll(other.items);
    warnings.addAll(other.warnings);
    notes.addAll(other.notes);
    titles.addAll(other.titles);
    deletesCollection = deletesCollection || other.deletesCollection;
    _version++;
  }
}

/// The workspace as plan calls see it: [base] (the cache) with [layers] of
/// pending changes on top, later layers winning. Refs, values and filters
/// resolve against it, so a call sees the schema, cards and `@` refs an
/// earlier call of the same turn planned.
final class OverlayReader implements WorkspaceReader {
  OverlayReader(this.base, this.layers);

  final WorkspaceReader base;
  final List<PendingChanges> layers;

  List<Collection>? _collections;
  (Object, String)? _collectionsKey;
  final Map<String, ((Object, String), List<MorkvaObject>)> _objects = {};

  /// Every collection with the pending drafts in place (new ones appended),
  /// lookups resolved.
  @override
  List<Collection> get collections {
    final key = _key(base.collections);
    if (_collections != null && _same(_collectionsKey, key)) {
      return _collections!;
    }
    final byId = <String, Collection>{
      for (final c in base.collections) c.id: c,
    };
    for (final layer in layers) {
      byId.addAll(layer.drafts);
    }
    _collectionsKey = key;
    return _collections = List.unmodifiable(
      resolveLookups(byId.values.toList()),
    );
  }

  /// The cards of [collectionId] with pending updates, creates and deletes
  /// applied. The base reads only collections the cache holds, so lease
  /// first.
  @override
  List<MorkvaObject> objectsOf(String collectionId) {
    final raw = base.objectsOf(collectionId);
    final key = _key(raw);
    final memo = _objects[collectionId];
    if (memo != null && _same(memo.$1, key)) return memo.$2;
    var out = raw;
    for (final layer in layers) {
      final deleted = layer.deleted[collectionId] ?? const {};
      final updated = layer.updated[collectionId] ?? const {};
      final created = layer.created[collectionId] ?? const [];
      if (deleted.isEmpty && updated.isEmpty && created.isEmpty) continue;
      out = [
        for (final o in out)
          if (!deleted.contains(o.id)) updated[o.id] ?? o,
        for (final o in created)
          if (!deleted.contains(o.id)) updated[o.id] ?? o,
      ];
    }
    final list = List<MorkvaObject>.unmodifiable(out);
    _objects[collectionId] = (key, list);
    return list;
  }

  /// The collection [id] with lookups resolved, or null.
  Collection? collection(String id) =>
      collections.where((c) => c.id == id).firstOrNull;

  /// The card [id] of [collectionId] as pending changes leave it, or null.
  MorkvaObject? object(String collectionId, String id) =>
      objectsOf(collectionId).where((o) => o.id == id).firstOrNull;

  /// Every `@c1` card ref minted so far.
  Map<String, String> get cardAliases => {
    for (final l in layers) ...l.cardAliases,
  };

  /// The collection id `@x` names, or null.
  String? collectionAlias(String ref) {
    for (final l in layers.reversed) {
      if (l.collectionAliases[ref.trim()] case final id?) return id;
    }
    return null;
  }

  /// Whether [collectionId] is created by a pending call.
  bool isNew(String collectionId) =>
      layers.any((l) => l.newCollections.contains(collectionId));

  /// Whether a pending call created card [id].
  bool isCreated(String collectionId, String id) => layers.any(
    (l) => l.created[collectionId]?.any((o) => o.id == id) ?? false,
  );

  /// Whether a pending call deletes card [id].
  bool isDeleted(String collectionId, String id) =>
      layers.any((l) => l.deleted[collectionId]?.contains(id) ?? false);

  /// The items planned so far, in order.
  Iterable<PlanItem> get items => layers.expand((l) => l.items);

  /// The base list (compared by identity) and every layer's version.
  (Object, String) _key(Object list) =>
      (list, [for (final l in layers) l.version].join(','));

  static bool _same((Object, String)? a, (Object, String) b) =>
      a != null && identical(a.$1, b.$1) && a.$2 == b.$2;
}

/// One turn's planning state for one actor: every validated call's pending
/// changes and items, merged, plus the calls that failed. `plans.seal`
/// turns it into one [Plan].
///
/// It is itself a [WorkspaceReader] over the cache with the turn's pending
/// changes applied; [stage] layers one more call on top.
final class PlanningOverlay implements WorkspaceReader {
  PlanningOverlay({
    required this.actor,
    required this.turnId,
    required this.planId,
    required this.createdBy,
    required WorkspaceReader base,
    required this.startedAt,
  }) : _base = base;

  final Actor actor;
  final String turnId;

  /// Minted when the turn's first plan call arrives; every call's response
  /// and the sealed plan carry it.
  final String planId;

  /// The actor and grants of the turn's first plan call.
  final PlanCreator createdBy;
  final DateTime startedAt;

  final WorkspaceReader _base;
  final PendingChanges pending = PendingChanges();

  /// callId → why the call failed, in call order.
  final Map<String, HarnessError> failures = {};

  /// Every call that reached a plan op, in order.
  final List<String> callIds = [];

  late final OverlayReader _reader = OverlayReader(_base, [pending]);

  @override
  List<Collection> get collections => _reader.collections;

  @override
  List<MorkvaObject> objectsOf(String collectionId) =>
      _reader.objectsOf(collectionId);

  /// A reader over this turn with a fresh layer for one call.
  OverlayReader stage() => OverlayReader(_base, [pending, PendingChanges()]);

  /// Merges a staged call (from [stage]) that validated.
  void accept(String callId, OverlayReader staged) {
    callIds.add(callId);
    pending.merge(staged.layers.last);
  }

  /// Records that call [callId] failed; `plans.seal` then returns every
  /// failure and no plan.
  void fail(String callId, HarnessError error) {
    callIds.add(callId);
    failures[callId] = error;
  }

  bool get isEmpty => pending.items.isEmpty && failures.isEmpty;

  int get itemCount => pending.items.length;
}
