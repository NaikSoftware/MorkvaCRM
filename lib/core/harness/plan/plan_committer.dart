import 'dart:async';
import 'dart:math' show min;

import '../../../api/data/data_repository.dart';
import '../../domain/domain.dart';
import '../api/envelope.dart';
import '../api/harness_context.dart';
import '../cache/collection_snapshot.dart';
import '../cache/workspace_cache.dart';
import '../query/result_shaper.dart';
import 'journal_entry.dart';
import 'plan.dart';
import 'plan_store.dart' show kMaxUndoableCards;

/// Whether the workspace has a connection right now (the host maps its
/// `SyncStatus` to it). Every commit and undo needs one: a write batch
/// resolves only on the server's ack.
typedef OnlineCheck = bool Function();

/// How long one batch or transaction may wait for the server's ack.
const Duration kCommitAckTimeout = Duration(seconds: 30);

/// Above this many items a commit reports `progress` events.
const int kProgressThreshold = 20;

/// The stale reasons a receipt names.
const String kChangedElsewhere = 'changed_elsewhere';
const String kMissing = 'missing';

enum ItemStatus { applied, queued, declined, stale, failed }

/// What happened to one plan item at commit.
final class ItemOutcome {
  const ItemOutcome._(this.status, {this.reason, this.code, this.message});

  const ItemOutcome.stale(String reason)
    : this._(ItemStatus.stale, reason: reason);

  const ItemOutcome.failed(String code, String message)
    : this._(ItemStatus.failed, code: code, message: message);

  static const ItemOutcome applied = ItemOutcome._(ItemStatus.applied);

  /// Written locally; the server's ack did not arrive in time.
  static const ItemOutcome queued = ItemOutcome._(ItemStatus.queued);
  static const ItemOutcome declined = ItemOutcome._(ItemStatus.declined);
  static const ItemOutcome changedElsewhere = ItemOutcome.stale(
    kChangedElsewhere,
  );
  static const ItemOutcome missing = ItemOutcome.stale(kMissing);
  static final ItemOutcome offline = ItemOutcome.failed(
    ErrorCode.offline.wire,
    'The connection dropped before this change was sent.',
  );

  final ItemStatus status;

  /// [kChangedElsewhere] or [kMissing], when stale.
  final String? reason;

  /// A harness error code (wire form) and message, when failed.
  final String? code;
  final String? message;

  bool get written =>
      status == ItemStatus.applied || status == ItemStatus.queued;

  @override
  String toString() => 'ItemOutcome(${status.name}${reason ?? code ?? ''})';
}

/// What one commit did: an outcome per plan item and the inverse items of
/// what it wrote (applied and queued alike).
final class CommitResult {
  const CommitResult(this.outcomes, this.journal);

  /// By item id, every item of the plan.
  final Map<String, ItemOutcome> outcomes;
  final List<JournalItem> journal;
}

/// What `journal.undo` did, per journal item.
final class UndoResult {
  UndoResult();

  int reverted = 0;
  final List<({String id, String reason})> skipped = [];
  final List<({String id, String code, String message})> failed = [];

  /// The items that failed to write (kept in the journal for another try).
  final List<JournalItem> failedItems = [];

  /// Reverted card items by collection, for the summary.
  final Map<String, int> _cards = {};
  int _schema = 0;

  Map<String, Object?> toJson({required String summary}) => {
    'reverted': reverted,
    'skipped': [
      for (final s in skipped) {'id': s.id, 'reason': s.reason},
    ],
    'failed': [
      for (final f in failed)
        {'id': f.id, 'code': f.code, 'message': f.message},
    ],
    'summary': summary,
  };
}

/// Writes an approved plan and reverts a journal entry (D6, D7).
///
/// A commit runs, in this order, writing nothing before the first step that
/// writes:
/// 1. the online gate (`offline` before anything is written);
/// 2. selection: unticked items, and items that need one, are
///    `declinedByUser`; an item outside the creator's grants fails
///    `not_permitted`;
/// 3. new collections (`saveCollection`, unticked new fields left out);
/// 4. schema and view edits, one transaction per collection on the
///    **server** copy (`updateCollection`, or `updateViews` when only views
///    change), each item stale-checked on its touched keys inside it;
/// 5. card creates, then card updates and deletes (an update may link a
///    created card and depends on its create), through `saveObjectsBatch`
///    in chunks, stale-checked against the live cache;
/// 6. a collection delete: its cards in chunks, the schema doc last, so a
///    failure midway can be retried.
///
/// Every batch or transaction waits at most [ackTimeout] for the server.
/// When one does not answer, its items are `queued` (written locally,
/// journaled from their after-values) and nothing more is started: the
/// rest fail `offline`, for `plans.retryFailed`.
///
/// Undo is the same machinery fed with the inverse items, stale-checked
/// against the after-values: anything edited since is left as it is.
final class PlanCommitter {
  PlanCommitter({
    required DataRepository repository,
    required this.cache,
    required this.registry,
    required OnlineCheck isOnline,
    this.ackTimeout = kCommitAckTimeout,
    this.batchSize = maxBatchWrites,
  }) : _repository = repository,
       _isOnline = isOnline;

  final DataRepository _repository;
  final OnlineCheck _isOnline;

  /// The live read model the stale checks compare against.
  final WorkspaceCache cache;

  /// Builds field definitions from their JSON images.
  final FieldTypeRegistry registry;
  final Duration ackTimeout;

  /// Writes per `saveObjectsBatch` call (one ack each).
  final int batchSize;

  static const ResultShaper _shaper = ResultShaper();

  /// Throws `offline` unless the workspace has a connection.
  void requireOnline() {
    if (_isOnline()) return;
    throw HarnessException(
      HarnessError(
        code: ErrorCode.offline,
        message: 'You are offline. Nothing was changed.',
        hint: 'Needs a connection; try again once online.',
      ),
    );
  }

  // ---------------------------------------------------------------- commit

  /// Commits [plan]'s [selected] items (null: all of them). [prior] holds
  /// the outcomes of an earlier commit of the same plan (`retryFailed`):
  /// those items are not touched again and count as done for their
  /// dependents. [callId] tags the progress events.
  Future<CommitResult> commit(
    Plan plan,
    HarnessContext ctx, {
    required String callId,
    Set<String>? selected,
    Map<String, ItemOutcome> prior = const {},
  }) async {
    requireOnline();
    final outcomes = <String, ItemOutcome>{...prior};
    final todo = [
      for (final i in plan.items)
        if (!prior.containsKey(i.itemId)) i,
    ];
    for (final i in todo) {
      if (selected != null && !selected.contains(i.itemId)) {
        outcomes[i.itemId] = ItemOutcome.declined;
      }
    }
    // Ids are minted up front, so a dependency may come later in the plan.
    for (var changed = true; changed;) {
      changed = false;
      for (final i in todo) {
        if (outcomes[i.itemId] == null &&
            i.dependsOn.any((d) => outcomes[d] == ItemOutcome.declined)) {
          outcomes[i.itemId] = ItemOutcome.declined;
          changed = true;
        }
      }
    }
    final grants = plan.createdBy.grants;
    for (final i in todo) {
      if (outcomes[i.itemId] != null) continue;
      if (!grants.allows(i.capability) ||
          !grants.allowsCollection(i.collectionId)) {
        outcomes[i.itemId] = ItemOutcome.failed(
          ErrorCode.notPermitted.wire,
          '${plan.createdBy.actor} may not ${i.capability.wire} here.',
        );
      }
    }
    final attempt = [
      for (final i in todo)
        if (outcomes[i.itemId] == null) i,
    ];
    final run = _Run(ctx, callId, attempt.length);
    final c = _Commit(this, plan, outcomes, run);
    await cache.ready;
    await c.createCollections(attempt.whereType<CreateCollectionItem>());
    await c.editSchemas(attempt.where(_isSchemaEdit));
    // Creates first: an update may link a card created here and depends on
    // its create, so it must see that create's outcome.
    await c.createCards(attempt.whereType<CreateCardItem>());
    await c.editCards([
      for (final i in attempt)
        if (i is UpdateCardItem || i is DeleteCardItem) i,
    ]);
    await c.deleteCollections(attempt.whereType<DeleteCollectionItem>());
    for (final i in attempt) {
      outcomes.putIfAbsent(
        i.itemId,
        () => ItemOutcome.failed(
          ErrorCode.internal.wire,
          'The ${i.kind.name} item was not handled.',
        ),
      );
    }
    run.report();
    return CommitResult(outcomes, c.journal());
  }

  /// The receipt JSON (`Receipt.fromJson` reads it) of [outcomes].
  Map<String, Object?> receipt(
    Plan plan,
    Map<String, ItemOutcome> outcomes, {
    String? journalId,
    DateTime? undoUntil,
  }) {
    List<PlanItem> by(ItemStatus s) => [
      for (final i in plan.items)
        if (outcomes[i.itemId]?.status == s) i,
    ];
    final applied = by(ItemStatus.applied);
    final queued = by(ItemStatus.queued);
    final declined = by(ItemStatus.declined);
    final stale = by(ItemStatus.stale);
    final failed = by(ItemStatus.failed);
    final written = applied.length + queued.length;

    final String head;
    if (written == 0) {
      head = 'Nothing was changed';
    } else if (written == plan.itemCount) {
      head = plan.title;
    } else {
      head = 'Applied $written of ${plan.itemCount}';
    }
    final parts = [
      head,
      if (queued.isNotEmpty)
        '${queued.length} ${queued.length == 1 ? 'change' : 'changes'} '
            'waiting for a connection',
      if (stale.isNotEmpty) '${stale.length} changed elsewhere',
      for (final f in failed)
        if (f is DeleteCollectionItem) outcomes[f.itemId]!.message!,
      if (failed.whereType<DeleteCollectionItem>().length < failed.length)
        '${failed.length - failed.whereType<DeleteCollectionItem>().length} '
            'failed',
    ];
    return {
      'planId': plan.planId,
      'applied': [for (final i in applied) i.itemId],
      'queued': [for (final i in queued) i.itemId],
      'declinedByUser': [for (final i in declined) i.itemId],
      'stale': [
        for (final i in stale)
          {'itemId': i.itemId, 'reason': outcomes[i.itemId]!.reason},
      ],
      'failed': [
        for (final i in failed)
          {
            'itemId': i.itemId,
            'code': outcomes[i.itemId]!.code,
            'message': outcomes[i.itemId]!.message,
          },
      ],
      'journalId': ?journalId,
      if (undoUntil != null) 'undoUntil': undoUntil.toUtc().toIso8601String(),
      'summary': parts.join(' · '),
    };
  }

  /// The outcomes a stored [receipt] records, without its failed items
  /// (what `retryFailed` passes as `prior`).
  static Map<String, ItemOutcome> settledIn(Map<String, Object?> receipt) => {
    for (final id in receipt['applied']! as List)
      id as String: ItemOutcome.applied,
    for (final id in receipt['queued']! as List)
      id as String: ItemOutcome.queued,
    for (final id in receipt['declinedByUser']! as List)
      id as String: ItemOutcome.declined,
    for (final s in receipt['stale']! as List)
      (s as Map)['itemId'] as String: ItemOutcome.stale(s['reason'] as String),
  };

  /// The failed item ids of a stored [receipt].
  static Set<String> failedIn(Map<String, Object?> receipt) => {
    for (final f in receipt['failed']! as List) (f as Map)['itemId'] as String,
  };

  static bool _isSchemaEdit(PlanItem i) =>
      i is UpdateCollectionItem ||
      (i is AddFieldItem && !i.newCollection) ||
      i is UpdateFieldItem ||
      i is DeleteFieldItem ||
      _isViewItem(i);

  static bool _isViewItem(PlanItem i) =>
      i is CreateViewItem || i is UpdateViewItem || i is DeleteViewItem;

  // ------------------------------------------------------------------ undo

  /// Reverts [entry]: deleted collections first, then schema entries (one
  /// transaction per collection), then cards, then created collections
  /// (kept when someone added cards to them since). Each item is skipped
  /// when what it wrote changed since.
  Future<({UndoResult result, String summary})> undo(
    JournalEntry entry,
    HarnessContext ctx, {
    required String callId,
  }) async {
    requireOnline();
    await cache.ready;
    final u = _Undo(this, _Run(ctx, callId, entry.items.length));
    await u.recreateCollections(
      entry.items.whereType<JournalCollectionDelete>(),
    );
    await u.revertSchemas([
      for (final i in entry.items)
        if (i is JournalFieldEntry ||
            i is JournalViewEntry ||
            i is JournalLayoutEntry ||
            i is JournalCollectionMeta)
          i,
    ]);
    await u.revertCards([
      for (final i in entry.items)
        if (i is JournalCardUpdate ||
            i is JournalCardCreate ||
            i is JournalCardDelete)
          i,
    ]);
    await u.deleteCreated(entry.items.whereType<JournalCollectionCreate>());
    u.run.report();
    return (result: u.result, summary: u.summary());
  }

  // ----------------------------------------------------------- shared I/O

  /// Awaits [write] under the watchdog: false when the ack did not arrive.
  Future<bool> _acked(Future<void> write) async {
    try {
      await write.timeout(ackTimeout);
      return true;
    } on TimeoutException {
      return false;
    }
  }

  /// Runs [apply] on the server copy of [collectionId] in a transaction:
  /// `updateViews` when [viewsOf] is given (only views change; [viewsOf]
  /// supplies the rest of the collection), else `updateCollection`.
  Future<_TxnResult> _transact(
    String collectionId,
    Collection Function(Collection server) apply, {
    Collection? viewsOf,
  }) async {
    try {
      final write = viewsOf == null
          ? _repository.updateCollection(collectionId, apply)
          : _repository.updateViews(
              collectionId,
              (views) => apply(viewsOf.copyWith(views: views)).views,
            );
      return await _acked(write) ? _TxnResult.acked : _TxnResult.timedOut;
    } on StateError {
      return _TxnResult.missing;
    } on Object catch (e) {
      return _TxnResult.error(e);
    }
  }

  /// Writes [writes] in chunks of [batchSize], settling each one. Before a
  /// chunk, writes to cards the live cache no longer has are settled
  /// [ItemOutcome.missing]; a chunk refused `not-found` is re-verified
  /// (cache, then the repository), the missing ids dropped and the rest
  /// retried, until nothing more can be dropped. [counts] says whether
  /// each write is one progress step.
  Future<void> _writeCards(
    List<_CardWrite> writes,
    Map<String, Collection> schemas,
    _Run run, {
    bool counts = true,
  }) async {
    void settle(_CardWrite w, ItemOutcome o) {
      w.settle(o);
      if (counts) run.done++;
    }

    for (var start = 0; start < writes.length; start += batchSize) {
      var chunk = writes.sublist(start, min(start + batchSize, writes.length));
      for (var tries = chunk.length; chunk.isNotEmpty;) {
        if (run.stopped) {
          for (final w in chunk) {
            settle(w, ItemOutcome.offline);
          }
          break;
        }
        final rest = <_CardWrite>[];
        for (final w in chunk) {
          if (w.write is! ObjectCreate && !_cached(w.write)) {
            settle(w, ItemOutcome.missing);
          } else {
            rest.add(w);
          }
        }
        chunk = rest;
        if (chunk.isEmpty) break;
        final BatchResult result;
        try {
          final batch = _repository.saveObjectsBatch(
            [for (final w in chunk) w.write],
            schemas: {
              for (final w in chunk)
                w.write.collectionId: ?schemas[w.write.collectionId],
            },
          );
          final acked = await _ackedBatch(batch);
          if (acked == null) {
            run.stopped = true;
            for (final w in chunk) {
              settle(w, ItemOutcome.queued);
            }
            break;
          }
          result = acked;
        } on Object catch (e) {
          for (final w in chunk) {
            settle(
              w,
              ItemOutcome.failed(
                ErrorCode.internal.wire,
                'The write failed: $e',
              ),
            );
          }
          break;
        }
        final refused = <_CardWrite>[];
        for (final w in chunk) {
          if (result.failed.containsKey(w.write.id)) {
            refused.add(w);
          } else {
            settle(w, ItemOutcome.applied);
          }
        }
        if (refused.isEmpty) break;
        if (tries-- > 0 &&
            refused.any((w) => result.failed[w.write.id] == 'not-found')) {
          final gone = await _gone(refused, schemas);
          if (gone.isNotEmpty) {
            for (final w in gone) {
              settle(w, ItemOutcome.missing);
            }
            chunk = [
              for (final w in refused)
                if (!gone.contains(w)) w,
            ];
            continue;
          }
        }
        for (final w in refused) {
          final backend = result.failed[w.write.id]!;
          settle(
            w,
            ItemOutcome.failed(
              _codeOf(backend),
              'The server refused the write ($backend).',
            ),
          );
        }
        break;
      }
      run.report();
    }
  }

  Future<BatchResult?> _ackedBatch(Future<BatchResult> batch) async {
    try {
      return await batch.timeout(ackTimeout);
    } on TimeoutException {
      return null;
    }
  }

  bool _cached(ObjectWrite w) => cache.current(w.collectionId)?[w.id] != null;

  /// The writes of [refused] whose card is gone: by the live cache, else by
  /// asking the repository.
  Future<List<_CardWrite>> _gone(
    List<_CardWrite> refused,
    Map<String, Collection> schemas,
  ) async {
    final byCache = [
      for (final w in refused)
        if (!_cached(w.write)) w,
    ];
    if (byCache.isNotEmpty) return byCache;
    final found = await Future.wait([
      for (final w in refused)
        if (schemas[w.write.collectionId] case final schema?)
          _repository
              .getObject(w.write.collectionId, w.write.id, schema: schema)
              .then((o) => o == null ? w : null)
        else
          Future.value(w),
    ]);
    return found.nonNulls.toList();
  }

  /// A harness error code for a backend error code.
  static String _codeOf(String backend) => switch (backend) {
    'permission-denied' || 'unauthenticated' => ErrorCode.notPermitted.wire,
    'unavailable' || 'deadline-exceeded' => ErrorCode.offline.wire,
    'not-found' ||
    'aborted' ||
    'already-exists' ||
    'failed-precondition' => ErrorCode.conflict.wire,
    _ => ErrorCode.internal.wire,
  };

  /// Leases the existing ones of [collectionIds] (null when none exists).
  Future<Lease?> _lease(Iterable<String> collectionIds) async {
    final ids = {
      for (final id in collectionIds)
        if (cache.collection(id) != null) id,
    };
    if (ids.isEmpty) return null;
    try {
      return await cache.lease(ids);
    } on MissingCollectionException {
      return null;
    }
  }

  /// `3 orders`, `1 order` ([ResultShaper.cards]).
  static String cards(Collection? collection, int n) =>
      _shaper.cards(collection?.name, n);
}

// ---------------------------------------------------------------------------
// One commit.

final class _Commit {
  _Commit(this.c, this.plan, this.outcomes, this.run);

  final PlanCommitter c;
  final Plan plan;
  final Map<String, ItemOutcome> outcomes;
  final _Run run;

  /// The schemas as this commit wrote them (the cache lags behind).
  final Map<String, Collection> written = {};
  final List<JournalItem> _journal = [];

  /// Card ids created in each collection this commit created.
  final Map<String, List<String>> _createdIn = {};

  WorkspaceCache get cache => c.cache;

  List<JournalItem> journal() => [
    for (final e in _createdIn.entries)
      JournalCollectionCreate(collectionId: e.key, createdCardIds: e.value),
    ..._journal,
  ];

  void settle(PlanItem item, ItemOutcome o) => outcomes[item.itemId] = o;

  /// The outcome [item] inherits from a dependency that did not go
  /// through, or null when it may run.
  ItemOutcome? blocked(PlanItem item) {
    for (final d in item.dependsOn) {
      final o = outcomes[d];
      if (o == null || o.written) continue;
      if (o.status == ItemStatus.declined) return ItemOutcome.declined;
      return ItemOutcome.failed(
        o.code ?? ErrorCode.conflict.wire,
        'Needs $d, which was not applied.',
      );
    }
    return null;
  }

  /// Settles [item] when it cannot run (a dependency, or the watchdog
  /// stopped the commit); true when it was settled.
  bool skip(PlanItem item) {
    final o = blocked(item) ?? (run.stopped ? ItemOutcome.offline : null);
    if (o == null) return false;
    settle(item, o);
    run.done++;
    return true;
  }

  Collection? schemaOf(String collectionId) =>
      written[collectionId] ?? cache.collection(collectionId);

  // New collections ----------------------------------------------------------

  Future<void> createCollections(Iterable<CreateCollectionItem> items) async {
    for (final item in items) {
      final id = item.collectionId;
      final fieldItems = [
        for (final i in plan.items)
          if (i is AddFieldItem && i.newCollection && i.collectionId == id) i,
      ];
      final kept = [
        for (final f in fieldItems)
          if (outcomes[f.itemId] == null) f,
      ];
      void settleAll(ItemOutcome o) {
        for (final i in [item, ...kept]) {
          settle(i, o);
        }
        run.done += 1 + kept.length;
      }

      if (blocked(item) case final o?) {
        settleAll(o);
        continue;
      }
      if (run.stopped) {
        settleAll(ItemOutcome.offline);
        continue;
      }
      if (cache.collection(id) != null) {
        settleAll(ItemOutcome.changedElsewhere);
        continue;
      }
      final listed = {for (final f in fieldItems) f.field.id};
      final keep = {for (final f in kept) f.field.id};
      final fields = [
        for (final f in item.collection.fields)
          if (!listed.contains(f.id) || keep.contains(f.id)) f,
      ];
      final ids = [for (final f in fields) f.id];
      final collection = item.collection.copyWith(
        fields: fields,
        layout: item.collection.layout.reconcile(ids),
        views: [for (final v in item.collection.views) v.reconcile(ids)],
      );
      try {
        final acked = await c._acked(c._repository.saveCollection(collection));
        if (!acked) run.stopped = true;
        settleAll(acked ? ItemOutcome.applied : ItemOutcome.queued);
        written[id] = collection;
        _createdIn[id] = [];
      } on Object catch (e) {
        settleAll(
          ItemOutcome.failed(
            ErrorCode.internal.wire,
            'The collection was not created: $e',
          ),
        );
      }
      run.report();
    }
  }

  // Schema and views ---------------------------------------------------------

  Future<void> editSchemas(Iterable<PlanItem> items) async {
    final groups = <String, List<PlanItem>>{};
    for (final i in items) {
      (groups[i.collectionId] ??= []).add(i);
    }
    for (final MapEntry(key: cid, value: group) in groups.entries) {
      final ready = [
        for (final i in group)
          if (!skip(i)) i,
      ];
      if (ready.isEmpty) continue;
      // A collection created by this commit may not be in the cache yet.
      final cached = schemaOf(cid);
      if (cached == null) {
        for (final i in ready) {
          settle(i, ItemOutcome.missing);
        }
        run.done += ready.length;
        continue;
      }
      final viewsOnly = ready.every(PlanCommitter._isViewItem);
      var local = <String, ItemOutcome>{};
      Collection? before;
      Collection? after;
      Collection apply(Collection server) {
        local = {};
        var next = server;
        for (final i in ready) {
          final (applied, o) = _apply(next, i);
          next = applied;
          if (o != null) local[i.itemId] = o;
        }
        if (!viewsOnly) next = _finish(next, server);
        before = server;
        return after = next;
      }

      final r = await c._transact(
        cid,
        apply,
        viewsOf: viewsOnly ? cached : null,
      );
      switch (r) {
        case _TxnResult(kind: _Txn.acked || _Txn.timedOut):
          final ok = r.kind == _Txn.acked;
          if (!ok) run.stopped = true;
          for (final i in ready) {
            settle(
              i,
              local[i.itemId] ??
                  (ok ? ItemOutcome.applied : ItemOutcome.queued),
            );
          }
          if (before != null && after != null) {
            _journal.addAll(schemaDiff(before!, after!));
            written[cid] = after!;
          }
        case _TxnResult(kind: _Txn.missing):
          for (final i in ready) {
            settle(i, ItemOutcome.missing);
          }
        case _TxnResult(:final error):
          for (final i in ready) {
            settle(
              i,
              ItemOutcome.failed(
                ErrorCode.internal.wire,
                'The schema change failed: $error',
              ),
            );
          }
      }
      run.done += ready.length;
      run.report();
    }
  }

  /// [collection] with [item] applied, or as it is plus why [item] cannot
  /// apply. Only the item's touched keys are compared and written.
  (Collection, ItemOutcome?) _apply(Collection collection, PlanItem item) {
    final fields = collection.fields;
    final views = collection.views;
    switch (item) {
      case UpdateCollectionItem(:final keys):
        var next = collection;
        for (final MapEntry(:key, :value) in keys.entries) {
          final live = JournalCollectionMeta.valueOf(collection, key);
          if (!jsonEquals(live, value.before)) {
            return (collection, ItemOutcome.changedElsewhere);
          }
          next = JournalCollectionMeta.withValue(next, key, value.after);
        }
        return (next, null);
      case AddFieldItem(:final field, :final index):
        if (collection.fieldById(field.id) != null) {
          return (collection, ItemOutcome.changedElsewhere);
        }
        return (
          collection.copyWith(
            fields: [...fields]..insert(min(index, fields.length), field),
          ),
          null,
        );
      case UpdateFieldItem(:final before, :final after, views: final entries):
        final live = collection.fieldById(before.id);
        if (live == null) return (collection, ItemOutcome.missing);
        final (lj, bj, aj) = (live.toJson(), before.toJson(), after.toJson());
        if (!unchanged(lj, bj, aj)) {
          return (collection, ItemOutcome.changedElsewhere);
        }
        final merged = c.registry.definitionFromJson(merge(lj, bj, aj));
        final byId = {
          for (final e in entries)
            if (e.before != null && e.after != null) e.viewId: e,
        };
        return (
          collection.copyWith(
            fields: [for (final f in fields) f.id == live.id ? merged : f],
            views: [
              for (final v in views)
                if (byId[v.id] case final e?)
                  mergeView(v, e.before!, e.after!)
                // A view changed since keeps its own filters.
                else
                  v,
            ],
          ),
          null,
        );
      case DeleteFieldItem(:final before):
        if (collection.fieldById(before.id) == null) {
          return (collection, ItemOutcome.missing);
        }
        return (
          collection.copyWith(
            fields: [
              for (final f in fields)
                if (f.id != before.id) f,
            ],
          ),
          null,
        );
      case CreateViewItem(:final view, :final index):
        if (views.any((v) => v.id == view.id)) {
          return (collection, ItemOutcome.changedElsewhere);
        }
        return (
          collection.copyWith(
            views: [...views]..insert(min(index, views.length), view),
          ),
          null,
        );
      case UpdateViewItem(:final before, :final after):
        final live = views.where((v) => v.id == before.id).firstOrNull;
        if (live == null) return (collection, ItemOutcome.missing);
        final (lj, bj, aj) = (live.toJson(), before.toJson(), after.toJson());
        if (!unchanged(lj, bj, aj)) {
          return (collection, ItemOutcome.changedElsewhere);
        }
        return (
          collection.copyWith(
            views: [
              for (final v in views)
                v.id == live.id
                    ? ViewDefinition.fromJson(merge(lj, bj, aj))
                    : v,
            ],
          ),
          null,
        );
      case DeleteViewItem(:final before):
        if (!views.any((v) => v.id == before.id)) {
          return (collection, ItemOutcome.missing);
        }
        if (views.length == 1) {
          return (
            collection,
            ItemOutcome.failed(
              ErrorCode.lastView.wire,
              'A collection keeps at least one view.',
            ),
          );
        }
        return (
          collection.copyWith(
            views: [
              for (final v in views)
                if (v.id != before.id) v,
            ],
          ),
          null,
        );
      default:
        throw StateError('${item.kind.name} is not a schema item');
    }
  }

  /// The editor's recipe after field edits: the layout and views made
  /// consistent with the fields, new fields shown in every view.
  static Collection _finish(Collection next, Collection server) {
    final ids = [for (final f in next.fields) f.id];
    return next
        .copyWith(
          layout: next.layout.reconcile(ids),
          views: [for (final v in next.views) v.reconcile(ids)],
        )
        .withNewFieldsInViews(server);
  }

  // Cards ---------------------------------------------------------------------

  Future<void> editCards(List<PlanItem> items) async {
    if (items.isEmpty) return;
    final lease = await c._lease(items.map((i) => i.collectionId));
    try {
      final writes = <_CardWrite>[];
      for (final item in items) {
        if (skip(item)) continue;
        final schema = schemaOf(item.collectionId);
        final card = cache.current(item.collectionId)?[item.targetId!];
        if (schema == null || card == null) {
          settle(item, ItemOutcome.missing);
          run.done++;
          continue;
        }
        switch (item) {
          case UpdateCardItem(:final changes):
            final keys = <String, ValueChange>{};
            ItemOutcome? stale;
            for (final ch in changes) {
              final f = schema.fieldById(ch.fieldId!);
              if (f == null || f is CalculatedFieldDefinition) continue;
              final live = (card[f.id] ?? f.emptyValue()).toJson();
              if (!jsonEquals(live, ch.before)) {
                stale = ItemOutcome.changedElsewhere;
                break;
              }
              keys[f.id] = (before: ch.before, after: ch.after);
            }
            stale ??= keys.isEmpty ? ItemOutcome.missing : null;
            if (stale != null) {
              settle(item, stale);
              run.done++;
              continue;
            }
            writes.add(
              _CardWrite(
                ObjectUpdate(
                  collectionId: item.collectionId,
                  id: card.id,
                  values: {for (final e in keys.entries) e.key: e.value.after},
                ),
                (o) {
                  settle(item, o);
                  if (o.written) {
                    _journal.add(
                      JournalCardUpdate(
                        collectionId: item.collectionId,
                        id: card.id,
                        keys: keys,
                      ),
                    );
                  }
                },
              ),
            );
          case DeleteCardItem(:final before):
            final changed = schema.fields.any(
              (f) =>
                  f is! CalculatedFieldDefinition &&
                  !jsonEquals(
                    (card[f.id] ?? f.emptyValue()).toJson(),
                    (before[f.id] ?? f.emptyValue()).toJson(),
                  ),
            );
            if (changed) {
              settle(item, ItemOutcome.changedElsewhere);
              run.done++;
              continue;
            }
            writes.add(
              _CardWrite(
                ObjectDelete(collectionId: item.collectionId, id: card.id),
                (o) {
                  settle(item, o);
                  if (o.written) {
                    _journal.add(JournalCardDelete.of(card, schema));
                  }
                },
              ),
            );
          default:
            throw StateError('${item.kind.name} is not a card edit');
        }
      }
      await c._writeCards(writes, _schemas(writes), run);
    } finally {
      lease?.release();
    }
  }

  Future<void> createCards(Iterable<CreateCardItem> items) async {
    final writes = <_CardWrite>[];
    for (final item in items) {
      if (skip(item)) continue;
      final schema = schemaOf(item.collectionId);
      if (schema == null) {
        settle(item, ItemOutcome.missing);
        run.done++;
        continue;
      }
      // Normalized to the schema as written: values of new fields the user
      // left out are dropped, the card is still created.
      final object = MorkvaObject.create(
        id: item.object.id,
        collection: schema,
        values: item.object.values,
        createdAt: item.object.createdAt,
        updatedAt: item.object.updatedAt,
      );
      writes.add(
        _CardWrite(ObjectCreate(object), (o) {
          settle(item, o);
          if (!o.written) return;
          _journal.add(
            JournalCardCreate(
              collectionId: object.collectionId,
              id: object.id,
              after: {
                for (final f in schema.fields)
                  if (f is! CalculatedFieldDefinition &&
                      f is! AutoNumberFieldDefinition &&
                      (object[f.id]?.isNotEmpty ?? false))
                    f.id: object[f.id]!.toJson(),
              },
            ),
          );
          _createdIn[object.collectionId]?.add(object.id);
        }),
      );
    }
    await c._writeCards(writes, _schemas(writes), run);
  }

  Map<String, Collection> _schemas(List<_CardWrite> writes) => {
    for (final w in writes)
      w.write.collectionId: ?schemaOf(w.write.collectionId),
  };

  // Collection delete -----------------------------------------------------------

  Future<void> deleteCollections(Iterable<DeleteCollectionItem> items) async {
    for (final item in items) {
      if (skip(item)) continue;
      final id = item.collectionId;
      if (cache.collection(id) == null) {
        settle(item, ItemOutcome.missing);
        run.done++;
        continue;
      }
      final CollectionSnapshot snapshot;
      final Collection server;
      try {
        snapshot = await cache.read(id);
        server = await c._repository.getCollection(id) ?? item.before;
      } on MissingCollectionException {
        settle(item, ItemOutcome.missing);
        run.done++;
        continue;
      }
      final undoable = snapshot.count <= kMaxUndoableCards;
      var left = 0;
      ItemOutcome? firstFailure;
      final writes = [
        for (final card in snapshot.raw)
          _CardWrite(ObjectDelete(collectionId: id, id: card.id), (o) {
            if (o.written || o.status == ItemStatus.stale) {
              if (o.written && undoable) {
                _journal.add(JournalCardDelete.of(card, server));
              }
              // A queued delete still waits for the server.
              if (o.status == ItemStatus.queued) left++;
              return;
            }
            left++;
            firstFailure ??= o;
          }),
      ];
      await c._writeCards(writes, {id: server}, run, counts: false);
      if (left > 0 || run.stopped) {
        settle(
          item,
          ItemOutcome.failed(
            firstFailure?.code ?? ErrorCode.offline.wire,
            '${PlanCommitter.cards(server, left)} left, collection kept',
          ),
        );
        run.done++;
        continue;
      }
      try {
        final acked = await c._acked(c._repository.deleteCollection(id));
        if (!acked) run.stopped = true;
        settle(item, acked ? ItemOutcome.applied : ItemOutcome.queued);
        if (undoable) {
          _journal.add(
            JournalCollectionDelete(collectionId: id, before: server.toJson()),
          );
        }
      } on Object catch (e) {
        settle(
          item,
          ItemOutcome.failed(
            ErrorCode.internal.wire,
            'The cards are deleted but the collection was not: $e',
          ),
        );
      }
      run.done++;
      run.report();
    }
  }
}

// ---------------------------------------------------------------------------
// One undo.

final class _Undo {
  _Undo(this.c, this.run);

  final PlanCommitter c;
  final _Run run;
  final UndoResult result = UndoResult();

  /// Schemas this undo wrote (re-created collections).
  final Map<String, Collection> written = {};

  /// Created cards this undo deleted.
  final Set<String> deletedCards = {};

  WorkspaceCache get cache => c.cache;

  void reverted(JournalItem item) {
    result.reverted++;
    if (item
        case JournalCardUpdate() ||
            JournalCardCreate() ||
            JournalCardDelete()) {
      result._cards.update(item.collectionId, (n) => n + 1, ifAbsent: () => 1);
    } else {
      result._schema++;
    }
    run.done++;
  }

  void skipped(JournalItem item, String reason) {
    result.skipped.add((id: item.targetId, reason: reason));
    run.done++;
  }

  void failed(JournalItem item, String code, String message) {
    result.failed.add((id: item.targetId, code: code, message: message));
    result.failedItems.add(item);
    run.done++;
  }

  /// Settles [item] by a write outcome.
  void settle(JournalItem item, ItemOutcome o) => switch (o.status) {
    ItemStatus.applied || ItemStatus.queued => reverted(item),
    ItemStatus.stale => skipped(item, o.reason!),
    _ => failed(item, o.code!, o.message!),
  };

  bool stoppedFor(JournalItem item) {
    if (!run.stopped) return false;
    settle(item, ItemOutcome.offline);
    return true;
  }

  Future<void> recreateCollections(
    Iterable<JournalCollectionDelete> items,
  ) async {
    for (final item in items) {
      if (stoppedFor(item)) continue;
      if (cache.collection(item.collectionId) != null) {
        skipped(item, 'exists');
        continue;
      }
      try {
        final collection = Collection.fromJson(item.before, c.registry);
        final acked = await c._acked(c._repository.saveCollection(collection));
        if (!acked) run.stopped = true;
        written[collection.id] = collection;
        reverted(item);
      } on Object catch (e) {
        failed(item, ErrorCode.internal.wire, 'Not re-created: $e');
      }
    }
  }

  Future<void> revertSchemas(List<JournalItem> items) async {
    final groups = <String, List<JournalItem>>{};
    for (final i in items) {
      (groups[i.collectionId] ??= []).add(i);
    }
    for (final MapEntry(key: cid, value: group) in groups.entries) {
      if (run.stopped) {
        group.forEach(stoppedFor);
        continue;
      }
      final cached = cache.collection(cid);
      if (cached == null) {
        for (final i in group) {
          skipped(i, kMissing);
        }
        continue;
      }
      final viewsOnly = group.every((i) => i is JournalViewEntry);
      var local = <JournalItem, String>{};
      Collection apply(Collection server) {
        local = {};
        var next = server;
        void each<T extends JournalItem>(
          (Collection, String?) Function(Collection, T) revert,
        ) {
          for (final i in group.whereType<T>()) {
            final (applied, why) = revert(next, i);
            next = applied;
            if (why != null) local[i] = why;
          }
        }

        each<JournalFieldEntry>(_revertField);
        if (!viewsOnly) {
          next = next.copyWith(
            layout: next.layout.reconcile([for (final f in next.fields) f.id]),
          );
        }
        each<JournalLayoutEntry>(_revertLayout);
        each<JournalViewEntry>(_revertView);
        each<JournalCollectionMeta>(_revertMeta);
        if (!viewsOnly) {
          final ids = [for (final f in next.fields) f.id];
          next = next.copyWith(
            layout: next.layout.reconcile(ids),
            views: [for (final v in next.views) v.reconcile(ids)],
          );
        }
        return next;
      }

      final r = await c._transact(
        cid,
        apply,
        viewsOf: viewsOnly ? cached : null,
      );
      switch (r) {
        case _TxnResult(kind: _Txn.acked || _Txn.timedOut):
          if (r.kind == _Txn.timedOut) run.stopped = true;
          for (final i in group) {
            if (local[i] case final why?) {
              skipped(i, why);
            } else {
              reverted(i);
            }
          }
        case _TxnResult(kind: _Txn.missing):
          for (final i in group) {
            skipped(i, kMissing);
          }
        case _TxnResult(:final error):
          for (final i in group) {
            failed(i, ErrorCode.internal.wire, 'Not reverted: $error');
          }
      }
      run.report();
    }
  }

  (Collection, String?) _revertField(Collection col, JournalFieldEntry e) {
    final live = col.fieldById(e.fieldId);
    final fields = col.fields;
    switch ((e.before, e.after)) {
      case (null, final after?):
        if (live == null) return (col, kMissing);
        if (!jsonEquals(live.toJson(), after)) return (col, _changedSince);
        return (
          col.copyWith(
            fields: [
              for (final f in fields)
                if (f.id != e.fieldId) f,
            ],
          ),
          null,
        );
      case (final before?, null):
        if (live != null) return (col, _changedSince);
        final field = c.registry.definitionFromJson(before);
        return (
          col.copyWith(
            fields: [...fields]..insert(min(e.index, fields.length), field),
          ),
          null,
        );
      case (final before?, final after?):
        if (live == null) return (col, kMissing);
        final lj = live.toJson();
        if (!unchanged(lj, after, before)) return (col, _changedSince);
        final merged = c.registry.definitionFromJson(merge(lj, after, before));
        return (
          col.copyWith(
            fields: [for (final f in fields) f.id == e.fieldId ? merged : f],
          ),
          null,
        );
      default:
        return (col, null);
    }
  }

  (Collection, String?) _revertView(Collection col, JournalViewEntry e) {
    final views = col.views;
    final live = views.where((v) => v.id == e.viewId).firstOrNull;
    switch ((e.before, e.after)) {
      case (null, final after?):
        if (live == null) return (col, kMissing);
        // UI state (manual order, collapsed groups) may move freely.
        if (!jsonEquals(
          _withoutUiState(live.toJson()),
          _withoutUiState(after),
        )) {
          return (col, _changedSince);
        }
        if (views.length == 1) return (col, ErrorCode.lastView.wire);
        return (
          col.copyWith(
            views: [
              for (final v in views)
                if (v.id != e.viewId) v,
            ],
          ),
          null,
        );
      case (final before?, null):
        if (live != null) return (col, _changedSince);
        return (
          col.copyWith(
            views: [...views]
              ..insert(
                min(e.index, views.length),
                ViewDefinition.fromJson(before),
              ),
          ),
          null,
        );
      case (final before?, final after?):
        if (live == null) return (col, kMissing);
        final lj = live.toJson();
        if (!unchanged(lj, after, before)) return (col, _changedSince);
        return (
          col.copyWith(
            views: [
              for (final v in views)
                v.id == e.viewId
                    ? ViewDefinition.fromJson(merge(lj, after, before))
                    : v,
            ],
          ),
          null,
        );
      default:
        return (col, null);
    }
  }

  /// Puts [e]'s field back in its old row and span. shortcut: when its old
  /// section is gone the cell stays where `reconcile` appended it; upgrade
  /// when the assistant edits layouts (out of scope in v1).
  (Collection, String?) _revertLayout(Collection col, JournalLayoutEntry e) {
    final before = e.before;
    if (before == null) return (col, null);
    if (col.fieldById(e.fieldId) == null) return (col, kMissing);
    final layout = col.layout;
    final live = CellPlacement.of(layout, e.fieldId);
    if (e.after != null && !e.after!.sameSpot(live)) {
      return (col, _changedSince);
    }
    if (!layout.sections.any((s) => s.id == before.sectionId)) {
      return (col, null);
    }
    // Lift the cell out (pruning the row reconcile appended for it), then
    // put it back in its old row, or in a new row at its old position.
    final lifted = layout.reconcile([
      for (final id in layout.fieldIds)
        if (id != e.fieldId) id,
    ]);
    final cell = LayoutCell(fieldId: e.fieldId, span: before.span);
    var next = CardLayout(
      sections: [
        for (final s in lifted.sections)
          if (s.id != before.sectionId)
            s
          else
            switch (s.rows.indexWhere((r) => r.id == before.rowId)) {
              -1 => s.copyWith(
                rows: [...s.rows]
                  ..insert(
                    min(before.rowIndex, s.rows.length),
                    LayoutRow(id: before.rowId, cells: [cell]),
                  ),
              ),
              final at => s.copyWith(
                rows: [...s.rows]
                  ..[at] = s.rows[at].copyWith(
                    cells: [...s.rows[at].cells]
                      ..insert(
                        min(before.cellIndex, s.rows[at].cells.length),
                        cell,
                      ),
                  ),
              ),
            },
      ],
    );
    // Shrinks the row's other cells when the spans overflow.
    next = next.setCellSpan(before.rowId, e.fieldId, before.span);
    return (col.copyWith(layout: next), null);
  }

  (Collection, String?) _revertMeta(Collection col, JournalCollectionMeta e) {
    var next = col;
    for (final MapEntry(:key, :value) in e.keys.entries) {
      if (!jsonEquals(JournalCollectionMeta.valueOf(col, key), value.after)) {
        return (col, _changedSince);
      }
      next = JournalCollectionMeta.withValue(next, key, value.before);
    }
    return (next, null);
  }

  Future<void> revertCards(List<JournalItem> items) async {
    if (items.isEmpty) return;
    final lease = await c._lease(items.map((i) => i.collectionId));
    try {
      final writes = <_CardWrite>[];
      final schemas = <String, Collection>{};
      for (final item in items) {
        final cid = item.collectionId;
        final schema = written[cid] ?? cache.collection(cid);
        if (schema == null) {
          skipped(item, kMissing);
          continue;
        }
        schemas[cid] = schema;
        final card = written.containsKey(cid)
            ? null
            : cache.current(cid)?[item.targetId];
        switch (item) {
          case JournalCardDelete():
            if (card != null) {
              skipped(item, 'exists');
              continue;
            }
            writes.add(
              _CardWrite(ObjectCreate(item.object(schema)), (o) {
                settle(item, o);
              }),
            );
          case JournalCardUpdate(:final keys):
            if (card == null) {
              skipped(item, kMissing);
              continue;
            }
            final values = <String, Object?>{};
            var changed = false;
            for (final MapEntry(:key, :value) in keys.entries) {
              final f = schema.fieldById(key);
              if (f == null) continue;
              if (!jsonEquals(
                (card[key] ?? f.emptyValue()).toJson(),
                value.after,
              )) {
                changed = true;
                break;
              }
              values[key] = value.before;
            }
            if (changed || values.isEmpty) {
              skipped(item, changed ? _changedSince : kMissing);
              continue;
            }
            writes.add(
              _CardWrite(
                ObjectUpdate(collectionId: cid, id: item.id, values: values),
                (o) => settle(item, o),
              ),
            );
          case JournalCardCreate(:final after):
            if (card == null) {
              skipped(item, kMissing);
              continue;
            }
            // Every writable field: one left empty at creation and filled
            // since is a change too.
            final changed = schema.fields.any(
              (f) =>
                  f is! CalculatedFieldDefinition &&
                  f is! AutoNumberFieldDefinition &&
                  (after.containsKey(f.id)
                      ? !jsonEquals(
                          (card[f.id] ?? f.emptyValue()).toJson(),
                          after[f.id],
                        )
                      : !(card[f.id]?.isEmpty ?? true)),
            );
            if (changed) {
              skipped(item, _changedSince);
              continue;
            }
            writes.add(
              _CardWrite(ObjectDelete(collectionId: cid, id: item.id), (o) {
                if (o.written) deletedCards.add(item.id);
                settle(item, o);
              }),
            );
          default:
            throw StateError('${item.kind} is not a card item');
        }
      }
      await c._writeCards(writes, schemas, run);
    } finally {
      lease?.release();
    }
  }

  Future<void> deleteCreated(Iterable<JournalCollectionCreate> items) async {
    for (final item in items) {
      if (stoppedFor(item)) continue;
      final id = item.collectionId;
      if (cache.collection(id) == null) {
        skipped(item, kMissing);
        continue;
      }
      try {
        final snapshot = await cache.read(id);
        final others = snapshot.raw.where((o) => !deletedCards.contains(o.id));
        if (others.isNotEmpty) {
          skipped(item, 'has_cards');
          continue;
        }
        final acked = await c._acked(c._repository.deleteCollection(id));
        if (!acked) run.stopped = true;
        reverted(item);
      } on MissingCollectionException {
        skipped(item, kMissing);
      } on Object catch (e) {
        failed(item, ErrorCode.internal.wire, 'Not deleted: $e');
      }
    }
  }

  /// "Reverted 12 orders", "Reverted 4 changes · 2 changed since; left as
  /// they are".
  String summary() {
    final cards = result._cards;
    final String head;
    if (result.reverted == 0) {
      head = 'Nothing was reverted';
    } else if (result._schema == 0 && cards.length == 1) {
      head =
          'Reverted ${PlanCommitter.cards(cache.collection(cards.keys.single), cards.values.single)}';
    } else {
      head =
          'Reverted ${result.reverted} '
          '${result.reverted == 1 ? 'change' : 'changes'}';
    }
    final since = result.skipped.where((s) => s.reason == _changedSince).length;
    return [
      head,
      if (since > 0) '$since changed since; left as they are',
      if (result.failed.isNotEmpty) '${result.failed.length} failed',
    ].join(' · ');
  }

  static const String _changedSince = 'changed_since';

  static Map<String, Object?> _withoutUiState(Map<String, Object?> view) =>
      {...view}
        ..remove('manualOrder')
        ..remove('collapsedGroups');
}

// ---------------------------------------------------------------------------
// Helpers.

/// Whether [live] still holds [before] on every key [after] changes.
bool unchanged(
  Map<String, Object?> live,
  Map<String, Object?> before,
  Map<String, Object?> after,
) {
  for (final key in {...before.keys, ...after.keys}) {
    if (jsonEquals(before[key], after[key])) continue;
    if (!jsonEquals(live[key], before[key])) return false;
  }
  return true;
}

/// [live] with every key [after] changes against [before] taken from
/// [after] (removed where [after] lacks it).
Map<String, Object?> merge(
  Map<String, Object?> live,
  Map<String, Object?> before,
  Map<String, Object?> after,
) {
  final out = {...live};
  for (final key in {...before.keys, ...after.keys}) {
    if (jsonEquals(before[key], after[key])) continue;
    if (after.containsKey(key)) {
      out[key] = after[key];
    } else {
      out.remove(key);
    }
  }
  return out;
}

/// [live] with the keys [before] → [after] changes, when [live] still holds
/// them; else [live] as it is.
ViewDefinition mergeView(
  ViewDefinition live,
  ViewDefinition before,
  ViewDefinition after,
) {
  final (lj, bj, aj) = (live.toJson(), before.toJson(), after.toJson());
  return unchanged(lj, bj, aj)
      ? ViewDefinition.fromJson(merge(lj, bj, aj))
      : live;
}

/// The journal entries that turn [after] back into [before]: changed
/// collection keys, field and view entries, and moved layout cells.
List<JournalItem> schemaDiff(Collection before, Collection after) {
  final cid = after.id;
  final items = <JournalItem>[];
  final meta = <String, ValueChange>{
    for (final key in JournalCollectionMeta.metaKeys)
      if (JournalCollectionMeta.valueOf(before, key) !=
          JournalCollectionMeta.valueOf(after, key))
        key: (
          before: JournalCollectionMeta.valueOf(before, key),
          after: JournalCollectionMeta.valueOf(after, key),
        ),
  };
  if (meta.isNotEmpty) {
    items.add(JournalCollectionMeta(collectionId: cid, keys: meta));
  }
  final beforeIds = [for (final f in before.fields) f.id];
  final afterIds = [for (final f in after.fields) f.id];
  for (final id in {...beforeIds, ...afterIds}) {
    final b = before.fieldById(id)?.toJson();
    final a = after.fieldById(id)?.toJson();
    if (jsonEquals(b, a)) continue;
    items.add(
      JournalFieldEntry(
        collectionId: cid,
        fieldId: id,
        index: b != null ? beforeIds.indexOf(id) : afterIds.indexOf(id),
        before: b,
        after: a,
      ),
    );
  }
  for (final e in viewEntries(before.views, after.views)) {
    items.add(
      JournalViewEntry(
        collectionId: cid,
        viewId: e.viewId,
        index: e.index,
        before: e.before?.toJson(),
        after: e.after?.toJson(),
      ),
    );
  }
  for (final id in {...before.layout.fieldIds, ...after.layout.fieldIds}) {
    final b = CellPlacement.of(before.layout, id);
    final a = CellPlacement.of(after.layout, id);
    if (b != null && b.sameSpot(a)) continue;
    items.add(
      JournalLayoutEntry(collectionId: cid, fieldId: id, before: b, after: a),
    );
  }
  return items;
}

/// Commit or undo progress: [done] of [total] items settled.
final class _Run {
  _Run(this.ctx, this.callId, this.total);

  final HarnessContext ctx;
  final String callId;
  final int total;
  int done = 0;
  int _reported = -1;

  /// Set once a write was not acknowledged in time: nothing more starts.
  bool stopped = false;

  /// Emits a `progress` event when the count moved (plans over
  /// [kProgressThreshold] items only).
  void report() {
    if (total <= kProgressThreshold || done == _reported) return;
    _reported = done;
    ctx.emit(
      ProgressEvent(callId: callId, done: min(done, total), total: total),
    );
  }
}

/// One card write and what to do with its outcome.
final class _CardWrite {
  _CardWrite(this.write, this.settle);

  final ObjectWrite write;
  final void Function(ItemOutcome outcome) settle;
}

enum _Txn { acked, timedOut, missing, error }

final class _TxnResult {
  const _TxnResult._(this.kind, [this.error]);

  const _TxnResult.error(Object error) : this._(_Txn.error, error);

  static const _TxnResult acked = _TxnResult._(_Txn.acked);
  static const _TxnResult timedOut = _TxnResult._(_Txn.timedOut);
  static const _TxnResult missing = _TxnResult._(_Txn.missing);

  final _Txn kind;
  final Object? error;
}
