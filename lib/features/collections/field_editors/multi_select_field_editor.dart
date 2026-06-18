import 'package:flutter/material.dart';

import '../../../core/domain/domain.dart';
import 'field_editor.dart';
import 'widgets/option_set_editor.dart';
import 'widgets/preview_affordances.dart';

/// [FieldEditor] for the multi-select (tags) field type.
class MultiSelectFieldEditor extends FieldEditor {
  const MultiSelectFieldEditor();

  @override
  String get typeId => kMultiSelectFieldType;

  @override
  String get displayLabel => 'Multi select';

  @override
  String get description => 'Pick any number of options (tags).';

  @override
  IconData get icon => Icons.checklist;

  @override
  FieldDefinition createDefault({required String id, required String name}) =>
      MultiSelectFieldDefinition(id: id, name: name);

  @override
  Widget buildConfigEditor(
    BuildContext context,
    FieldDefinition definition,
    ValueChanged<FieldDefinition> onChanged, {
    required List<Collection> collections,
    required String editingCollectionId,
  }) {
    final field = definition as MultiSelectFieldDefinition;
    return OptionSetEditor(
      options: field.options,
      onChanged: (options) => onChanged(
        MultiSelectFieldDefinition(
          id: field.id,
          name: field.name,
          description: field.description,
          isRequired: field.isRequired,
          options: options,
        ),
      ),
    );
  }

  @override
  String summarize(
    FieldDefinition definition, {
    List<Collection> collections = const [],
  }) {
    final field = definition as MultiSelectFieldDefinition;
    final count = field.options.length;
    return count == 1 ? '1 option' : '$count options';
  }

  @override
  Widget buildPreviewAffordance(
    BuildContext context,
    FieldDefinition definition,
  ) {
    final field = definition as MultiSelectFieldDefinition;
    final options = field.options;
    return PreviewStubChips(
      labels: options.isEmpty
          ? const ['—']
          : options.take(4).map((o) => o.label).toList(),
      colors: options.isEmpty
          ? const [null]
          : options.take(4).map((o) => o.color).toList(),
    );
  }
}
