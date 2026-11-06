import '../collection.dart';
import '../types/auto_number_field.dart';

/// Numbers for the auto-number fields of a new object of [schema].
///
/// [values] are the object's encoded values (a field that already holds a
/// number keeps it — e.g. an object restored by Undo); [counters] the last
/// number handed out per field id. Returns the numbers to add to the values
/// and the counters to store (both empty when nothing was assigned).
({Map<String, int> assigned, Map<String, int> counters}) allocateSequences(
  Collection schema,
  Map<String, Object?> values,
  Map<String, Object?> counters,
) {
  final assigned = <String, int>{};
  final next = <String, int>{};
  for (final f in schema.fields.whereType<AutoNumberFieldDefinition>()) {
    final current = values[f.id];
    final last = (counters[f.id] as num?)?.toInt() ?? 0;
    if (current is num) {
      // Keep it, and never hand it out again.
      if (current > last) next[f.id] = current.toInt();
      continue;
    }
    final number = (last < f.start - 1 ? f.start - 1 : last) + 1;
    assigned[f.id] = number;
    next[f.id] = number;
  }
  return (assigned: assigned, counters: next);
}
