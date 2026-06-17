import 'package:equatable/equatable.dart';

import '../../../core/domain/domain.dart';

/// State of the single-collection schema editor.
///
/// Holds a detached, in-memory working [draft] of the collection plus the
/// [saved] snapshot it was loaded from. Edits mutate [draft] only; nothing
/// reaches the [DataRepository] until [CollectionEditorCubit.save]. [dirty] is
/// derived (`draft != saved`) and surfaces the Save affordance / leave guard.
///
/// [persistedFieldIds] are the ids of fields that existed at load time. Their
/// `type` is locked (decision 4 of the design): changing a persisted field's
/// type would be the only operation that could reinterpret stored object bytes,
/// so it is disallowed. Fields added in this editing session are draft-only and
/// may still change type freely (by remove + re-add).
sealed class CollectionEditorState extends Equatable {
  const CollectionEditorState();

  @override
  List<Object?> get props => const [];
}

/// Before [CollectionEditorCubit.load] has resolved.
final class CollectionEditorLoading extends CollectionEditorState {
  const CollectionEditorLoading();
}

/// The requested collection id does not exist (e.g. deep link to a deleted one).
final class CollectionEditorNotFound extends CollectionEditorState {
  const CollectionEditorNotFound(this.collectionId);

  /// The id that could not be resolved.
  final String collectionId;

  @override
  List<Object?> get props => [collectionId];
}

/// A loaded collection, ready to edit.
final class CollectionEditorReady extends CollectionEditorState {
  const CollectionEditorReady({
    required this.draft,
    required this.saved,
    required this.persistedFieldIds,
    this.selectedFieldId,
    this.saving = false,
    this.error,
  });

  /// The in-memory working copy being edited.
  final Collection draft;

  /// The last-persisted snapshot, for dirty comparison.
  final Collection saved;

  /// Ids of fields that existed at load; their type is locked.
  final Set<String> persistedFieldIds;

  /// The field whose config panel is open, or null when none is selected.
  final String? selectedFieldId;

  /// Whether a save is in flight.
  final bool saving;

  /// A non-fatal error from the last save attempt (draft retained, still dirty).
  final String? error;

  /// Whether the draft differs from the last-saved snapshot.
  bool get dirty => draft != saved;

  /// Whether [fieldId] is type-locked (it existed at load time).
  bool isFieldTypeLocked(String fieldId) => persistedFieldIds.contains(fieldId);

  /// The currently selected field definition, or null.
  FieldDefinition? get selectedField =>
      selectedFieldId == null ? null : draft.fieldById(selectedFieldId!);

  CollectionEditorReady copyWith({
    Collection? draft,
    Collection? saved,
    Set<String>? persistedFieldIds,
    String? selectedFieldId,
    bool clearSelection = false,
    bool? saving,
    String? error,
    bool clearError = false,
  }) {
    return CollectionEditorReady(
      draft: draft ?? this.draft,
      saved: saved ?? this.saved,
      persistedFieldIds: persistedFieldIds ?? this.persistedFieldIds,
      selectedFieldId: clearSelection
          ? null
          : (selectedFieldId ?? this.selectedFieldId),
      saving: saving ?? this.saving,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [
    draft,
    saved,
    persistedFieldIds,
    selectedFieldId,
    saving,
    error,
  ];
}
