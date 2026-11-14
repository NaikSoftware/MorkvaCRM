import '../../core/domain/inbox/inbox_item.dart';

/// The member's Inbox (`workspaces/{wid}/inbox`, items assigned to them).
///
/// Writes resolve on server ack, like every store in `lib/api`, so callers
/// fire them without awaiting and attach `catchError` (spec §5).
abstract interface class InboxRepository {
  /// Binds the workspace and the signed-in member. Before it, every call
  /// throws [StateError].
  void initialize({required String workspaceId, required String uid});

  /// Every item assigned to the member, live; errors surface on the stream.
  /// [fromCache]: the snapshot is the local cache's, not yet confirmed by
  /// the server (it may miss or hold stale items).
  Stream<({List<InboxItem> items, bool fromCache})> watch();

  /// A fresh document id for a new item.
  String newId();

  /// Creates [item] (a full `set`).
  Future<void> create(InboxItem item);

  /// Writes only [fields] of item [id] (JSON names of [InboxItem.toJson];
  /// DateTimes allowed), plus `updatedAt`.
  Future<void> update(String id, Map<String, Object?> fields);

  Future<void> delete(String id);
}
