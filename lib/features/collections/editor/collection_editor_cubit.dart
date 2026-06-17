import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../api/data/data_repository.dart';
import '../../../core/domain/domain.dart';
import '../field_editors/field_editor.dart';
import '../util/id_generator.dart';
import 'collection_editor_state.dart';

/// Sentinel for [CollectionEditorCubit.updateFieldEnvelope]'s nullable
/// `description`, so an explicit `null` (clear) is distinguishable from
/// "unchanged".
const Object _unsetDescription = Object();

/// A schema-editor validation problem.
///
/// [blocking] problems (empty collection name, duplicate field names) must be
/// resolved before [CollectionEditorCubit.save] will persist; non-blocking ones
/// (a select field with no options, a reference field with no target) are
/// surfaced inline as warnings but do not prevent saving — they are still valid
/// documents the author may finish later.
class EditorValidationIssue {
  const EditorValidationIssue({
    required this.message,
    required this.blocking,
    this.fieldId,
  });

  /// Human-readable description of the problem.
  final String message;

  /// Whether this problem blocks save.
  final bool blocking;

  /// The field the problem belongs to, or null for collection-level problems.
  final String? fieldId;
}

/// The result of validating a draft: the blocking and non-blocking issues.
class EditorValidation {
  const EditorValidation(this.issues);

  /// All issues, blocking and non-blocking.
  final List<EditorValidationIssue> issues;

  /// The blocking issues only.
  List<EditorValidationIssue> get blocking =>
      issues.where((i) => i.blocking).toList(growable: false);

  /// The non-blocking warnings only.
  List<EditorValidationIssue> get warnings =>
      issues.where((i) => !i.blocking).toList(growable: false);

  /// Whether any blocking issue exists (i.e. save is disallowed).
  bool get hasBlocking => issues.any((i) => i.blocking);
}

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
  }) : _ids = idGenerator ?? IdGenerator(),
       _fieldTypes = defaultFieldTypeRegistry(),
       super(const CollectionEditorLoading());

  final DataRepository _repository;
  final FieldEditorRegistry _registry;
  final IdGenerator _ids;

  /// The canonical domain type registry, owned here so the cubit can rebuild a
  /// field's common envelope via a lossless toJson → definitionFromJson
  /// round-trip without any `switch (type)` (see [updateFieldEnvelope]).
  final FieldTypeRegistry _fieldTypes;

  /// Loads the collection [collectionId] into an editable draft.
  ///
  /// Emits [CollectionEditorNotFound] when the id does not resolve.
  Future<void> load(String collectionId) async {
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
      ),
    );
  }

  CollectionEditorReady? get _ready {
    final current = state;
    return current is CollectionEditorReady ? current : null;
  }

  /// Appends a default field of [typeId] to the draft and selects it.
  ///
  /// A no-op if [typeId] has no registered editor.
  void addField(String typeId) {
    final ready = _ready;
    if (ready == null) return;
    final editor = _registry.forType(typeId);
    if (editor == null) return;

    final fieldId = _ids.fieldId();
    final name = _uniqueFieldName(ready.draft, editor.displayLabel);
    final field = editor.createDefault(id: fieldId, name: name);
    final fields = [...ready.draft.fields, field];
    emit(
      ready.copyWith(
        draft: ready.draft.copyWith(fields: fields),
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
    emit(
      ready.copyWith(
        draft: ready.draft.copyWith(fields: fields),
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
    // Build directly so a cleared description becomes null (copyWith can't null).
    final draft = Collection(
      id: ready.draft.id,
      name: name,
      description: (trimmedDescription == null || trimmedDescription.isEmpty)
          ? null
          : trimmedDescription,
      icon: ready.draft.icon,
      fields: ready.draft.fields,
    );
    emit(ready.copyWith(draft: draft, clearError: true));
  }

  /// Sets (or clears, with null) the draft collection's icon key. Marks the
  /// draft dirty via the derived `draft != saved` comparison.
  void setIcon(String? icon) {
    final ready = _ready;
    if (ready == null) return;
    if (ready.draft.icon == icon) return;
    emit(ready.copyWith(draft: ready.draft.copyWith(icon: icon), clearError: true));
  }

  /// Selects [fieldId] (drives the config panel), or clears selection if null.
  void selectField(String? fieldId) {
    final ready = _ready;
    if (ready == null) return;
    if (fieldId == null) {
      emit(ready.copyWith(clearSelection: true));
    } else {
      emit(ready.copyWith(selectedFieldId: fieldId));
    }
  }

  /// Validates the current draft. See [EditorValidation].
  EditorValidation validate() {
    final ready = _ready;
    if (ready == null) return const EditorValidation([]);
    return _validate(ready.draft);
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

    final validation = _validate(ready.draft);
    if (validation.hasBlocking) {
      emit(ready.copyWith(error: validation.blocking.first.message));
      return false;
    }

    emit(ready.copyWith(saving: true, clearError: true));
    try {
      await _repository.saveCollection(ready.draft);
    } catch (error) {
      if (!isClosed) {
        final current = _ready;
        if (current != null) {
          emit(
            current.copyWith(saving: false, error: 'Failed to save: $error'),
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
          saved: current.draft,
          persistedFieldIds: current.draft.fields.map((f) => f.id).toSet(),
          clearError: true,
        ),
      );
    }
    return true;
  }

  EditorValidation _validate(Collection draft) {
    final issues = <EditorValidationIssue>[];

    if (draft.name.trim().isEmpty) {
      issues.add(
        const EditorValidationIssue(
          message: 'Collection name is required',
          blocking: true,
        ),
      );
    }

    // Duplicate (case-insensitive, trimmed) field names block save.
    final seen = <String, String>{};
    for (final field in draft.fields) {
      final key = field.name.trim().toLowerCase();
      if (key.isEmpty) {
        issues.add(
          EditorValidationIssue(
            message: 'Field name is required',
            blocking: true,
            fieldId: field.id,
          ),
        );
        continue;
      }
      final firstId = seen[key];
      if (firstId != null) {
        issues.add(
          EditorValidationIssue(
            message: 'Duplicate field name "${field.name.trim()}"',
            blocking: true,
            fieldId: field.id,
          ),
        );
      } else {
        seen[key] = field.id;
      }
    }

    // Non-blocking warnings.
    for (final field in draft.fields) {
      if (field is SingleSelectFieldDefinition && field.options.isEmpty) {
        issues.add(
          EditorValidationIssue(
            message: '"${field.name}" has no options yet',
            blocking: false,
            fieldId: field.id,
          ),
        );
      } else if (field is MultiSelectFieldDefinition && field.options.isEmpty) {
        issues.add(
          EditorValidationIssue(
            message: '"${field.name}" has no options yet',
            blocking: false,
            fieldId: field.id,
          ),
        );
      } else if (field is ReferenceFieldDefinition &&
          field.targetCollectionId.isEmpty) {
        issues.add(
          EditorValidationIssue(
            message: '"${field.name}" has no target collection yet',
            blocking: false,
            fieldId: field.id,
          ),
        );
      }
    }

    return EditorValidation(issues);
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
