import 'dart:async';

import 'capability.dart';
import 'envelope.dart';
import 'harness_context.dart';

/// What an op does, which decides who may call it and how the gate treats it.
enum OpKind {
  /// Reads data; runs freely.
  read,

  /// Validates and builds a plan; writes nothing.
  plan,

  /// A UI intent (rendered as a chip; navigation happens on the user's tap).
  ui,

  /// Writes an approved plan or undoes one. Host and user actor only, never
  /// declared to the model.
  commit,
}

/// The public contract of one op: what `harness.describe` reports, what the
/// agent turns into a tool declaration and what the future JS SDK types are
/// generated from.
final class OperationDescriptor {
  const OperationDescriptor({
    required this.id,
    required this.kind,
    required this.summary,
    required this.argsSchema,
    required this.resultSchema,
    this.capability,
    this.exemption,
    this.since = '1.0',
    this.modelVisible = true,
  }) : assert(
         (capability == null) != (exemption == null),
         'An op declares exactly one of capability or exemption.',
       ),
       assert(
         kind != OpKind.commit || !modelVisible,
         'Commit ops are never declared to the model.',
       );

  /// Stable dotted id, e.g. `cards.update`.
  final String id;

  /// The `major.minor` version the op appeared in.
  final String since;
  final OpKind kind;

  /// The one capability the op needs (extra ones may be required per argument
  /// by `Operation.requiredCapabilities`). Null only for the protocol ops that
  /// touch nothing but the caller's own turn or plan; [exemption] says why.
  final Capability? capability;

  /// Why no capability is needed, e.g. `own turn` for `plans.seal`.
  final String? exemption;

  /// At most two sentences; becomes the tool description.
  final String summary;

  /// JSON Schema (the subset `JsonSchema` supports) of the `args` object.
  final Map<String, Object?> argsSchema;

  /// JSON Schema of the `result` object.
  final Map<String, Object?> resultSchema;

  /// Whether the agent may declare it to the model. False for commit ops and
  /// for the protocol ops.
  final bool modelVisible;

  Map<String, Object?> toJson() => {
    'id': id,
    'since': since,
    'kind': kind.name,
    'capability': capability?.wire,
    if (exemption != null) 'exempt': exemption,
    'summary': summary,
    'modelVisible': modelVisible,
    'args': argsSchema,
    'result': resultSchema,
  };
}

/// What an op's [Operation.run] returns: the JSON result plus the meta the
/// harness cannot know itself.
final class OpResult {
  const OpResult(this.result, {this.generation, this.truncated = false});

  /// Plain JSON only: no `DateTime`, `Timestamp` or other Dart objects.
  final Map<String, Object?> result;

  /// The cache generation the result was computed from, when it read data.
  final int? generation;

  /// Whether [result] was cut to its byte budget.
  final bool truncated;
}

/// One harness op. `Harness.call` has already checked the version, the actor,
/// the turn, the capabilities and the JSON Schema of the args before
/// [decode] runs; collection scope is checked by the op (and its resolvers)
/// on every collection it touches, through `ctx.grants.allowsCollection`.
///
/// [A] is the op's decoded args: ids instead of names, typed values instead of
/// friendly input.
abstract class Operation<A> {
  const Operation();

  OperationDescriptor get descriptor;

  /// Every capability this call needs. Defaults to the descriptor's one;
  /// override when an argument needs more (`collections.create` with `cards`
  /// also needs `data:write`). Runs on the raw args, before schema checks, so
  /// it must not assume their shape; if it throws, the call fails `internal`.
  Iterable<Capability> requiredCapabilities(Map<String, Object?> args) => [
    ?descriptor.capability,
  ];

  /// Resolves schema-valid [args]: refs to ids, friendly values to stored
  /// JSON. Throws [HarnessException] with candidates on a bad ref or value.
  FutureOr<A> decode(Map<String, Object?> args, HarnessContext ctx);

  /// Does the work. Throws [HarnessException] for an expected failure;
  /// anything else becomes `internal`. [request] carries the `callId` for
  /// progress events.
  Future<OpResult> run(A args, HarnessContext ctx, HarnessRequest request);
}
