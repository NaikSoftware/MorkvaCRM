import 'package:flutter/material.dart';

import '../../../core/domain/domain.dart';
import 'field_editor.dart';

/// [FieldEditor] for the boolean (true/false) field type.
///
/// The boolean type carries no per-type config, so the config editor shows a
/// short explanatory note. Name / description / required are edited by the host
/// panel's common envelope.
class BooleanFieldEditor extends FieldEditor {
  const BooleanFieldEditor();

  @override
  String get typeId => kBooleanFieldType;

  @override
  String get displayLabel => 'Yes / No';

  @override
  String get description => 'A simple true/false toggle.';

  @override
  IconData get icon => Icons.toggle_on_outlined;

  @override
  FieldDefinition createDefault({required String id, required String name}) =>
      BooleanFieldDefinition(id: id, name: name);

  @override
  Widget buildConfigEditor(
    BuildContext context,
    FieldDefinition definition,
    ValueChanged<FieldDefinition> onChanged, {
    required List<Collection> collections,
    required String editingCollectionId,
  }) {
    return Text(
      'A yes/no field has no extra settings.',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  @override
  String summarize(FieldDefinition definition) => '';
}
