import 'dart:async';
import 'dart:math' show min;

import '../../../api/data/data_repository.dart';
import '../../domain/domain.dart';
import 'collection_snapshot.dart';
import 'derived_snapshot.dart';

/// A lease or read named a collection the workspace does not have (or no
/// longer has).
final class MissingCollectionException implements Exception {
  const MissingCollectionException(this.collectionId);

  final String collectionId;

  @override
  String toString() =>
      'MissingCollectionException: no collection $collectionId';
}

/// The assistant's session-scoped read model of one workspace: the schema,
/// always watched, and the objects of the collections someone leased.
///
/// - **Schema.** One `watchCollections` subscription from [initialize] to
///   [reset]. Each emission runs `resolveLookups` once and bumps
///   [schemaGeneration]. A leased collection whose decoded fields changed
///   (the repository decodes only the schema it was given) is resubscribed
///   with the new schema, so a field added mid-session is read, not blank.
/// - **Objects.** One `watchObjects` subscription per collection however many
///   leases share it, refcounted. While [panelOpen] every collection leased
///   in the session stays alive; otherwise the last release starts an idle
///   timer of [leaseTtl] that cancels the subscription.
/// - **Generations.** Every emission gets a number unique across the cache
///   (an evicted and re-leased collection never reuses one), so results keyed
///   by generations are valid exactly while the data is unchanged.
///
/// Created once and never disposed with the session: sign-out is [reset],
/// sign-in [initialize] again.
final class WorkspaceCache {
  WorkspaceCache(
    this._repository, {
    this.leaseTtl = const Duration(minutes: 5),
  });

  final DataRepository _repository;

  String? _workspaceId;
  StreamSubscription<List<Collection>>? _schemaSub;
  Timer? _schemaRetry;
  int _schemaRetries = 0;
  Completer<void> _schemaReady = Completer();
  List<Collection> _collections = const [];
  Map<String, Collection> _byId = const {};
  int _schemaGeneration = 0;

  /// The last generation handed out.
  int _clock = 0;

  /// Bumped by [reset], so leases from before it release nothing.
  int _session = 0;

  bool _panelOpen = false;
  final Map<String, _Entry> _entries = {};
  final Map<String, DerivedSnapshot> _derived = {};
  final Map<String, String> _derivedKeys = {};

  /// How long an unleased collection stays subscribed once the panel is
  /// closed (`leaseTtlMinutes` of the assistant config). A change applies to
  /// idle timers started afterwards.
  Duration leaseTtl;

  /// The workspace [initialize] bound, or null when reset.
  String? get workspaceId => _workspaceId;

  /// Every collection (lookups resolved), as of the last schema emission.
  List<Collection> get collections => _collections;

  /// Bumped by every schema emission.
  int get schemaGeneration => _schemaGeneration;

  /// Completes on the first schema emission after [initialize].
  Future<void> get ready => _schemaReady.future;

  /// The collection [id], or null when the workspace has none.
  Collection? collection(String id) => _byId[id];

  /// Ids of the collections whose objects are held right now (leased, kept
  /// alive by the panel, or idling until their timer fires).
  Iterable<String> get liveCollectionIds => [
    for (final e in _entries.values)
      if (e.snapshot != null) e.id,
  ];

  /// The latest snapshot of [collectionId], or null when it is not held.
  /// Reading it takes no lease.
  CollectionSnapshot? current(String collectionId) =>
      _entries[collectionId]?.snapshot;

  /// The generations of the held [collectionIds] (absent ones omitted).
  Map<String, int> generationsOf(Iterable<String> collectionIds) => {
    for (final id in collectionIds)
      if (current(id) case final s?) id: s.generation,
  };

  /// Whether the assistant panel is open. Opening it keeps every held
  /// collection alive; closing it starts the idle timer of each one no lease
  /// holds.
  bool get panelOpen => _panelOpen;
  set panelOpen(bool open) {
    if (open == _panelOpen) return;
    _panelOpen = open;
    for (final e in _entries.values) {
      if (open) {
        e.cancelIdle();
      } else if (e.refs == 0) {
        _startIdle(e);
      }
    }
  }

  /// Starts watching [workspaceId]'s schema. The repository must already be
  /// initialized for it. A workspace switch is [reset] then [initialize].
  void initialize(String workspaceId) {
    if (_schemaSub != null) {
      throw StateError('WorkspaceCache is already bound to $_workspaceId.');
    }
    _workspaceId = workspaceId;
    _listenSchema();
  }

  void _listenSchema() {
    _schemaSub = _repository.watchCollections().listen(
      _onSchema,
      onError: _onSchemaError,
    );
  }

  /// Cancels every subscription and timer and forgets all data; pending
  /// leases fail and older leases release nothing. [initialize] may follow.
  Future<void> reset() async {
    _session++;
    final cancels = <Future<void>>[?_schemaSub?.cancel()];
    _schemaSub = null;
    _schemaRetry?.cancel();
    _schemaRetry = null;
    _schemaRetries = 0;
    _workspaceId = null;
    final reset = StateError('WorkspaceCache was reset.');
    _failPending(_schemaReady, reset);
    _schemaReady = Completer();
    for (final e in _entries.values) {
      e.cancelIdle();
      cancels.add(e.cancel());
      _failPending(e.ready, reset);
    }
    _entries.clear();
    _derived.clear();
    _derivedKeys.clear();
    _collections = const [];
    _byId = const {};
    await Future.wait(cancels);
  }

  /// Takes a lease on [collectionIds], completing once each has emitted at
  /// least once (from the local cache when the backend has one). Hold it
  /// while reading and [Lease.release] it after; the panel or the idle timer
  /// keeps the data warm for the next call.
  ///
  /// Throws [MissingCollectionException] for an unknown collection, and the
  /// stream's error when a collection cannot be read.
  Future<Lease> lease(Iterable<String> collectionIds) async {
    if (_schemaSub == null) {
      throw StateError('WorkspaceCache is not initialized.');
    }
    final ids = collectionIds.toSet();
    final session = _session;
    await _schemaReady.future;
    _checkSession(session);
    for (final id in ids) {
      if (!_byId.containsKey(id)) throw MissingCollectionException(id);
    }
    final entries = [
      for (final id in ids) _entries.putIfAbsent(id, () => _Entry(id)),
    ];
    final lease = Lease._(this, session, ids);
    final pending = <Future<void>>[];
    for (final e in entries) {
      e.refs++;
      e.cancelIdle();
      if (e.sub == null) _subscribe(e, _byId[e.id]!);
      pending.add(e.ready.future);
    }
    try {
      await Future.wait(pending);
      _checkSession(session);
    } catch (_) {
      lease.release();
      rethrow;
    }
    return lease;
  }

  /// The current snapshot of [collectionId], leasing it just for the read.
  Future<CollectionSnapshot> read(String collectionId) async {
    final lease = await this.lease([collectionId]);
    try {
      return lease.snapshot(collectionId);
    } finally {
      lease.release();
    }
  }

  /// [collectionId] with calculated values, derived against [today] over
  /// fresh snapshots of it and of every `Derivation.sourcesOf` it (leased
  /// and awaited first, so no source reads as loading). One instance is
  /// shared until the schema, any of those generations or [today] changes.
  Future<DerivedSnapshot> derive(
    String collectionId, {
    required DateTime today,
  }) async {
    final own = await lease([collectionId]);
    Lease? sources;
    try {
      final sourceIds = Derivation.sourcesOf(
        collectionId,
        _collections,
      ).where(_byId.containsKey);
      if (sourceIds.isNotEmpty) sources = await lease(sourceIds);
      final base = own.snapshot(collectionId);
      final snapshots = {
        for (final id in sources?.collectionIds ?? const <String>{})
          id: sources!.snapshot(id),
      };
      final gens = [
        for (final s in snapshots.values) '${s.collectionId}=${s.generation}',
      ]..sort();
      final key = [
        _schemaGeneration,
        base.generation,
        ...gens,
        today.toIso8601String(),
      ].join('|');
      if (_derivedKeys[collectionId] == key) return _derived[collectionId]!;
      _derivedKeys[collectionId] = key;
      return _derived[collectionId] = DerivedSnapshot(
        base: base,
        sources: snapshots,
        collections: _collections,
        today: today,
      );
    } finally {
      own.release();
      sources?.release();
    }
  }

  // ---------------------------------------------------------------------------

  void _onSchema(List<Collection> stored) {
    final resolved = List<Collection>.unmodifiable(resolveLookups(stored));
    _collections = resolved;
    _byId = {for (final c in resolved) c.id: c};
    _schemaGeneration++;
    _schemaRetries = 0;
    if (!_schemaReady.isCompleted) _schemaReady.complete();
    for (final e in [..._entries.values]) {
      final schema = _byId[e.id];
      if (schema == null) {
        _drop(e);
      } else if (e.sub != null && !_sameFields(e.decodedWith, schema.fields)) {
        _subscribe(e, schema);
      } else if (e.snapshot case final s? when s.schema != schema) {
        e.snapshot = s.withSchema(schema, ++_clock);
      }
    }
  }

  /// The backend closes a listener after an error, so listen again, backing
  /// off from 1 s to [_maxSchemaRetry]; the last schema stays readable.
  void _onSchemaError(Object error, StackTrace stack) {
    unawaited(_schemaSub?.cancel());
    _schemaRetry?.cancel();
    final session = _session;
    final seconds = min(1 << _schemaRetries, _maxSchemaRetry.inSeconds);
    _schemaRetries = min(_schemaRetries + 1, 6);
    _schemaRetry = Timer(Duration(seconds: seconds), () {
      _schemaRetry = null;
      if (session == _session) _listenSchema();
    });
    // The re-listen still recovers: only waiters until now see it.
    if (_schemaReady.isCompleted) return;
    _failPending(_schemaReady, error, stack);
    _schemaReady = Completer();
  }

  /// (Re)opens [e]'s objects stream decoded against [schema]. The last
  /// snapshot stays readable until the new stream's first emission, which
  /// new leases wait for.
  void _subscribe(_Entry e, Collection schema) {
    unawaited(e.cancel());
    e.decodedWith = schema.fields;
    if (e.ready.isCompleted) e.ready = Completer();
    e.sub = _repository
        .watchObjects(e.id, schema: schema)
        .listen(
          (objects) => _onObjects(e, objects),
          onError: (Object error, StackTrace stack) =>
              _onObjectsError(e, error, stack),
        );
  }

  void _onObjects(_Entry e, List<MorkvaObject> objects) {
    final schema = _byId[e.id];
    if (schema == null) return;
    e.snapshot = CollectionSnapshot(
      schema: schema,
      generation: ++_clock,
      raw: objects,
    );
    if (!e.ready.isCompleted) e.ready.complete();
  }

  /// A failed stream is closed; the last snapshot stays readable and the
  /// next lease subscribes again.
  void _onObjectsError(_Entry e, Object error, StackTrace stack) {
    unawaited(e.cancel());
    if (!e.ready.isCompleted) {
      _failPending(e.ready, error, stack);
      e.ready = Completer();
    }
  }

  /// Forgets [e] (its collection is gone); waiting leases fail.
  void _drop(_Entry e) {
    e.cancelIdle();
    unawaited(e.cancel());
    _failPending(e.ready, MissingCollectionException(e.id));
    _entries.remove(e.id);
    _derived.remove(e.id);
    _derivedKeys.remove(e.id);
  }

  void _release(Lease lease) {
    if (lease._session != _session) return;
    for (final id in lease.collectionIds) {
      final e = _entries[id];
      if (e == null) continue;
      e.refs--;
      if (e.refs == 0 && !_panelOpen) _startIdle(e);
    }
  }

  void _startIdle(_Entry e) {
    e.cancelIdle();
    e.idle = Timer(leaseTtl, () {
      e.idle = null;
      if (e.refs > 0 || _panelOpen) return;
      unawaited(e.cancel());
      _entries.remove(e.id);
      _derived.remove(e.id);
      _derivedKeys.remove(e.id);
    });
  }

  static const Duration _maxSchemaRetry = Duration(seconds: 60);

  void _checkSession(int session) {
    if (session != _session) throw StateError('WorkspaceCache was reset.');
  }

  static void _failPending(
    Completer<void> completer,
    Object error, [
    StackTrace? stack,
  ]) {
    if (completer.isCompleted) return;
    completer.future.ignore(); // nobody may be waiting
    completer.completeError(error, stack);
  }

  /// What decoding a stored value depends on: renames and option edits
  /// don't, so they don't re-open a stream (as `CollectionViewsCubit`).
  static Object _decodeKey(FieldDefinition f) =>
      (f.id, f.type, f is DateFieldDefinition ? f.includeTime : null);

  static bool _sameFields(List<FieldDefinition>? a, List<FieldDefinition> b) {
    if (a == null || a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (_decodeKey(a[i]) != _decodeKey(b[i])) return false;
    }
    return true;
  }
}

/// A hold on some collections' objects, from [WorkspaceCache.lease]. While
/// any lease holds a collection, its subscription stays open.
final class Lease {
  Lease._(this._cache, this._session, Set<String> collectionIds)
    : collectionIds = Set.unmodifiable(collectionIds);

  final WorkspaceCache _cache;
  final int _session;

  /// The leased collections.
  final Set<String> collectionIds;

  bool _released = false;

  bool get isReleased => _released;

  /// The latest snapshot of leased [collectionId] (it moves on as the data
  /// changes). Throws [MissingCollectionException] once the collection is
  /// deleted or the cache was reset.
  CollectionSnapshot snapshot(String collectionId) {
    if (!collectionIds.contains(collectionId)) {
      throw ArgumentError.value(collectionId, 'collectionId', 'not leased');
    }
    return _cache.current(collectionId) ??
        (throw MissingCollectionException(collectionId));
  }

  /// Gives the collections back; idempotent.
  void release() {
    if (_released) return;
    _released = true;
    _cache._release(this);
  }
}

final class _Entry {
  _Entry(this.id);

  final String id;
  int refs = 0;
  StreamSubscription<List<MorkvaObject>>? sub;

  /// The fields [sub] decodes with.
  List<FieldDefinition>? decodedWith;

  /// Completes on [sub]'s first emission.
  Completer<void> ready = Completer();
  CollectionSnapshot? snapshot;
  Timer? idle;

  void cancelIdle() {
    idle?.cancel();
    idle = null;
  }

  Future<void> cancel() {
    final s = sub;
    sub = null;
    return s?.cancel() ?? Future.value();
  }
}
