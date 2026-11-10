import '../api/capability.dart';
import '../api/envelope.dart';
import '../api/harness_context.dart';
import '../api/operation.dart';
import '../plan/plan_store.dart';
import '../plan/planners/plan_call.dart';
import '../schema/json_schema.dart';
import 'card_ops.dart';
import 'registry.dart';
import 'schema_ops.dart';

export '../plan/planners/plan_call.dart' show PlanServices;

/// Registers the plan ops (`collections.*`, `fields.*`,
/// `cards.create/update/delete`) and the plan protocol ops `plans.seal` and
/// `plans.get`. The view plan ops come with `registerViewOps`.
void registerPlanOps(OperationRegistry ops, PlanServices services) {
  for (final op in [...cardOps(services), ...schemaOps(services)]) {
    ops.register(op);
  }
  ops
    ..register(SealOperation(services.store))
    ..register(GetPlanOperation(services.store));
}

/// The plan JSON shape `plans.seal` and `plans.get` return (items are
/// described loosely: their data keys depend on the kind).
Map<String, Object?> planSchema() => JsonSchema.object({
  'planId': JsonSchema.string(),
  'turnId': JsonSchema.string(),
  'title': JsonSchema.string(),
  'risk': JsonSchema.enumOf(const ['low', 'medium', 'high']),
  'createdBy': JsonSchema.object({
    'actor': JsonSchema.string(),
    'grants': {'type': 'object'},
  }),
  'createdAt': JsonSchema.string(),
  'expiresAt': JsonSchema.string(),
  'itemCount': JsonSchema.integer(minimum: 0),
  'items': JsonSchema.array({
    'type': 'object',
    'description':
        'itemId, callId, kind, label, collectionId, targetId?, risk, '
        'changes[{fieldId?, field, beforeText?, afterText?}], detail?, '
        'dependsOn?, plus the kind\'s data.',
  }),
  'moreItems': JsonSchema.integer(minimum: 1),
  'sharedChange': {'type': 'object'},
  'warnings': JsonSchema.array(
    JsonSchema.object({
      'code': JsonSchema.string(),
      'message': JsonSchema.string(),
    }),
  ),
  'notes': JsonSchema.array(JsonSchema.string()),
  'moreNotes': JsonSchema.integer(minimum: 1),
  'undo': JsonSchema.enumOf(const ['full', 'partial', 'none']),
  'errors': JsonSchema.array(
    JsonSchema.object({
      'callId': JsonSchema.string(),
      'error': {'type': 'object'},
    }),
  ),
});

/// `plans.seal {turnId}`: merges the caller's plan calls of its own turn
/// into one plan (the compact form the model sees), or returns every call's
/// error when one failed. Above 500 items it fails `limit_exceeded`.
final class SealOperation extends Operation<Map<String, Object?>> {
  SealOperation(this._store);

  final PlanStore _store;

  @override
  final OperationDescriptor descriptor = OperationDescriptor(
    id: 'plans.seal',
    kind: OpKind.plan,
    exemption: 'own turn',
    modelVisible: false,
    summary:
        'Merges the plan calls of the caller\'s turn into one plan for the '
        'user to approve, or lists the calls that failed.',
    argsSchema: JsonSchema.object(
      {'turnId': JsonSchema.string()},
      required: ['turnId'],
    ),
    resultSchema: planSchema(),
  );

  @override
  Map<String, Object?> decode(Map<String, Object?> args, HarnessContext ctx) =>
      args;

  @override
  Future<OpResult> run(
    Map<String, Object?> args,
    HarnessContext ctx,
    HarnessRequest request,
  ) async {
    final turnId = args['turnId']! as String;
    // The harness checked that ctx.turnId is this actor's; the args must
    // name that same turn.
    if (ctx.turnId != turnId) {
      throw HarnessException.of(
        ErrorCode.notPermitted,
        'plans.seal can only seal the turn the call runs in.',
        path: 'turnId',
      );
    }
    return switch (_store.seal(ctx.actor, turnId, now: ctx.now)) {
      SealedPlan(:final plan) => OpResult(plan.toCompactJson()),
      SealFailed(:final failures) => OpResult({
        'errors': [
          for (final e in failures.entries)
            {'callId': e.key, 'error': e.value.toJson()},
        ],
      }),
    };
  }
}

/// `plans.get {planId}`: the full plan, every item, for the UI. Only its
/// creator or the user may read it.
final class GetPlanOperation extends Operation<Map<String, Object?>> {
  GetPlanOperation(this._store);

  final PlanStore _store;

  @override
  final OperationDescriptor descriptor = OperationDescriptor(
    id: 'plans.get',
    kind: OpKind.read,
    exemption: 'own plan, or the user',
    modelVisible: false,
    summary: 'Returns a plan with every item, for the approval card.',
    argsSchema: JsonSchema.object(
      {'planId': JsonSchema.string()},
      required: ['planId'],
    ),
    resultSchema: planSchema(),
  );

  @override
  Map<String, Object?> decode(Map<String, Object?> args, HarnessContext ctx) =>
      args;

  @override
  Future<OpResult> run(
    Map<String, Object?> args,
    HarnessContext ctx,
    HarnessRequest request,
  ) async {
    final planId = args['planId']! as String;
    final plan = _store.get(planId);
    if (plan == null) {
      throw HarnessException.of(
        ErrorCode.planExpired,
        'Plan "$planId" is unknown or gone.',
        path: 'planId',
        hint: 'Rebuild it: ask for the change again.',
      );
    }
    if (plan.createdBy.actor != ctx.actor && ctx.actor.kind != ActorKind.user) {
      throw HarnessException.of(
        ErrorCode.notPermitted,
        'Plan "$planId" belongs to another client.',
        path: 'planId',
      );
    }
    if (plan.isExpired(ctx.now)) {
      throw HarnessException.of(
        ErrorCode.planExpired,
        'Plan "$planId" expired at ${plan.expiresAt.toUtc().toIso8601String()}.',
        path: 'planId',
        hint: 'Rebuild it: ask for the change again.',
      );
    }
    return OpResult(plan.toJson());
  }
}
