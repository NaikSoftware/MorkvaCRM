import '../api/capability.dart';
import '../api/envelope.dart';
import '../api/harness_context.dart';
import '../api/operation.dart';
import '../plan/journal.dart';
import '../plan/plan.dart';
import '../plan/plan_committer.dart';
import '../plan/plan_store.dart';
import '../schema/json_schema.dart';
import 'registry.dart';

/// What the host-only commit ops run on; the host builds one per session.
final class HostServices {
  HostServices({
    required this.store,
    required this.committer,
    required this.journal,
  });

  final PlanStore store;
  final PlanCommitter committer;
  final Journal journal;

  /// Plan and journal ids whose commit, retry or undo is running.
  final Set<String> _running = {};

  /// Runs [body] unless [id] is already running (a double click, a bloc
  /// race): a second call fails `invalid_args` until the first is done.
  Future<T> _once<T>(String id, String path, Future<T> Function() body) async {
    if (!_running.add(id)) {
      throw HarnessException.of(
        ErrorCode.invalidArgs,
        '"$id" is already committing; wait for it to finish.',
        path: path,
      );
    }
    try {
      return await body();
    } finally {
      _running.remove(id);
    }
  }
}

/// Registers the host-only commit ops: `plans.commit/reject/retryFailed` and
/// `journal.undo/restore`. All are kind `commit` (so `Harness.call` refuses
/// any actor but the user), need `host:commit` and are never declared to
/// the model; only the assistant bloc calls them.
void registerHostOps(OperationRegistry ops, HostServices services) {
  for (final op in [
    _HostOp(_commit, (args, ctx, req) => _runCommit(services, args, ctx, req)),
    _HostOp(_reject, (args, ctx, req) => _runReject(services, args, ctx)),
    _HostOp(_retry, (args, ctx, req) => _runRetry(services, args, ctx, req)),
    _HostOp(_undo, (args, ctx, req) => _runUndo(services, args, ctx, req)),
    _HostOp(_restore, (args, ctx, req) => _runRestore(services, args, ctx)),
  ]) {
    ops.register(op);
  }
}

typedef _Run =
    Future<Map<String, Object?>> Function(
      Map<String, Object?> args,
      HarnessContext ctx,
      HarnessRequest request,
    );

final class _HostOp extends Operation<Map<String, Object?>> {
  _HostOp(this.descriptor, this._run);

  @override
  final OperationDescriptor descriptor;
  final _Run _run;

  @override
  Map<String, Object?> decode(Map<String, Object?> args, HarnessContext ctx) =>
      args;

  @override
  Future<OpResult> run(
    Map<String, Object?> args,
    HarnessContext ctx,
    HarnessRequest request,
  ) async => OpResult(await _run(args, ctx, request));
}

OperationDescriptor _host(
  String id,
  String summary,
  Map<String, Object?> args,
  Map<String, Object?> result,
) => OperationDescriptor(
  id: id,
  kind: OpKind.commit,
  capability: Capability.hostCommit,
  modelVisible: false,
  summary: summary,
  argsSchema: args,
  resultSchema: result,
);

Map<String, Object?> _receiptSchema() => JsonSchema.object(
  {
    'planId': JsonSchema.string(),
    'applied': JsonSchema.array(JsonSchema.string()),
    'queued': JsonSchema.array(
      JsonSchema.string(),
      description: 'Written locally; the server ack is pending.',
    ),
    'declinedByUser': JsonSchema.array(JsonSchema.string()),
    'stale': JsonSchema.array(
      JsonSchema.object({
        'itemId': JsonSchema.string(),
        'reason': JsonSchema.enumOf(const [kChangedElsewhere, kMissing]),
      }),
    ),
    'failed': JsonSchema.array(
      JsonSchema.object({
        'itemId': JsonSchema.string(),
        'code': JsonSchema.string(),
        'message': JsonSchema.string(),
      }),
    ),
    'journalId': JsonSchema.string(),
    'undoUntil': JsonSchema.string(),
    'summary': JsonSchema.string(),
    'journal': {
      'type': 'object',
      'description':
          'The JournalEntry (schema 1) to mirror on the chat message; '
          'absent above 400 KB.',
    },
  },
  required: [
    'planId',
    'applied',
    'queued',
    'declinedByUser',
    'stale',
    'failed',
    'summary',
  ],
);

/// A second `plans.commit`/`plans.retryFailed` of a plan still committing
/// (or `journal.undo` of an entry still undoing) fails `invalid_args`.
final _commit = _host(
  'plans.commit',
  'Applies the ticked items of an approved plan and journals their undo.',
  JsonSchema.object(
    {
      'planId': JsonSchema.string(),
      'itemIds': JsonSchema.array(
        JsonSchema.string(),
        description: 'The ticked items; all of them when absent.',
      ),
    },
    required: ['planId'],
  ),
  _receiptSchema(),
);

final _reject = _host(
  'plans.reject',
  'Drops a plan without writing anything.',
  JsonSchema.object(
    {
      'planId': JsonSchema.string(),
      'reason': JsonSchema.enumOf(const ['user', 'skipped']),
    },
    required: ['planId'],
  ),
  JsonSchema.object(const {}),
);

final _retry = _host(
  'plans.retryFailed',
  'Retries the failed items of a committed plan.',
  JsonSchema.object({'planId': JsonSchema.string()}, required: ['planId']),
  _receiptSchema(),
);

final _undo = _host(
  'journal.undo',
  'Reverts a commit, skipping what changed since.',
  JsonSchema.object(
    {'journalId': JsonSchema.string()},
    required: ['journalId'],
  ),
  JsonSchema.object(
    {
      'reverted': JsonSchema.integer(minimum: 0),
      'skipped': JsonSchema.array(
        JsonSchema.object({
          'id': JsonSchema.string(),
          'reason': JsonSchema.string(),
        }),
      ),
      'failed': JsonSchema.array(
        JsonSchema.object({
          'id': JsonSchema.string(),
          'code': JsonSchema.string(),
          'message': JsonSchema.string(),
        }),
      ),
      'summary': JsonSchema.string(),
    },
    required: ['reverted', 'skipped', 'failed', 'summary'],
  ),
);

/// T11 contract: fails `plan_expired` when no item can be put back (hide
/// Undo), and returns an `expiresAt` capped at the entry's `createdAt` +
/// the journal's ttl; an entry dated after now fails `invalid_args`.
final _restore = _host(
  'journal.restore',
  'Re-validates a mirrored journal entry after a reload and makes it '
      'undoable again until its original expiry.',
  JsonSchema.object(
    {
      'entry': {
        'type': 'object',
        'description': 'A JournalEntry (schema 1) as plans.commit returned it.',
      },
    },
    required: ['entry'],
  ),
  JsonSchema.object(
    {
      'journalId': JsonSchema.string(),
      'expiresAt': JsonSchema.string(),
      'dropped': JsonSchema.array(
        JsonSchema.object({
          'id': JsonSchema.string(),
          'reason': JsonSchema.string(),
        }),
      ),
    },
    required: ['journalId', 'expiresAt', 'dropped'],
  ),
);

// ---------------------------------------------------------------------------

/// The live plan [args] names; `plan_expired` when it is unknown or past its
/// expiry.
Plan _plan(HostServices s, Map<String, Object?> args, HarnessContext ctx) {
  final planId = args['planId']! as String;
  final plan = s.store.get(planId);
  if (plan == null || plan.isExpired(ctx.now)) {
    throw HarnessException.of(
      ErrorCode.planExpired,
      plan == null
          ? 'Plan "$planId" is unknown or gone.'
          : 'Plan "$planId" expired at '
                '${plan.expiresAt.toUtc().toIso8601String()}.',
      path: 'planId',
      hint: 'Rebuild it: ask for the change again.',
    );
  }
  return plan;
}

Future<Map<String, Object?>> _runCommit(
  HostServices s,
  Map<String, Object?> args,
  HarnessContext ctx,
  HarnessRequest request,
) async {
  final plan = _plan(s, args, ctx);
  if (s.store.receiptOf(plan.planId) != null) {
    throw HarnessException.of(
      ErrorCode.invalidArgs,
      'Plan "${plan.planId}" is already committed.',
      path: 'planId',
      hint: 'Use plans.retryFailed for its failed items.',
    );
  }
  Set<String>? selected;
  if (args['itemIds'] case final List ids) {
    selected = ids.cast<String>().toSet();
    final unknown = selected.where((id) => plan.item(id) == null).toList();
    if (unknown.isNotEmpty) {
      throw HarnessException.of(
        ErrorCode.invalidArgs,
        'Plan "${plan.planId}" has no item ${unknown.join(', ')}.',
        path: 'itemIds',
        candidates: [for (final i in plan.items) i.itemId],
      );
    }
  }
  return s._once(plan.planId, 'planId', () async {
    final result = await s.committer.commit(
      plan,
      ctx,
      callId: request.callId,
      selected: selected,
    );
    return _finish(s, plan, result, ctx);
  });
}

Future<Map<String, Object?>> _runRetry(
  HostServices s,
  Map<String, Object?> args,
  HarnessContext ctx,
  HarnessRequest request,
) async {
  final plan = _plan(s, args, ctx);
  // Refused before the receipt check: a retry during the first commit
  // finds no receipt yet.
  return s._once(plan.planId, 'planId', () => _retryOf(s, plan, ctx, request));
}

Future<Map<String, Object?>> _retryOf(
  HostServices s,
  Plan plan,
  HarnessContext ctx,
  HarnessRequest request,
) async {
  final last = s.store.receiptOf(plan.planId);
  if (last == null) {
    throw HarnessException.of(
      ErrorCode.invalidArgs,
      'Plan "${plan.planId}" was not committed yet.',
      path: 'planId',
      hint: 'Use plans.commit.',
    );
  }
  final failed = PlanCommitter.failedIn(last);
  if (failed.isEmpty) return last;
  final result = await s.committer.commit(
    plan,
    ctx,
    callId: request.callId,
    selected: failed,
    prior: PlanCommitter.settledIn(last),
  );
  return _finish(s, plan, result, ctx, journalId: last['journalId'] as String?);
}

/// Journals [result] (extending the entry [journalId] while it is live) and
/// stores and returns the receipt, with the entry's mirror.
Map<String, Object?> _finish(
  HostServices s,
  Plan plan,
  CommitResult result,
  HarnessContext ctx, {
  String? journalId,
}) {
  var entry = journalId == null ? null : s.journal.get(journalId);
  if (entry != null && entry.isExpired(ctx.now)) entry = null;
  if (result.journal.isNotEmpty) {
    if (entry != null) {
      entry = entry.withItems([...entry.items, ...result.journal]);
      s.journal.put(entry);
    } else {
      entry = s.journal.record(
        planId: plan.planId,
        actor: ctx.actor,
        now: ctx.now,
        items: result.journal,
      );
    }
  }
  final receipt = s.committer.receipt(
    plan,
    result.outcomes,
    journalId: entry?.journalId,
    undoUntil: entry?.expiresAt,
  );
  s.store.putReceipt(plan.planId, receipt);
  return {...receipt, 'journal': ?entry?.mirror()};
}

Future<Map<String, Object?>> _runReject(
  HostServices s,
  Map<String, Object?> args,
  HarnessContext ctx,
) async {
  final planId = args['planId']! as String;
  if (s.store.receiptOf(planId) != null) {
    throw HarnessException.of(
      ErrorCode.invalidArgs,
      'Plan "$planId" is already committed; undo it instead.',
      path: 'planId',
    );
  }
  // Rejecting an unknown or expired plan is a no-op: nothing was written.
  s.store.remove(planId);
  return const {};
}

Future<Map<String, Object?>> _runUndo(
  HostServices s,
  Map<String, Object?> args,
  HarnessContext ctx,
  HarnessRequest request,
) async {
  final journalId = args['journalId']! as String;
  final entry = s.journal.get(journalId);
  if (entry == null || entry.isExpired(ctx.now)) {
    if (entry != null) s.journal.remove(journalId);
    throw HarnessException.of(
      ErrorCode.planExpired,
      'Undo for "$journalId" is no longer available.',
      path: 'journalId',
    );
  }
  if (entry.actor != ctx.actor.wire) {
    throw HarnessException.of(
      ErrorCode.notPermitted,
      'This change was made by ${entry.actor}, not ${ctx.actor}.',
      path: 'journalId',
    );
  }
  final (:result, :summary) = await s._once(
    journalId,
    'journalId',
    () => s.committer.undo(entry, ctx, callId: request.callId),
  );
  // What failed to write stays undoable; everything else is done.
  if (result.failedItems.isEmpty) {
    s.journal.remove(journalId);
  } else {
    s.journal.put(entry.withItems(result.failedItems));
  }
  return result.toJson(summary: summary);
}

Future<Map<String, Object?>> _runRestore(
  HostServices s,
  Map<String, Object?> args,
  HarnessContext ctx,
) async {
  await s.committer.cache.ready;
  final restored = s.journal.restore(
    (args['entry']! as Map).cast<String, Object?>(),
    actor: ctx.actor,
    now: ctx.now,
    collections: s.committer.cache.collections,
    registry: s.committer.registry,
  );
  return restored.toJson();
}
