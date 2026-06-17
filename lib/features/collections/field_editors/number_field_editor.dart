import 'package:flutter/material.dart';

import '../../../core/domain/domain.dart';
import 'field_editor.dart';
import 'widgets/config_controls.dart';
import 'widgets/preview_affordances.dart';

/// [FieldEditor] for the numeric field type.
class NumberFieldEditor extends FieldEditor {
  const NumberFieldEditor();

  @override
  String get typeId => kNumberFieldType;

  @override
  String get displayLabel => 'Number';

  @override
  String get description => 'A numeric value, optionally bounded.';

  @override
  IconData get icon => Icons.numbers;

  @override
  FieldDefinition createDefault({required String id, required String name}) =>
      NumberFieldDefinition(id: id, name: name);

  @override
  Widget buildConfigEditor(
    BuildContext context,
    FieldDefinition definition,
    ValueChanged<FieldDefinition> onChanged, {
    required List<Collection> collections,
    required String editingCollectionId,
  }) {
    final field = definition as NumberFieldDefinition;

    NumberFieldDefinition update({
      int? Function()? decimalPlaces,
      String? Function()? unitLabel,
      num? Function()? min,
      num? Function()? max,
    }) => NumberFieldDefinition(
      id: field.id,
      name: field.name,
      description: field.description,
      isRequired: field.isRequired,
      decimalPlaces: decimalPlaces == null
          ? field.decimalPlaces
          : decimalPlaces(),
      unitLabel: unitLabel == null ? field.unitLabel : unitLabel(),
      min: min == null ? field.min : min(),
      max: max == null ? field.max : max(),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConfigTextField(
          label: 'Decimal places',
          hint: 'Whole number',
          value: field.decimalPlaces?.toString() ?? '',
          keyboardType: TextInputType.number,
          onChanged: (text) =>
              onChanged(update(decimalPlaces: () => parseOptionalInt(text))),
        ),
        ConfigTextField(
          label: 'Unit label',
          hint: 'e.g. kg, \$',
          value: field.unitLabel ?? '',
          onChanged: (text) => onChanged(
            update(unitLabel: () => text.trim().isEmpty ? null : text.trim()),
          ),
        ),
        ConfigTextField(
          label: 'Minimum',
          hint: 'No minimum',
          value: field.min?.toString() ?? '',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (text) =>
              onChanged(update(min: () => parseOptionalNum(text))),
        ),
        ConfigTextField(
          label: 'Maximum',
          hint: 'No maximum',
          value: field.max?.toString() ?? '',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (text) =>
              onChanged(update(max: () => parseOptionalNum(text))),
        ),
      ],
    );
  }

  @override
  String summarize(
    FieldDefinition definition, {
    List<Collection> collections = const [],
  }) {
    final field = definition as NumberFieldDefinition;
    final parts = <String>[
      if (field.unitLabel != null) field.unitLabel!,
      if (field.decimalPlaces != null) '${field.decimalPlaces} dp',
      if (field.min != null || field.max != null)
        '${field.min ?? '–'}…${field.max ?? '–'}',
    ];
    return parts.join(' · ');
  }

  @override
  Widget buildPreviewAffordance(
    BuildContext context,
    FieldDefinition definition,
  ) => const PreviewStubInput(height: 36);
}
