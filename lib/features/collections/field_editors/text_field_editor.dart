import 'package:flutter/material.dart';

import '../../../core/domain/domain.dart';
import '../../../l10n/l10n.dart';
import 'field_editor.dart';
import 'widgets/config_controls.dart';
import 'widgets/preview_affordances.dart';

/// [FieldEditor] for the free-text field type.
class TextFieldEditor extends FieldEditor {
  const TextFieldEditor();

  @override
  String get typeId => kTextFieldType;

  @override
  String label(AppLocalizations l10n) => l10n.collectionsTypeText;

  @override
  String description(AppLocalizations l10n) =>
      l10n.collectionsTypeTextDescription;

  @override
  IconData get icon => Icons.text_fields;

  @override
  FieldDefinition createDefault({required String id, required String name}) =>
      TextFieldDefinition(id: id, name: name);

  @override
  Widget buildConfigEditor(
    BuildContext context,
    FieldDefinition definition,
    ValueChanged<FieldDefinition> onChanged, {
    required List<Collection> collections,
    required String editingCollectionId,
  }) {
    final field = definition as TextFieldDefinition;
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConfigSwitch(
          label: l10n.collectionsMultiline,
          subtitle: l10n.collectionsMultilineHint,
          value: field.multiline,
          onChanged: (value) => onChanged(
            TextFieldDefinition(
              id: field.id,
              name: field.name,
              description: field.description,
              isRequired: field.isRequired,
              multiline: value,
              maxLength: field.maxLength,
            ),
          ),
        ),
        ConfigTextField(
          label: l10n.collectionsMaxLength,
          hint: l10n.collectionsNoLimit,
          value: field.maxLength?.toString() ?? '',
          keyboardType: TextInputType.number,
          onChanged: (text) => onChanged(
            TextFieldDefinition(
              id: field.id,
              name: field.name,
              description: field.description,
              isRequired: field.isRequired,
              multiline: field.multiline,
              maxLength: parseOptionalInt(text),
            ),
          ),
        ),
      ],
    );
  }

  @override
  String summarize(
    AppLocalizations l10n,
    FieldDefinition definition, {
    List<Collection> collections = const [],
  }) {
    final field = definition as TextFieldDefinition;
    final parts = <String>[
      if (field.multiline) l10n.collectionsSummaryMultiline,
      if (field.maxLength case final max?) l10n.collectionsSummaryMax(max),
    ];
    return parts.join(' · ');
  }

  @override
  Widget buildPreviewAffordance(
    BuildContext context,
    FieldDefinition definition,
  ) {
    final field = definition as TextFieldDefinition;
    return PreviewStubInput(height: field.multiline ? 56 : 36);
  }
}
