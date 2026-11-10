/// Shared setup for the plan tests: the seed workspace behind a
/// [FakeDataRepository], a [WorkspaceCache], the query engine, a
/// [PlanStore] and a [Harness] with every plan op registered.
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/core/domain/ids.dart';
import 'package:morkva_crm/core/harness/cache/result_store.dart';
import 'package:morkva_crm/core/harness/cache/workspace_cache.dart';
import 'package:morkva_crm/core/harness/harness.dart';
import 'package:morkva_crm/core/harness/ops/plan_protocol_ops.dart';
import 'package:morkva_crm/core/harness/ops/view_ops.dart';
import 'package:morkva_crm/core/harness/plan/plan.dart';
import 'package:morkva_crm/core/harness/plan/plan_store.dart';
import 'package:morkva_crm/core/harness/query/query_engine.dart';

import '../../../features/collections/fake_data_repository.dart';
import '../fixtures/seed_workspace.dart';

export '../fixtures/seed_workspace.dart';

/// The seed's "today" as the host passes it (a local calendar day).
final DateTime today = DateTime(2026, 11, 10);
final DateTime now = DateTime(2026, 11, 10, 14, 30);

/// A live seed workspace with the plan ops over it.
final class PlanHarness {
  PlanHarness([SeedWorkspace? seed]) : seed = seed ?? SeedWorkspace() {
    repo = this.seed.repository();
    cache = WorkspaceCache(repo)..initialize('w1');
    queries = QueryEngine(cache, ResultStore());
    store = PlanStore(random: Random(7));
    final services = PlanServices(
      cache: cache,
      queries: queries,
      store: store,
      registry: defaultFieldTypeRegistry(),
      ids: IdGenerator(random: Random(3)),
    );
    registry = OperationRegistry();
    registerPlanOps(registry, services);
    registerViewOps(registry, services);
    harness = Harness(registry, random: Random(5));
    turn = harness.openTurn(Actor.assistant);
  }

  final SeedWorkspace seed;
  late final FakeDataRepository repo;
  late final WorkspaceCache cache;
  late final QueryEngine queries;
  late final PlanStore store;
  late final OperationRegistry registry;
  late final Harness harness;

  /// The current turn of the assistant actor.
  late String turn;
  int _calls = 0;

  /// The seeded collections with lookups resolved.
  late final List<Collection> resolved = resolveLookups(seed.collections);

  Collection collection(String id) => resolved.firstWhere((c) => c.id == id);

  /// Starts a new assistant turn.
  void newTurn() => turn = harness.openTurn(Actor.assistant);

  HarnessContext context({
    Actor actor = Actor.assistant,
    Grants? grants,
    ScreenContext? focus,
    DateTime? at,
  }) => HarnessContext(
    workspaceId: 'w1',
    actor: actor,
    grants: grants ?? Grants.all(),
    now: at ?? now,
    today: today,
    focus: focus,
  );

  /// Calls [op] in the current turn (or [turnId]).
  Future<HarnessResponse> call(
    String op,
    Map<String, Object?> args, {
    Actor actor = Actor.assistant,
    Grants? grants,
    ScreenContext? focus,
    String? turnId,
    DateTime? at,
    bool noTurn = false,
  }) => harness.call(
    HarnessRequest(
      op: op,
      args: args,
      callId: 'r1.${++_calls}',
      turnId: noTurn ? null : (turnId ?? turn),
    ),
    context(actor: actor, grants: grants, focus: focus, at: at),
  );

  /// The result of a call that must succeed.
  Future<Map<String, Object?>> ok(
    String op,
    Map<String, Object?> args, {
    ScreenContext? focus,
    Grants? grants,
  }) async {
    final r = await call(op, args, focus: focus, grants: grants);
    if (r is HarnessFailure) fail('$op failed: ${r.error.toJson()}');
    return (r as HarnessOk).result;
  }

  /// The error of a call that must fail.
  Future<HarnessError> error(
    String op,
    Map<String, Object?> args, {
    ScreenContext? focus,
    Grants? grants,
  }) async {
    final r = await call(op, args, focus: focus, grants: grants);
    if (r is HarnessOk) fail('$op should fail but gave ${r.result}');
    return (r as HarnessFailure).error;
  }

  /// Seals the current turn; the compact plan (or `{errors}`).
  Future<Map<String, Object?>> seal() async {
    final r = await call('plans.seal', {'turnId': turn});
    if (r is HarnessFailure) fail('seal failed: ${r.error.toJson()}');
    return (r as HarnessOk).result;
  }

  /// Seals the current turn and returns the stored plan.
  Future<Plan> sealPlan() async {
    final compact = await seal();
    expect(compact['errors'], isNull, reason: '$compact');
    return store.get(compact['planId']! as String)!;
  }

  Future<void> dispose() => cache.reset();
}

/// The [UpdateCardItem]s of [plan], by card id.
Map<String, UpdateCardItem> updatesOf(Plan plan) => {
  for (final i in plan.items.whereType<UpdateCardItem>()) i.cardId: i,
};

/// The value of [fieldId] on seeded [card].
FieldValue? valueOf(MorkvaObject card, String fieldId) => card[fieldId];
