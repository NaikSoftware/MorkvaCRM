import 'package:flutter/material.dart';

import '../../../core/domain/domain.dart';
import '../../../design/design.dart';
import 'field_editor.dart';
import 'widgets/config_controls.dart';

/// [FieldEditor] for the calculated field type.
///
/// Declared-only in this epic: the output type and expression persist, but
/// evaluation ships in a later update (see [isComputed]).
class CalculatedFieldEditor extends FieldEditor {
  const CalculatedFieldEditor();

  /// The output types a calculation may declare (the simple, non-computed
  /// scalar types). The author picks one so a later evaluator knows how to
  /// format the cached result.
  static const Map<String, String> outputTypes = {
    kTextFieldType: 'Text',
    kNumberFieldType: 'Number',
    kBooleanFieldType: 'Yes / No',
    kDateFieldType: 'Date',
  };

  @override
  String get typeId => kCalculatedFieldType;

  @override
  String get displayLabel => 'Calculated';

  @override
  String get description => 'A value derived from a formula.';

  @override
  IconData get icon => Icons.functions;

  @override
  bool get isComputed => true;

  @override
  FieldDefinition createDefault({required String id, required String name}) =>
      CalculatedFieldDefinition(
        id: id,
        name: name,
        declaredOutputType: kTextFieldType,
      );

  @override
  Widget buildConfigEditor(
    BuildContext context,
    FieldDefinition definition,
    ValueChanged<FieldDefinition> onChanged, {
    required List<Collection> collections,
    required String editingCollectionId,
  }) {
    final field = definition as CalculatedFieldDefinition;

    CalculatedFieldDefinition update({
      String? declaredOutputType,
      String? Function()? expression,
    }) => CalculatedFieldDefinition(
      id: field.id,
      name: field.name,
      description: field.description,
      isRequired: field.isRequired,
      declaredOutputType: declaredOutputType ?? field.declaredOutputType,
      expression: expression == null ? field.expression : expression(),
    );

    // Tolerate a stored output type that is not in our offered list (e.g. set
    // by a future module): fall back to no selection rather than asserting.
    final knownOutput = outputTypes.containsKey(field.declaredOutputType);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ComputedLaterBanner(
          message:
              'Formulas are evaluated in a later update. '
              'Your output type and expression are saved now.',
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: Spacing.sm),
          child: DropdownButtonFormField<String>(
            initialValue: knownOutput ? field.declaredOutputType : null,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Output type',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            items: [
              for (final entry in outputTypes.entries)
                DropdownMenuItem(value: entry.key, child: Text(entry.value)),
            ],
            onChanged: (value) {
              if (value != null) onChanged(update(declaredOutputType: value));
            },
          ),
        ),
        TextFormField(
          initialValue: field.expression ?? '',
          minLines: 2,
          maxLines: 4,
          onChanged: (text) =>
              onChanged(update(expression: () => text.isEmpty ? null : text)),
          decoration: const InputDecoration(
            labelText: 'Expression',
            hintText: 'e.g. price * quantity',
            isDense: true,
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  @override
  String summarize(FieldDefinition definition) {
    final field = definition as CalculatedFieldDefinition;
    final outputLabel =
        outputTypes[field.declaredOutputType] ?? field.declaredOutputType;
    return '→ $outputLabel';
  }
}
