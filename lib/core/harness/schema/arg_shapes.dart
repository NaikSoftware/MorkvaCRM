/// The shared argument and result shapes of the harness ops (the spec's
/// `$defs`), as schema builders. Ops compose them, so they arrive inlined.
library;

import '../../domain/view/view_definition.dart';
import 'json_schema.dart';

/// The two meta fields every card has; usable wherever a field ref is.
const String kCreatedAtRef = '@createdAt';
const String kUpdatedAtRef = '@updatedAt';

/// The relative dates a filter may use instead of a literal date. The harness
/// expands them from `HarnessContext.today`; callers never compute them.
const List<String> kRelativeDates = [
  'today',
  'yesterday',
  'tomorrow',
  'this_week',
  'last_week',
  'this_month',
  'last_month',
  'this_year',
  'last_n_days',
  'next_n_days',
];

/// An id (`c_…`, `f_…`, `v_…`, `o_…`, `b_…`) or a name, label or title,
/// matched case-insensitively.
Map<String, Object?> refSchema({String? description}) => JsonSchema.string(
  description:
      description ?? 'An id, or a name/label/title (case-insensitive).',
);

/// A field ref, or `@createdAt` / `@updatedAt`.
Map<String, Object?> fieldRefSchema({String? description}) => JsonSchema.string(
  description:
      description ?? 'A field id or name, or $kCreatedAtRef / $kUpdatedAtRef.',
);

/// One field value in friendly form: text, a number, a bool, a date string
/// (`YYYY-MM-DD` or ISO), an option label, a card title or id, or a list of
/// those for multi-select and multi-reference fields.
Map<String, Object?> anyValueSchema({String? description}) {
  final scalar = [
    JsonSchema.string(),
    JsonSchema.number(),
    JsonSchema.boolean(),
  ];
  return JsonSchema.anyOf([
    ...scalar,
    JsonSchema.array(JsonSchema.anyOf(scalar)),
  ], description: description);
}

/// `{field, op, value?, relative?, n?}`; the op enum is every [FilterOp].
Map<String, Object?> filterSchema() => JsonSchema.object(
  {
    'field': fieldRefSchema(),
    'op': JsonSchema.enumOf([for (final op in FilterOp.values) op.name]),
    'value': anyValueSchema(
      description: 'The operand; a list for anyOf/noneOf.',
    ),
    'relative': JsonSchema.enumOf(
      kRelativeDates,
      description: 'A date relative to today, instead of value.',
    ),
    'n': JsonSchema.integer(
      minimum: 1,
      description: 'Days for last_n_days / next_n_days.',
    ),
  },
  required: ['field', 'op'],
);

/// AND-ed filters; never empty (an empty `where` would match every card).
Map<String, Object?> whereSchema({int maxItems = 10}) => JsonSchema.array(
  filterSchema(),
  minItems: 1,
  maxItems: maxItems,
  description: 'Filters, all of which must match.',
);

/// `{field, dir}`.
Map<String, Object?> sortSchema() => JsonSchema.object(
  {
    'field': fieldRefSchema(),
    'dir': JsonSchema.enumOf(const ['asc', 'desc']),
  },
  required: ['field', 'dir'],
);

/// `{fieldRef: value}`: the one free-form map of the API.
Map<String, Object?> valuesSchema({String? description}) => JsonSchema.mapOf(
  anyValueSchema(),
  description: description ?? 'Field name or id → value.',
);

/// Which cards a change applies to: `{ids}` or `{where}`.
Map<String, Object?> targetSchema({int maxIds = 500}) => JsonSchema.anyOf([
  JsonSchema.object(
    {
      'ids': JsonSchema.array(
        JsonSchema.string(),
        minItems: 1,
        maxItems: maxIds,
      ),
    },
    required: ['ids'],
  ),
  JsonSchema.object({'where': whereSchema()}, required: ['where']),
], description: 'Card ids, or filters matching the cards.');

/// A card in a result: `{id, title, v: {fieldName: displayValue}}`, empty
/// values omitted; `createdAt`/`updatedAt` only when asked for.
Map<String, Object?> cardSchema() => JsonSchema.object(
  {
    'id': JsonSchema.string(),
    'title': JsonSchema.string(),
    'v': JsonSchema.mapOf(
      JsonSchema.anyOf([
        ...[JsonSchema.string(), JsonSchema.number(), JsonSchema.boolean()],
        JsonSchema.array(
          JsonSchema.anyOf([
            JsonSchema.string(),
            JsonSchema.object({
              'id': JsonSchema.string(),
              'title': JsonSchema.string(),
            }),
          ]),
        ),
      ]),
    ),
    'createdAt': JsonSchema.string(),
    'updatedAt': JsonSchema.string(),
  },
  required: ['id', 'title', 'v'],
);
