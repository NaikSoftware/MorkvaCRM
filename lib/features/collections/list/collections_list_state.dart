import 'package:equatable/equatable.dart';

import '../../../core/domain/domain.dart';

/// State of the collections surface (Home).
///
/// Sealed so the UI can switch exhaustively. Equality is by value so the cubit
/// only emits on real changes (the watch stream may re-emit equal lists).
sealed class CollectionsListState extends Equatable {
  const CollectionsListState();

  @override
  List<Object?> get props => const [];
}

/// Before the first snapshot of the collections stream has arrived.
final class CollectionsListLoading extends CollectionsListState {
  const CollectionsListLoading();
}

/// The workspace's collections, possibly empty.
final class CollectionsListReady extends CollectionsListState {
  const CollectionsListReady(this.collections);

  /// All collections in the workspace, in stream order.
  final List<Collection> collections;

  /// Whether the workspace has no collections yet (drives the empty state).
  bool get isEmpty => collections.isEmpty;

  @override
  List<Object?> get props => [collections];
}

/// The collections stream failed; carries a user-facing [message].
final class CollectionsListError extends CollectionsListState {
  const CollectionsListError({required this.message});

  /// Human-readable description of the failure.
  final String message;

  @override
  List<Object?> get props => [message];
}
