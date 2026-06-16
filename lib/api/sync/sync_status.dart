import 'package:equatable/equatable.dart';

/// The synchronization state of the local data against Cloud Firestore.
///
/// Derived from Firestore snapshot metadata (`isFromCache`, `hasPendingWrites`)
/// plus explicit conflict/error reports — there is no custom sync engine. Sealed
/// so consumers can exhaustively switch over every variant.
sealed class SyncStatus extends Equatable {
  /// Const base constructor for all variants.
  const SyncStatus();
}

/// Local data matches the server: no pending writes, not serving from cache.
final class SyncSynced extends SyncStatus {
  /// Creates a [SyncSynced] status.
  const SyncSynced();

  @override
  List<Object?> get props => const [];
}

/// Local writes are queued and not yet acknowledged by the server.
final class SyncPending extends SyncStatus {
  /// Creates a [SyncPending] status.
  const SyncPending();

  @override
  List<Object?> get props => const [];
}

/// Data is being served from the local cache (offline / disconnected).
final class SyncOffline extends SyncStatus {
  /// Creates a [SyncOffline] status.
  const SyncOffline();

  @override
  List<Object?> get props => const [];
}

/// A remote change overwrote a local edit (last-write-wins). Surfaced as a
/// visible warning until the user dismisses it.
final class SyncConflict extends SyncStatus {
  /// Creates a [SyncConflict] carrying the ids of the affected objects.
  const SyncConflict({required this.affectedObjectIds});

  /// Ids of the object documents involved in the conflict.
  final Set<String> affectedObjectIds;

  @override
  List<Object?> get props => [affectedObjectIds];
}

/// Synchronization failed with an error.
final class SyncError extends SyncStatus {
  /// Creates a [SyncError] with a human-readable [message] and optional [cause].
  const SyncError({required this.message, this.cause});

  /// Human-readable description of the failure.
  final String message;

  /// The underlying error, if any.
  final Object? cause;

  @override
  List<Object?> get props => [message];
}
