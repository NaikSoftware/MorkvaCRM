import 'package:equatable/equatable.dart';

import '../../core/domain/domain.dart';
import '../views/widgets/view_labels.dart';
import 'value_editors/field_value_editor.dart';

/// Where the editor is in its life.
enum ObjectEditorStatus { editing, saving, saveFailed, saved, deleted }

/// The object form's state: the stored object (live), the draft of changed
/// values over it, and what validation shows.
class ObjectEditorState extends Equatable {
  const ObjectEditorState({
    required this.collection,
    required this.readOnlyFieldIds,
    this.titleFieldId,
    this.stored,
    this.prefill = const {},
    this.draft = const {},
    this.inputErrors = const {},
    this.touched = const {},
    this.showAllErrors = false,
    this.status = ObjectEditorStatus.editing,
    this.conflictFieldIds = const {},
    this.remoteDeleted = false,
    this.references = ReferenceChoices.none,
    this.uploads = const [],
    this.uploadErrors = const {},
    this.savedObject,
  });

  final Collection collection;

  /// auto_number / calculated (and unknown) fields: never dirty, never errors.
  final Set<String> readOnlyFieldIds;

  /// The field the header title reads from.
  final String? titleFieldId;

  /// The object as last streamed; null in create mode.
  final MorkvaObject? stored;

  /// Create mode's starting values (the group/day a quick add came from).
  final Map<String, FieldValue> prefill;

  /// Changed values only, by field id.
  final Map<String, FieldValue> draft;

  /// Text that does not parse, by field id (blocks save).
  final Map<String, String> inputErrors;

  /// Fields edited and blurred: their errors show before a save attempt.
  final Set<String> touched;

  /// A save was attempted: every field shows its errors.
  final bool showAllErrors;

  final ObjectEditorStatus status;

  /// Dirty fields whose stored value changed elsewhere while editing.
  final Set<String> conflictFieldIds;

  /// The object was deleted elsewhere; saving writes it back whole.
  final bool remoteDeleted;

  final ReferenceChoices references;

  /// File uploads in flight; Save waits for them.
  final List<PendingUpload> uploads;

  /// "Couldn't upload ⟨name⟩" by field id, until the field's next upload.
  final Map<String, String> uploadErrors;

  /// The object as it is after the last successful save (whole, even when
  /// only changed keys were written).
  final MorkvaObject? savedObject;

  String? get savedId => savedObject?.id;

  bool get isCreate => stored == null;

  bool get isSaving => status == ObjectEditorStatus.saving;

  bool get isUploading => uploads.isNotEmpty;

  /// The value the form shows for [field]: draft ?? stored ?? prefill ?? empty.
  FieldValue valueOf(FieldDefinition field) =>
      draft[field.id] ??
      stored?.values[field.id] ??
      prefill[field.id] ??
      field.emptyValue();

  /// Changed fields (the draft's keys).
  Set<String> get changedFieldIds => draft.keys.toSet();

  bool get hasUnsavedChanges =>
      status != ObjectEditorStatus.saved &&
      status != ObjectEditorStatus.deleted &&
      (draft.isNotEmpty || inputErrors.isNotEmpty || isUploading);

  /// Every current error (input error first, else the first rule broken),
  /// whether shown yet or not.
  Map<String, String> get errors => {
    for (final field in collection.fields)
      if (!readOnlyFieldIds.contains(field.id))
        field.id:
            ?(inputErrors[field.id] ??
            field.validate(valueOf(field)).firstOrNull?.message),
  };

  /// The errors the form shows now: touched fields, or all after a save
  /// attempt.
  Map<String, String> get visibleErrors {
    final all = errors;
    if (showAllErrors) return all;
    return {
      for (final e in all.entries)
        if (touched.contains(e.key)) e.key: e.value,
    };
  }

  int get errorCount => visibleErrors.length;

  /// "New deal" in create mode, else the title field's text or "Untitled".
  String get title {
    if (isCreate) return 'New ${itemLabelOf(collection)}';
    final field = titleFieldId == null
        ? null
        : collection.fieldById(titleFieldId!);
    if (field == null) return 'Untitled';
    final text = formatFieldValue(field, valueOf(field)).trim();
    return text.isEmpty ? 'Untitled' : text;
  }

  ObjectEditorState copyWith({
    MorkvaObject? stored,
    Map<String, FieldValue>? draft,
    Map<String, String>? inputErrors,
    Set<String>? touched,
    bool? showAllErrors,
    ObjectEditorStatus? status,
    Set<String>? conflictFieldIds,
    bool? remoteDeleted,
    ReferenceChoices? references,
    List<PendingUpload>? uploads,
    Map<String, String>? uploadErrors,
    MorkvaObject? savedObject,
  }) => ObjectEditorState(
    collection: collection,
    readOnlyFieldIds: readOnlyFieldIds,
    titleFieldId: titleFieldId,
    stored: stored ?? this.stored,
    prefill: prefill,
    draft: draft ?? this.draft,
    inputErrors: inputErrors ?? this.inputErrors,
    touched: touched ?? this.touched,
    showAllErrors: showAllErrors ?? this.showAllErrors,
    status: status ?? this.status,
    conflictFieldIds: conflictFieldIds ?? this.conflictFieldIds,
    remoteDeleted: remoteDeleted ?? this.remoteDeleted,
    references: references ?? this.references,
    uploads: uploads ?? this.uploads,
    uploadErrors: uploadErrors ?? this.uploadErrors,
    savedObject: savedObject ?? this.savedObject,
  );

  @override
  List<Object?> get props => [
    collection,
    readOnlyFieldIds,
    titleFieldId,
    stored,
    prefill,
    draft,
    inputErrors,
    touched,
    showAllErrors,
    status,
    conflictFieldIds,
    remoteDeleted,
    references,
    uploads,
    uploadErrors,
    savedObject,
  ];
}
