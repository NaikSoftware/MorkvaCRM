import 'package:flutter/material.dart';

import '../../../core/domain/domain.dart';
import 'field_editor.dart';
import 'widgets/config_controls.dart';

/// [FieldEditor] for the auto-number field type.
///
/// Declared-only in this epic: the prefix/padding persist, but the engine that
/// allocates sequence numbers ships in a later update (see [isComputed]).
class AutoNumberFieldEditor extends FieldEditor {
  const AutoNumberFieldEditor();

  @override
  String get typeId => kAutoNumberFieldType;

  @override
  String get displayLabel => 'Auto number';

  @override
  String get description => 'An automatically assigned sequence number.';

  @override
  IconData get icon => Icons.tag;

  @override
  bool get isComputed => true;

  @override
  FieldDefinition createDefault({required String id, required String name}) =>
      AutoNumberFieldDefinition(id: id, name: name);

  @override
  Widget buildConfigEditor(
    BuildContext context,
    FieldDefinition definition,
    ValueChanged<FieldDefinition> onChanged, {
    required List<Collection> collections,
    required String editingCollectionId,
  }) {
    final field = definition as AutoNumberFieldDefinition;

    AutoNumberFieldDefinition update({
      String? Function()? prefix,
      int? Function()? padding,
    }) => AutoNumberFieldDefinition(
      id: field.id,
      name: field.name,
      description: field.description,
      isRequired: field.isRequired,
      prefix: prefix == null ? field.prefix : prefix(),
      padding: padding == null ? field.padding : padding(),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ComputedLaterBanner(
          message:
              'Numbers are assigned automatically in a later update. '
              'Your prefix and padding are saved now.',
        ),
        ConfigTextField(
          label: 'Prefix',
          hint: 'e.g. INV-',
          value: field.prefix ?? '',
          onChanged: (text) =>
              onChanged(update(prefix: () => text.isEmpty ? null : text)),
        ),
        ConfigTextField(
          label: 'Padding (digits)',
          hint: 'e.g. 5 → 00042',
          value: field.padding?.toString() ?? '',
          keyboardType: TextInputType.number,
          onChanged: (text) =>
              onChanged(update(padding: () => parseOptionalInt(text))),
        ),
      ],
    );
  }

  @override
  String summarize(FieldDefinition definition) {
    final field = definition as AutoNumberFieldDefinition;
    final parts = <String>[
      if (field.prefix != null) field.prefix!,
      if (field.padding != null) '${field.padding} digits',
    ];
    return parts.isEmpty ? 'auto' : parts.join(' · ');
  }
}
