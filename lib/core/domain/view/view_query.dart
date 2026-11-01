import '../collection.dart';
import '../field_definition.dart';
import '../field_value.dart';
import '../morkva_object.dart';
import '../types/auto_number_field.dart';
import '../types/boolean_field.dart';
import '../types/calculated_field.dart';
import '../types/date_field.dart';
import '../types/multi_select_field.dart';
import '../types/number_field.dart';
import '../types/reference_field.dart';
import '../types/single_select_field.dart';
import '../types/text_field.dart';
import 'field_format.dart';
import 'view_definition.dart';

const _empties = [FilterOp.isEmpty, FilterOp.isNotEmpty];

/// The filter operators that apply to [field], in menu order.
List<FilterOp> operatorsFor(FieldDefinition field) => switch (field) {
  TextFieldDefinition() => const [
    FilterOp.contains,
    FilterOp.notContains,
    FilterOp.equals,
    ..._empties,
  ],
  NumberFieldDefinition() || AutoNumberFieldDefinition() => const [
    FilterOp.equals,
    FilterOp.notEquals,
    FilterOp.greaterThan,
    FilterOp.lessThan,
    ..._empties,
  ],
  DateFieldDefinition() => const [
    FilterOp.before,
    FilterOp.after,
    FilterOp.onDay,
    ..._empties,
  ],
  SingleSelectFieldDefinition() || MultiSelectFieldDefinition() => const [
    FilterOp.anyOf,
    FilterOp.noneOf,
    ..._empties,
  ],
  BooleanFieldDefinition() => const [FilterOp.isTrue, FilterOp.isFalse],
  ReferenceFieldDefinition() => const [FilterOp.anyOf, ..._empties],
  _ => _empties,
};

/// Whether [value] of [field] passes [filter]. (Not named `matches`, which
/// would clash with the `flutter_test` matcher of that name.)
///
/// Negative operators (notEquals, notContains, noneOf) pass empty values;
/// positive ones (equals, contains, anyOf, greaterThan, lessThan, before,
/// after, onDay) fail them. `isFalse` passes an unset boolean. Text matching
/// is case-insensitive. A filter whose operator does not apply to the field or
/// whose operand is missing / of the wrong type is ignored (passes).
bool matchesFilter(ViewFilter filter, FieldDefinition field, FieldValue value) {
  final op = filter.op;
  if (!operatorsFor(field).contains(op)) return true;
  if (op == FilterOp.isEmpty) return value.isEmpty;
  if (op == FilterOp.isNotEmpty) return value.isNotEmpty;
  final operand = filter.operand;

  switch (value) {
    case BooleanFieldValue(value: final b):
      return op == FilterOp.isTrue ? b == true : b != true;

    case TextFieldValue(:final text):
      if (operand is! String) return true;
      final t = (text ?? '').toLowerCase();
      final o = operand.toLowerCase();
      return switch (op) {
        FilterOp.contains => text != null && text.isNotEmpty && t.contains(o),
        FilterOp.notContains => !t.contains(o) || t.isEmpty,
        _ => text != null && text.isNotEmpty && t == o,
      };

    case NumberFieldValue() || AutoNumberFieldValue():
      if (operand is! num) return true;
      final n = value is NumberFieldValue
          ? value.value
          : (value as AutoNumberFieldValue).sequence;
      if (n == null) return op == FilterOp.notEquals;
      return switch (op) {
        FilterOp.equals => n == operand,
        FilterOp.notEquals => n != operand,
        FilterOp.greaterThan => n > operand,
        _ => n < operand,
      };

    case DateFieldValue(value: final dt):
      final day = _operandDay(operand);
      if (day == null) return true;
      if (dt == null) return false;
      final valueDay = calendarDayOf(field as DateFieldDefinition, dt);
      return switch (op) {
        FilterOp.before => valueDay.isBefore(day),
        FilterOp.after => valueDay.isAfter(day),
        _ => valueDay == day,
      };

    case SingleSelectFieldValue() ||
        MultiSelectFieldValue() ||
        ReferenceFieldValue():
      if (operand is! List) return true;
      final wanted = operand.whereType<String>().toSet();
      final ids = switch (value) {
        SingleSelectFieldValue(:final optionId) =>
          value.isEmpty ? const <String>[] : [optionId!],
        MultiSelectFieldValue(:final optionIds) => optionIds,
        ReferenceFieldValue(:final objectIds) => objectIds,
        _ => const <String>[],
      };
      final hit = ids.any(wanted.contains);
      return op == FilterOp.anyOf ? hit : !hit;
  }
  return true;
}

/// A `YYYY-MM-DD` (or any ISO) operand as a local-midnight calendar day.
DateTime? _operandDay(Object? operand) {
  if (operand is! String) return null;
  final parsed = DateTime.tryParse(operand);
  if (parsed == null) return null;
  final d = parsed.isUtc ? parsed.toLocal() : parsed;
  return DateTime(d.year, d.month, d.day);
}

/// [objects] that pass every filter of [view] (AND), ordered by its sort or,
/// when it has none, by its manual order.
///
/// Sorting puts empty values last in both directions; ties keep `createdAt`
/// order. Manual order lists the known ids first (stale ids ignored, first
/// occurrence wins), then the rest oldest first. A sort on a field the
/// collection no longer has falls back to manual order.
List<MorkvaObject> applyView(
  Collection collection,
  ViewDefinition view,
  List<MorkvaObject> objects,
) {
  final filters = [
    for (final f in view.filters)
      if (collection.fieldById(f.fieldId) case final field?) (f, field),
  ];
  final kept = objects.where((o) {
    for (final (filter, field) in filters) {
      if (!matchesFilter(filter, field, o[field.id] ?? field.emptyValue())) {
        return false;
      }
    }
    return true;
  }).toList()..sort(_byCreated);

  final sort = view.sort;
  final Object? Function(MorkvaObject)? keyOf = switch (sort?.fieldId) {
    ViewSort.createdAt => (o) => o.createdAt,
    ViewSort.updatedAt => (o) => o.updatedAt,
    final String id => switch (collection.fieldById(id)) {
      final field? => (o) => _sortKey(field, o[id] ?? field.emptyValue()),
      null => null,
    },
    null => null,
  };

  if (sort == null || keyOf == null) {
    final rank = <String, int>{};
    for (final id in view.manualOrder) {
      rank.putIfAbsent(id, () => rank.length);
    }
    final listed = kept.where((o) => rank.containsKey(o.id)).toList()
      ..sort((a, b) => rank[a.id]!.compareTo(rank[b.id]!));
    return [...listed, ...kept.where((o) => !rank.containsKey(o.id))];
  }

  final keys = {for (final o in kept) o.id: keyOf(o)};
  final sign = sort.ascending ? 1 : -1;
  return kept..sort((a, b) {
    final ka = keys[a.id];
    final kb = keys[b.id];
    if (ka == null && kb == null) return _byCreated(a, b);
    if (ka == null) return 1;
    if (kb == null) return -1;
    final c = _compareKeys(ka, kb) * sign;
    return c != 0 ? c : _byCreated(a, b);
  });
}

int _byCreated(MorkvaObject a, MorkvaObject b) {
  final c = a.createdAt.compareTo(b.createdAt);
  return c != 0 ? c : a.id.compareTo(b.id);
}

int _compareKeys(Object a, Object b) {
  if (a is num && b is num) return a.compareTo(b);
  if (a is DateTime && b is DateTime) return a.compareTo(b);
  return a.toString().compareTo(b.toString());
}

/// The comparable sort key of [value], or null when empty. Select sorts by
/// option order (an unknown option after all known ones); booleans false
/// before true; everything else without a natural order by its formatted text.
Object? _sortKey(FieldDefinition field, FieldValue value) {
  if (value.isEmpty) return null;
  return switch ((field, value)) {
    (_, TextFieldValue(:final text)) => text!.toLowerCase(),
    (_, NumberFieldValue(:final value)) => value,
    (_, AutoNumberFieldValue(:final sequence)) => sequence,
    (_, DateFieldValue(:final value)) => value,
    (_, BooleanFieldValue(:final value)) => value! ? 1 : 0,
    (
      SingleSelectFieldDefinition(:final options),
      SingleSelectFieldValue(:final optionId),
    ) =>
      switch (options.indexWhere((o) => o.id == optionId)) {
        -1 => options.length,
        final i => i,
      },
    (_, CalculatedFieldValue(:final cached)) =>
      cached is num ? cached : '$cached'.toLowerCase(),
    _ => formatFieldValue(field, value).toLowerCase(),
  };
}

/// The title of [object] in [view]: the formatted value of the view's first
/// field, or `'Untitled'` when that is empty or missing.
String titleOf(
  ViewDefinition view,
  Collection collection,
  MorkvaObject object,
) {
  final firstId = view.fieldIds.firstOrNull;
  final field = firstId == null ? null : collection.fieldById(firstId);
  if (field == null) return 'Untitled';
  final text = formatFieldValue(field, object[field.id] ?? field.emptyValue());
  return text.trim().isEmpty ? 'Untitled' : text;
}
