import 'package:morkva_crm/core/domain/domain.dart';

/// Persistence boundary for MorkvaCRM domain data.
///
/// Deliberately Firestore-agnostic: this contract speaks only the domain types
/// from `lib/core/domain/` so callers (blocs, UI) never touch backend types. The
/// Firestore implementation lives in `lib/api/data/` and is the only place that
/// knows about documents, snapshots, and revisions.
///
/// Object reads take the owning [Collection] `schema` so values can be decoded
/// from native backend types back into the domain's canonical representation.
abstract interface class DataRepository {
  /// Binds this repository to [workspaceId] before any reads or writes.
  Future<void> initialize(String workspaceId);

  // Collections.

  /// Streams the workspace's collections, emitting on every change.
  Stream<List<Collection>> watchCollections();

  /// Reads all collections once.
  Future<List<Collection>> getCollections();

  /// Reads a single collection by [collectionId], or `null` if missing.
  Future<Collection?> getCollection(String collectionId);

  /// Creates or updates [collection].
  Future<void> saveCollection(Collection collection);

  /// Replaces only the saved views of the existing collection [collectionId],
  /// leaving its fields and layout as stored (so a client with an older copy
  /// of the schema cannot revert them).
  Future<void> saveViews(String collectionId, List<ViewDefinition> views);

  /// Deletes the collection identified by [collectionId].
  Future<void> deleteCollection(String collectionId);

  // Sidebar pins.

  /// Streams the ids of the collections pinned to the sidebar, in display
  /// order. Ids of deleted collections may linger; callers filter them.
  Stream<List<String>> watchPinnedCollectionIds();

  /// Replaces the pinned collection ids with [ids], in display order.
  Future<void> savePinnedCollectionIds(List<String> ids);

  // Objects.

  /// Streams the objects in [collectionId], emitting on every change.
  ///
  /// [schema] is the owning collection, used to decode object values; when
  /// omitted the implementation resolves it as needed.
  Stream<List<MorkvaObject>> watchObjects(
    String collectionId, {
    Collection? schema,
  });

  /// Streams the object [objectId] of [collectionId], decoded against
  /// [schema], emitting on every change; `null` while it does not exist.
  /// Cheaper than [watchObjects] for following a single object.
  Stream<MorkvaObject?> watchObject(
    String collectionId,
    String objectId, {
    required Collection schema,
  });

  /// Reads all objects in [collectionId] once, decoded against [schema].
  Future<List<MorkvaObject>> getObjects(
    String collectionId, {
    required Collection schema,
  });

  /// Reads all objects in [collectionId] from the **server** only, never the
  /// local cache (which may lag or be partial); throws when the server
  /// cannot be reached. Decoded against [schema].
  Future<List<MorkvaObject>> getServerObjects(
    String collectionId, {
    required Collection schema,
  });

  /// Reads a single object by [objectId] in [collectionId], decoded against
  /// [schema]; `null` if missing.
  Future<MorkvaObject?> getObject(
    String collectionId,
    String objectId, {
    required Collection schema,
  });

  /// Creates or updates [object], encoding its values against [schema].
  /// [origin] says who caused the write; it travels on its [CardChange].
  Future<void> saveObject(
    MorkvaObject object, {
    required Collection schema,
    WriteOrigin origin = const WriteOrigin.ui(),
  });

  /// Deletes the object identified by [objectId] in [collectionId].
  ///
  /// [before] is the object as it stood, for its [CardChange]; when omitted
  /// the implementation looks it up locally and emits nothing if it can't.
  Future<void> deleteObject(
    String collectionId,
    String objectId, {
    MorkvaObject? before,
    WriteOrigin origin = const WriteOrigin.ui(),
  });

  // Bulk and transactional writes (the assistant's plan commits).

  /// Applies [writes] in atomic batches of at most [maxBatchWrites], in
  /// order. [schemas] maps each write's collection id to its schema, used to
  /// encode values (calculated fields are never stored).
  ///
  /// A chunk that fails is reported per id in [BatchResult.failed] with a
  /// backend error code (e.g. `not-found` when an updated object is gone) and
  /// the later chunks still run. Creates missing an auto-number get one from
  /// a single counter reservation per chunk; a number already present (an
  /// undo re-create) is kept and needs no reservation. The future completes
  /// only once the backend acknowledged each chunk.
  Future<BatchResult> saveObjectsBatch(
    List<ObjectWrite> writes, {
    required Map<String, Collection> schemas,
    WriteOrigin origin = const WriteOrigin.ui(),
  });

  /// Every card write this instance made, after it resolved (D5). Broadcast;
  /// never remote changes, failed writes or schema writes.
  Stream<CardChange> get changes;

  /// Rewrites the collection [id] as [apply] returns it, reading the
  /// **server** copy inside a transaction, so a concurrent edit by another
  /// client to anything [apply] leaves alone survives. Throws a [StateError]
  /// when the collection does not exist.
  Future<void> updateCollection(
    String id,
    Collection Function(Collection server) apply,
  );

  /// Replaces the views of collection [collectionId] with what [apply]
  /// returns for the **server** views, inside a transaction; fields and
  /// layout are left as stored. Throws a [StateError] when the collection
  /// does not exist.
  Future<void> updateViews(
    String collectionId,
    List<ViewDefinition> Function(List<ViewDefinition> server) apply,
  );

  /// Releases resources and cancels any active subscriptions.
  Future<void> dispose();
}

/// Most writes one [DataRepository.saveObjectsBatch] chunk commits at once
/// (Firestore allows 500 per batch; the rest is headroom).
const maxBatchWrites = 450;

/// One object write in a [DataRepository.saveObjectsBatch] call.
sealed class ObjectWrite {
  const ObjectWrite();

  /// The collection the object belongs to.
  String get collectionId;

  /// The object's id.
  String get id;
}

/// Creates [object] (a full object; its auto-numbers may already be set).
final class ObjectCreate extends ObjectWrite {
  const ObjectCreate(this.object);

  final MorkvaObject object;

  @override
  String get collectionId => object.collectionId;

  @override
  String get id => object.id;
}

/// Sets only the touched [values] (field id → domain JSON, as
/// `FieldValue.toJson` gives it) of an existing object; other values stay.
final class ObjectUpdate extends ObjectWrite {
  const ObjectUpdate({
    required this.collectionId,
    required this.id,
    required this.values,
    this.before,
  });

  @override
  final String collectionId;

  @override
  final String id;

  final Map<String, Object?> values;

  /// The object before this write; without it no [CardChange] is emitted.
  final MorkvaObject? before;
}

/// Deletes an object; deleting a missing one is a no-op.
final class ObjectDelete extends ObjectWrite {
  const ObjectDelete({
    required this.collectionId,
    required this.id,
    this.before,
  });

  @override
  final String collectionId;

  @override
  final String id;

  /// The object before this write; without it no [CardChange] is emitted.
  final MorkvaObject? before;
}

/// The outcome of [DataRepository.saveObjectsBatch].
final class BatchResult {
  const BatchResult({this.written = const [], this.failed = const {}});

  /// Ids whose write the backend acknowledged.
  final List<String> written;

  /// Ids whose chunk failed, mapped to the backend error code.
  final Map<String, String> failed;

  @override
  String toString() => 'BatchResult(written: $written, failed: $failed)';
}

/// What kind of caller made a write.
enum WriteKind { ui, plan, automation, undo, template, collectionDelete }

/// Who caused a write; travels with every write call (D5).
final class WriteOrigin {
  const WriteOrigin.ui()
    : kind = WriteKind.ui,
      actor = null,
      runId = null,
      commitId = null,
      depth = 0,
      chain = const [];

  const WriteOrigin({
    required this.kind,
    this.actor,
    this.runId,
    this.commitId,
    this.depth = 0,
    this.chain = const [],
  });

  final WriteKind kind;

  /// `agent:assistant` | `plugin:<id>` | null (= the signed-in user).
  final String? actor;

  /// The automation run that made the write.
  final String? runId;

  /// The plan id for plan/host commits; minted per UI write call. Every
  /// change of one call shares it (the fan-out key).
  final String? commitId;

  /// 0 for ui/plan; the run's depth for automation writes.
  final int depth;

  /// Automation ids, root first.
  final List<String> chain;

  /// This origin with [commitId] set.
  WriteOrigin withCommitId(String commitId) => WriteOrigin(
    kind: kind,
    actor: actor,
    runId: runId,
    commitId: commitId,
    depth: depth,
    chain: chain,
  );

  @override
  String toString() =>
      'WriteOrigin(${kind.name}, actor: $actor, runId: $runId, '
      'commitId: $commitId, depth: $depth, chain: $chain)';
}

/// One card write a [DataRepository] made, emitted on
/// [DataRepository.changes] once the write resolved.
final class CardChange {
  const CardChange({
    required this.collectionId,
    required this.cardId,
    required this.before,
    required this.after,
    required this.writeId,
    required this.origin,
    this.rev,
  });

  final String collectionId;
  final String cardId;

  /// Null = created.
  final MorkvaObject? before;

  /// Null = deleted.
  final MorkvaObject? after;

  /// The new rev (saveObject only; batch writes increment, so null).
  final int? rev;

  /// Minted per emitted change (the idempotency key).
  final String writeId;

  final WriteOrigin origin;

  @override
  String toString() =>
      'CardChange($collectionId/$cardId, '
      '${before == null
          ? 'created'
          : after == null
          ? 'deleted'
          : 'updated'}, '
      'rev: $rev, writeId: $writeId, origin: $origin)';
}

/// Whether an update from [before] to [after] changed none of the
/// [touched] values; such a write emits no [CardChange].
bool isNoOpUpdate(
  MorkvaObject before,
  MorkvaObject after,
  Iterable<String> touched,
) => touched.every((k) => before.values[k] == after.values[k]);
