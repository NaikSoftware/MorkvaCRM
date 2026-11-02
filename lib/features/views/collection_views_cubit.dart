import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../api/data/data_repository.dart';
import '../../core/domain/domain.dart';
import '../collections/util/id_generator.dart';
import 'collection_views_state.dart';

/// Reverts one object write (or a manual-order change). Completes when the
/// revert has been written.
typedef ViewUndo = Future<void> Function();

/// Drives a collection's Work surface: its saved views and their objects.
///
/// Watches the collection (via [DataRepository.watchCollections]) and its
/// objects, plus, once needed, the objects of each collection a shown or
/// laid-out reference field points at (for labels and board columns). Every
/// stream is subscribed once per cubit lifetime: the repository only releases
/// subscriptions on dispose.
///
/// View commands persist the collection with `saveCollection`; object
/// commands save objects with `saveObject`. Both apply optimistically: object
/// changes sit in an overlay until the objects stream confirms them, and a
/// failed write drops the change again and reports [ViewsReady.writeError].
class CollectionViewsCubit extends Cubit<CollectionViewsState> {
  CollectionViewsCubit(
    this._repository,
    this.collectionId, {
    IdGenerator? idGenerator,
    DateTime Function()? clock,
  }) : _ids = idGenerator ?? IdGenerator(),
       _now = clock ?? DateTime.now,
       super(const ViewsLoading());

  final DataRepository _repository;
  final String collectionId;
  final IdGenerator _ids;
  final DateTime Function() _now;

  StreamSubscription<List<Collection>>? _collectionsSub;
  StreamSubscription<List<MorkvaObject>>? _objectsSub;
  final Map<String, StreamSubscription<List<MorkvaObject>>> _targetSubs = {};
  final Map<String, List<MorkvaObject>> _targetObjects = {};
  final Set<String> _failedTargets = {};

  List<Collection> _collections = const [];
  Collection? _streamCollection;
  Collection? _localCollection;
  List<MorkvaObject>? _streamObjects;
  final Map<String, _Pending> _pending = {};
  String? _activeViewId;
  String? _writeError;
  int _writeErrorSeq = 0;
  bool _notFound = false;

  /// Starts watching. Call once after creating the cubit.
  void initialize() {
    _collectionsSub = _repository.watchCollections().listen(
      _onCollections,
      onError: _onStreamError,
    );
  }

  /// Re-subscribes after a [ViewsError].
  Future<void> retry() async {
    await _cancelAll();
    _streamCollection = null;
    _localCollection = null;
    _streamObjects = null;
    _targetObjects.clear();
    _pending.clear();
    _notFound = false;
    _writeError = null;
    emit(const ViewsLoading());
    initialize();
  }

  // ---------------------------------------------------------------------------
  // Streams
  // ---------------------------------------------------------------------------

  void _onCollections(List<Collection> collections) {
    if (isClosed) return;
    _collections = collections;
    final collection = collections.where((c) => c.id == collectionId);
    if (collection.isEmpty) {
      _notFound = true;
      emit(const ViewsNotFound());
      return;
    }
    _notFound = false;
    _streamCollection = _withViews(collection.first);
    _objectsSub ??= _repository
        .watchObjects(collectionId, schema: collection.first)
        .listen(_onObjects, onError: _onStreamError);
    _emitReady();
  }

  void _onObjects(List<MorkvaObject> objects) {
    if (isClosed) return;
    _streamObjects = objects;
    _pending.removeWhere((_, p) => p.settled);
    _emitReady();
  }

  void _onStreamError(Object error) {
    if (!isClosed) emit(ViewsError('$error'));
  }

  /// Watches the target collections of the active view's reference fields,
  /// once each.
  void _watchTargets(Collection collection, ViewDefinition view) {
    final ids = {view.layoutFieldId, ...view.fieldIds};
    for (final field in collection.fields) {
      if (field is! ReferenceFieldDefinition || !ids.contains(field.id)) {
        continue;
      }
      final targetId = field.targetCollectionId;
      if (targetId == collectionId || _targetSubs.containsKey(targetId)) {
        continue;
      }
      final target = _collections.where((c) => c.id == targetId).firstOrNull;
      if (target == null) continue;
      _targetSubs[targetId] = _repository
          .watchObjects(targetId, schema: target)
          .listen(
            (objects) {
              if (isClosed) return;
              _targetObjects[targetId] = objects;
              _emitReady();
            },
            onError: (Object _) {
              if (isClosed || !_failedTargets.add(targetId)) return;
              _reportWriteError("Couldn't load ${target.name} names");
            },
          );
    }
  }

  static Collection _withViews(Collection c) => c.views.isNotEmpty
      ? c
      : c.copyWith(views: [ViewDefinition.defaultFor(c.fields)]);

  Collection? get _collection => _localCollection ?? _streamCollection;

  /// Stream objects with the pending overlay applied.
  List<MorkvaObject> get _allObjects {
    final objects = [...?_streamObjects];
    for (final MapEntry(key: id, value: pending) in _pending.entries) {
      final index = objects.indexWhere((o) => o.id == id);
      final object = pending.object;
      if (object == null) {
        if (index >= 0) objects.removeAt(index);
      } else if (index >= 0) {
        objects[index] = object;
      } else {
        objects.add(object);
      }
    }
    return objects;
  }

  /// Labels of [targetId]'s objects in the target's own default order (its
  /// first view's order, unfiltered): the first text field, or 'Untitled'.
  Map<String, String> _labelsFor(String targetId, Collection self) {
    final target = targetId == collectionId
        ? self
        : _collections.where((c) => c.id == targetId).firstOrNull;
    final objects = targetId == collectionId
        ? _allObjects
        : _targetObjects[targetId];
    if (target == null || objects == null) return const {};
    final view =
        (target.views.firstOrNull ?? ViewDefinition.defaultFor(target.fields))
            .copyWith(filters: const []);
    final titleField = target.fields
        .whereType<TextFieldDefinition>()
        .firstOrNull;
    return {
      for (final o in applyView(target, view, objects))
        o.id: switch (o[titleField?.id ?? '']) {
          TextFieldValue(:final text?) when text.trim().isNotEmpty => text,
          _ => 'Untitled',
        },
    };
  }

  void _emitReady() {
    final collection = _collection;
    if (collection == null || _streamObjects == null || _notFound || isClosed) {
      return;
    }
    final view =
        collection.views.where((v) => v.id == _activeViewId).firstOrNull ??
        collection.views.first;
    _activeViewId = view.id;
    _watchTargets(collection, view);

    final all = _allObjects;
    final applied = applyView(collection, view, all);
    final shownIds = {view.layoutFieldId, ...view.fieldIds};
    final labelsByTarget = {
      for (final f in collection.fields)
        if (f is ReferenceFieldDefinition && shownIds.contains(f.id))
          f.targetCollectionId: _labelsFor(f.targetCollectionId, collection),
    };
    final layout = view.layoutFieldId == null
        ? null
        : collection.fieldById(view.layoutFieldId!);

    emit(
      ViewsReady(
        collection: collection,
        activeViewId: view.id,
        objects: applied,
        totalCount: all.length,
        groups: switch (layout) {
          SingleSelectFieldDefinition() => groupObjects(layout, applied),
          ReferenceFieldDefinition(multiple: false) => groupObjects(
            layout,
            applied,
            referenceLabels:
                labelsByTarget[layout.targetCollectionId] ?? const {},
          ),
          _ => null,
        },
        days: layout is DateFieldDefinition
            ? bucketByDay(layout, applied)
            : null,
        referenceLabels: {
          for (final labels in labelsByTarget.values) ...labels,
        },
        writeError: _writeError,
        writeErrorSeq: _writeErrorSeq,
      ),
    );
  }

  void _reportWriteError(String message) {
    _writeError = message;
    _writeErrorSeq++;
    _emitReady();
  }

  // ---------------------------------------------------------------------------
  // View commands
  // ---------------------------------------------------------------------------

  ViewDefinition? get _activeView {
    final collection = _collection;
    if (collection == null) return null;
    return collection.views.where((v) => v.id == _activeViewId).firstOrNull ??
        collection.views.first;
  }

  /// Shows the view [viewId] (local only; not persisted).
  void selectView(String viewId) {
    final collection = _collection;
    if (collection == null || !collection.views.any((v) => v.id == viewId)) {
      return;
    }
    _activeViewId = viewId;
    _emitReady();
  }

  /// Adds a view after the others, selects it and returns its id. It shows
  /// the default fields (see [ViewDefinition.defaultFor]).
  Future<String?> createView(
    String name, {
    String mode = ViewModeIds.table,
    String? layoutFieldId,
  }) async {
    final collection = _collection;
    if (collection == null) return null;
    final view = ViewDefinition(
      id: _ids.viewId(),
      name: name.trim().isEmpty ? 'Untitled view' : name.trim(),
      mode: mode,
      layoutFieldId: layoutFieldId,
      fieldIds: ViewDefinition.defaultFor(collection.fields).fieldIds,
    );
    final previous = _activeViewId;
    _activeViewId = view.id;
    if (await _saveViews([...collection.views, view])) return view.id;
    _activeViewId = previous;
    _emitReady();
    return null;
  }

  /// Renames [viewId]; a blank name is ignored.
  Future<void> renameView(String viewId, String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return Future.value();
    return _updateView(viewId, (v) => v.copyWith(name: trimmed));
  }

  /// Copies [viewId] right after itself as `<name> copy`, selects the copy
  /// and returns its id.
  Future<String?> duplicateView(String viewId) async {
    final collection = _collection;
    final index = collection?.views.indexWhere((v) => v.id == viewId) ?? -1;
    if (collection == null || index < 0) return null;
    final source = collection.views[index];
    final copy = source.copyWith(
      id: _ids.viewId(),
      name: '${source.name} copy',
    );
    final previous = _activeViewId;
    _activeViewId = copy.id;
    if (await _saveViews([...collection.views]..insert(index + 1, copy))) {
      return copy.id;
    }
    _activeViewId = previous;
    _emitReady();
    return null;
  }

  /// Deletes [viewId] unless it is the last view; returns whether it did.
  /// Deleting the active view selects its left neighbour.
  Future<bool> deleteView(String viewId) async {
    final collection = _collection;
    if (collection == null || collection.views.length <= 1) return false;
    final index = collection.views.indexWhere((v) => v.id == viewId);
    if (index < 0) return false;
    final views = [...collection.views]..removeAt(index);
    if (_activeViewId == viewId) {
      _activeViewId = views[index == 0 ? 0 : index - 1].id;
    }
    await _saveViews(views);
    return true;
  }

  /// Switches the active view's mode; [layoutFieldId], when given, becomes
  /// its layout field too.
  Future<void> setMode(String mode, {String? layoutFieldId}) => _updateActive(
    (v) =>
        v.copyWith(mode: mode, layoutFieldId: layoutFieldId ?? v.layoutFieldId),
  );

  Future<void> setFilters(List<ViewFilter> filters) =>
      _updateActive((v) => v.copyWith(filters: List.unmodifiable(filters)));

  /// Sets the active view's sort; null means manual order.
  Future<void> setSort(ViewSort? sort) =>
      _updateActive((v) => v.copyWith(sort: sort));

  /// Sets the fields the active view shows, in order (the first is the title).
  Future<void> setFieldIds(List<String> fieldIds) =>
      _updateActive((v) => v.copyWith(fieldIds: List.unmodifiable(fieldIds)));

  /// Sets (or with null clears) the field the active view lays out by.
  Future<void> setLayoutField(String? fieldId) {
    if (fieldId != null && _collection?.fieldById(fieldId) == null) {
      return Future.value();
    }
    return _updateActive((v) => v.copyWith(layoutFieldId: fieldId));
  }

  Future<void> _updateActive(ViewDefinition Function(ViewDefinition) update) {
    final view = _activeView;
    return view == null ? Future.value() : _updateView(view.id, update);
  }

  Future<void> _updateView(
    String viewId,
    ViewDefinition Function(ViewDefinition) update,
  ) async {
    final collection = _collection;
    if (collection == null) return;
    final views = [
      for (final v in collection.views) v.id == viewId ? update(v) : v,
    ];
    if (_sameViews(views, collection.views)) return;
    await _saveViews(views);
  }

  static bool _sameViews(List<ViewDefinition> a, List<ViewDefinition> b) =>
      a.length == b.length &&
      [for (var i = 0; i < a.length; i++) a[i] == b[i]].every((s) => s);

  /// Saves [views]; returns whether the save succeeded.
  Future<bool> _saveViews(List<ViewDefinition> views) async {
    final collection = _collection;
    if (collection == null) return false;
    final updated = collection.copyWith(views: views);
    _localCollection = updated;
    _emitReady();
    try {
      await _repository.saveCollection(updated);
    } catch (_) {
      if (identical(_localCollection, updated)) _localCollection = null;
      if (!isClosed) _reportWriteError("Couldn't save the view");
      return false;
    }
    if (identical(_localCollection, updated)) _localCollection = null;
    _emitReady();
    return true;
  }

  // ---------------------------------------------------------------------------
  // Object commands
  // ---------------------------------------------------------------------------

  MorkvaObject? _objectById(String id) =>
      _allObjects.where((o) => o.id == id).firstOrNull;

  /// The group key of [object] under [field], as [groupObjects] sees it.
  static String? _groupKeyOf(FieldDefinition field, MorkvaObject object) =>
      switch (object[field.id]) {
        SingleSelectFieldValue(:final optionId) => optionId,
        ReferenceFieldValue(:final objectIds) => objectIds.firstOrNull,
        _ => null,
      };

  static bool _isGroupable(FieldDefinition? f) =>
      f is SingleSelectFieldDefinition ||
      (f is ReferenceFieldDefinition && !f.multiple);

  /// Moves [objectId] to the board group [groupKey] (null = the `No <field>`
  /// group) by writing the active view's layout field. With manual order,
  /// it lands before [beforeId], or at the end of the group. Returns an undo,
  /// or null when nothing changed.
  ViewUndo? moveToGroup(String objectId, String? groupKey, {String? beforeId}) {
    final collection = _collection;
    final view = _activeView;
    final field = view?.layoutFieldId == null
        ? null
        : collection?.fieldById(view!.layoutFieldId!);
    final object = _objectById(objectId);
    if (collection == null || view == null || object == null) return null;
    if (!_isGroupable(field)) return null;
    final value = groupValueFor(field!, groupKey);
    final updated = object.copyWith(
      values: {...object.values, field.id: value},
      updatedAt: _now(),
    );
    final objects = [
      for (final o in _allObjects) o.id == objectId ? updated : o,
    ];
    final order = view.sort == null
        ? _orderWith(
            collection,
            view,
            objects,
            objectId,
            beforeId: beforeId,
            groupField: field,
          )
        : null;
    final valueChanged = object[field.id] != value;
    final orderChanged =
        order != null &&
        !_sameIds(order, _effectiveIds(collection, view, objects));
    if (!valueChanged && !orderChanged) return null;

    final writes = Future.wait([
      if (valueChanged) _writeObject(updated),
      if (orderChanged)
        _updateView(view.id, (v) => v.copyWith(manualOrder: order)),
    ]);
    return () async {
      await writes;
      await Future.wait([
        if (valueChanged) _writeObject(object.copyWith(updatedAt: _now())),
        if (orderChanged)
          _updateView(
            view.id,
            (v) => v.copyWith(manualOrder: view.manualOrder),
          ),
      ]);
    };
  }

  /// Moves [objectId] to calendar [day] (null clears the date) on the active
  /// view's date layout field, keeping the time of day. Returns an undo, or
  /// null when nothing changed.
  ViewUndo? moveToDay(String objectId, DateTime? day) {
    final collection = _collection;
    final view = _activeView;
    final field = view?.layoutFieldId == null
        ? null
        : collection?.fieldById(view!.layoutFieldId!);
    final object = _objectById(objectId);
    if (field is! DateFieldDefinition || object == null) return null;
    final current = object[field.id];
    final currentDate = current is DateFieldValue
        ? current
        : const DateFieldValue(null);
    final value = day == null
        ? const DateFieldValue(null)
        : withDay(field, currentDate, day);
    if (value == currentDate) return null;
    final write = _writeObject(
      object.copyWith(
        values: {...object.values, field.id: value},
        updatedAt: _now(),
      ),
    );
    return () async {
      await write;
      await _writeObject(object.copyWith(updatedAt: _now()));
    };
  }

  /// Puts [objectId] before [beforeId] in the active view's manual order (or
  /// at the end of its group / the list when [beforeId] is null). A sorted
  /// view switches to manual order, starting from what the sort showed.
  /// Returns an undo, or null when nothing changed.
  ViewUndo? reorder(String objectId, {String? beforeId}) {
    final collection = _collection;
    final view = _activeView;
    if (collection == null || view == null || _objectById(objectId) == null) {
      return null;
    }
    final layout = view.layoutFieldId == null
        ? null
        : collection.fieldById(view.layoutFieldId!);
    final order = _orderWith(
      collection,
      view,
      _allObjects,
      objectId,
      beforeId: beforeId,
      groupField: _isGroupable(layout) ? layout : null,
    );
    if (view.sort == null &&
        _sameIds(order, _effectiveIds(collection, view, _allObjects))) {
      return null;
    }
    final write = _updateView(
      view.id,
      (v) => v.copyWith(manualOrder: order, sort: null),
    );
    return () async {
      await write;
      await _updateView(
        view.id,
        (v) => v.copyWith(manualOrder: view.manualOrder, sort: view.sort),
      );
    };
  }

  /// The ids of [objects] in [view]'s order ignoring filters, with [objectId]
  /// moved before [beforeId] — or, without one, after the last object of its
  /// group under [groupField], else to the end.
  static List<String> _orderWith(
    Collection collection,
    ViewDefinition view,
    List<MorkvaObject> objects,
    String objectId, {
    String? beforeId,
    FieldDefinition? groupField,
  }) {
    final ordered = applyView(
      collection,
      view.copyWith(filters: const []),
      objects,
    );
    final moved = ordered.firstWhere((o) => o.id == objectId);
    final rest = ordered.where((o) => o.id != objectId).toList();
    var index = beforeId == null
        ? -1
        : rest.indexWhere((o) => o.id == beforeId);
    if (index < 0) {
      index = rest.length;
      if (groupField != null) {
        final key = _groupKeyOf(groupField, moved);
        final last = rest.lastIndexWhere(
          (o) => _groupKeyOf(groupField, o) == key,
        );
        final from = ordered.indexOf(moved);
        // Already the last of its group: stay put.
        if (last < from) {
          index = from;
        } else {
          index = last + 1;
        }
      }
    }
    rest.insert(index, moved);
    return [for (final o in rest) o.id];
  }

  /// The ids of [objects] in [view]'s current order, ignoring filters.
  static List<String> _effectiveIds(
    Collection collection,
    ViewDefinition view,
    List<MorkvaObject> objects,
  ) => [
    for (final o in applyView(
      collection,
      view.copyWith(filters: const []),
      objects,
    ))
      o.id,
  ];

  static bool _sameIds(List<String> a, List<String> b) =>
      a.length == b.length &&
      [for (var i = 0; i < a.length; i++) a[i] == b[i]].every((s) => s);

  /// Creates an object titled [title], pre-filled with the active view's
  /// layout value ([groupKey] for a board group, [day] for a date). Saved
  /// right away; returns the new id (null without a loaded collection).
  ///
  /// The title goes into the view's title field when it is a text field,
  /// else into the collection's first text field.
  String? quickAdd(String title, {String? groupKey, DateTime? day}) {
    final collection = _collection;
    final view = _activeView;
    if (collection == null || view == null) return null;
    final titleField = quickAddTitleField();
    final layout = view.layoutFieldId == null
        ? null
        : collection.fieldById(view.layoutFieldId!);
    final trimmed = title.trim();
    final now = _now();
    final object = MorkvaObject.create(
      id: _ids.objectId(),
      collection: collection,
      values: {
        if (titleField != null && trimmed.isNotEmpty)
          titleField.id: TextFieldValue(trimmed),
        if (groupKey != null && _isGroupable(layout))
          layout!.id: groupValueFor(layout, groupKey),
        if (day != null && layout is DateFieldDefinition)
          layout.id: withDay(layout, const DateFieldValue(null), day),
      },
      createdAt: now,
      updatedAt: now,
    );
    unawaited(_writeObject(object));
    return object.id;
  }

  /// The field [quickAdd] puts the title into: the active view's title field
  /// when it is a text field, else the collection's first text field.
  TextFieldDefinition? quickAddTitleField() {
    final collection = _collection;
    final view = _activeView;
    if (collection == null || view == null) return null;
    final first = view.fieldIds.isEmpty
        ? null
        : collection.fieldById(view.fieldIds.first);
    return first is TextFieldDefinition
        ? first
        : collection.fields.whereType<TextFieldDefinition>().firstOrNull;
  }

  /// Deletes [objectId]; the undo restores it with the same id.
  ViewUndo? deleteObject(String objectId) {
    final object = _objectById(objectId);
    if (object == null) return null;
    final delete = _deleteObject(object);
    return () async {
      await delete;
      await _writeObject(object);
    };
  }

  Future<void> _writeObject(MorkvaObject object) async {
    final collection = _collection;
    if (collection == null || isClosed) return;
    // Saved as given: values of fields this object was decoded without stay
    // untouched in storage (the repository merges values).
    final pending = _Pending(object);
    _pending[object.id] = pending;
    _emitReady();
    try {
      await _repository.saveObject(object, schema: collection);
      _settle(object.id, pending);
    } catch (_) {
      _fail(object.id, pending, "Couldn't save the change");
    }
  }

  Future<void> _deleteObject(MorkvaObject object) async {
    final pending = _Pending(null);
    _pending[object.id] = pending;
    _emitReady();
    try {
      await _repository.deleteObject(collectionId, object.id);
      _settle(object.id, pending);
    } catch (_) {
      _fail(object.id, pending, "Couldn't delete it");
    }
  }

  /// A confirmed write: drop its overlay now if the stream already shows it,
  /// else at the next objects emission.
  void _settle(String id, _Pending pending) {
    if (isClosed || !identical(_pending[id], pending)) return;
    final streamed = _streamObjects?.where((o) => o.id == id).firstOrNull;
    if (streamed == pending.object) {
      _pending.remove(id);
    } else {
      pending.settled = true;
    }
  }

  void _fail(String id, _Pending pending, String message) {
    if (isClosed) return;
    if (identical(_pending[id], pending)) _pending.remove(id);
    _reportWriteError(message);
  }

  Future<void> _cancelAll() async {
    await _collectionsSub?.cancel();
    await _objectsSub?.cancel();
    for (final sub in _targetSubs.values) {
      await sub.cancel();
    }
    _collectionsSub = null;
    _objectsSub = null;
    _targetSubs.clear();
  }

  @override
  Future<void> close() async {
    await _cancelAll();
    return super.close();
  }
}

/// An optimistic object change: the new object, or null for a deletion.
class _Pending {
  _Pending(this.object);

  final MorkvaObject? object;

  /// The write succeeded; the next objects emission retires this entry.
  bool settled = false;
}
