import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../api/data/data_repository.dart';
import '../../../core/domain/domain.dart';
import '../../../core/domain/ids.dart';
import '../field_editors/field_editor.dart';
import 'collection_editor_state.dart';

/// Sentinel for [CollectionEditorCubit.updateFieldEnvelope]'s nullable
/// `description`, so an explicit `null` (clear) is distinguishable from
/// "unchanged".
const Object _unsetDescription = Object();

/// Drives the single-collection schema editor over a [DataRepository].
///
/// Loads one collection into an in-memory [Collection] draft; every mutating
/// method rebuilds the draft immutably (domain types are immutable) and never
/// touches the repository until [save]. [save] commits the whole draft
/// atomically so Firestore never sees a partial schema.
class CollectionEditorCubit extends Cubit<CollectionEditorState> {
  /// Creates a [CollectionEditorCubit] over [repository] and a [registry] of
  /// [FieldEditor]s (used to build default field definitions on `addField`).
  CollectionEditorCubit(
    this._repository,
    this._registry, {
    IdGenerator? idGenerator,
    String Function(SchemaIssue issue)? describeIssue,
    String Function(String error)? describeSaveError,
  }) : _ids = idGenerator ?? IdGenerator(),
       _describeIssue = describeIssue ?? ((issue) => issue.message),
       _describeSaveError =
           describeSaveError ?? ((error) => 'Failed to save: $error'),
       _fieldTypes = defaultFieldTypeRegistry(),
       super(const CollectionEditorLoading());

  final DataRepository _repository;
  final FieldEditorRegistry _registry;
  final IdGenerator _ids;

  /// Words a blocking schema issue for [CollectionEditorReady.error].
  final String Function(SchemaIssue issue) _describeIssue;

  /// Words a failed save (raw error text) for [CollectionEditorReady.error].
  final String Function(String error) _describeSaveError;

  /// The canonical domain type registry, owned here so the cubit can rebuild a
  /// field's common envelope via a lossless toJson → definitionFromJson
  /// round-trip without any `switch (type)` (see [updateFieldEnvelope]).
  final FieldTypeRegistry _fieldTypes;

  /// Loads the collection [collectionId] into an editable draft.
  ///
  /// Emits [CollectionEditorNotFound] when the id does not resolve. When
  /// [selectFieldId] names a field of the collection it starts selected (the
  /// `?field=` deep link); an unknown id is ignored.
  Future<void> load(String collectionId, {String? selectFieldId}) async {
    emit(const CollectionEditorLoading());
    final Collection? collection;
    try {
      collection = await _repository.getCollection(collectionId);
    } catch (error) {
      if (!isClosed) emit(CollectionEditorNotFound(collectionId));
      return;
    }
    if (isClosed) return;
    if (collection == null) {
      emit(CollectionEditorNotFound(collectionId));
      return;
    }
    // One-shot snapshot of the workspace collections for the reference picker
    // and reference summaries — not a live stream (the editor edits a detached
    // draft and commits atomically).
    List<Collection> available;
    try {
      available = await _repository.getCollections();
    } catch (_) {
      available = const [];
    }
    if (isClosed) return;
    emit(
      CollectionEditorReady(
        draft: collection,
        saved: collection,
        persistedFieldIds: collection.fields.map((f) => f.id).toSet(),
        availableCollections: available,
        selectedFieldId: collection.fields.any((f) => f.id == selectFieldId)
            ? selectFieldId
            : null,
      ),
    );
  }

  CollectionEditorReady? get _ready {
    final current = state;
    return current is CollectionEditorReady ? current : null;
  }

  /// Appends a default field of [typeId] to the draft and selects it.
  ///
  /// Its name is [label] (the type's English label by default), numbered when
  /// taken. A no-op if [typeId] has no registered editor.
  void addField(String typeId, {String? label}) {
    final ready = _ready;
    if (ready == null) return;
    final editor = _registry.forType(typeId);
    if (editor == null) return;

    final fieldId = _ids.fieldId();
    final name = _uniqueFieldName(ready.draft, label ?? editor.displayLabel);
    final field = editor.createDefault(id: fieldId, name: name);
    final fields = [...ready.draft.fields, field];
    final layout = ready.draft.layout.reconcile(
      fields.map((f) => f.id).toList(),
    );
    emit(
      ready.copyWith(
        draft: ready.draft.copyWith(fields: fields, layout: layout),
        selectedFieldId: fieldId,
        clearError: true,
      ),
    );
  }

  /// Replaces the field with [definition]'s id in the draft.
  ///
  /// Rejects (no-op) a `type` change on a persisted field id — the type lock
  /// from decision 4. Draft-only fields may change type freely.
  void updateField(FieldDefinition definition) {
    final ready = _ready;
    if (ready == null) return;
    final index = ready.draft.fields.indexWhere((f) => f.id == definition.id);
    if (index < 0) return;

    final existing = ready.draft.fields[index];
    if (existing.type != definition.type &&
        ready.isFieldTypeLocked(definition.id)) {
      assert(
        false,
        'Cannot change the type of persisted field "${definition.id}" '
        '(${existing.type} -> ${definition.type}); type is locked after save.',
      );
      return;
    }

    final fields = [...ready.draft.fields]..[index] = definition;
    emit(
      ready.copyWith(
        draft: ready.draft.copyWith(fields: fields),
        clearError: true,
      ),
    );
  }

  /// Updates a field's **common envelope** (name / description / required)
  /// without naming its concrete subclass.
  ///
  /// Only the supplied arguments change. [description] uses a sentinel default
  /// so passing an explicit `null` (or an empty/blank string) clears the
  /// description, while omitting it preserves the current value. The rebuild is
  /// a lossless `toJson` → [FieldTypeRegistry.definitionFromJson] round-trip,
  /// owned here so widgets stay free of the type registry and any `switch`.
  ///
  /// A no-op if [fieldId] is unknown in the draft.
  void updateFieldEnvelope(
    String fieldId, {
    String? name,
    Object? description = _unsetDescription,
    bool? isRequired,
  }) {
    final ready = _ready;
    if (ready == null) return;
    final field = ready.draft.fieldById(fieldId);
    if (field == null) return;

    final json = field.toJson();
    if (name != null) json['name'] = name;
    if (!identical(description, _unsetDescription)) {
      final value = description as String?;
      if (value == null || value.trim().isEmpty) {
        json.remove('description');
      } else {
        json['description'] = value;
      }
    }
    if (isRequired != null) json['required'] = isRequired;

    updateField(_fieldTypes.definitionFromJson(json));
  }

  /// Removes the field [fieldId] from the draft, clearing selection if it was
  /// the selected field.
  void removeField(String fieldId) {
    final ready = _ready;
    if (ready == null) return;
    final fields = ready.draft.fields.where((f) => f.id != fieldId).toList();
    if (fields.length == ready.draft.fields.length) return;
    final clearSelection = ready.selectedFieldId == fieldId;
    final layout = ready.draft.layout.reconcile(
      fields.map((f) => f.id).toList(),
    );
    emit(
      ready.copyWith(
        draft: ready.draft.copyWith(fields: fields, layout: layout),
        clearSelection: clearSelection,
        clearError: true,
      ),
    );
  }

  /// Moves the field at [oldIndex] to [newIndex] in the draft.
  ///
  /// Uses [ReorderableListView] index semantics: when moving down, [newIndex]
  /// is the position *before* removal, so it is decremented after removing.
  void reorderFields(int oldIndex, int newIndex) {
    final ready = _ready;
    if (ready == null) return;
    final fields = [...ready.draft.fields];
    if (oldIndex < 0 || oldIndex >= fields.length) return;
    var target = newIndex;
    if (target > oldIndex) target -= 1;
    if (target < 0) target = 0;
    if (target >= fields.length) target = fields.length - 1;
    if (target == oldIndex) return;
    final moved = fields.removeAt(oldIndex);
    fields.insert(target, moved);
    emit(
      ready.copyWith(
        draft: ready.draft.copyWith(fields: fields),
        clearError: true,
      ),
    );
  }

  /// Renames the draft collection, optionally updating its description.
  void renameCollection(String name, {String? description}) {
    final ready = _ready;
    if (ready == null) return;
    final trimmedDescription = description?.trim();
    // copyWith keeps layout and views; its sentinel lets description clear.
    final draft = ready.draft.copyWith(
      name: name,
      description: (trimmedDescription == null || trimmedDescription.isEmpty)
          ? null
          : trimmedDescription,
    );
    emit(ready.copyWith(draft: draft, clearError: true));
  }

  /// Sets (or clears, with null) the draft collection's icon key. Marks the
  /// draft dirty via the derived `draft != saved` comparison.
  void setIcon(String? icon) {
    final ready = _ready;
    if (ready == null) return;
    if (ready.draft.icon == icon) return;
    emit(
      ready.copyWith(draft: ready.draft.copyWith(icon: icon), clearError: true),
    );
  }

  /// Selects [fieldId] (drives the properties panel), or clears selection if
  /// null. Clears any section selection (field/section are mutually exclusive).
  void selectField(String? fieldId) {
    final ready = _ready;
    if (ready == null) return;
    if (fieldId == null) {
      emit(ready.copyWith(clearSelection: true, clearSectionSelection: true));
    } else {
      emit(
        ready.copyWith(selectedFieldId: fieldId, clearSectionSelection: true),
      );
    }
  }

  /// Selects [sectionId] (drives the group inspector), or clears if null.
  /// Clears any field selection (field/section are mutually exclusive).
  void selectSection(String? sectionId) {
    final ready = _ready;
    if (ready == null) return;
    if (sectionId == null) {
      emit(ready.copyWith(clearSectionSelection: true, clearSelection: true));
    } else {
      emit(ready.copyWith(selectedSectionId: sectionId, clearSelection: true));
    }
  }

  /// Validates the current draft. See [validateCollectionSchema].
  SchemaValidation validate() {
    final ready = _ready;
    if (ready == null) return const SchemaValidation([]);
    return _validate(ready);
  }

  /// Persists the whole draft via [DataRepository.saveCollection].
  ///
  /// Returns `true` on success (clears [CollectionEditorReady.dirty] by
  /// adopting the draft as the new saved snapshot, and promotes all field ids
  /// to persisted/type-locked). Returns `false` when blocked by a validation
  /// error or when the save call fails (draft retained, stays dirty, error
  /// surfaced for retry).
  Future<bool> save() async {
    final ready = _ready;
    if (ready == null) return false;

    final validation = _validate(ready);
    if (validation.hasBlocking) {
      emit(
        ready.copyWith(error: _describeIssue(validation.blocking.first)),
      );
      return false;
    }

    emit(ready.copyWith(saving: true, clearError: true));
    // New fields show up in every existing view until the user hides them.
    final toSave = ready.draft.withNewFieldsInViews(ready.saved);
    try {
      await _repository.saveCollection(toSave);
    } catch (error) {
      if (!isClosed) {
        final current = _ready;
        if (current != null) {
          emit(
            current.copyWith(
              saving: false,
              error: _describeSaveError('$error'),
            ),
          );
        }
      }
      return false;
    }
    if (isClosed) return true;
    final current = _ready;
    if (current != null) {
      emit(
        current.copyWith(
          saving: false,
          draft: current.draft.copyWith(views: toSave.views),
          saved: toSave,
          persistedFieldIds: current.draft.fields.map((f) => f.id).toSet(),
          clearError: true,
        ),
      );
    }
    return true;
  }

  /// Select fields without options and references without a target only
  /// warn: they are valid schemas the author may finish later.
  SchemaValidation _validate(CollectionEditorReady ready) =>
      validateCollectionSchema(ready.draft, saved: ready.saved);

  // ---------------------------------------------------------------------------
  // Layout operations — thin delegates to CardLayout, emitting a new draft.
  // ---------------------------------------------------------------------------

  /// Emits a new draft with [layout] applied. No-op when not ready.
  void _emitLayout(CardLayout layout) {
    final ready = _ready;
    if (ready == null) return;
    emit(
      ready.copyWith(
        draft: ready.draft.copyWith(layout: layout),
        clearError: true,
      ),
    );
  }

  /// Sets the span of cell [fieldId] within [rowId] (neighbour absorbs overflow).
  void setCellSpan(String rowId, String fieldId, int span) {
    final ready = _ready;
    if (ready == null) return;
    _emitLayout(ready.draft.layout.setCellSpan(rowId, fieldId, span));
  }

  void moveCellToRow(String fieldId, String targetRowId, int index) {
    final ready = _ready;
    if (ready == null) return;
    _emitLayout(ready.draft.layout.moveCellToRow(fieldId, targetRowId, index));
  }

  void moveCellToNewRow(String fieldId, String sectionId, int rowIndex) {
    final ready = _ready;
    if (ready == null) return;
    _emitLayout(
      ready.draft.layout.moveCellToNewRow(
        fieldId,
        sectionId,
        rowIndex,
        _ids.rowId(),
      ),
    );
  }

  void reorderCellInRow(String rowId, int oldIndex, int newIndex) {
    final ready = _ready;
    if (ready == null) return;
    _emitLayout(ready.draft.layout.reorderCellInRow(rowId, oldIndex, newIndex));
  }

  void addSection({String? title}) {
    final ready = _ready;
    if (ready == null) return;
    _emitLayout(ready.draft.layout.addSection(_ids.sectionId(), title: title));
  }

  void renameSection(String sectionId, String? title) {
    final ready = _ready;
    if (ready == null) return;
    _emitLayout(ready.draft.layout.renameSection(sectionId, title));
  }

  void toggleSectionCollapsed(String sectionId) {
    final ready = _ready;
    if (ready == null) return;
    _emitLayout(ready.draft.layout.toggleSectionCollapsed(sectionId));
  }

  void reorderSections(int oldIndex, int newIndex) {
    final ready = _ready;
    if (ready == null) return;
    _emitLayout(ready.draft.layout.reorderSections(oldIndex, newIndex));
  }

  void moveRowToSection(String rowId, String targetSectionId, int index) {
    final ready = _ready;
    if (ready == null) return;
    _emitLayout(
      ready.draft.layout.moveRowToSection(rowId, targetSectionId, index),
    );
  }

  void deleteSection(String sectionId) {
    final ready = _ready;
    if (ready == null) return;
    final layout = ready.draft.layout.deleteSection(sectionId);
    final clearSection = ready.selectedSectionId == sectionId;
    emit(
      ready.copyWith(
        draft: ready.draft.copyWith(layout: layout),
        clearSectionSelection: clearSection,
        clearError: true,
      ),
    );
  }

  /// A field name not already used in [collection], based on [label].
  String _uniqueFieldName(Collection collection, String label) {
    final used = collection.fields
        .map((f) => f.name.trim().toLowerCase())
        .toSet();
    if (!used.contains(label.toLowerCase())) return label;
    var n = 2;
    while (used.contains('$label $n'.toLowerCase())) {
      n++;
    }
    return '$label $n';
  }
}
