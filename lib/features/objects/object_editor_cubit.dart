import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mime/mime.dart';

import '../../api/data/data_repository.dart';
import '../../api/files/attachment_store.dart';
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
    AttachmentStore? attachments,
    IdGenerator? idGenerator,
    DateTime Function()? clock,
    Map<String, FieldValue> Function(MorkvaObject draft)? derive,
    Map<String, String> notes = const {},
  }) : editors = editors ?? _defaultEditors,
       _deriveValues =
           collection.fields.any((f) => f is CalculatedFieldDefinition)
           ? derive
           : null,
       _attachments = attachments,
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
           notes: notes,
         ),
       );

  static final _defaultEditors = defaultValueEditorRegistry();

  final DataRepository _repository;

  /// The value editors the form renders with (also decides read-only fields).
  final FieldValueEditorRegistry editors;
  final AttachmentStore? _attachments;
  final IdGenerator _ids;
  final DateTime Function() _now;

  /// Whether file fields can upload (a store was given).
  bool get canUpload => _attachments != null;

  /// Calculates the derived values of the draft (null: nothing to derive).
  final Map<String, FieldValue> Function(MorkvaObject draft)? _deriveValues;

  /// Every state carries the calculated values of what it shows.
  @override
  void emit(ObjectEditorState state) {
    final derive = _deriveValues;
    if (derive == null) return super.emit(state);
    final now = _now();
    final draft = MorkvaObject(
      id: state.stored?.id ?? _newId,
      collectionId: _collection.id,
      values: {for (final f in _collection.fields) f.id: state.valueOf(f)},
      createdAt: state.stored?.createdAt ?? now,
      updatedAt: now,
    );
    super.emit(state.copyWith(derived: derive(draft)));
  }

  final List<StreamSubscription<Object?>> _subs = [];
  final Map<String, List<MorkvaObject>> _targetObjects = {};
  List<Collection> _targets = const [];

  /// Reference targets that aren't in the workspace (deleted, or the
  /// collections failed to load): loaded with no objects.
  Set<String> _missingTargetIds = const {};

  /// Upload ids the user canceled: they end without an error.
  final Set<String> _canceledUploads = {};

  /// The object has been in a snapshot: only then is its absence a delete
  /// (a quick-added object may not reach the stream until committed).
  bool _seenStored = false;

  /// Set at the start of [close], before `isClosed` turns true.
  bool _closing = false;

  /// Create mode's id, minted once so a retried save writes the same object.
  late final String _newId = _ids.objectId();

  Collection get _collection => state.collection;

  Iterable<ReferenceFieldDefinition> get _referenceFields =>
      _collection.fields.whereType<ReferenceFieldDefinition>();

  /// Starts watching the object and the reference targets.
  Future<void> initialize() async {
    if (_deriveValues != null) emit(state);
    if (state.stored case final stored?) _watchStored(stored);
    final targetIds = {for (final f in _referenceFields) f.targetCollectionId};
    List<Collection> collections;
    try {
      collections = resolveLookups(await _repository.getCollections());
    } catch (_) {
      collections = const [];
    }
    if (isClosed || _closing) return;
    _targets = [
      for (final id in targetIds)
        if (id == _collection.id)
          _collection
        else
          ?collections.where((c) => c.id == id).firstOrNull,
    ];
    _missingTargetIds = targetIds.difference({for (final t in _targets) t.id});
    _sublists = [
      for (final c in _collection.withWorkspace(collections))
        for (final r in c.fields.whereType<ReferenceFieldDefinition>())
          if (r.targetCollectionId == _collection.id)
            Sublist(collection: c, via: r),
    ];
    _workspace = _collection.withWorkspace(collections);
    final byId = {for (final c in _workspace) c.id: c};
    final watched = {
      for (final t in _targets) t.id: t,
      for (final s in _sublists) ...{
        s.collection.id: s.collection,
        // What the items' calculations read, for the item form's preview.
        for (final id in Derivation.sourcesOf(s.collection.id, _workspace))
          id: ?byId[id],
      },
    };
    for (final c in watched.values) {
      _subs.add(
        _repository
            .watchObjects(c.id, schema: c)
            .listen(
              (objects) => _onTargetObjects(c.id, objects),
              // A failed target shows no choices instead of loading forever.
              onError: (Object _) => _onTargetObjects(c.id, const []),
            ),
      );
    }
    _emitReferences();
  }

  /// The linked-item lists, in the workspace's order; items filled per emit.
  List<Sublist> _sublists = const [];

  /// Every collection (this one as edited first), once loaded.
  List<Collection> _workspace = const [];

  /// The workspace as loaded (for describing an item's calculations).
  List<Collection> get workspace => _workspace;

  /// The calculated values of [draft], an item of [sublist], against the
  /// loaded objects and this object as it stands in the form.
  Map<String, FieldValue> deriveChild(Sublist sublist, MorkvaObject draft) {
    final child = sublist.collection;
    final objects = _withSelf(_targetObjects);
    objects[child.id] = [
      ...?objects[child.id]?.where((o) => o.id != draft.id),
      draft,
    ];
    final derived = Derivation(
      collections: _workspace,
      objects: objects,
    ).objectsOf(child.id).lastWhere((o) => o.id == draft.id);
    return {
      for (final f in child.fields.whereType<CalculatedFieldDefinition>())
        f.id: derived[f.id] ?? f.emptyValue(),
    };
  }

  /// The id the object has, or will have once saved.
  String get _objectId => state.stored?.id ?? _newId;

  void _onTargetObjects(String targetId, List<MorkvaObject> objects) {
    if (isClosed) return;
    _targetObjects[targetId] = objects;
    _emitReferences();
  }

  void _emitReferences() {
    if (isClosed) return;
    final hasTargets = _targets.isNotEmpty || _missingTargetIds.isNotEmpty;
    if (!hasTargets && _sublists.isEmpty) return;
    emit(
      state.copyWith(
        references: hasTargets
            ? ReferenceChoices.fromObjects(
                targets: _targets,
                objects: _targetObjects,
                missingTargetIds: _missingTargetIds,
              )
            : null,
        sublists: [for (final s in _sublists) _fill(s)],
      ),
    );
  }

  /// [sublist] with the loaded items linking to this object, in the order
  /// of its collection's first view.
  Sublist _fill(Sublist sublist) {
    final all = _targetObjects[sublist.collection.id];
    if (all == null) return sublist.withItems(null);
    final id = _objectId;
    final linking = [
      for (final o in all)
        if (o[sublist.via.id] case ReferenceFieldValue(
          :final objectIds,
        ) when objectIds.contains(id))
          o,
    ];
    final c = sublist.collection;
    final view = (c.views.firstOrNull ?? ViewDefinition.defaultFor(c.fields))
        .copyWith(filters: const []);
    final ids = {for (final o in linking) o.id};
    final derived = c.fields.any((f) => f is CalculatedFieldDefinition)
        ? [
            for (final o in Derivation(
              collections: _workspace,
              objects: _withSelf(_targetObjects),
            ).objectsOf(c.id))
              if (ids.contains(o.id)) o,
          ]
        : linking;
    return sublist.withItems(applyView(c, view, derived));
  }

  /// [objects] with this object as it stands in the form.
  Map<String, List<MorkvaObject>> _withSelf(
    Map<String, List<MorkvaObject>> objects,
  ) {
    final now = _now();
    final self = MorkvaObject(
      id: _objectId,
      collectionId: _collection.id,
      values: {
        for (final f in _collection.fields)
          if (f is! CalculatedFieldDefinition) f.id: state.valueOf(f),
      },
      createdAt: state.stored?.createdAt ?? now,
      updatedAt: now,
    );
    return {
      ...objects,
      _collection.id: [
        ...?objects[_collection.id]?.where((o) => o.id != self.id),
        self,
      ],
    };
  }

  /// The starting values of a new item of [sublist]: linked to this object.
  Map<String, FieldValue> prefillFor(Sublist sublist) => {
    sublist.via.id: ReferenceFieldValue([_objectId]),
  };

  /// Records an item added from a sublist; while this object is new, it is
  /// deleted again if the object is discarded.
  void childAdded(Sublist sublist, String objectId) {
    if (isClosed || !state.isCreate) return;
    emit(
      state.copyWith(
        addedChildren: {
          ...state.addedChildren,
          objectId: sublist.collection.id,
        },
      ),
    );
  }

  /// Writes [value] into [fieldId] of [item] (only that key; the repository
  /// merges it). Returns whether the write went through.
  Future<bool> setChildValue(
    Sublist sublist,
    MorkvaObject item,
    String fieldId,
    FieldValue value,
  ) async {
    try {
      await _repository.saveObject(
        item.copyWith(values: {fieldId: value}, updatedAt: _now()),
        schema: sublist.collection,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Deletes [item] of [sublist] (the child form asked to).
  Future<bool> deleteChild(Sublist sublist, MorkvaObject item) async {
    if (state.addedChildren.containsKey(item.id) && !isClosed) {
      emit(
        state.copyWith(
          addedChildren: {...state.addedChildren}..remove(item.id),
        ),
      );
    }
    try {
      await _repository.deleteObject(
        sublist.collection.id,
        item.id,
        before: item,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  void _watchStored(MorkvaObject stored) => _subs.add(
    _repository
        .watchObject(_collection.id, stored.id, schema: _collection)
        .listen(_onStored, onError: (Object _) {}),
  );

  void _onStored(MorkvaObject? next) {
    if (isClosed) return;
    final previous = state.stored;
    if (previous == null) return;
    final status = state.status;
    if (status == ObjectEditorStatus.saved ||
        status == ObjectEditorStatus.deleted) {
      return;
    }
    if (next == null) {
      if (_seenStored) emit(state.copyWith(remoteDeleted: true));
      return;
    }
    _seenStored = true;
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
    // Items' calculations may read this object: follow the edit.
    // shortcut: re-derives every loaded item per keystroke; derive only the
    // items' fields that read this object if a large workspace makes typing lag.
    if (_sublists.any(
      (s) => s.collection.fields.any((f) => f is CalculatedFieldDefinition),
    )) {
      _emitReferences();
    }
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

  /// Uploads [files] into file field [fieldId]: each shows as a pending
  /// upload, then joins the draft (replacing the file on a single-file
  /// field). A failure leaves the value as it was and sets the field's
  /// "Couldn't upload ⟨name⟩".
  Future<void> upload(String fieldId, List<PickedFile> files) async {
    final store = _attachments;
    final field = _collection.fieldById(fieldId);
    if (store == null || field is! FileFieldDefinition || _isInert(fieldId)) {
      return;
    }
    if (files.isEmpty) return;
    emit(
      state.copyWith(uploadErrors: {...state.uploadErrors}..remove(fieldId)),
    );
    await Future.wait([
      for (final file in field.multiple ? files : files.take(1))
        _uploadOne(store, field, file),
    ]);
  }

  Future<void> _uploadOne(
    AttachmentStore store,
    FileFieldDefinition field,
    PickedFile file,
  ) async {
    final pending = PendingUpload(
      id: _ids.attachmentId(),
      fieldId: field.id,
      name: file.name,
    );
    emit(state.copyWith(uploads: [...state.uploads, pending]));
    FileAttachment? done;
    final tooLarge = file.bytes.length >= kMaxAttachmentBytes;
    if (!tooLarge) {
      try {
        done = await store.upload(
          id: pending.id,
          fileName: file.name,
          bytes: file.bytes,
          mimeType: lookupMimeType(file.name),
          onProgress: (p) => _setProgress(pending.id, p),
        );
      } catch (_) {
        // Shown as the field's error below; the form keeps working.
      }
    }
    if (isClosed) return;
    final canceled = _canceledUploads.remove(pending.id);
    if (done != null && !canceled) {
      final current = (state.valueOf(field) as FileFieldValue).attachments;
      change(
        field.id,
        FileFieldValue(field.multiple ? [...current, done] : [done]),
      );
      touch(field.id);
    }
    emit(
      state.copyWith(
        uploads: [
          for (final u in state.uploads)
            if (u.id != pending.id) u,
        ],
        uploadErrors: done == null && !canceled
            ? {
                ...state.uploadErrors,
                field.id: (file: file.name, tooLarge: tooLarge),
              }
            : null,
      ),
    );
  }

  /// Cancels the in-flight upload [uploadId]: its tile goes, no error shows.
  void cancelUpload(String uploadId) {
    final store = _attachments;
    if (store == null || isClosed) return;
    if (!state.uploads.any((u) => u.id == uploadId)) return;
    _canceledUploads.add(uploadId);
    unawaited(store.cancelUpload(uploadId));
  }

  void _setProgress(String uploadId, double progress) {
    if (isClosed) return;
    emit(
      state.copyWith(
        uploads: [
          for (final u in state.uploads)
            u.id == uploadId ? u.withProgress(progress) : u,
        ],
      ),
    );
  }

  /// Where [attachment] can be opened; throws when Storage fails.
  Future<Uri> downloadUrl(FileAttachment attachment) {
    final store = _attachments;
    if (store == null) throw StateError('No attachment store');
    return store.downloadUrl(attachment);
  }

  /// Validates and writes the draft. Returns whether the object is saved;
  /// false when errors block it (all errors then show) or the write failed.
  ///
  /// [stayOpen] ("Save and run"): the editor keeps editing the saved object
  /// instead of closing, so an action can run on it while the form follows
  /// the stored card.
  Future<bool> save({bool stayOpen = false}) async {
    if (isClosed || state.isSaving || state.isUploading) return false;
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
      if (!stayOpen) {
        emit(
          checked.copyWith(
            status: ObjectEditorStatus.saved,
            savedObject: stored,
          ),
        );
      }
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
    if (isClosed) return true;
    if (!stayOpen) {
      emit(
        state.copyWith(status: ObjectEditorStatus.saved, savedObject: whole),
      );
      return true;
    }
    final created = stored == null;
    emit(
      ObjectEditorState(
        collection: state.collection,
        readOnlyFieldIds: state.readOnlyFieldIds,
        titleFieldId: state.titleFieldId,
        stored: whole,
        // Remembered so closing later still reports the save.
        savedObject: whole,
        notes: state.notes,
        sublists: state.sublists,
        references: state.references,
        derived: state.derived,
      ),
    );
    // A created card is followed from now on, as an opened one is.
    if (created) _watchStored(whole);
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
    _closing = true;
    // A new object discarded: the items added to it would point at nothing.
    // Not while saving: the object may still land.
    if (state.isCreate &&
        (state.status == ObjectEditorStatus.editing ||
            state.status == ObjectEditorStatus.saveFailed)) {
      for (final MapEntry(key: id, value: collectionId)
          in state.addedChildren.entries) {
        unawaited(
          _repository.deleteObject(collectionId, id).catchError((Object _) {}),
        );
      }
    }
    final subs = [..._subs];
    _subs.clear();
    await Future.wait([for (final s in subs) s.cancel()]);
    return super.close();
  }
}
