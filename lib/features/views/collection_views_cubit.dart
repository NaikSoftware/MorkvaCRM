import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../api/data/data_repository.dart';
import '../../core/domain/domain.dart';
import '../../core/harness/input/ref_resolver.dart';
import '../collections/util/id_generator.dart';
import 'collection_views_state.dart';
import 'view_link.dart';
import 'widgets/view_labels.dart';

/// Reverts one object write (or a manual-order change). Completes when the
/// revert has been written.
typedef ViewUndo = Future<void> Function();

/// Drives a collection's Work surface: its saved views and their objects.
///
/// Watches the collection (via [DataRepository.watchCollections]) and its
/// objects, plus, once needed, the objects of each collection a shown or
/// laid-out reference field points at (for labels and board columns). An
/// objects stream decodes with the schema it was opened with, so it is
/// re-opened whenever that collection's fields change (e.g. in Build, which
/// keeps this cubit alive).
///
/// View commands persist only the views (`saveViews`), so they never write
/// back a stale schema; object commands save objects with `saveObject`. Both
/// apply optimistically: view changes sit over the streamed collection and
/// object changes in an overlay until the stream confirms them, and a failed
/// write drops the change again and reports [ViewsReady.writeError].
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

  /// The fields [_objectsSub] decodes with.
  List<FieldDefinition>? _objectsSchema;
  final Map<String, StreamSubscription<List<MorkvaObject>>> _targetSubs = {};

  /// The fields each of [_targetSubs] decodes with.
  final Map<String, List<FieldDefinition>> _targetSchemas = {};
  final Map<String, List<MorkvaObject>> _targetObjects = {};
  final Set<String> _failedTargets = {};

  /// Reference fields whose choices a filter builder asked for.
  final Set<String> _choiceFields = {};

  List<Collection> _collections = const [];
  Collection? _streamCollection;

  /// Views saved locally but not yet acknowledged; shown over the stream's.
  List<ViewDefinition>? _localViews;
  List<MorkvaObject>? _streamObjects;
  final Map<String, _Pending> _pending = {};
  String? _activeViewId;
  String? _writeError;
  int _writeErrorSeq = 0;
  bool _notFound = false;

  /// A stream failed: stay on [ViewsError] until [retry].
  bool _streamFailed = false;

  /// Filters a deep link put over view [_transientViewId]; dropped once
  /// another view is shown.
  List<ViewFilter> _transient = const [];
  String? _transientViewId;

  /// A deep link waiting for the collection (and, for a filter, the cards
  /// its reference fields may name) to load.
  ({String? viewId, String? filter})? _pendingLink;

  /// Starts watching. Call once after creating the cubit.
  void initialize() {
    _collectionsSub = _repository.watchCollections().listen(
      _onCollections,
      onError: _onStreamError,
    );
  }

  /// Re-subscribes after a [ViewsError].
  Future<void> retry() async {
    // Not awaited: a cancel may complete late, and the old streams are
    // already silent.
    unawaited(_cancelAll());
    _streamCollection = null;
    _localViews = null;
    _streamObjects = null;
    _targetObjects.clear();
    _pending.clear();
    _notFound = false;
    _streamFailed = false;
    _writeError = null;
    emit(const ViewsLoading());
    initialize();
  }

  // ---------------------------------------------------------------------------
  // Streams
  // ---------------------------------------------------------------------------

  void _onCollections(List<Collection> collections) {
    if (isClosed) return;
    collections = resolveLookups(collections);
    _collections = collections;
    final collection = collections.where((c) => c.id == collectionId);
    if (collection.isEmpty) {
      _notFound = true;
      emit(const ViewsNotFound());
      return;
    }
    _notFound = false;
    final streamed = _withViews(collection.first);
    _streamCollection = streamed;
    // Firestore echoes a local write in the stream at once, offline too,
    // while the write's future completes only on server ack: clear the
    // overlay on the echo, or it would mask later changes (Build) forever.
    final local = _localViews;
    if (local != null && _sameViews(streamed.views, local)) _localViews = null;
    if (_choiceFields.isNotEmpty) {
      _choiceFields.removeWhere(
        (id) => collection.first.fieldById(id) is! ReferenceFieldDefinition,
      );
    }
    _watchObjects(collection.first);
    _dropStaleTargets();
    _emitReady();
  }

  /// What decoding a stored value depends on: renames and option edits
  /// don't, so they don't re-open a stream.
  static Object _decodeKey(FieldDefinition f) =>
      (f.id, f.type, f is DateFieldDefinition ? f.includeTime : null);

  static bool _sameFields(List<FieldDefinition>? a, List<FieldDefinition> b) =>
      a != null &&
      a.length == b.length &&
      [
        for (var i = 0; i < a.length; i++) _decodeKey(a[i]) == _decodeKey(b[i]),
      ].every((s) => s);

  /// (Re-)opens the objects stream when [collection]'s fields changed. The
  /// old objects stay shown until the new stream's first emission.
  void _watchObjects(Collection collection) {
    if (_objectsSub != null && _sameFields(_objectsSchema, collection.fields)) {
      return;
    }
    unawaited(_objectsSub?.cancel());
    _objectsSchema = collection.fields;
    _objectsSub = _repository
        .watchObjects(collectionId, schema: collection)
        .listen(_onObjects, onError: _onStreamError);
  }

  /// Closes target streams whose collection's fields changed (or that is
  /// gone); [_emitReady] re-opens the ones still needed, keeping their last
  /// objects meanwhile.
  void _dropStaleTargets() {
    for (final id in [..._targetSubs.keys]) {
      final target = _collections.where((c) => c.id == id).firstOrNull;
      if (target != null && _sameFields(_targetSchemas[id], target.fields)) {
        continue;
      }
      unawaited(_targetSubs.remove(id)?.cancel());
      _targetSchemas.remove(id);
    }
  }

  void _onObjects(List<MorkvaObject> objects) {
    if (isClosed) return;
    _streamObjects = objects;
    _pending.removeWhere((_, p) => p.settled);
    _emitReady();
  }

  void _onStreamError(Object error) {
    if (isClosed) return;
    _streamFailed = true;
    emit(ViewsError('$error'));
  }

  /// The reference fields of [collection] that [view] shows, lays out by or
  /// filters on.
  static Iterable<ReferenceFieldDefinition> _viewReferences(
    Collection collection,
    ViewDefinition view,
  ) {
    final ids = {
      view.layoutFieldId,
      ...view.fieldIds,
      for (final f in view.filters) f.fieldId,
    };
    return collection.fields.whereType<ReferenceFieldDefinition>().where(
      (f) => ids.contains(f.id),
    );
  }

  /// Watches the target collections of the active view's reference fields,
  /// once each.
  void _watchTargets(Collection collection, ViewDefinition view) {
    _viewReferences(collection, view).forEach(_watchTarget);
    _choiceReferences(collection).forEach(_watchTarget);
    Derivation.sourcesOf(
      collectionId,
      _workspace(collection),
    ).forEach(_watchCollection);
  }

  /// The workspace's collections with [collection] as this cubit sees it.
  List<Collection> _workspace(Collection collection) => [
    collection,
    for (final c in _collections)
      if (c.id != collectionId) c,
  ];

  Iterable<ReferenceFieldDefinition> _choiceReferences(Collection collection) =>
      collection.fields.whereType<ReferenceFieldDefinition>().where(
        (f) => _choiceFields.contains(f.id),
      );

  void _watchTarget(ReferenceFieldDefinition field) =>
      _watchCollection(field.targetCollectionId);

  /// Watches the objects of another collection [targetId], once.
  void _watchCollection(String targetId) {
    if (isClosed) return;
    if (targetId == collectionId || _targetSubs.containsKey(targetId)) return;
    final target = _collections.where((c) => c.id == targetId).firstOrNull;
    if (target == null) return;
    _targetSchemas[targetId] = target.fields;
    // A re-opened stream may fail again; report that again too.
    _failedTargets.remove(targetId);
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
            _reportWriteError("Couldn't load ${target.name}");
          },
        );
  }

  /// Starts loading what reference field [fieldId] can point at; the
  /// states that follow carry it in [ViewsReady.referenceChoices].
  void loadReferenceChoices(String fieldId) {
    if (isClosed) return;
    final field = _collection?.fieldById(fieldId);
    if (field is! ReferenceFieldDefinition || !_choiceFields.add(fieldId)) {
      return;
    }
    _watchTarget(field);
    _emitReady();
  }

  // ---------------------------------------------------------------------------
  // Deep links
  // ---------------------------------------------------------------------------

  /// Applies a deep link's `view` and `filter` parameters (see
  /// `collectionLink`) once the collection has loaded: selects [viewId] when
  /// the collection has it, then puts the decoded [filter] over the view as
  /// transient filters. Without a filter the transient ones stay, unless the
  /// view changes. An invalid filter is dropped and reported through
  /// [ViewsReady.writeError].
  void openLink({String? viewId, String? filter}) {
    if (isClosed || (viewId == null && filter == null)) return;
    _pendingLink = (viewId: viewId, filter: filter);
    _emitReady();
  }

  /// An [openLink] is still waiting to be applied.
  bool get linkPending => _pendingLink != null;

  /// Puts [filters] over the active view, unsaved, until [clearTransientFilters]
  /// or another view is shown. Callers validate them (see `parseLinkFilter`).
  void setTransientFilters(List<ViewFilter> filters) {
    _transient = List.unmodifiable(filters);
    _transientViewId = _activeView?.id;
    _emitReady();
  }

  void clearTransientFilters() => setTransientFilters(const []);

  /// Saves the active view with its transient filters as a new view right
  /// after it, selects it and returns its id.
  Future<String?> saveTransientAsView() async {
    final collection = _collection;
    final view = _activeView;
    final transient = _transient;
    if (collection == null || view == null || transient.isEmpty) return null;
    final copy = view.copyWith(
      id: _ids.viewId(),
      name: '${view.name} · filtered',
      filters: List.unmodifiable([...view.filters, ...transient]),
    );
    final index = collection.views.indexOf(view);
    _activeViewId = copy.id;
    if (await _saveViews([...collection.views]..insert(index + 1, copy))) {
      return copy.id;
    }
    _activeViewId = view.id;
    _transient = transient;
    _transientViewId = view.id;
    _emitReady();
    return null;
  }

  /// Applies [_pendingLink] once it can be: a filter waits for the cards of
  /// every reference field's target, which its values may name.
  void _resolveLink(Collection collection) {
    final link = _pendingLink;
    if (link == null) return;
    if (link.viewId case final id?
        when collection.views.any((v) => v.id == id)) {
      _activeViewId = id;
    }
    final filter = link.filter;
    // The view is selected once; the user may switch while the filter waits.
    _pendingLink = filter == null ? null : (viewId: null, filter: filter);
    if (filter == null) return;
    final targets = {
      for (final f in collection.fields.whereType<ReferenceFieldDefinition>())
        f.targetCollectionId,
    }..remove(collectionId);
    targets.forEach(_watchCollection);
    if (targets.any(
      (t) =>
          _targetSubs.containsKey(t) &&
          !_targetObjects.containsKey(t) &&
          !_failedTargets.contains(t),
    )) {
      return;
    }
    _pendingLink = null;
    final filters = parseLinkFilter(
      filter,
      collection: collection,
      workspace: StaticWorkspace(_workspace(collection), {
        ..._targetObjects,
        collectionId: _allObjects,
      }),
      today: _now(),
    );
    if (filters == null) {
      _transient = const [];
      _writeError = "This link's filter isn't valid";
      _writeErrorSeq++;
      return;
    }
    _transient = List.unmodifiable(filters);
    _transientViewId =
        collection.views.where((v) => v.id == _activeViewId).firstOrNull?.id ??
        collection.views.first.id;
  }

  static Collection _withViews(Collection c) => c.views.isNotEmpty
      ? c
      : c.copyWith(views: [ViewDefinition.defaultFor(c.fields)]);

  Collection? get _collection {
    final views = _localViews;
    return views == null
        ? _streamCollection
        : _streamCollection?.copyWith(views: views);
  }

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
  /// Null while they load; empty when the target is gone or failed.
  Map<String, String>? _labelsFor(String targetId, Collection self) {
    final target = targetId == collectionId
        ? self
        : _collections.where((c) => c.id == targetId).firstOrNull;
    final objects = targetId == collectionId
        ? _allObjects
        : _targetObjects[targetId];
    if (target == null) return const {};
    if (objects == null) {
      return _failedTargets.contains(targetId) ? const {} : null;
    }
    return objectLabels(target, objects);
  }

  void _emitReady() {
    final collection = _collection;
    if (collection == null ||
        _streamObjects == null ||
        _notFound ||
        _streamFailed ||
        isClosed) {
      return;
    }
    _resolveLink(collection);
    final view =
        collection.views.where((v) => v.id == _activeViewId).firstOrNull ??
        collection.views.first;
    _activeViewId = view.id;
    if (_transientViewId != view.id) _transient = const [];
    final effective = _transient.isEmpty
        ? view
        : view.copyWith(filters: [...view.filters, ..._transient]);
    _watchTargets(collection, effective);

    final all = _derive(collection, _allObjects);
    final applied = applyView(collection, effective, all);
    final labelsByTarget = {
      for (final f in _viewReferences(collection, effective))
        f.targetCollectionId:
            _labelsFor(f.targetCollectionId, collection) ?? const {},
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
          final f? when isGroupable(f) => groupObjects(
            f,
            applied,
            referenceLabels: f is ReferenceFieldDefinition
                ? labelsByTarget[f.targetCollectionId] ?? const {}
                : const {},
          ),
          _ => null,
        },
        days: layout is DateFieldDefinition
            ? bucketByDay(layout, applied)
            : null,
        referenceLabels: {
          for (final labels in labelsByTarget.values) ...labels,
        },
        referenceChoices: {
          for (final f in _choiceReferences(collection))
            f.id: ?_labelsFor(f.targetCollectionId, collection),
        },
        calculationNotes: calculationNotes(),
        transientFilters: _transient,
        writeError: _writeError,
        writeErrorSeq: _writeErrorSeq,
      ),
    );
  }

  /// [objects] with their calculated values; others' objects as loaded.
  List<MorkvaObject> _derive(
    Collection collection,
    List<MorkvaObject> objects,
  ) {
    if (!collection.fields.any((f) => f is CalculatedFieldDefinition)) {
      return objects;
    }
    final inputs = <Object>[
      collection.fields,
      _collections,
      ..._targetObjects.values,
      ...objects,
    ];
    final cached = _derived;
    if (cached != null && _sameInstances(cached.inputs, inputs)) {
      return cached.result;
    }
    final result = Derivation(
      collections: _workspace(collection),
      objects: {..._targetObjects, collectionId: objects},
    ).objectsOf(collectionId);
    _derived = (inputs: inputs, result: result);
    return result;
  }

  // shortcut: TODAY() is evaluated when inputs change, so a page left open
  // past midnight keeps yesterday until the next data change.

  /// The last derivation and what it was computed from: emits that change
  /// nothing it reads (a view setting, a write error) reuse it.
  ({List<Object> inputs, List<MorkvaObject> result})? _derived;

  static bool _sameInstances(List<Object> a, List<Object> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!identical(a[i], b[i])) return false;
    }
    return true;
  }

  /// The calculated values of [draft] (an edited or new object of this
  /// collection) against the loaded data, for the object form's live preview.
  // shortcut: rebuilds a whole Derivation per call (O(all loaded objects), per
  // keystroke in the form); derive only the draft's dependents if a large
  // workspace makes typing lag.
  Map<String, FieldValue> deriveFor(MorkvaObject draft) {
    final collection = _collection;
    if (collection == null) return const {};
    final others = _allObjects.where((o) => o.id != draft.id);
    final derived = _derive(collection, [...others, draft]);
    final object = derived.lastWhere((o) => o.id == draft.id);
    return {
      for (final f in collection.fields.whereType<CalculatedFieldDefinition>())
        f.id: object[f.id] ?? f.emptyValue(),
    };
  }

  /// What each calculated field computes, in one line, by field id.
  Map<String, String> calculationNotes() {
    final collection = _collection;
    if (collection == null) return const {};
    return {
      for (final f in collection.fields.whereType<CalculatedFieldDefinition>())
        f.id: calculationSummary(f, collection, _collections),
    };
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
    final previous = _activeViewId;
    if (_activeViewId == viewId) {
      _activeViewId = views[index == 0 ? 0 : index - 1].id;
    }
    if (await _saveViews(views)) return true;
    _activeViewId = previous;
    _emitReady();
    return false;
  }

  /// Switches the active view's mode and sets its layout field to
  /// [layoutFieldId] in the same write (null clears it).
  Future<void> setMode(String mode, {String? layoutFieldId}) => _updateActive(
    (v) => v.copyWith(mode: mode, layoutFieldId: layoutFieldId),
  );

  Future<void> setFilters(List<ViewFilter> filters) =>
      _updateActive((v) => v.copyWith(filters: List.unmodifiable(filters)));

  /// "Clear filters": drops the transient filters and the view's own.
  Future<void> clearFilters() {
    if (_transient.isNotEmpty) clearTransientFilters();
    return setFilters(const []);
  }

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

  /// Collapses or expands the active view's board group [groupKey]
  /// (null = the `No <field>` group).
  Future<void> toggleGroupCollapsed(String? groupKey) {
    final token = groupKey ?? ViewDefinition.noGroupToken;
    return _updateActive(
      (v) => v.copyWith(
        collapsedGroups: List.unmodifiable(
          v.collapsedGroups.contains(token)
              ? v.collapsedGroups.where((k) => k != token)
              : [...v.collapsedGroups, token],
        ),
      ),
    );
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
    if (_collection == null) return false;
    final saved = List<ViewDefinition>.unmodifiable(views);
    _localViews = saved;
    _emitReady();
    try {
      await _repository.saveViews(collectionId, saved);
    } catch (_) {
      if (identical(_localViews, saved)) _localViews = null;
      if (!isClosed) _reportWriteError("Couldn't save the view");
      return false;
    }
    if (identical(_localViews, saved)) _localViews = null;
    _emitReady();
    return true;
  }

  // ---------------------------------------------------------------------------
  // Object commands
  // ---------------------------------------------------------------------------

  MorkvaObject? _objectById(String id) =>
      _allObjects.where((o) => o.id == id).firstOrNull;

  /// The loaded object [id], even when the filters hide it.
  MorkvaObject? findObject(String id) => _objectById(id);

  /// The group key of [object] under [field], as [groupObjects] sees it.
  static String? _groupKeyOf(FieldDefinition field, MorkvaObject object) =>
      switch (object[field.id]) {
        SingleSelectFieldValue(:final optionId) => optionId,
        ReferenceFieldValue(:final objectIds) => objectIds.firstOrNull,
        _ => null,
      };

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
    if (!isGroupable(field)) return null;
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
        if (valueChanged)
          _revertField(
            objectId,
            field.id,
            object[field.id] ?? field.emptyValue(),
          ),
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
      await _revertField(objectId, field.id, currentDate);
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
      groupField: isGroupable(layout) ? layout : null,
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
        if (groupKey != null && isGroupable(layout))
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
      await _writeObject(object, origin: _undo);
    };
  }

  static const _undo = WriteOrigin(kind: WriteKind.undo);

  /// Puts [fieldId] of [objectId] back to [value] (an undo), writing only that
  /// key so other fields changed meanwhile keep their stored values.
  Future<void> _revertField(String objectId, String fieldId, FieldValue value) {
    final current = _objectById(objectId);
    if (current == null) return Future.value();
    final now = _now();
    return _writeObject(
      current.copyWith(
        values: {...current.values, fieldId: value},
        updatedAt: now,
      ),
      saved: current.copyWith(values: {fieldId: value}, updatedAt: now),
      origin: _undo,
    );
  }

  /// Shows [object] at once and saves [saved] (default: [object]).
  Future<void> _writeObject(
    MorkvaObject object, {
    MorkvaObject? saved,
    WriteOrigin origin = const WriteOrigin.ui(),
  }) async {
    final collection = _collection;
    if (collection == null || isClosed) return;
    // Saved as given: values of fields this object was decoded without stay
    // untouched in storage (the repository merges values).
    final pending = _Pending(object);
    _pending[object.id] = pending;
    _emitReady();
    try {
      await _repository.saveObject(
        saved ?? object,
        schema: collection,
        origin: origin,
      );
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
      await _repository.deleteObject(collectionId, object.id, before: object);
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

  /// Cancels every stream at once, so no event arrives after this returns;
  /// the future completes when the cancels have.
  Future<void> _cancelAll() {
    final subs = [?_collectionsSub, ?_objectsSub, ..._targetSubs.values];
    _collectionsSub = null;
    _objectsSub = null;
    _objectsSchema = null;
    _targetSubs.clear();
    _targetSchemas.clear();
    _failedTargets.clear();
    return Future.wait([for (final sub in subs) sub.cancel()]);
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
