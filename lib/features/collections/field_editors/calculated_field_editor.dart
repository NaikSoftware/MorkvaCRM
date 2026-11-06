import 'package:flutter/material.dart';

import '../../../core/domain/domain.dart';
import 'field_editor.dart';
import 'widgets/calculation_config.dart';
import 'widgets/preview_affordances.dart';

/// [FieldEditor] for the calculated field type: a formula or an aggregate,
/// configured in [CalculationConfig].
class CalculatedFieldEditor extends FieldEditor {
  const CalculatedFieldEditor();

  @override
  String get typeId => kCalculatedFieldType;

  @override
  String get displayLabel => 'Calculated';

  @override
  String get description => 'A formula, or a total over linked items.';

  @override
  IconData get icon => Icons.functions;

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
    FieldDefinition definition, {
    List<Collection> collections = const [],
  }) {
    final field = definition as CalculatedFieldDefinition;
    final output =
        FormulaType.ofFieldType(field.declaredOutputType)?.label ??
        field.declaredOutputType;
    final a = field.aggregate;
    return a == null ? 'Formula → $output' : '${a.op.label} → $output';
  }

  @override
  Widget buildPreviewAffordance(
    BuildContext context,
    FieldDefinition definition,
  ) => const PreviewStubInput(icon: Icons.functions, height: 36);
}
