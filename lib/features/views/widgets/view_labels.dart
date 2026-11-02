import 'package:flutter/material.dart';

import '../../../core/domain/domain.dart';
import '../../collections/field_editors/built_in_field_editors.dart';
import '../../../design/design.dart';

final _fieldEditors = defaultFieldEditorRegistry();

/// The noun for one object of [collection]: its name, lower-cased and naively
/// singularized ("Deals" → "deal", "Companies" → "company").
String itemLabelOf(Collection collection) {
  final name = collection.name.trim().toLowerCase();
  if (name.isEmpty) return 'item';
  if (name.endsWith('ies') && name.length > 3) {
    return '${name.substring(0, name.length - 3)}y';
  }
  if (name.endsWith('s') && !name.endsWith('ss') && name.length > 1) {
    return name.substring(0, name.length - 1);
  }
  return name;
}

/// The field type's icon, as the schema editor shows it.
IconData fieldTypeIcon(FieldDefinition field) =>
    _fieldEditors.forType(field.type)?.icon ?? Icons.notes;

/// The colour of a select option, or null.
Color? optionColor(FieldDefinition field, String? optionId) {
  final options = switch (field) {
    SingleSelectFieldDefinition(:final options) => options,
    MultiSelectFieldDefinition(:final options) => options,
    _ => const <SelectOption>[],
  };
  final hex = options.where((o) => o.id == optionId).firstOrNull?.color;
  return hex == null ? null : colorFromHex(hex);
}

/// Whether [field] reads best right-aligned with tabular digits.
bool isNumericField(FieldDefinition field) =>
    field is NumberFieldDefinition || field is AutoNumberFieldDefinition;

/// Whether [field] is the kind that may sit top-right on a card.
bool isMetricField(FieldDefinition field) =>
    isNumericField(field) || field is DateFieldDefinition;

/// Short text for a filter chip: "Stage is Lead, Won", "Amount > 100".
/// Reference ids show as their [referenceLabels] entry when known.
String filterLabel(
  ViewFilter filter,
  Collection collection, {
  Map<String, String> referenceLabels = const {},
}) {
  final field = collection.fieldById(filter.fieldId);
  if (field == null) return 'Unknown field';
  final operand = filter.operand;
  final value = switch (operand) {
    final List<Object?> ids => [
      for (final id in ids.whereType<String>())
        switch (field) {
          SingleSelectFieldDefinition(:final options) ||
          MultiSelectFieldDefinition(
            :final options,
          ) => options.where((o) => o.id == id).firstOrNull?.label ?? id,
          ReferenceFieldDefinition() => referenceLabels[id] ?? 'Unknown item',
          _ => id,
        },
    ].join(', '),
    null => '',
    final String day when field is DateFieldDefinition =>
      switch (DateTime.tryParse(day)) {
        final d? => formatFieldValue(
          DateFieldDefinition(id: field.id, name: field.name),
          DateFieldValue(DateTime.utc(d.year, d.month, d.day)),
        ),
        null => day,
      },
    _ => '$operand',
  };
  final count = operand is List ? operand.whereType<String>().length : 0;
  final has =
      field is MultiSelectFieldDefinition ||
      (field is ReferenceFieldDefinition && field.multiple);
  // One value reads as plain "is" / "has"; several keep "any of".
  final op = switch (filter.op) {
    FilterOp.anyOf when count == 1 => has ? 'has' : 'is',
    FilterOp.noneOf when count == 1 => has ? 'has no' : 'is not',
    final op => operatorLabel(op, field),
  };
  return [field.name, op, if (value.isNotEmpty) value].join(' ');
}

/// The words for [op] on [field], shared by filter chips and the builder.
String operatorLabel(FilterOp op, FieldDefinition field) => switch (op) {
  FilterOp.isEmpty => 'is empty',
  FilterOp.isNotEmpty => 'is not empty',
  FilterOp.equals => field is TextFieldDefinition ? 'is' : '=',
  FilterOp.notEquals => '≠',
  FilterOp.contains => 'contains',
  FilterOp.notContains => 'does not contain',
  FilterOp.greaterThan => '>',
  FilterOp.lessThan => '<',
  FilterOp.before => 'is before',
  FilterOp.after => 'is after',
  FilterOp.onDay => 'is on',
  FilterOp.anyOf =>
    field is MultiSelectFieldDefinition ||
            (field is ReferenceFieldDefinition && field.multiple)
        ? 'has any of'
        : 'is any of',
  FilterOp.noneOf =>
    field is MultiSelectFieldDefinition ? 'has none of' : 'is none of',
  FilterOp.isTrue => 'is checked',
  FilterOp.isFalse => 'is not checked',
};
