import 'package:flutter/material.dart';

import '../../../core/domain/domain.dart';
import '../collection_views_cubit.dart';
import '../collection_views_state.dart';

/// What a mode renders from, plus the page actions it may trigger. Modes
/// read [state]; they never query. Object commands go to
/// `context.read<CollectionViewsCubit>()`.
class ViewModeData {
  const ViewModeData({
    required this.state,
    required this.itemLabel,
    required this.openObject,
    required this.quickAdd,
    required this.editFields,
    required this.notify,
  });

  final ViewsReady state;

  /// The noun for one object, e.g. "deal" ("+ New deal").
  final String itemLabel;

  /// Opens the read-only detail sheet of an object.
  final ValueChanged<MorkvaObject> openObject;

  /// Opens the quick-add dialog, pre-filling a board group or a day.
  final void Function({String? groupKey, DateTime? day}) quickAdd;

  /// Opens Columns / Setup card.
  final VoidCallback editFields;

  /// Shows a snackbar, with an Undo action when [undo] is given.
  final void Function(String message, {ViewUndo? undo}) notify;
}

/// A way to draw a view's objects (Table, Board, …). Register one in
/// [ViewModeRegistry]; nothing else changes to add a mode.
abstract class ViewMode {
  const ViewMode();

  /// Stable id stored in [ViewDefinition.mode] (see [ViewModeIds]).
  String get id;
  String get label;

  /// Tab / picker icon (Material Symbols via [Icons]).
  IconData get icon;

  /// One line for the new-view picker.
  String get description;

  /// Whether a view in this mode needs a layout field (Board, Calendar).
  bool get needsLayoutField => false;

  /// Whether [field] can be this mode's layout field.
  bool acceptsLayoutField(FieldDefinition field) => false;

  /// Why [collection] can't use this mode (e.g. "Needs a date field"), or
  /// null when it can.
  String? unavailableReason(Collection collection) => null;

  /// Label of the toolbar button that edits the shown fields.
  String get fieldsLabel => 'Setup card';

  /// The mode's data area.
  Widget buildBody(BuildContext context, ViewModeData data);

  /// The toolbar chip for the mode's setting ("Group: Stage"), if any.
  Widget? buildSettingsChip(BuildContext context, ViewModeData data) => null;
}

/// The modes this client knows, in picker order.
class ViewModeRegistry {
  ViewModeRegistry(List<ViewMode> modes)
    : assert(modes.isNotEmpty),
      modes = List.unmodifiable(modes);

  final List<ViewMode> modes;

  ViewMode? byId(String id) => modes.where((m) => m.id == id).firstOrNull;

  /// The mode for [id]; an unknown id (a view from a newer client) falls back
  /// to the first mode, Table.
  ViewMode resolve(String id) => byId(id) ?? modes.first;
}
