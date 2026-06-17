import 'package:flutter/widgets.dart';

import '../../../core/domain/domain.dart';

/// The UI-side counterpart to a domain field type.
///
/// Where [FieldTypeRegistry] knows how to (de)serialize a [FieldDefinition],
/// a [FieldEditor] knows how to *present and configure* one in the schema
/// editor: its label/icon for pickers and rows, a sensible default instance,
/// the widget that edits its per-type config, and a short summary string.
///
/// This is the single open-for-extension seam of the schema editor. The editor
/// screen and field rows dispatch through [FieldEditorRegistry] and never name a
/// concrete field type. Adding a field type is one registration line in
/// `built_in_field_editors.dart` (mirroring `built_in_field_types.dart`) — no
/// edits to the editor screen, exactly as a future JS-module field type would
/// register at runtime.
///
/// Domain definitions are immutable, so a [FieldEditor]'s config widget never
/// mutates the definition it is given: it builds and emits a replacement via the
/// `onChanged` callback.
abstract class FieldEditor {
  const FieldEditor();

  /// The type discriminator this editor handles; matches [FieldDefinition.type].
  String get typeId;

  /// Human-readable type name shown in the picker and the field's type badge.
  String get displayLabel;

  /// One-line description shown in the add-field type picker.
  String get description;

  /// Icon shown in the picker and on the field row.
  IconData get icon;

  /// Whether this type is *declared* now but computed in a later epic
  /// (`auto_number`, `calculated`). The UI tags these and shows a "computed
  /// later" note instead of pretending the value is live.
  bool get isComputed => false;

  /// A fresh definition of this type with sensible defaults, using [id]/[name].
  FieldDefinition createDefault({required String id, required String name});

  /// Builds the per-type config editor for [definition].
  ///
  /// Emits a replacement definition through [onChanged] on every edit. The
  /// common envelope (name, description, required) is edited by the host panel,
  /// not here — this widget edits only this type's own config keys.
  ///
  /// [collections] is the live collection list (the reference picker needs the
  /// available targets); [editingCollectionId] is the collection being edited
  /// (so a picker can mark self-references).
  Widget buildConfigEditor(
    BuildContext context,
    FieldDefinition definition,
    ValueChanged<FieldDefinition> onChanged, {
    required List<Collection> collections,
    required String editingCollectionId,
  });

  /// A short, human summary of [definition]'s config for the field row
  /// (e.g. "3 options", "→ Orders", "multiline"). Empty string when there is
  /// nothing useful to add beyond the type badge.
  ///
  /// [collections] is the workspace's collection list; editors that reference
  /// another collection (e.g. the reference type) resolve a human name from it
  /// rather than printing a raw id. Other editors ignore it.
  String summarize(
    FieldDefinition definition, {
    List<Collection> collections = const [],
  });

  /// Builds an inert, read-only silhouette of this type's value affordance for
  /// the card preview (a text stub, a switch shape, color-hinted chips, …).
  ///
  /// Strictly non-interactive: it shows the *shape* of a value, never any data
  /// entry (that is Epic 5). This is the registry seam that keeps the card
  /// preview free of any `switch (type)` over concrete field types.
  Widget buildPreviewAffordance(
    BuildContext context,
    FieldDefinition definition,
  );
}

/// Maps field-type discriminators to the [FieldEditor]s that present them.
///
/// The UI-layer mirror of [FieldTypeRegistry]. Built-in editors are registered
/// by `registerBuiltInFieldEditors`; a populated instance is provided by
/// `defaultFieldEditorRegistry()` (see `built_in_field_editors.dart`).
class FieldEditorRegistry {
  FieldEditorRegistry();

  final Map<String, FieldEditor> _editors = {};

  /// Registers [editor], replacing any previously registered editor for the
  /// same [FieldEditor.typeId].
  void register(FieldEditor editor) {
    _editors[editor.typeId] = editor;
  }

  /// The editor for [typeId], or `null` if none is registered.
  FieldEditor? forType(String typeId) => _editors[typeId];

  /// All registered editors, in registration order (the type-picker order).
  List<FieldEditor> get all => List.unmodifiable(_editors.values);
}
