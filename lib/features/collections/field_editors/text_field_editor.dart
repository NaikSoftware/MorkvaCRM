import 'package:flutter/material.dart';

import '../../../core/domain/domain.dart';
import 'field_editor.dart';
import 'widgets/config_controls.dart';

/// [FieldEditor] for the free-text field type.
class TextFieldEditor extends FieldEditor {
  const TextFieldEditor();

  @override
  String get typeId => kTextFieldType;

  @override
  String get displayLabel => 'Text';

  @override
  String get description => 'Free text, single- or multi-line.';

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConfigSwitch(
          label: 'Multiline',
          subtitle: 'Allow line breaks in the value.',
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
          label: 'Max length',
          hint: 'No limit',
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
  String summarize(FieldDefinition definition) {
    final field = definition as TextFieldDefinition;
    final parts = <String>[
      if (field.multiline) 'multiline',
      if (field.maxLength != null) 'max ${field.maxLength}',
    ];
    return parts.join(' · ');
  }
}
