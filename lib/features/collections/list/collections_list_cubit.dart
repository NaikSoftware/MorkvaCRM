import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../api/data/data_repository.dart';
import '../../../core/domain/domain.dart';
import '../util/id_generator.dart';
import 'collections_list_state.dart';

/// Drives the collections surface (Home) over a [DataRepository].
///
/// Subscribes to [DataRepository.watchCollections] — a replaying stream (Epic 2
/// `BehaviorSubject`) — and folds each snapshot into a [CollectionsListState].
/// Create / rename / delete are thin commands that build the new [Collection]
/// and persist it; the resulting list arrives back through the stream, so the
/// stream stays the single source of truth.
class CollectionsListCubit extends Cubit<CollectionsListState> {
  /// Creates a [CollectionsListCubit] over [repository].
  ///
  /// [idGenerator] is injectable so tests can supply a deterministic generator.
  CollectionsListCubit(this._repository, {IdGenerator? idGenerator})
    : _ids = idGenerator ?? IdGenerator(),
      super(const CollectionsListLoading());

  final DataRepository _repository;
  final IdGenerator _ids;
  StreamSubscription<List<Collection>>? _subscription;

  /// Subscribes to the collections stream and reflects it into state.
  ///
  /// Idempotent: calling more than once does not stack subscriptions.
  void initialize() {
    _subscription?.cancel();
    _subscription = _repository.watchCollections().listen(
      (collections) {
        if (!isClosed) emit(CollectionsListReady(collections));
      },
      onError: (Object error) {
        if (!isClosed) {
          emit(
            CollectionsListError(message: 'Failed to load collections: $error'),
          );
        }
      },
    );
  }

  /// Creates a new collection (one "Name" text field, the default view) and
  /// returns its generated id.
  ///
  /// The caller typically navigates to `/collections/:id` with the returned id.
  /// The new collection appears in the list via the watch stream.
  Future<String> createCollection(
    String name, {
    String? description,
    String? icon,
  }) async {
    final id = _ids.collectionId();
    final trimmedDescription = description?.trim();
    // Every new collection starts with a "Name" text field so its default
    // view has a title column.
    final fields = [TextFieldDefinition(id: _ids.fieldId(), name: 'Name')];
    final collection = Collection(
      id: id,
      name: name.trim(),
      description: (trimmedDescription == null || trimmedDescription.isEmpty)
          ? null
          : trimmedDescription,
      icon: icon,
      fields: fields,
      layout: CardLayout.synthesize([for (final f in fields) f.id]),
      views: [ViewDefinition.defaultFor(fields)],
    );
    await _repository.saveCollection(collection);
    return id;
  }

  /// Adds [template]'s collections and sample objects to the workspace under
  /// fresh ids; returns the id of its first collection.
  ///
  /// Collections are written first, so the objects' references and
  /// auto-numbers (allocated on save) have their schema.
  Future<String> importTemplate(
    WorkspaceTemplate template, {
    DateTime? now,
  }) async {
    final built = template.instantiate(
      _registry,
      collectionId: _ids.collectionId,
      objectId: _ids.objectId,
      now: now ?? DateTime.now(),
    );
    final byId = {for (final c in built.collections) c.id: c};
    for (final c in built.collections) {
      await _repository.saveCollection(c);
    }
    await Future.wait([
      for (final o in built.objects)
        _repository.saveObject(
          o,
          schema: byId[o.collectionId]!,
          origin: const WriteOrigin(kind: WriteKind.template),
        ),
    ]);
    return built.collections.first.id;
  }

  static final _registry = defaultFieldTypeRegistry();

  /// Renames the collection [id], optionally updating its description.
  ///
  /// Preserves the existing field schema, layout and views. A no-op (other
  /// than surfacing) if the collection is not currently known to the list.
  Future<void> renameCollection(
    String id,
    String name, {
    String? description,
    String? icon,
  }) async {
    final existing = _findById(id);
    if (existing == null) return;
    final trimmedDescription = description?.trim();
    // copyWith keeps layout and views; its sentinels let description / icon
    // be cleared to null.
    final updated = existing.copyWith(
      name: name.trim(),
      description: (trimmedDescription == null || trimmedDescription.isEmpty)
          ? null
          : trimmedDescription,
      icon: icon,
    );
    await _repository.saveCollection(updated);
  }

  /// Deletes the collection identified by [id].
  Future<void> deleteCollection(String id) => _repository.deleteCollection(id);

  Collection? _findById(String id) {
    final current = state;
    if (current is! CollectionsListReady) return null;
    for (final collection in current.collections) {
      if (collection.id == id) return collection;
    }
    return null;
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
