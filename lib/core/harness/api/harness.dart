import 'dart:math';

import '../ops/registry.dart';
import '../schema/json_schema.dart';
import 'api_version.dart';
import 'capability.dart';
import 'envelope.dart';
import 'harness_context.dart';
import 'operation.dart';

/// The Morkva Harness: one entry point, [call], for every client (the
/// assistant's agent loop, the host bloc, later the JS plugin bridge).
///
/// A call runs this pipeline, failing at the first step that rejects it:
/// 1. version (`v` must equal [kHarnessApiVersion]) → `unsupported_version`
/// 2. op lookup → `unknown_op`
/// 3. actor (commit ops need a user actor) → `not_permitted`
/// 4. turn ownership (a `turnId` must be one [openTurn] minted for this
///    actor) → `not_permitted`
/// 5. capabilities (`Operation.requiredCapabilities` ⊆ grants) →
///    `not_permitted`
/// 6. JSON Schema of `args` → `invalid_args`, every problem in `details`
/// 7. `Operation.decode` (refs → ids, strict values; collection scope)
/// 8. `Operation.run`
///
/// [call] never throws: a [HarnessException] becomes its error, anything
/// else becomes `internal`.
final class Harness {
  Harness(this._ops, {Random? random}) : _random = random ?? Random.secure();

  final OperationRegistry _ops;
  final Random _random;
  final Map<String, Actor> _turns = {};

  /// Every op's descriptor, sorted by id. The agent declares the model-visible
  /// ones its grants allow.
  List<OperationDescriptor> get descriptors => _ops.descriptors;

  /// Mints an opaque turn id bound to [actor]. Plan calls carrying it merge
  /// into one plan; another actor presenting it is refused.
  String openTurn(Actor actor) {
    String id;
    do {
      id = 't_${_hex(8)}';
    } while (_turns.containsKey(id));
    _turns[id] = actor;
    return id;
  }

  /// Ends [turnId]: later calls carrying it are refused. Plans already built
  /// in it live on in their store.
  void closeTurn(String turnId) => _turns.remove(turnId);

  /// Whether [turnId] is open and belongs to [actor].
  bool ownsTurn(Actor actor, String turnId) => _turns[turnId] == actor;

  /// Forgets every turn (sign-out or a workspace switch).
  void reset() => _turns.clear();

  Future<HarnessResponse> call(
    HarnessRequest request,
    HarnessContext ctx,
  ) async {
    final watch = Stopwatch()..start();
    try {
      final op = _resolve(request, ctx);
      final turnId = _checkTurn(request, ctx);
      _checkCapabilities(op, request, ctx);

      final problems = JsonSchema.validate(
        op.descriptor.argsSchema,
        request.args,
      );
      if (problems.isNotEmpty) {
        throw HarnessException(
          HarnessError.fromDetails(
            problems,
            hint: 'Fix the arguments of ${request.op} and call it again.',
          ),
        );
      }

      final callCtx = turnId == ctx.turnId ? ctx : ctx.withTurn(turnId);
      final args = await op.decode(request.args, callCtx);
      final out = await op.run(args, callCtx, request);
      assert(_isJson(out.result), '${request.op} returned a non-JSON result');
      return HarnessOk(
        out.result,
        ResponseMeta(
          ms: watch.elapsedMilliseconds,
          generation: out.generation,
          truncated: out.truncated,
        ),
      );
    } on HarnessException catch (e) {
      return HarnessFailure(e.error);
    } catch (e) {
      return HarnessFailure(
        HarnessError(
          code: ErrorCode.internal,
          message: 'Unexpected error in ${request.op}: $e',
        ),
      );
    }
  }

  Operation<Object?> _resolve(HarnessRequest request, HarnessContext ctx) {
    if (request.v != kHarnessApiVersion) {
      throw HarnessException.of(
        ErrorCode.unsupportedVersion,
        'This harness speaks v$kHarnessApiVersion (version $kHarnessVersion); '
        'the request asked for v${request.v}.',
      );
    }
    final op = _ops.lookup(request.op);
    if (op == null) {
      final namespace = request.op.split('.').first;
      final near = [
        for (final id in _ops.ids)
          if (id.split('.').first == namespace) id,
      ];
      throw HarnessException.of(
        ErrorCode.unknownOp,
        'There is no op "${request.op}".',
        candidates: near.isEmpty ? null : near,
        hint: 'harness.describe lists every op.',
      );
    }
    if (op.descriptor.kind == OpKind.commit &&
        ctx.actor.kind != ActorKind.user) {
      throw HarnessException.of(
        ErrorCode.notPermitted,
        '${request.op} can only be called by the user, not ${ctx.actor}.',
      );
    }
    return op;
  }

  String? _checkTurn(HarnessRequest request, HarnessContext ctx) {
    final fromRequest = request.turnId;
    final fromContext = ctx.turnId;
    if (fromRequest != null &&
        fromContext != null &&
        fromRequest != fromContext) {
      throw HarnessException.of(
        ErrorCode.notPermitted,
        'The request names turn "$fromRequest" but the call runs in turn '
        '"$fromContext".',
        path: 'turnId',
      );
    }
    final turnId = fromRequest ?? fromContext;
    if (turnId != null && !ownsTurn(ctx.actor, turnId)) {
      throw HarnessException.of(
        ErrorCode.notPermitted,
        'Turn "$turnId" was not opened for ${ctx.actor}.',
        path: 'turnId',
      );
    }
    return turnId;
  }

  void _checkCapabilities(
    Operation<Object?> op,
    HarnessRequest request,
    HarnessContext ctx,
  ) {
    final missing = [
      for (final cap in op.requiredCapabilities(request.args))
        if (!ctx.grants.allows(cap)) cap.wire,
    ];
    if (missing.isNotEmpty) {
      throw HarnessException.of(
        ErrorCode.notPermitted,
        '${request.op} needs ${missing.join(', ')}, which this client was '
        'not granted.',
      );
    }
  }

  String _hex(int bytes) => [
    for (var i = 0; i < bytes; i++)
      _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ].join();

  static bool _isJson(Object? value) => switch (value) {
    null || bool() || String() => true,
    num() => value.isFinite,
    List() => value.every(_isJson),
    Map() => value.entries.every((e) => e.key is String && _isJson(e.value)),
    _ => false,
  };
}
