import 'dart:async';

import 'package:morkva_crm/core/agent/agent_loop.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/core/harness/harness.dart';

/// What a [FakeOp] does with one call.
typedef FakeHandler =
    FutureOr<Map<String, Object?>> Function(
      Map<String, Object?> args,
      HarnessContext ctx,
      HarnessRequest request,
    );

/// One recorded call of a [FakeOp].
typedef FakeCall = ({
  Map<String, Object?> args,
  HarnessContext ctx,
  HarnessRequest request,
});

/// A scripted harness op. The real [Harness] runs it (the pipeline, the
/// actor and turn checks included), so the agent is tested against the same
/// entry point it uses in the app; the real plan ops land in T6/T7.
final class FakeOp extends Operation<Map<String, Object?>> {
  FakeOp(
    String id, {
    OpKind kind = OpKind.read,
    Capability? capability = Capability.dataRead,
    String? exemption,
    bool modelVisible = true,
    String? summary,
    FakeHandler? handler,
  }) : _handler = handler ?? ((_, _, _) => {'summary': 'Ran $id'}),
       descriptor = OperationDescriptor(
         id: id,
         kind: kind,
         summary: summary ?? 'Fake $id.',
         argsSchema: const {'type': 'object'},
         resultSchema: const {'type': 'object'},
         capability: exemption == null ? capability : null,
         exemption: exemption,
         modelVisible: modelVisible,
       );

  @override
  final OperationDescriptor descriptor;

  final FakeHandler _handler;
  final List<FakeCall> calls = [];

  @override
  Map<String, Object?> decode(Map<String, Object?> args, HarnessContext ctx) =>
      args;

  @override
  Future<OpResult> run(
    Map<String, Object?> args,
    HarnessContext ctx,
    HarnessRequest request,
  ) async {
    calls.add((args: args, ctx: ctx, request: request));
    final out = await _handler(args, ctx, request);
    if (out['error'] case final HarnessError error) {
      throw HarnessException(error);
    }
    return OpResult(out);
  }
}

/// The fake `plans.seal`: answers with [planJson] (or `{errors}` / a thrown
/// error from [handler]) and records the turns it sealed.
FakeOp fakeSeal({FakeHandler? handler}) => FakeOp(
  'plans.seal',
  kind: OpKind.plan,
  exemption: 'own turn',
  modelVisible: false,
  handler: handler,
);

/// A compact plan as `plans.seal` returns it.
Map<String, Object?> planJson(String planId, {int items = 2}) => {
  'planId': planId,
  'title': 'Set Status to Shipped · $items orders',
  'risk': 'low',
  'itemCount': items,
  'items': const [],
};

/// A harness over [ops] (plus a host-only commit op the model must never
/// see).
Harness fakeHarness(Iterable<FakeOp> ops) {
  final registry = OperationRegistry();
  for (final op in ops) {
    registry.register(op);
  }
  registry.register(
    FakeOp(
      'plans.commit',
      kind: OpKind.commit,
      capability: Capability.hostCommit,
      modelVisible: false,
    ),
  );
  return Harness(registry);
}

/// A fixed workspace for grounding.
final class FakeWorkspace implements AgentWorkspace {
  FakeWorkspace({
    this.collections = const [],
    this.digestText = '- "Orders" (3)',
  });

  @override
  String get workspaceId => 'ws_1';

  @override
  final List<Collection> collections;

  String digestText;

  @override
  String digest() => digestText;
}
