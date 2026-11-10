import '../api/capability.dart';
import '../api/operation.dart';
import '../plan/planners/card_create_planner.dart';
import '../plan/planners/collection_planners.dart';
import '../plan/planners/field_planners.dart';
import '../plan/planners/plan_call.dart';
import '../schema/arg_shapes.dart';
import '../schema/field_specs.dart';
import '../schema/json_schema.dart';

/// The schema plan ops: `collections.create/update/delete` and
/// `fields.add/update/delete`. Registered by `registerPlanOps`.
List<PlanOperation> schemaOps(PlanServices services) => [
  _CollectionsCreate(services),
  _SchemaOp(services, _collectionsUpdate, planCollectionsUpdate),
  _CollectionsDelete(services),
  _SchemaOp(services, _fieldsAdd(services), planFieldsAdd),
  _SchemaOp(services, _fieldsUpdate, planFieldsUpdate),
  _SchemaOp(services, _fieldsDelete, planFieldsDelete),
];

typedef _Planner =
    Future<void> Function(Map<String, Object?> args, PlanCall call);

/// A plan op described by its descriptor and planned by a planner function.
class _SchemaOp extends PlanOperation {
  _SchemaOp(super.services, this.descriptor, this._planner);

  @override
  final OperationDescriptor descriptor;
  final _Planner _planner;

  @override
  Future<void> plan(Map<String, Object?> args, PlanCall call) =>
      _planner(args, call);
}

Map<String, Object?> _fieldSpec(PlanServices s) =>
    fieldSpecSchema(s.registry.registeredTypes);

final class _CollectionsCreate extends _SchemaOp {
  _CollectionsCreate(PlanServices s)
    : super(
        s,
        OperationDescriptor(
          id: 'collections.create',
          kind: OpKind.plan,
          capability: Capability.schemaWrite,
          summary:
              'Plans new collections with their fields (and optional seed '
              'cards). Give each a ref like "@suppliers" so link fields and '
              'cards in the same call or turn can name it.',
          argsSchema: JsonSchema.object(
            {
              'collections': JsonSchema.array(
                JsonSchema.object(
                  {
                    'ref': JsonSchema.string(description: '"@x".'),
                    'name': JsonSchema.string(),
                    'description': JsonSchema.string(),
                    'icon': collectionIconSchema(),
                    'fields': JsonSchema.array(
                      _fieldSpec(s),
                      maxItems: kMaxNewFields,
                    ),
                  },
                  required: ['name', 'fields'],
                ),
                minItems: 1,
                maxItems: kMaxNewCollections,
              ),
              'cards': JsonSchema.array(
                JsonSchema.object(
                  {
                    'collection': refSchema(
                      description: 'The @ref of a collection created here.',
                    ),
                    'ref': JsonSchema.string(),
                    'values': valuesSchema(),
                  },
                  required: ['collection', 'values'],
                ),
                minItems: 1,
                maxItems: kMaxCreateCards,
              ),
            },
            required: ['collections'],
          ),
          resultSchema: planCallResultSchema(),
        ),
        planCollectionsCreate,
      );

  /// Seed cards are data, so they need `data:write` too.
  @override
  Iterable<Capability> requiredCapabilities(Map<String, Object?> args) => [
    ...super.requiredCapabilities(args),
    if (args['cards'] case final List cards when cards.isNotEmpty)
      Capability.dataWrite,
  ];
}

final class _CollectionsDelete extends _SchemaOp {
  _CollectionsDelete(PlanServices s)
    : super(
        s,
        OperationDescriptor(
          id: 'collections.delete',
          kind: OpKind.plan,
          capability: Capability.schemaDelete,
          summary:
              'Plans deleting a whole collection and its cards. Send it on '
              'its own, with no other change in the same turn.',
          argsSchema: JsonSchema.object(
            {'collection': refSchema()},
            required: ['collection'],
          ),
          resultSchema: planCallResultSchema(),
        ),
        planCollectionsDelete,
      );

  @override
  bool get standalone => true;
}

final OperationDescriptor _collectionsUpdate = OperationDescriptor(
  id: 'collections.update',
  kind: OpKind.plan,
  capability: Capability.schemaWrite,
  summary: 'Plans renaming a collection or changing its description or icon.',
  argsSchema: JsonSchema.object(
    {
      'collection': refSchema(),
      'name': JsonSchema.string(),
      'description': JsonSchema.string(),
      'icon': collectionIconSchema(),
    },
    required: ['collection'],
  ),
  resultSchema: planCallResultSchema(),
);

OperationDescriptor _fieldsAdd(PlanServices s) => OperationDescriptor(
  id: 'fields.add',
  kind: OpKind.plan,
  capability: Capability.schemaWrite,
  summary:
      'Plans adding fields to a collection (added to every view). Fill a '
      'new field from others with cards.update setFrom.',
  argsSchema: JsonSchema.object(
    {
      'collection': refSchema(),
      'fields': JsonSchema.array(
        _fieldSpec(s),
        minItems: 1,
        maxItems: kMaxAddFields,
      ),
      'after': refSchema(description: 'Place them after this field.'),
    },
    required: ['collection', 'fields'],
  ),
  resultSchema: planCallResultSchema(),
);

final OperationDescriptor _fieldsUpdate = OperationDescriptor(
  id: 'fields.update',
  kind: OpKind.plan,
  capability: Capability.schemaWrite,
  summary:
      'Plans changing a field: name, description, required, settings and '
      'options (add, rename, remove). The type is locked: add a new field '
      'and fill it with cards.update setFrom instead.',
  argsSchema: JsonSchema.object(
    {
      'collection': refSchema(),
      'field': refSchema(),
      'patch': JsonSchema.object({
        // Accepted so a type change reaches the planner's type_locked hint.
        'type': JsonSchema.string(description: 'Locked; always refused.'),
        'name': JsonSchema.string(),
        'description': JsonSchema.string(),
        'required': JsonSchema.boolean(),
        ...fieldConfigSchemas(),
        'addOptions': JsonSchema.array(
          JsonSchema.object(
            {
              'label': JsonSchema.string(),
              'color': JsonSchema.string(description: '#RRGGBB'),
            },
            required: ['label'],
          ),
          minItems: 1,
        ),
        'renameOptions': JsonSchema.array(
          JsonSchema.object(
            {'option': refSchema(), 'label': JsonSchema.string()},
            required: ['option', 'label'],
          ),
          minItems: 1,
        ),
        'removeOptions': JsonSchema.array(
          refSchema(
            description: 'An option to remove; cards using it are cleared.',
          ),
          minItems: 1,
        ),
      }),
    },
    required: ['collection', 'field', 'patch'],
  ),
  resultSchema: planCallResultSchema(),
);

final OperationDescriptor _fieldsDelete = OperationDescriptor(
  id: 'fields.delete',
  kind: OpKind.plan,
  capability: Capability.schemaDelete,
  summary:
      'Plans deleting fields (and their filters, sort and columns in views). '
      'Card values are kept, so undo brings them back.',
  argsSchema: JsonSchema.object(
    {
      'collection': refSchema(),
      'fields': JsonSchema.array(
        refSchema(),
        minItems: 1,
        maxItems: kMaxDeleteFields,
      ),
    },
    required: ['collection', 'fields'],
  ),
  resultSchema: planCallResultSchema(),
);
