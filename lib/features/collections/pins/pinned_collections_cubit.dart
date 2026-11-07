import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../api/data/data_repository.dart';
import '../../../core/domain/domain.dart';

/// The ids of the collections pinned to the sidebar, in display order.
///
/// Writes are optimistic: the new order is emitted at once and the
/// repository's stream (the source of truth) confirms it.
class PinnedCollectionsCubit extends Cubit<List<String>> {
  PinnedCollectionsCubit(this._repository) : super(const []);

  final DataRepository _repository;
  StreamSubscription<List<String>>? _subscription;

  /// Follows the stored pins. Idempotent.
  void initialize() {
    _subscription?.cancel();
    _subscription = _repository.watchPinnedCollectionIds().listen(
      (ids) {
        if (!isClosed) emit(List.unmodifiable(ids));
      },
      // Pins are a convenience: on failure the sidebar just shows none.
      onError: (Object _) {},
    );
  }

  bool isPinned(String id) => state.contains(id);

  /// Pins [id] at the end, or unpins it.
  Future<void> toggle(String id) =>
      _save(isPinned(id) ? [...state.where((p) => p != id)] : [...state, id]);

  Future<void> unpin(String id) => _save([...state.where((p) => p != id)]);

  /// Moves the pin at [oldIndex] of [visible] (the pins that still exist, as
  /// shown) to [newIndex], counted in the list without it. Pins of deleted
  /// collections are dropped on the way.
  Future<void> reorder(List<String> visible, int oldIndex, int newIndex) {
    final ids = [...visible];
    final moved = ids.removeAt(oldIndex);
    ids.insert(newIndex, moved);
    return _save(ids);
  }

  Future<void> _save(List<String> ids) {
    emit(List.unmodifiable(ids));
    return _repository.savePinnedCollectionIds(ids);
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}

/// The pinned collections among [collections], in pin order; pins whose
/// collection is gone are skipped.
List<Collection> pinnedCollections(
  List<String> pins,
  List<Collection> collections,
) {
  final byId = {for (final c in collections) c.id: c};
  return [for (final id in pins) ?byId[id]];
}
