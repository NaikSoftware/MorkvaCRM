import 'package:flutter/material.dart';

import '../../../core/domain/domain.dart';
import '../../../l10n/l10n.dart';
import 'field_editor.dart';
import 'widgets/config_controls.dart';
import 'widgets/preview_affordances.dart';

/// [FieldEditor] for the numeric field type.
class NumberFieldEditor extends FieldEditor {
  const NumberFieldEditor();

  @override
  String get typeId => kNumberFieldType;

  @override
  String label(AppLocalizations l10n) => l10n.collectionsTypeNumber;

  @override
  String description(AppLocalizations l10n) =>
      l10n.collectionsTypeNumberDescription;

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

    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConfigTextField(
          label: l10n.collectionsDecimalPlaces,
          hint: l10n.collectionsWholeNumber,
          value: field.decimalPlaces?.toString() ?? '',
          keyboardType: TextInputType.number,
          onChanged: (text) =>
              onChanged(update(decimalPlaces: () => parseOptionalInt(text))),
        ),
        ConfigTextField(
          label: l10n.collectionsUnitLabel,
          hint: l10n.collectionsUnitLabelHint,
          value: field.unitLabel ?? '',
          onChanged: (text) => onChanged(
            update(unitLabel: () => text.trim().isEmpty ? null : text.trim()),
          ),
        ),
        ConfigTextField(
          label: l10n.collectionsMinimum,
          hint: l10n.collectionsNoMinimum,
          value: field.min?.toString() ?? '',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (text) =>
              onChanged(update(min: () => parseOptionalNum(text))),
        ),
        ConfigTextField(
          label: l10n.collectionsMaximum,
          hint: l10n.collectionsNoMaximum,
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
    AppLocalizations l10n,
    FieldDefinition definition, {
    List<Collection> collections = const [],
  }) {
    final field = definition as NumberFieldDefinition;
    final parts = <String>[
      if (field.unitLabel != null) field.unitLabel!,
      if (field.decimalPlaces case final places?)
        l10n.collectionsSummaryDecimals(places),
      if (field.min != null || field.max != null)
        '${field.min ?? '–'}…${field.max ?? '–'}',
    ];
    return parts.join(' · ');
  }

  @override
  Widget buildPreviewAffordance(
    BuildContext context,
    FieldDefinition definition,
  ) => const PreviewStubInput(icon: Icons.numbers, height: 36);
}
