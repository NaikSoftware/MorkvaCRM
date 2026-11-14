import 'package:flutter/material.dart';

import '../../../core/domain/domain.dart';
import '../../collections/field_editors/built_in_field_editors.dart';
import '../../../design/design.dart';
import '../../../l10n/l10n.dart';

final _fieldEditors = defaultFieldEditorRegistry();

// The helpers below take [AppLocalizations] when the caller has a context;
// without it they follow the app's locale (`Intl.defaultLocale`).

/// What a view is sorted by ("Amount", "Created"), or null for manual order.
String? sortLabel(
  ViewSort? sort,
  Collection collection, {
  AppLocalizations? l10n,
}) => switch (sort?.fieldId) {
  null => null,
  ViewSort.createdAt => (l10n ?? currentAppStrings()).viewWidgetsSortCreated,
  ViewSort.updatedAt => (l10n ?? currentAppStrings()).viewWidgetsSortUpdated,
  final id => collection.fieldById(id)?.name,
};

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

/// One plain line saying what [field] of [owner] calculates:
/// "= {Price} * {Quantity}", "Sum of Quantity of Orders linking here via Item
/// where Status is Paid", "Count of all Orders".
String calculationSummary(
  CalculatedFieldDefinition field,
  Collection owner,
  Iterable<Collection> collections, {
  AppLocalizations? l10n,
}) {
  final t = l10n ?? currentAppStrings();
  if (field.lookup case final lookup?) {
    final ref = owner.fieldById(lookup.referenceFieldId);
    if (ref is! ReferenceFieldDefinition) {
      return t.viewWidgetsPickLookupReference;
    }
    final target = ref.targetCollectionId == owner.id
        ? owner
        : collections.where((c) => c.id == ref.targetCollectionId).firstOrNull;
    final shown = target?.fieldById(lookup.fieldId ?? '');
    if (target == null || shown == null) return t.viewWidgetsPickLookupField;
    return t.viewWidgetsLookupSummary(
      shown.name,
      itemLabelOf(target),
      ref.name,
    );
  }
  final a = field.aggregate;
  if (a == null) {
    final expression = field.expression?.trim() ?? '';
    return expression.isEmpty
        ? t.viewWidgetsNoFormulaYet
        : '= ${formulaToDisplay(expression, owner.fields)}';
  }
  Collection? byId(String? id) =>
      id == owner.id ? owner : collections.where((c) => c.id == id).firstOrNull;
  final ref = switch (a.source) {
    AggregateSource.linked => owner.fieldById(a.referenceFieldId ?? ''),
    AggregateSource.linkedFrom => byId(
      a.collectionId,
    )?.fieldById(a.referenceFieldId ?? ''),
    AggregateSource.all => null,
  };
  final source = byId(switch (ref) {
    ReferenceFieldDefinition(:final targetCollectionId)
        when a.source == AggregateSource.linked =>
      targetCollectionId,
    _ => a.collectionId,
  });
  if (source == null) return t.viewWidgetsPickAggregateSource;
  final op = t.aggregateOpLabel(a.op);
  final shown = source.fieldById(a.fieldId ?? '')?.name ?? '…';
  final refName = ref?.name ?? '…';
  final summary = switch ((a.op.needsField, a.source)) {
    (true, AggregateSource.linkedFrom) => t.viewWidgetsAggregateOfLinkingHere(
      op,
      shown,
      source.name,
      refName,
    ),
    (true, AggregateSource.linked) => t.viewWidgetsAggregateOfLinked(
      op,
      shown,
      source.name,
      refName,
    ),
    (true, AggregateSource.all) => t.viewWidgetsAggregateOfAll(
      op,
      shown,
      source.name,
    ),
    (false, AggregateSource.linkedFrom) => t.viewWidgetsCountLinkingHere(
      source.name,
      refName,
    ),
    (false, AggregateSource.linked) => t.viewWidgetsCountLinked(
      source.name,
      refName,
    ),
    (false, AggregateSource.all) => t.viewWidgetsCountAll(source.name),
  };
  final where = [
    for (final f in a.filters)
      if (source.fieldById(f.fieldId) != null) filterLabel(f, source, l10n: t),
  ];
  if (where.isEmpty) return summary;
  return t.viewWidgetsSummaryWhere(
    summary,
    where.join(t.viewWidgetsConditionSeparator),
  );
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
    field is NumberFieldDefinition ||
    field is AutoNumberFieldDefinition ||
    (field is CalculatedFieldDefinition &&
        field.declaredOutputType == kNumberFieldType);

/// Whether [field] is the kind that may sit top-right on a card.
bool isMetricField(FieldDefinition field) =>
    isNumericField(field) ||
    field is DateFieldDefinition ||
    (field is CalculatedFieldDefinition &&
        field.declaredOutputType == kDateFieldType);

/// Short text for a filter chip: "Stage is Lead, Won", "Amount > 100".
/// Reference ids show as their [referenceLabels] entry when known.
String filterLabel(
  ViewFilter filter,
  Collection collection, {
  Map<String, String> referenceLabels = const {},
  AppLocalizations? l10n,
}) {
  final t = l10n ?? currentAppStrings();
  final field = switch (collection.fieldById(filter.fieldId)) {
    CalculatedFieldDefinition(:final outputField) => outputField,
    final f => f,
  };
  if (field == null) return t.viewWidgetsUnknownField;
  final operand = filter.operand;
  final value = switch (operand) {
    final List<Object?> ids => [
      for (final id in ids.whereType<String>())
        switch (field) {
          SingleSelectFieldDefinition(:final options) ||
          MultiSelectFieldDefinition(
            :final options,
          ) => options.where((o) => o.id == id).firstOrNull?.label ?? id,
          ReferenceFieldDefinition() =>
            referenceLabels[id] ?? t.viewWidgetsUnknownItem,
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
    FilterOp.anyOf when count == 1 =>
      has ? t.viewWidgetsOpHas : t.viewWidgetsOpIs,
    FilterOp.noneOf when count == 1 =>
      has ? t.viewWidgetsOpHasNo : t.viewWidgetsOpIsNot,
    final op => operatorLabel(op, field, l10n: t),
  };
  // Ukrainian reads "Стадія: Лід" / "Теги: містить VIP" — the colon carries
  // "is" and keeps the verb clear of the field name's number.
  return t.viewWidgetsFilterChip(
    field.name,
    [op, value].where((s) => s.isNotEmpty).join(' '),
  );
}

/// The words for [op] on [field], shared by filter chips and the builder.
String operatorLabel(
  FilterOp op,
  FieldDefinition field, {
  AppLocalizations? l10n,
}) {
  final t = l10n ?? currentAppStrings();
  return switch (op) {
    FilterOp.isEmpty => t.viewWidgetsOpIsEmpty,
    FilterOp.isNotEmpty => t.viewWidgetsOpIsNotEmpty,
    FilterOp.equals =>
      field is TextFieldDefinition ? t.viewWidgetsOpEquals : '=',
    FilterOp.notEquals => '≠',
    FilterOp.contains => t.viewWidgetsOpContains,
    FilterOp.notContains => t.viewWidgetsOpNotContains,
    FilterOp.greaterThan => '>',
    FilterOp.lessThan => '<',
    FilterOp.before => t.viewWidgetsOpBefore,
    FilterOp.after => t.viewWidgetsOpAfter,
    FilterOp.onDay => t.viewWidgetsOpOnDay,
    FilterOp.anyOf =>
      field is MultiSelectFieldDefinition ||
              (field is ReferenceFieldDefinition && field.multiple)
          ? t.viewWidgetsOpHasAnyOf
          : t.viewWidgetsOpIsAnyOf,
    FilterOp.noneOf =>
      field is MultiSelectFieldDefinition
          ? t.viewWidgetsOpHasNoneOf
          : t.viewWidgetsOpIsNoneOf,
    FilterOp.isTrue => t.viewWidgetsOpIsChecked,
    FilterOp.isFalse => t.viewWidgetsOpIsNotChecked,
  };
}
