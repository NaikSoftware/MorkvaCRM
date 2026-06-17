import 'package:flutter/material.dart';

import '../../../core/domain/domain.dart';
import '../../../design/design.dart';
import 'field_editor.dart';
import 'widgets/config_controls.dart';

/// [FieldEditor] for the reference field type (link to another collection).
class ReferenceFieldEditor extends FieldEditor {
  const ReferenceFieldEditor();

  @override
  String get typeId => kReferenceFieldType;

  @override
  String get displayLabel => 'Reference';

  @override
  String get description => 'Link to objects in another collection.';

  @override
  IconData get icon => Icons.link;

  @override
  FieldDefinition createDefault({required String id, required String name}) =>
      // Empty target until the author picks one (a non-blocking warning until
      // then). Stored as a valid document; the editor flags it inline.
      ReferenceFieldDefinition(id: id, name: name, targetCollectionId: '');

  @override
  Widget buildConfigEditor(
    BuildContext context,
    FieldDefinition definition,
    ValueChanged<FieldDefinition> onChanged, {
    required List<Collection> collections,
    required String editingCollectionId,
  }) {
    final field = definition as ReferenceFieldDefinition;

    ReferenceFieldDefinition update({
      String? targetCollectionId,
      bool? multiple,
    }) => ReferenceFieldDefinition(
      id: field.id,
      name: field.name,
      description: field.description,
      isRequired: field.isRequired,
      targetCollectionId: targetCollectionId ?? field.targetCollectionId,
      multiple: multiple ?? field.multiple,
    );

    // The current target may not be among `collections` (e.g. a freshly added
    // field whose target is still empty). Use a null value in that case so the
    // dropdown shows its hint instead of asserting on an unknown value.
    final hasTarget = collections.any((c) => c.id == field.targetCollectionId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: Spacing.sm),
          child: DropdownButtonFormField<String>(
            initialValue: hasTarget ? field.targetCollectionId : null,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Target collection',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            hint: const Text('Choose a collection'),
            items: [
              for (final collection in collections)
                DropdownMenuItem(
                  value: collection.id,
                  child: Text(
                    collection.id == editingCollectionId
                        ? '${collection.name} (this collection)'
                        : collection.name,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (value) {
              if (value != null) onChanged(update(targetCollectionId: value));
            },
          ),
        ),
        ConfigSwitch(
          label: 'Allow multiple',
          subtitle: 'Reference more than one object.',
          value: field.multiple,
          onChanged: (value) => onChanged(update(multiple: value)),
        ),
      ],
    );
  }

  @override
  String summarize(FieldDefinition definition) {
    final field = definition as ReferenceFieldDefinition;
    if (field.targetCollectionId.isEmpty) return 'no target';
    final arrow = field.multiple ? '→ many' : '→';
    return '$arrow ${field.targetCollectionId}';
  }
}
