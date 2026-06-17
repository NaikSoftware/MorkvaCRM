import 'package:flutter_bloc/flutter_bloc.dart';

import 'sync_status.dart';

/// Tracks the app-wide [SyncStatus] from signals reported by the data layer.
///
/// Pure Dart, no Firebase dependency: the Firestore data repository translates
/// snapshot metadata and write outcomes into the `report*` calls below, and this
/// cubit folds them into a single status the UI can render.
///
/// A [SyncConflict] is "sticky": while in conflict, snapshot-metadata updates are
/// ignored so the warning stays visible until the user explicitly dismisses it.
class SyncStatusCubit extends Cubit<SyncStatus> {
  /// Creates a [SyncStatusCubit] in the [SyncUnknown] state — no sync signal
  /// has been observed yet, so the UI shows nothing rather than a misleading
  /// "Offline". The first `report*` call moves it to a real status.
  SyncStatusCubit() : super(const SyncUnknown());

  /// Reports that a local write was queued. Moves to [SyncPending] unless a
  /// conflict is currently being shown (which takes precedence).
  void reportPendingWrite() {
    if (state is SyncConflict) return;
    emit(const SyncPending());
  }

  /// Folds Firestore snapshot metadata into a status.
  ///
  /// Ignored while in [SyncConflict] (explicit [dismissConflict] required first).
  /// Otherwise: serving from cache with no pending writes → [SyncOffline];
  /// pending writes → [SyncPending]; everything acknowledged → [SyncSynced].
  void reportSnapshotMeta({
    required bool isFromCache,
    required bool hasPendingWrites,
  }) {
    if (state is SyncConflict) return;
    if (isFromCache && !hasPendingWrites) {
      emit(const SyncOffline());
    } else if (hasPendingWrites) {
      emit(const SyncPending());
    } else {
      emit(const SyncSynced());
    }
  }

  /// Reports a last-write-wins conflict affecting [affectedObjectIds].
  ///
  /// If already in [SyncConflict], the new ids are unioned with the existing set
  /// so no affected object is dropped from the warning.
  void reportConflict(Set<String> affectedObjectIds) {
    final current = state;
    final ids = current is SyncConflict
        ? {...current.affectedObjectIds, ...affectedObjectIds}
        : {...affectedObjectIds};
    emit(SyncConflict(affectedObjectIds: ids));
  }

  /// Dismisses the conflict warning. Only acts when in [SyncConflict]; resolves
  /// to [SyncPending] so subsequent snapshot metadata can settle the status.
  void dismissConflict() {
    if (state is! SyncConflict) return;
    emit(const SyncPending());
  }

  /// Reports a synchronization error.
  void reportError(String message, {Object? cause}) {
    emit(SyncError(message: message, cause: cause));
  }
}
