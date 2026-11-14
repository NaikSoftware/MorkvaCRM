import 'package:flutter/material.dart';

import '../../../core/domain/domain.dart';
import '../../../l10n/l10n.dart';
import 'field_editor.dart';
import 'widgets/option_set_editor.dart';
import 'widgets/preview_affordances.dart';
import 'package:morkva_crm/design/morkva_icons.dart';

/// [FieldEditor] for the multi-select (tags) field type.
class MultiSelectFieldEditor extends FieldEditor {
  const MultiSelectFieldEditor();

  @override
  String get typeId => kMultiSelectFieldType;

  @override
  String label(AppLocalizations l10n) => l10n.collectionsTypeMultiSelect;

  @override
  String description(AppLocalizations l10n) =>
      l10n.collectionsTypeMultiSelectDescription;

  @override
  IconData get icon => MorkvaIcons.checklist;

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
    AppLocalizations l10n,
    FieldDefinition definition, {
    List<Collection> collections = const [],
  }) {
    final field = definition as MultiSelectFieldDefinition;
    return l10n.collectionsOptionCount(field.options.length);
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
