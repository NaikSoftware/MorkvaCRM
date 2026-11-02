import 'package:equatable/equatable.dart';

import '../collection.dart';
import '../field_definition.dart';
import '../field_value.dart';
import '../morkva_object.dart';
import '../types/date_field.dart';
import '../types/reference_field.dart';
import '../types/single_select_field.dart';
import 'field_format.dart';

/// One board column: the objects whose layout field equals [key].
class ViewGroup extends Equatable {
  const ViewGroup({
    required this.key,
    required this.label,
    this.color,
    this.objects = const [],
  });

  /// Option id / referenced object id, or null for the `No <field>` group.
  final String? key;
  final String label;

  /// The select option's color, if any.
  final String? color;
  final List<MorkvaObject> objects;

  @override
  List<Object?> get props => [key, label, color, objects];
}

/// Objects bucketed by calendar day of a date field.
class DayBuckets extends Equatable {
  const DayBuckets({this.days = const {}, this.undated = const []});

  /// Local-midnight day → objects on it, keys in ascending order.
  final Map<DateTime, List<MorkvaObject>> days;

  /// Objects with an empty date (the "No date" tray).
  final List<MorkvaObject> undated;

  @override
  List<Object?> get props => [days, undated];
}

/// Whether objects can be grouped by [field] (board columns, list
/// sections): a single-select or a single reference.
bool isGroupable(FieldDefinition? field) =>
    field is SingleSelectFieldDefinition ||
    (field is ReferenceFieldDefinition && !field.multiple);

/// Fields a board can group by (see [isGroupable]).
List<FieldDefinition> groupableFields(Collection collection) => [
  for (final f in collection.fields)
    if (isGroupable(f)) f,
];

/// Splits [ordered] into groups by [field], keeping each group in [ordered]'s
/// order. Empty groups are kept; the `No <field>` group comes last.
///
/// Select: one group per option in option order. Reference: one group per
/// entry of [referenceLabels] in its iteration order (the caller passes the
/// target collection's objects in display order). A value pointing at an
/// unknown option / object lands in the `No <field>` group.
List<ViewGroup> groupObjects(
  FieldDefinition field,
  List<MorkvaObject> ordered, {
  Map<String, String> referenceLabels = const {},
}) {
  final heads = <(String, String, String?)>[
    if (field is SingleSelectFieldDefinition)
      for (final o in field.options) (o.id, o.label, o.color)
    else if (field is ReferenceFieldDefinition)
      for (final e in referenceLabels.entries) (e.key, e.value, null),
  ];
  final buckets = {for (final (id, _, _) in heads) id: <MorkvaObject>[]};
  final none = <MorkvaObject>[];
  for (final o in ordered) {
    final key = switch (o[field.id]) {
      SingleSelectFieldValue(:final optionId) => optionId,
      ReferenceFieldValue(:final objectIds) => objectIds.firstOrNull,
      _ => null,
    };
    (buckets[key] ?? none).add(o);
  }
  return [
    for (final (id, label, color) in heads)
      ViewGroup(key: id, label: label, color: color, objects: buckets[id]!),
    ViewGroup(key: null, label: 'No ${field.name}', objects: none),
  ];
}

/// Buckets [ordered] by the calendar day of [field] (see [calendarDayOf]),
/// keeping [ordered]'s order inside a day.
DayBuckets bucketByDay(DateFieldDefinition field, List<MorkvaObject> ordered) {
  final days = <DateTime, List<MorkvaObject>>{};
  final undated = <MorkvaObject>[];
  for (final o in ordered) {
    final value = o[field.id];
    final dt = value is DateFieldValue ? value.value : null;
    if (dt == null) {
      undated.add(o);
    } else {
      days.putIfAbsent(calendarDayOf(field, dt), () => []).add(o);
    }
  }
  final keys = days.keys.toList()..sort();
  return DayBuckets(
    days: {for (final k in keys) k: days[k]!},
    undated: undated,
  );
}

/// The value to write into [field] when an object is dropped on group [key]
/// (null = the `No <field>` group). Throws [ArgumentError] for a field that
/// is not groupable.
FieldValue groupValueFor(FieldDefinition field, String? key) => switch (field) {
  SingleSelectFieldDefinition() => SingleSelectFieldValue(key),
  ReferenceFieldDefinition() => ReferenceFieldValue(
    key == null ? const [] : [key],
  ),
  _ => throw ArgumentError.value(field.type, 'field', 'not groupable'),
};

/// [current] moved to calendar [day] (only its year/month/day are read).
///
/// A field with time keeps the local time of day of [current] (midnight when
/// empty); a date-only field stores the day as UTC midnight, like
/// [DateFieldDefinition] normalizes it.
DateFieldValue withDay(
  DateFieldDefinition field,
  DateFieldValue current,
  DateTime day,
) {
  if (!field.includeTime) {
    return DateFieldValue(DateTime.utc(day.year, day.month, day.day));
  }
  final t = current.value?.toLocal();
  return DateFieldValue(
    DateTime(
      day.year,
      day.month,
      day.day,
      t?.hour ?? 0,
      t?.minute ?? 0,
      t?.second ?? 0,
      t?.millisecond ?? 0,
    ).toUtc(),
  );
}
