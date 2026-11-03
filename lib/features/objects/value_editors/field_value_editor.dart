import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';

import '../../../core/domain/domain.dart';
import 'unsupported_value_editor.dart';

/// Edits one field's *value* in the object form — the value-side counterpart
/// to the schema editor's `FieldEditor`.
///
/// The form never names a field type: it looks the editor up in
/// [FieldValueEditorRegistry] and hands it a [ValueEditorContext]. Adding a
/// type is one editor class plus one line in `built_in_value_editors.dart`.
///
/// **Who renders what.** The form owns the field chrome: the label (name plus
/// `*` when required), the description as helper text, and the error line
/// below the control. An editor renders only its control, and reflects
/// [ValueEditorContext.error] as state (an error border), never as text.
/// Exceptions an editor may add itself: its own helper that the form cannot
/// know (the text counter "n / max", "Set automatically" on read-only
/// types). An editor whose control already carries the field name (the
/// boolean switch row) sets [rendersOwnLabel], and the form then skips the
/// label but still renders the description and the error line.
///
/// Editors are dumb: they never mutate state, they report through
/// [ValueEditorContext.onChanged] / [ValueEditorContext.onInputError]. Local
/// UI state (a text controller) is fine; hosts should key each editor by the
/// field id so that state follows the field.
abstract class FieldValueEditor {
  const FieldValueEditor();

  /// The type discriminator this editor handles; matches [FieldDefinition.type].
  String get typeId;

  /// Whether the value is computed elsewhere (auto_number, calculated). The
  /// form skips read-only fields in validation, dirty and discard logic.
  bool get isReadOnly => false;

  /// Whether the control shows the field name itself (see the class doc).
  bool get rendersOwnLabel => false;

  /// Builds the control for [ctx].
  Widget build(BuildContext context, ValueEditorContext ctx);
}

/// Everything an editor may need, nothing type-specific.
class ValueEditorContext {
  const ValueEditorContext({
    required this.field,
    required this.value,
    required this.onChanged,
    this.onInputError = _ignoreInputError,
    this.error,
    this.enabled = true,
    this.references = ReferenceChoices.none,
    this.attachments,
  });

  final FieldDefinition field;

  /// The displayed value (draft ?? stored); always this field's value type.
  final FieldValue value;

  /// The message to flag, or null. Editors show it as state only (see
  /// [FieldValueEditor]); the form renders the text.
  final String? error;

  /// False while the form is busy (saving): the control is inert.
  final bool enabled;

  /// Emits the new value on every edit.
  final ValueChanged<FieldValue> onChanged;

  /// Reports text that does not parse (e.g. "12,3a" in a number) — it blocks
  /// save — or `null` once the input is valid again.
  final ValueChanged<String?> onInputError;

  /// Labels and targets for reference fields.
  final ReferenceChoices references;

  /// Upload/open for file fields; null when files are unavailable.
  final AttachmentActions? attachments;

  static void _ignoreInputError(String? _) {}
}

/// What reference editors can link to: per target collection, the target
/// itself and its objects' labels, plus a secondary line per object.
///
/// Plain immutable data, so a cubit can keep it in its state (Equatable, so a
/// change of labels is a new state).
class ReferenceChoices extends Equatable {
  const ReferenceChoices({
    this.targets = const {},
    this.labels = const {},
    this.secondary = const {},
  });

  /// Builds choices from loaded objects. A target missing from [objects] is
  /// still loading; pass an empty list for a target that failed or is empty.
  factory ReferenceChoices.fromObjects({
    required List<Collection> targets,
    required Map<String, List<MorkvaObject>> objects,
  }) {
    final labels = <String, Map<String, String>>{};
    final secondary = <String, String>{};
    for (final target in targets) {
      final list = objects[target.id];
      if (list == null) continue;
      labels[target.id] = objectLabels(target, list);
      secondary.addAll(_secondaryLines(target, list));
    }
    return ReferenceChoices(
      targets: {for (final t in targets) t.id: t},
      labels: labels,
      secondary: secondary,
    );
  }

  static const none = ReferenceChoices();

  /// Target collections by id.
  final Map<String, Collection> targets;

  /// Object labels (id → title, in the target's view order) by target id.
  /// A missing entry means the target is still loading.
  final Map<String, Map<String, String>> labels;

  /// The muted second line of an object in the picker, by object id.
  final Map<String, String> secondary;

  Collection? targetOf(ReferenceFieldDefinition field) =>
      targets[field.targetCollectionId];

  /// The target's labels, or null while they load.
  Map<String, String>? labelsFor(ReferenceFieldDefinition field) =>
      labels[field.targetCollectionId];

  String? secondaryOf(String objectId) => secondary[objectId];

  /// Up to two non-empty values from the target's first view, besides the
  /// title field, joined with " · ".
  static Map<String, String> _secondaryLines(
    Collection target,
    List<MorkvaObject> objects,
  ) {
    final title = target.fields.whereType<TextFieldDefinition>().firstOrNull;
    final view =
        target.views.firstOrNull ?? ViewDefinition.defaultFor(target.fields);
    final fields = [
      for (final id in view.fieldIds)
        if (target.fieldById(id) case final f?)
          // Nested references would only read "1 linked".
          if (f.id != title?.id && f is! ReferenceFieldDefinition) f,
    ];
    return {
      for (final o in objects)
        o.id: fields
            .map((f) => formatFieldValue(f, o[f.id] ?? f.emptyValue()))
            .where((text) => text.isNotEmpty)
            .take(2)
            .join(' · '),
    }..removeWhere((_, line) => line.isEmpty);
  }

  @override
  List<Object?> get props => [targets, labels, secondary];
}

/// A file the user picked, read into memory, ready to upload.
typedef PickedFile = ({String name, Uint8List bytes});

/// A file of one field being uploaded; [progress] runs 0…1.
class PendingUpload extends Equatable {
  const PendingUpload({
    required this.id,
    required this.fieldId,
    required this.name,
    this.progress = 0,
  });

  final String id;
  final String fieldId;
  final String name;
  final double progress;

  PendingUpload withProgress(double progress) =>
      PendingUpload(id: id, fieldId: fieldId, name: name, progress: progress);

  @override
  List<Object?> get props => [id, fieldId, name, progress];
}

/// File-field actions and uploads in flight for one field. Removing an
/// attachment is a plain [ValueEditorContext.onChanged] with the shorter
/// list; a failed upload's message is the form's error line.
class AttachmentActions {
  const AttachmentActions({
    required this.upload,
    required this.open,
    this.uploads = const [],
  });

  /// Uploads picked files into the field (appends, or replaces on a
  /// single-file field).
  final ValueChanged<List<PickedFile>> upload;

  /// Opens an attachment (download URL in a new tab / external app).
  final ValueChanged<FileAttachment> open;

  /// This field's uploads in flight.
  final List<PendingUpload> uploads;
}

/// Maps field-type discriminators to their [FieldValueEditor]s. The value-side
/// mirror of `FieldEditorRegistry`; a populated instance comes from
/// `defaultValueEditorRegistry()`.
class FieldValueEditorRegistry {
  FieldValueEditorRegistry();

  final Map<String, FieldValueEditor> _editors = {};

  /// Registers [editor], replacing any editor for the same type.
  void register(FieldValueEditor editor) {
    _editors[editor.typeId] = editor;
  }

  /// The editor for [typeId], or `null` if none is registered.
  FieldValueEditor? forType(String typeId) => _editors[typeId];

  /// The editor for [typeId], or a read-only "Can't edit … here" fallback.
  FieldValueEditor editorFor(String typeId) =>
      _editors[typeId] ?? UnsupportedValueEditor(typeId);
}
