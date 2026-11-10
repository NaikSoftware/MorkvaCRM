import '../api/api_version.dart';
import '../api/capability.dart';
import '../api/envelope.dart';
import '../api/harness_context.dart';
import '../api/operation.dart';
import '../schema/json_schema.dart';
import 'registry.dart';

/// Registers the protocol ops any actor may call: `harness.describe`.
/// (`plans.seal` and `plans.get` come with the plan ops.)
void registerProtocolOps(OperationRegistry ops) =>
    ops.register(DescribeOperation(ops));

/// `harness.describe`: the whole API contract (every op's descriptor, the
/// error codes, capabilities and event names). The JS SDK typings and the
/// descriptors golden are generated from it.
final class DescribeOperation extends Operation<Map<String, Object?>> {
  DescribeOperation(this._ops);

  final OperationRegistry _ops;

  static final OperationDescriptor _descriptor = OperationDescriptor(
    id: 'harness.describe',
    kind: OpKind.read,
    capability: Capability.schemaRead,
    modelVisible: false,
    summary:
        'Describes the harness API: every op with its JSON Schemas, the error '
        'codes, capabilities and event names.',
    argsSchema: JsonSchema.object(const {}),
    resultSchema: JsonSchema.object(
      {
        'apiVersion': JsonSchema.string(description: 'major.minor'),
        'ops': JsonSchema.array(
          JsonSchema.object(
            {
              'id': JsonSchema.string(),
              'since': JsonSchema.string(),
              'kind': JsonSchema.enumOf([
                for (final k in OpKind.values) k.name,
              ]),
              'capability': JsonSchema.enumOf([
                for (final c in Capability.values) c.wire,
              ]),
              'exempt': JsonSchema.string(),
              'summary': JsonSchema.string(),
              'modelVisible': JsonSchema.boolean(),
              'args': {'type': 'object', 'description': 'JSON Schema'},
              'result': {'type': 'object', 'description': 'JSON Schema'},
            },
            required: [
              'id',
              'since',
              'kind',
              'summary',
              'modelVisible',
              'args',
              'result',
            ],
          ),
        ),
        'errorCodes': JsonSchema.array(JsonSchema.string()),
        'capabilities': JsonSchema.array(JsonSchema.string()),
        'events': JsonSchema.array(JsonSchema.string()),
      },
      required: ['apiVersion', 'ops', 'errorCodes', 'capabilities', 'events'],
    ),
  );

  @override
  OperationDescriptor get descriptor => _descriptor;

  @override
  Map<String, Object?> decode(Map<String, Object?> args, HarnessContext ctx) =>
      args;

  @override
  Future<OpResult> run(
    Map<String, Object?> args,
    HarnessContext ctx,
    HarnessRequest request,
  ) async => OpResult({
    'apiVersion': kHarnessVersion,
    'ops': [for (final d in _ops.descriptors) d.toJson()],
    'errorCodes': [for (final c in ErrorCode.values) c.wire],
    'capabilities': [for (final c in Capability.values) c.wire],
    'events': HarnessEvent.names,
  });
}
