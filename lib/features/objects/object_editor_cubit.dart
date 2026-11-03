import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../api/data/data_repository.dart';
import '../../core/domain/domain.dart';
import '../collections/util/id_generator.dart';
import 'object_editor_state.dart';
import 'value_editors/built_in_value_editors.dart';
import 'value_editors/field_value_editor.dart';

export 'object_editor_state.dart';

/// Drives the object form: a draft of changed values over the live stored
/// object, validation, save and delete.
///
/// Edit mode ([object] given) saves only the changed keys — the repository
/// merges them, so concurrent edits of other fields survive. Create mode
/// writes the whole normalized object (with [prefill]). The stored object is
/// watched: untouched fields follow remote changes, dirty fields changed
/// elsewhere are flagged in [ObjectEditorState.conflictFieldIds], and a
/// remote delete makes Save write the object back whole.
class ObjectEditorCubit extends Cubit<ObjectEditorState> {
  ObjectEditorCubit(
    this._repository,
    Collection collection, {
    MorkvaObject? object,
    Map<String, FieldValue> prefill = const {},
    String? titleFieldId,
    FieldValueEditorRegistry? editors,
    IdGenerator? idGenerator,
    DateTime Function()? clock,
  }) : editors = editors ?? _defaultEditors,
       _ids = idGenerator ?? IdGenerator(),
       _now = clock ?? DateTime.now,
       super(
         ObjectEditorState(
           collection: collection,
           readOnlyFieldIds: {
             for (final f in collection.fields)
               if ((editors ?? _defaultEditors).editorFor(f.type).isReadOnly)
                 f.id,
           },
           titleFieldId:
               titleFieldId ??
               collection.fields
                   .whereType<TextFieldDefinition>()
                   .firstOrNull
                   ?.id,
           stored: object,
           prefill: prefill,
         ),
       );

  static final _defaultEditors = defaultValueEditorRegistry();

  final DataRepository _repository;

  /// The value editors the form renders with (also decides read-only fields).
  final FieldValueEditorRegistry editors;
  final IdGenerator _ids;
  final DateTime Function() _now;

  final List<StreamSubscription<List<MorkvaObject>>> _subs = [];
  final Map<String, List<MorkvaObject>> _targetObjects = {};
  List<Collection> _targets = const [];

  /// Create mode's id, minted once so a retried save writes the same object.
  late final String _newId = _ids.objectId();

  Collection get _collection => state.collection;

  Iterable<ReferenceFieldDefinition> get _referenceFields =>
      _collection.fields.whereType<ReferenceFieldDefinition>();

  /// Starts watching the object and the reference targets.
  Future<void> initialize() async {
    if (!state.isCreate || _referenceFields.any(_isSelfReference)) {
      _subs.add(
        _repository
            .watchObjects(_collection.id, schema: _collection)
            .listen(_onObjects, onError: (Object _) {}),
      );
    }
    final targetIds = {for (final f in _referenceFields) f.targetCollectionId};
    if (targetIds.isEmpty) return;
    List<Collection> collections;
    try {
      collections = await _repository.getCollections();
    } catch (_) {
      collections = const [];
    }
    if (isClosed) return;
    _targets = [
      for (final id in targetIds)
        if (id == _collection.id)
          _collection
        else
          ?collections.where((c) => c.id == id).firstOrNull,
    ];
    for (final target in _targets) {
      if (target.id == _collection.id) continue;
      _subs.add(
        _repository
            .watchObjects(target.id, schema: target)
            .listen(
              (objects) => _onTargetObjects(target.id, objects),
              // A failed target shows no choices instead of loading forever.
              onError: (Object _) => _onTargetObjects(target.id, const []),
            ),
      );
    }
    _emitReferences();
  }

  bool _isSelfReference(ReferenceFieldDefinition f) =>
      f.targetCollectionId == _collection.id;

  void _onTargetObjects(String targetId, List<MorkvaObject> objects) {
    if (isClosed) return;
    _targetObjects[targetId] = objects;
    _emitReferences();
  }

  void _emitReferences() {
    if (isClosed || _targets.isEmpty) return;
    emit(
      state.copyWith(
        references: ReferenceChoices.fromObjects(
          targets: _targets,
          objects: _targetObjects,
        ),
      ),
    );
  }

  void _onObjects(List<MorkvaObject> objects) {
    if (isClosed) return;
    if (_referenceFields.any(_isSelfReference)) {
      _targetObjects[_collection.id] = objects;
      _emitReferences();
    }
    final previous = state.stored;
    if (previous == null) return;
    final status = state.status;
    if (status == ObjectEditorStatus.saved ||
        status == ObjectEditorStatus.deleted) {
      return;
    }
    final next = objects.where((o) => o.id == previous.id).firstOrNull;
    if (next == null) {
      emit(state.copyWith(remoteDeleted: true));
      return;
    }
    // While saving, our own write echoes back: keep the draft until it is
    // confirmed, so a failed save loses nothing.
    final draft = state.isSaving
        ? state.draft
        : {
            for (final e in state.draft.entries)
              if (next.values[e.key] != e.value) e.key: e.value,
          };
    final conflicts = {
      for (final id in state.conflictFieldIds)
        if (draft.containsKey(id)) id,
      if (!state.isSaving)
        for (final id in draft.keys)
          if (next.values[id] != previous.values[id]) id,
    };
    emit(
      state.copyWith(
        stored: next,
        draft: draft,
        conflictFieldIds: conflicts,
        remoteDeleted: false,
      ),
    );
  }

  /// Sets [fieldId] to [value] in the draft; a value equal to the stored
  /// one drops the field from the draft. Read-only fields are ignored.
  void change(String fieldId, FieldValue value) {
    if (_isInert(fieldId)) return;
    final field = _collection.fieldById(fieldId);
    if (field == null) return;
    final base =
        state.stored?.values[fieldId] ??
        state.prefill[fieldId] ??
        field.emptyValue();
    final draft = {...state.draft};
    if (value == base) {
      draft.remove(fieldId);
    } else {
      draft[fieldId] = value;
    }
    emit(
      state.copyWith(
        draft: draft,
        conflictFieldIds: {
          for (final id in state.conflictFieldIds)
            if (draft.containsKey(id)) id,
        },
        status: state.status == ObjectEditorStatus.saveFailed
            ? ObjectEditorStatus.editing
            : null,
      ),
    );
  }

  /// Records (or with null clears) text in [fieldId] that does not parse.
  void setInputError(String fieldId, String? message) {
    if (_isInert(fieldId)) return;
    final errors = {...state.inputErrors};
    if (message == null) {
      errors.remove(fieldId);
    } else {
      errors[fieldId] = message;
    }
    emit(state.copyWith(inputErrors: errors));
  }

  /// Marks [fieldId] as visited (edited and blurred): its errors show.
  void touch(String fieldId) {
    if (_isInert(fieldId) || state.touched.contains(fieldId)) return;
    emit(state.copyWith(touched: {...state.touched, fieldId}));
  }

  bool _isInert(String fieldId) =>
      isClosed ||
      state.isSaving ||
      state.status == ObjectEditorStatus.saved ||
      state.status == ObjectEditorStatus.deleted ||
      state.readOnlyFieldIds.contains(fieldId);

  /// Validates and writes the draft. Returns whether the object is saved;
  /// false when errors block it (all errors then show) or the write failed.
  Future<bool> save() async {
    if (isClosed || state.isSaving) return false;
    if (state.status == ObjectEditorStatus.saved) return true;
    if (state.status == ObjectEditorStatus.deleted) return false;
    final checked = state.copyWith(showAllErrors: true);
    if (checked.errors.isNotEmpty) {
      emit(checked.copyWith(status: ObjectEditorStatus.editing));
      return false;
    }
    final stored = state.stored;
    final now = _now();
    final MorkvaObject object;
    if (stored == null) {
      object = MorkvaObject.create(
        id: _newId,
        collection: _collection,
        values: {...state.prefill, ...state.draft},
        createdAt: now,
        updatedAt: now,
      );
    } else if (state.remoteDeleted) {
      // Gone elsewhere: write it back whole ("Save as new").
      object = stored.copyWith(
        values: {...stored.values, ...state.draft},
        updatedAt: now,
      );
    } else if (state.draft.isEmpty) {
      emit(
        checked.copyWith(status: ObjectEditorStatus.saved, savedObject: stored),
      );
      return true;
    } else {
      // Only the changed keys: the repository merges them over the stored
      // values, so fields edited elsewhere meanwhile survive.
      object = stored.copyWith(values: state.draft, updatedAt: now);
    }
    final whole = object.copyWith(
      values: {...?stored?.values, ...object.values},
    );
    emit(checked.copyWith(status: ObjectEditorStatus.saving));
    try {
      await _repository.saveObject(object, schema: _collection);
    } catch (_) {
      if (!isClosed) {
        emit(state.copyWith(status: ObjectEditorStatus.saveFailed));
      }
      return false;
    }
    if (!isClosed) {
      emit(
        state.copyWith(status: ObjectEditorStatus.saved, savedObject: whole),
      );
    }
    return true;
  }

  /// Asks to delete the object (edit mode). The editor closes and the
  /// caller deletes with Undo.
  void requestDelete() {
    if (isClosed || state.isCreate || state.isSaving) return;
    emit(state.copyWith(status: ObjectEditorStatus.deleted));
  }

  @override
  Future<void> close() async {
    final subs = [..._subs];
    _subs.clear();
    await Future.wait([for (final s in subs) s.cancel()]);
    return super.close();
  }
}
