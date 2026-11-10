import '../api/capability.dart';
import '../api/operation.dart';
import '../plan/planners/card_create_planner.dart';
import '../plan/planners/card_delete_planner.dart';
import '../plan/planners/card_update_planner.dart';
import '../plan/planners/plan_call.dart';
import '../plan/planners/targets.dart';
import '../schema/arg_shapes.dart';
import '../schema/json_schema.dart';

/// The card plan ops: `cards.create`, `cards.update`, `cards.delete`.
/// Registered by `registerPlanOps`.
List<PlanOperation> cardOps(PlanServices services) => [
  _CardsCreate(services),
  _CardsUpdate(services),
  _CardsDelete(services),
];

final class _CardsCreate extends PlanOperation {
  _CardsCreate(super.services);

  @override
  late final OperationDescriptor descriptor = OperationDescriptor(
    id: 'cards.create',
    kind: OpKind.plan,
    capability: Capability.dataWrite,
    summary:
        'Plans new cards (shown to the user for approval, nothing is written '
        'yet). Give a card a "ref" like "@c1" to link to it from later calls.',
    argsSchema: JsonSchema.object(
      {
        'collection': refSchema(
          description: 'A collection id, name, or @ref from this turn.',
        ),
        'cards': JsonSchema.array(
          JsonSchema.object(
            {
              'ref': JsonSchema.string(description: '"@c1": a turn-local ref.'),
              'values': valuesSchema(),
            },
            required: ['values'],
          ),
          minItems: 1,
          maxItems: kMaxCreateCards,
        ),
      },
      required: ['collection', 'cards'],
    ),
    resultSchema: planCallResultSchema(),
  );

  @override
  Future<void> plan(Map<String, Object?> args, PlanCall call) =>
      planCardsCreate(args, call);
}

final class _CardsUpdate extends PlanOperation {
  _CardsUpdate(super.services);

  @override
  late final OperationDescriptor descriptor = OperationDescriptor(
    id: 'cards.update',
    kind: OpKind.plan,
    capability: Capability.dataWrite,
    summary:
        'Plans changes to cards: set/clear/setFrom/add/remove on a target, '
        'or per-card patches. Use setFrom for computed or copied values and '
        'add/remove for one tag or link; pass expectedCount for filters.',
    argsSchema: JsonSchema.object(
      {
        'collection': refSchema(),
        'target': writeTargetSchema(),
        'set': valuesSchema(description: 'Field → new value for the target.'),
        'clear': JsonSchema.array(
          fieldRefSchema(description: 'A field to empty.'),
          minItems: 1,
        ),
        'setFrom': JsonSchema.array(
          JsonSchema.object(
            {
              'field': refSchema(description: 'The field to fill.'),
              'from': refSchema(description: 'Copy this field.'),
              'formula': JsonSchema.string(
                description: 'Compute it, e.g. "{Price} * 1.1".',
              ),
            },
            required: ['field'],
          ),
          minItems: 1,
          maxItems: kMaxSetFrom,
        ),
        'add': valuesSchema(
          description: 'Multi-select / multi-link field → values to add.',
        ),
        'remove': valuesSchema(
          description: 'Multi-select / multi-link field → values to remove.',
        ),
        'patches': JsonSchema.array(
          JsonSchema.object(
            {'id': JsonSchema.string(), 'set': valuesSchema()},
            required: ['id', 'set'],
          ),
          minItems: 1,
          maxItems: kMaxPatches,
        ),
        'expectedCount': JsonSchema.integer(
          minimum: 0,
          description: 'How many cards the target matched when you queried.',
        ),
      },
      required: ['collection'],
    ),
    resultSchema: planCallResultSchema(),
  );

  @override
  Future<void> plan(Map<String, Object?> args, PlanCall call) =>
      planCardsUpdate(args, call);
}

final class _CardsDelete extends PlanOperation {
  _CardsDelete(super.services);

  @override
  late final OperationDescriptor descriptor = OperationDescriptor(
    id: 'cards.delete',
    kind: OpKind.plan,
    capability: Capability.dataDelete,
    summary:
        'Plans deleting cards (undoable for 10 minutes once applied). '
        'Filters and {"screen": true} need expectedCount.',
    argsSchema: JsonSchema.object(
      {
        'collection': refSchema(),
        'target': writeTargetSchema(),
        'expectedCount': JsonSchema.integer(minimum: 0),
      },
      required: ['collection', 'target'],
    ),
    resultSchema: planCallResultSchema(),
  );

  @override
  Future<void> plan(Map<String, Object?> args, PlanCall call) =>
      planCardsDelete(args, call);
}
