import 'package:flutter/material.dart';

import '../../../core/domain/domain.dart';
import '../../../l10n/l10n.dart';
import 'field_editor.dart';
import 'widgets/calculation_config.dart';
import 'widgets/preview_affordances.dart';
import 'package:morkva_crm/design/morkva_icons.dart';

/// [FieldEditor] for the calculated field type: a formula or an aggregate,
/// configured in [CalculationConfig].
class CalculatedFieldEditor extends FieldEditor {
  const CalculatedFieldEditor();

  @override
  String get typeId => kCalculatedFieldType;

  @override
  String label(AppLocalizations l10n) => l10n.collectionsTypeCalculated;

  @override
  String description(AppLocalizations l10n) =>
      l10n.collectionsTypeCalculatedDescription;

  @override
  IconData get icon => MorkvaIcons.formula;

  @override
  bool get isComputed => true;

  @override
  FieldDefinition createDefault({required String id, required String name}) =>
      CalculatedFieldDefinition(
        id: id,
        name: name,
        declaredOutputType: kNumberFieldType,
      );

  @override
  Widget buildConfigEditor(
    BuildContext context,
    FieldDefinition definition,
    ValueChanged<FieldDefinition> onChanged, {
    required List<Collection> collections,
    required String editingCollectionId,
  }) => CalculationConfig(
    key: ValueKey('calc_${definition.id}'),
    field: definition as CalculatedFieldDefinition,
    collections: collections,
    editingCollectionId: editingCollectionId,
    onChanged: onChanged,
  );

  @override
  String summarize(
    AppLocalizations l10n,
    FieldDefinition definition, {
    List<Collection> collections = const [],
  }) {
    final field = definition as CalculatedFieldDefinition;
    final type = FormulaType.ofFieldType(field.declaredOutputType);
    final output = type == null
        ? field.declaredOutputType
        : l10n.formulaTypeLabel(type);
    if (field.isLookup) return l10n.collectionsModeLookup;
    final a = field.aggregate;
    return a == null
        ? l10n.collectionsSummaryFormula(output)
        : '${l10n.aggregateOpLabel(a.op)} → $output';
  }

  @override
  Widget buildPreviewAffordance(
    BuildContext context,
    FieldDefinition definition,
  ) => const PreviewStubInput(icon: MorkvaIcons.formula, height: 36);
}
