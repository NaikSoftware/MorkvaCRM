/// Shared setup for the query engine tests: the seed workspace behind a
/// [FakeDataRepository], a [WorkspaceCache] over it and both engines.
library;

import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/core/harness/cache/result_store.dart';
import 'package:morkva_crm/core/harness/cache/workspace_cache.dart';
import 'package:morkva_crm/core/harness/harness.dart';
import 'package:morkva_crm/core/harness/query/aggregate_engine.dart';
import 'package:morkva_crm/core/harness/query/query_engine.dart';
import 'package:morkva_crm/core/harness/query/result_shaper.dart';

import '../../../features/collections/fake_data_repository.dart';
import '../fixtures/seed_workspace.dart';

export '../fixtures/seed_workspace.dart';

/// The seed's "today" as the host passes it (a local calendar day).
final DateTime today = DateTime(2026, 11, 10);

const String thread = 't1';

HarnessContext context({ScreenContext? focus, Grants? grants}) =>
    HarnessContext(
      workspaceId: 'w1',
      actor: Actor.assistant,
      grants: grants ?? Grants.all(),
      now: DateTime(2026, 11, 10, 14, 30),
      today: today,
      focus: focus,
    );

/// A live seed workspace with both engines over it.
final class QueryHarness {
  QueryHarness(this.seed, {ResultShaper shaper = const ResultShaper()})
    : repo = seed.repository() {
    cache = WorkspaceCache(repo)..initialize('w1');
    results = ResultStore();
    queries = QueryEngine(cache, results, shaper: shaper);
    aggregates = AggregateEngine(queries);
  }

  final SeedWorkspace seed;
  final FakeDataRepository repo;
  late final WorkspaceCache cache;
  late final ResultStore results;
  late final QueryEngine queries;
  late final AggregateEngine aggregates;

  /// The seeded collections with lookups resolved.
  late final List<Collection> resolved = resolveLookups(seed.collections);

  Collection collection(String id) => resolved.firstWhere((c) => c.id == id);

  /// Every seeded card with its calculated values, computed apart from the
  /// engines (the expected side of the assertions).
  late final Derivation derivation = Derivation(
    collections: resolved,
    objects: seed.objects,
    today: today,
  );

  List<MorkvaObject> derived(String collectionId) =>
      derivation.objectsOf(collectionId);

  Future<Map<String, Object?>> query(
    Map<String, Object?> args, {
    ScreenContext? focus,
    Grants? grants,
  }) => queries.query(
    args,
    context(focus: focus, grants: grants),
    thread: thread,
  );

  Future<Map<String, Object?>> aggregate(
    Map<String, Object?> args, {
    ScreenContext? focus,
    Grants? grants,
  }) => aggregates.aggregate(
    args,
    context(focus: focus, grants: grants),
    thread: thread,
  );

  Future<void> dispose() => cache.reset();
}

/// The ids of [rows] (`cards.query` / `cards.get` rows).
List<String> idsOf(Object? rows) => [
  for (final r in rows! as List) (r as Map)['id'] as String,
];

/// The ids of [objects] that pass [test], in stored order.
List<String> where(
  List<MorkvaObject> objects,
  bool Function(MorkvaObject o) test,
) => [
  for (final o in objects)
    if (test(o)) o.id,
];

num? numberOf(MorkvaObject o, String fieldId) => switch (o[fieldId]) {
  NumberFieldValue(:final value) => value,
  CalculatedFieldValue(:final num cached) => cached,
  _ => null,
};
