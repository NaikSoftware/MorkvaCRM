import 'dart:math';

import '../api/capability.dart';
import '../api/envelope.dart';
import '../input/ref_resolver.dart';
import 'plan.dart';
import 'planning_overlay.dart';

/// The plans of a session: the open turns' [PlanningOverlay]s, keyed by
/// `(actor, turnId)` so one actor's calls can never land in another's
/// preview, and the sealed [Plan]s by id until they expire.
///
/// Plans live [ttl] (15 minutes) from sealing; an expired plan is kept a
/// little longer so a late commit gets `plan_expired`, not "unknown plan".
/// The store also keeps each plan's last commit receipt for `retryFailed`.
final class PlanStore {
  PlanStore({
    this.ttl = const Duration(minutes: 15),
    this.keepExpired = const Duration(minutes: 45),
    Random? random,
  }) : _random = random ?? Random.secure();

  /// How long a sealed plan can be committed.
  final Duration ttl;

  /// How long an expired plan is still reported as expired.
  final Duration keepExpired;
  final Random _random;

  final Map<(Actor, String), PlanningOverlay> _overlays = {};
  final Map<String, Plan> _plans = {};
  final Map<String, Map<String, Object?>> _receipts = {};

  /// The overlay of [actor]'s [turnId], created on the turn's first plan
  /// call (minting the plan id, recording [grants] as the plan's creator).
  PlanningOverlay overlay(
    Actor actor,
    String turnId, {
    required Grants grants,
    required WorkspaceReader base,
    required DateTime now,
  }) {
    // A turn that never sealed (a crash, a dropped transport) is forgotten
    // after the plan TTL.
    _overlays.removeWhere(
      (key, o) => key != (actor, turnId) && !now.isBefore(o.startedAt.add(ttl)),
    );
    return _overlays.putIfAbsent(
      (actor, turnId),
      () => PlanningOverlay(
        actor: actor,
        turnId: turnId,
        planId: _mintPlanId(),
        createdBy: PlanCreator(actor, grants),
        base: base,
        startedAt: now,
      ),
    );
  }

  /// The open overlay of [actor]'s [turnId], or null.
  PlanningOverlay? overlayOf(Actor actor, String turnId) =>
      _overlays[(actor, turnId)];

  /// Drops [actor]'s open overlay of [turnId] without a plan.
  void discard(Actor actor, String turnId) => _overlays.remove((actor, turnId));

  /// Seals [actor]'s [turnId]: the overlay becomes one stored [Plan] (or,
  /// when a call failed, its failures are returned and nothing is stored).
  /// The overlay is closed either way, so the next plan call of the turn
  /// starts a new plan.
  ///
  /// Only failures of calls that reached a plan op are recorded: a call
  /// `Harness.call` refuses before the op runs (its args fail the JSON
  /// schema, a missing capability) never touches the overlay, so a caller
  /// that saw such a failure in the turn must drop the sealed plan itself
  /// (the agent loop does).
  ///
  /// Throws `invalid_args` when the turn planned nothing and
  /// `limit_exceeded` above [kMaxPlanItems] items.
  SealResult seal(Actor actor, String turnId, {required DateTime now}) {
    final overlay = _overlays.remove((actor, turnId));
    if (overlay == null || overlay.isEmpty) {
      throw HarnessException.of(
        ErrorCode.invalidArgs,
        'Nothing was planned in this turn.',
        path: 'turnId',
      );
    }
    if (overlay.failures.isNotEmpty) return SealFailed(overlay.failures);
    final pending = overlay.pending;
    if (pending.items.length > kMaxPlanItems) {
      throw HarnessException.of(
        ErrorCode.limitExceeded,
        'This turn planned ${pending.items.length} changes; one plan holds '
        'at most $kMaxPlanItems.',
        hint: 'Split the work into smaller requests.',
      );
    }
    _prune(now);
    final plan = Plan(
      planId: overlay.planId,
      turnId: turnId,
      title: _title(pending.titles),
      createdBy: overlay.createdBy,
      items: pending.items,
      createdAt: now,
      expiresAt: now.add(ttl),
      warnings: pending.warnings,
      notes: pending.notes,
      undo: _undo(pending.items),
    );
    _plans[plan.planId] = plan;
    return SealedPlan(plan);
  }

  /// The plan [planId], expired or not; null when unknown or long gone.
  Plan? get(String planId) => _plans[planId];

  /// Forgets [planId] (rejected, or fully committed and journaled).
  void remove(String planId) {
    _plans.remove(planId);
    _receipts.remove(planId);
  }

  /// Keeps [receipt] as [planId]'s last commit result (for `retryFailed`).
  void putReceipt(String planId, Map<String, Object?> receipt) =>
      _receipts[planId] = receipt;

  Map<String, Object?>? receiptOf(String planId) => _receipts[planId];

  /// Forgets everything (sign-out, a workspace switch).
  void reset() {
    _overlays.clear();
    _plans.clear();
    _receipts.clear();
  }

  void _prune(DateTime now) {
    final gone = [
      for (final p in _plans.values)
        if (!now.isBefore(p.expiresAt.add(keepExpired))) p.planId,
    ];
    gone.forEach(remove);
  }

  String _mintPlanId() {
    String id;
    do {
      id =
          'p_${[for (var i = 0; i < 8; i++) _random.nextInt(256).toRadixString(16).padLeft(2, '0')].join()}';
    } while (_plans.containsKey(id) ||
        _overlays.values.any((o) => o.planId == id));
    return id;
  }

  static String _title(List<String> titles) => switch (titles) {
    [] => 'Changes',
    [final one] => one,
    [final first, ...final rest] =>
      '$first + ${rest.length} more change${rest.length == 1 ? '' : 's'}',
  };

  static UndoSupport _undo(List<PlanItem> items) {
    final none = items.where(
      (i) => i is DeleteCollectionItem && i.cardCount > kMaxUndoableCards,
    );
    if (none.isEmpty) return UndoSupport.full;
    return none.length == items.length ? UndoSupport.none : UndoSupport.partial;
  }
}

/// Above this many cards a collection delete cannot be undone (its cards
/// are not kept in memory).
const int kMaxUndoableCards = 2000;

/// What [PlanStore.seal] produced.
sealed class SealResult {
  const SealResult();
}

final class SealedPlan extends SealResult {
  const SealedPlan(this.plan);

  final Plan plan;
}

/// Some calls failed: nothing is shown and every call comes back.
final class SealFailed extends SealResult {
  const SealFailed(this.failures);

  final Map<String, HarnessError> failures;
}
