import '../collection.dart';
import '../field_definition.dart';
import '../types/calculated_field.dart';
import '../types/file_field.dart';
import '../types/reference_field.dart';

/// Whether a lookup can show [field]: a value, not links or files.
bool isLookupable(FieldDefinition field) =>
    field is! ReferenceFieldDefinition && field is! FileFieldDefinition;

/// The field [lookup] of [owner] shows, as it presents (a calculated
/// target as its output), or null when its reference or field is gone.
FieldDefinition? lookupTargetOf(
  Collection owner,
  CalculatedFieldDefinition lookup,
  Iterable<Collection> collections,
) {
  final config = lookup.lookup;
  if (config == null) return null;
  final ref = owner.fieldById(config.referenceFieldId);
  if (ref is! ReferenceFieldDefinition) return null;
  final target = ref.targetCollectionId == owner.id
      ? owner
      : collections.where((c) => c.id == ref.targetCollectionId).firstOrNull;
  final field = target?.fieldById(config.fieldId ?? '');
  if (field == null || !isLookupable(field)) return null;
  return field is CalculatedFieldDefinition ? field.outputField : field;
}

/// [collections] with every lookup field's [CalculatedFieldDefinition.lookupTarget]
/// filled from the current schemas, so lookups format, filter and sort as
/// the field they show. Lookups of lookups resolve too (a few levels deep).
List<Collection> resolveLookups(List<Collection> collections) {
  if (!collections.any(_hasLookup)) return collections;
  var current = collections;
  // Each pass resolves one more level of lookup-of-lookup chains.
  for (var pass = 0; pass < 4; pass++) {
    var changed = false;
    final next = [
      for (final c in current)
        if (!_hasLookup(c))
          c
        else
          c.copyWith(
            fields: [
              for (final f in c.fields)
                if (f is CalculatedFieldDefinition && f.isLookup)
                  () {
                    final target = lookupTargetOf(c, f, current);
                    if (target == f.lookupTarget) return f;
                    changed = true;
                    return f.copyWith(
                      lookupTarget: target,
                      declaredOutputType: target?.type ?? f.declaredOutputType,
                    );
                  }()
                else
                  f,
            ],
          ),
    ];
    if (!changed) return current;
    current = next;
  }
  return current;
}

bool _hasLookup(Collection c) =>
    c.fields.any((f) => f is CalculatedFieldDefinition && f.isLookup);
