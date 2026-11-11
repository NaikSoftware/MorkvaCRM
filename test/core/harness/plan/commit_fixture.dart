/// The plan harness plus the host-only commit ops: a [PlanCommitter], a
/// [Journal] and helpers that call the commit ops as the signed-in user,
/// the way the assistant bloc does.
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/api/data/data_repository.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/core/harness/harness.dart';
import 'package:morkva_crm/core/harness/ops/host_ops.dart';
import 'package:morkva_crm/core/harness/plan/journal.dart';
import 'package:morkva_crm/core/harness/plan/plan.dart';
import 'package:morkva_crm/core/harness/plan/plan_committer.dart';

import 'plan_fixture.dart';

export 'plan_fixture.dart';

/// The signed-in user (only a user actor may call the commit ops).
const Actor user = Actor.user('u1');

final class CommitHarness {
  CommitHarness({
    SeedWorkspace? seed,
    int batchSize = maxBatchWrites,
    Duration ackTimeout = kCommitAckTimeout,
  }) : p = PlanHarness(seed) {
    journal = Journal(random: Random(11));
    committer = PlanCommitter(
      repository: p.repo,
      cache: p.cache,
      registry: defaultFieldTypeRegistry(),
      isOnline: () => online,
      batchSize: batchSize,
      ackTimeout: ackTimeout,
    );
    registerHostOps(
      p.registry,
      HostServices(store: p.store, committer: committer, journal: journal),
    );
  }

  final PlanHarness p;
  late final Journal journal;
  late final PlanCommitter committer;

  /// What the host's `SyncStatus` says.
  bool online = true;

  /// Progress events of every host call.
  final List<HarnessEvent> events = [];
  int _calls = 0;

  SeedWorkspace get seed => p.seed;

  HarnessContext userContext({DateTime? at, Actor actor = user}) =>
      HarnessContext(
        workspaceId: 'w1',
        actor: actor,
        grants: Grants.all(),
        now: at ?? now,
        today: today,
        events: _ListSink(events),
      );

  /// Calls host op [op] as [actor] (the user by default).
  Future<HarnessResponse> host(
    String op,
    Map<String, Object?> args, {
    DateTime? at,
    Actor actor = user,
  }) => p.harness.call(
    HarnessRequest(op: op, args: args, callId: 'h.${++_calls}'),
    userContext(at: at, actor: actor),
  );

  Future<Map<String, Object?>> ok(
    String op,
    Map<String, Object?> args, {
    DateTime? at,
  }) async {
    final r = await host(op, args, at: at);
    if (r is HarnessFailure) fail('$op failed: ${r.error.toJson()}');
    return (r as HarnessOk).result;
  }

  Future<HarnessError> error(
    String op,
    Map<String, Object?> args, {
    DateTime? at,
    Actor actor = user,
  }) async {
    final r = await host(op, args, at: at, actor: actor);
    if (r is HarnessOk) fail('$op should fail but gave ${r.result}');
    return (r as HarnessFailure).error;
  }

  /// Plans one call in a new assistant turn and seals it.
  Future<Plan> plan(String op, Map<String, Object?> args) async {
    p.newTurn();
    await p.ok(op, args);
    return p.sealPlan();
  }

  Future<Map<String, Object?>> commit(
    Plan plan, {
    List<String>? itemIds,
    DateTime? at,
  }) =>
      ok('plans.commit', {'planId': plan.planId, 'itemIds': ?itemIds}, at: at);

  Future<Map<String, Object?>> undo(String journalId, {DateTime? at}) =>
      ok('journal.undo', {'journalId': journalId}, at: at);

  /// Lets the repository's emissions reach the cache.
  Future<void> settle() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  /// The stored collection [id].
  Future<Collection?> stored(String id) => p.repo.getCollection(id);

  /// The stored card [id] of [collectionId].
  MorkvaObject? card(String collectionId, String id) =>
      p.repo.objectsOf(collectionId).where((o) => o.id == id).firstOrNull;

  Future<void> dispose() => p.dispose();
}

final class _ListSink implements Sink<HarnessEvent> {
  _ListSink(this._events);

  final List<HarnessEvent> _events;

  @override
  void add(HarnessEvent data) => _events.add(data);

  @override
  void close() {}
}

/// The option id of single-select [fieldId] on [card].
String? optionOf(MorkvaObject? card, String fieldId) =>
    (card?[fieldId] as SingleSelectFieldValue?)?.optionId;
