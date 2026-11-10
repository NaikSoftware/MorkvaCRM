/// The `FieldSpec` shape: how a caller describes a field to add or change, in
/// friendly wire form (`target`, `options: [label]`, `formula` in name form).
/// Planners convert it to domain JSON; this file only states and checks the
/// shape. `docs/domain-json-schema.md` is out of date and not used.
library;

import '../../domain/calc/aggregation.dart';
import '../../domain/types/auto_number_field.dart';
import '../../domain/types/boolean_field.dart';
import '../../domain/types/calculated_field.dart';
import '../../domain/types/date_field.dart';
import '../../domain/types/file_field.dart';
import '../../domain/types/multi_select_field.dart';
import '../../domain/types/number_field.dart';
import '../../domain/types/reference_field.dart';
import '../../domain/types/single_select_field.dart';
import '../../domain/types/text_field.dart';
import '../api/envelope.dart';
import 'arg_shapes.dart';
import 'json_schema.dart';

/// The collection icon ids, copied from `CollectionIcons.all` in
/// `lib/design/collection_icons.dart` (Flutter) so the pure-Dart harness can
/// validate them. A test keeps the two lists equal.
const List<String> kCollectionIconIds = [
  'cards',
  'grid',
  'box',
  'truck',
  'cart',
  'bag',
  'tag',
  'people',
  'person',
  'business',
  'store',
  'money',
  'receipt',
  'calendar',
  'task',
  'folder',
  'note',
  'star',
  'flag',
  'home',
  'car',
  'build',
  'pets',
  'restaurant',
];

/// A collection icon; an unknown id fails with the valid ids as candidates.
Map<String, Object?> collectionIconSchema() =>
    JsonSchema.enumOf(kCollectionIconIds, description: 'Collection icon.');

/// The config keys each field type takes in a FieldSpec, beyond the common
/// `ref`, `name`, `type`, `required` and `description`. A type that is
/// registered but missing here cannot be authored through the harness.
const Map<String, List<String>> kFieldConfigKeys = {
  kTextFieldType: ['multiline', 'maxLength'],
  kNumberFieldType: ['decimalPlaces', 'unitLabel', 'min', 'max'],
  kBooleanFieldType: [],
  kDateFieldType: ['includeTime', 'min', 'max'],
  kSingleSelectFieldType: ['options'],
  kMultiSelectFieldType: ['options'],
  kReferenceFieldType: ['target', 'multiple'],
  kFileFieldType: ['multiple', 'allowedExtensions'],
  kAutoNumberFieldType: ['prefix', 'padding', 'start'],
  kCalculatedFieldType: [
    'formula',
    'aggregate',
    'lookup',
    'decimalPlaces',
    'unitLabel',
  ],
};

/// The keys every FieldSpec may carry.
const List<String> kFieldCommonKeys = [
  'ref',
  'name',
  'type',
  'required',
  'description',
];

/// The calculated-field sources; a calculated FieldSpec takes exactly one.
const List<String> kCalculatedSourceKeys = ['formula', 'aggregate', 'lookup'];

/// The schema of every config key across all types (the union the flat
/// FieldSpec object offers). Reused by `fields.update`'s patch.
Map<String, Map<String, Object?>> fieldConfigSchemas() => {
  'multiline': JsonSchema.boolean(description: 'text: several lines.'),
  'maxLength': JsonSchema.integer(minimum: 1, description: 'text.'),
  'decimalPlaces': JsonSchema.integer(
    minimum: 0,
    maximum: 10,
    description: 'number, calculated.',
  ),
  'unitLabel': JsonSchema.string(
    description: 'number, calculated: unit such as USD or kg.',
  ),
  'min': JsonSchema.anyOf([
    JsonSchema.number(),
    JsonSchema.string(),
  ], description: 'number: a number; date: YYYY-MM-DD or ISO.'),
  'max': JsonSchema.anyOf([
    JsonSchema.number(),
    JsonSchema.string(),
  ], description: 'number: a number; date: YYYY-MM-DD or ISO.'),
  'includeTime': JsonSchema.boolean(description: 'date: has a time of day.'),
  'options': JsonSchema.array(
    JsonSchema.anyOf([
      JsonSchema.string(),
      JsonSchema.object(
        {
          'label': JsonSchema.string(),
          'color': JsonSchema.string(description: '#RRGGBB'),
        },
        required: ['label'],
      ),
    ]),
    minItems: 1,
    description: 'single_select, multi_select: option labels.',
  ),
  'target': refSchema(
    description:
        'reference: the linked collection (id, name, or @ref of one created '
        'in the same call).',
  ),
  'multiple': JsonSchema.boolean(
    description: 'reference, file: allow several.',
  ),
  'allowedExtensions': JsonSchema.array(
    JsonSchema.string(),
    description: 'file: e.g. ["pdf", "png"].',
  ),
  'prefix': JsonSchema.string(description: 'auto_number: e.g. "INV-".'),
  'padding': JsonSchema.integer(
    minimum: 0,
    maximum: 12,
    description: 'auto_number: zero-pad to this many digits.',
  ),
  'start': JsonSchema.integer(
    minimum: 0,
    description: 'auto_number: first number.',
  ),
  'formula': JsonSchema.string(
    description: 'calculated: e.g. "{Price} * {Qty}".',
  ),
  'aggregate': JsonSchema.object(
    {
      'source': JsonSchema.enumOf([
        for (final s in AggregateSource.values) s.name,
      ]),
      'collection': refSchema(),
      'referenceField': refSchema(),
      'op': JsonSchema.enumOf([for (final op in AggregateOp.values) op.name]),
      'field': refSchema(),
      'where': whereSchema(),
    },
    required: ['source', 'collection', 'op'],
    description: 'calculated: summarize linked or all cards.',
  ),
  'lookup': JsonSchema.object(
    {'via': refSchema(), 'field': refSchema()},
    required: ['via'],
    description: 'calculated: show a field of the linked card.',
  ),
};

/// The FieldSpec object for the field types in [registeredTypes] (pass
/// `FieldTypeRegistry.registeredTypes`) that have config keys here.
Map<String, Object?> fieldSpecSchema(Iterable<String> registeredTypes) {
  final types = [
    for (final t in registeredTypes)
      if (kFieldConfigKeys.containsKey(t)) t,
  ];
  final used = {for (final t in types) ...kFieldConfigKeys[t]!};
  final config = fieldConfigSchemas();
  return JsonSchema.object(
    {
      'ref': JsonSchema.string(
        description: 'An @placeholder other specs in the call can refer to.',
      ),
      'name': JsonSchema.string(),
      'type': JsonSchema.enumOf(types),
      'required': JsonSchema.boolean(),
      'description': JsonSchema.string(),
      for (final key in config.keys)
        if (used.contains(key)) key: config[key]!,
    },
    required: ['name', 'type'],
  );
}

/// The type-specific rules the flat schema cannot state: config keys must
/// belong to the spec's `type`, `min`/`max` must have that type's form, and a
/// calculated field needs exactly one of formula, aggregate or lookup. Run
/// after [JsonSchema.validate] passed; [path] prefixes each problem's path
/// (e.g. `fields[2]`).
List<ErrorDetail> checkFieldSpec(
  Map<String, Object?> spec, {
  String path = '',
}) {
  String at(String key) => path.isEmpty ? key : '$path.$key';
  final type = spec['type'];
  final allowed = kFieldConfigKeys[type];
  if (type is! String || allowed == null) {
    return [
      ErrorDetail(
        path: at('type'),
        code: ErrorCode.invalidArgs,
        message: 'Unknown field type "$type".',
        candidates: kFieldConfigKeys.keys.toList(),
      ),
    ];
  }
  final problems = <ErrorDetail>[];
  for (final key in spec.keys) {
    if (kFieldCommonKeys.contains(key) || allowed.contains(key)) continue;
    if (spec[key] == null) continue;
    problems.add(
      ErrorDetail(
        path: at(key),
        code: ErrorCode.invalidArgs,
        message: allowed.isEmpty
            ? '"$key" does not apply to a $type field, which takes no config.'
            : '"$key" does not apply to a $type field. '
                  'It takes: ${allowed.join(', ')}.',
        candidates: allowed,
      ),
    );
  }
  for (final key in const ['min', 'max']) {
    final value = spec[key];
    if (value == null) continue;
    if (type == kNumberFieldType && value is! num) {
      problems.add(_wrong(at(key), '"$key" of a number field is a number.'));
    } else if (type == kDateFieldType &&
        (value is! String || DateTime.tryParse(value) == null)) {
      problems.add(
        _wrong(at(key), '"$key" of a date field is YYYY-MM-DD or ISO-8601.'),
      );
    }
  }
  if (type == kCalculatedFieldType) {
    final sources = [
      for (final key in kCalculatedSourceKeys)
        if (spec[key] != null) key,
    ];
    if (sources.length != 1) {
      problems.add(
        ErrorDetail(
          path: path,
          code: ErrorCode.invalidArgs,
          message: sources.isEmpty
              ? 'A calculated field needs one of formula, aggregate or lookup.'
              : 'A calculated field takes only one of ${sources.join(', ')}.',
          candidates: kCalculatedSourceKeys,
        ),
      );
    }
  }
  return problems;
}

ErrorDetail _wrong(String path, String message) =>
    ErrorDetail(path: path, code: ErrorCode.invalidArgs, message: message);
