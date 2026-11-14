import 'package:flutter/material.dart';

import '../../../core/domain/domain.dart';
import '../../../l10n/l10n.dart';
import 'field_editor.dart';
import 'widgets/option_set_editor.dart';
import 'widgets/preview_affordances.dart';
import 'package:morkva_crm/design/morkva_icons.dart';

/// [FieldEditor] for the single-select field type.
class SingleSelectFieldEditor extends FieldEditor {
  const SingleSelectFieldEditor();

  @override
  String get typeId => kSingleSelectFieldType;

  @override
  String label(AppLocalizations l10n) => l10n.collectionsTypeSingleSelect;

  @override
  String description(AppLocalizations l10n) =>
      l10n.collectionsTypeSingleSelectDescription;

  @override
  IconData get icon => MorkvaIcons.dropdownField;

  @override
  FieldDefinition createDefault({required String id, required String name}) =>
      SingleSelectFieldDefinition(id: id, name: name);

  @override
  Widget buildConfigEditor(
    BuildContext context,
    FieldDefinition definition,
    ValueChanged<FieldDefinition> onChanged, {
    required List<Collection> collections,
    required String editingCollectionId,
  }) {
    final field = definition as SingleSelectFieldDefinition;
    return OptionSetEditor(
      options: field.options,
      onChanged: (options) => onChanged(
        SingleSelectFieldDefinition(
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
    final field = definition as SingleSelectFieldDefinition;
    return l10n.collectionsOptionCount(field.options.length);
  }

  @override
  Widget buildPreviewAffordance(
    BuildContext context,
    FieldDefinition definition,
  ) {
    final field = definition as SingleSelectFieldDefinition;
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
