import '../api/capability.dart';
import '../api/operation.dart';
import '../plan/planners/plan_call.dart';
import '../plan/planners/view_planners.dart';
import '../schema/arg_shapes.dart';
import '../schema/json_schema.dart';
import 'registry.dart';

/// Registers the view plan ops: `views.create/update/delete`.
void registerViewOps(OperationRegistry ops, PlanServices services) {
  ops
    ..register(_ViewOp(services, _create, planViewsCreate))
    ..register(_ViewOp(services, _update, planViewsUpdate))
    ..register(_ViewOp(services, _delete, planViewsDelete));
}

final class _ViewOp extends PlanOperation {
  _ViewOp(super.services, this.descriptor, this._planner);

  @override
  final OperationDescriptor descriptor;
  final Future<void> Function(Map<String, Object?>, PlanCall) _planner;

  @override
  Future<void> plan(Map<String, Object?> args, PlanCall call) =>
      _planner(args, call);
}

Map<String, Map<String, Object?>> _viewShape() => {
  'mode': JsonSchema.enumOf(
    kViewModes,
    description:
        'board needs a single-select or single-link layoutField, calendar a '
        'date one; list may take one; table and summary none.',
  ),
  'where': whereSchema(),
  'sort': sortSchema(),
  'fields': JsonSchema.array(
    refSchema(),
    minItems: 1,
    maxItems: 40,
    description: 'The fields shown, in order (the first is the title).',
  ),
  'layoutField': refSchema(description: 'The field the mode lays out by.'),
};

final OperationDescriptor _create = OperationDescriptor(
  id: 'views.create',
  kind: OpKind.plan,
  capability: Capability.viewsWrite,
  summary:
      'Plans a new saved view of a collection (a table, board, list, '
      'calendar or summary with its own filters and sort).',
  argsSchema: JsonSchema.object(
    {'collection': refSchema(), 'name': JsonSchema.string(), ..._viewShape()},
    required: ['collection', 'name', 'mode'],
  ),
  resultSchema: planCallResultSchema(),
);

final OperationDescriptor _update = OperationDescriptor(
  id: 'views.update',
  kind: OpKind.plan,
  capability: Capability.viewsWrite,
  summary:
      'Plans changing a saved view; where replaces its filters, and sort and '
      'fields replace its own.',
  argsSchema: JsonSchema.object(
    {
      'collection': refSchema(),
      'view': refSchema(),
      'name': JsonSchema.string(),
      ..._viewShape(),
    },
    required: ['collection', 'view'],
  ),
  resultSchema: planCallResultSchema(),
);

final OperationDescriptor _delete = OperationDescriptor(
  id: 'views.delete',
  kind: OpKind.plan,
  capability: Capability.viewsWrite,
  summary: 'Plans deleting a saved view; a collection keeps at least one.',
  argsSchema: JsonSchema.object(
    {'collection': refSchema(), 'view': refSchema()},
    required: ['collection', 'view'],
  ),
  resultSchema: planCallResultSchema(),
);
