import '../../../api/data/data_repository.dart';
import '../../domain/domain.dart';
import '../cache/result_store.dart';
import '../cache/workspace_cache.dart';
import '../harness.dart';
import '../ops/host_ops.dart';
import '../ops/module_ops.dart';
import '../ops/plan_protocol_ops.dart';
import '../ops/protocol_ops.dart';
import '../ops/read_ops.dart';
import '../ops/ui_ops.dart';
import '../ops/view_ops.dart';
import '../plan/journal.dart';
import '../plan/plan_committer.dart';
import '../plan/plan_store.dart';
import '../query/aggregate_engine.dart';
import '../query/query_engine.dart';

/// The one harness every caller shares (D17): the assistant and the
/// automation runner. A second [Harness] would mint turns the first does not
/// know, and a second [HostServices] would bypass its double-commit guard.
///
/// Built once with the [AutomationCatalog] (module ops and the committer
/// reach automation docs through it) and re-bound per workspace:
/// [initialize] after the data repository is ready, [reset] on sign-out
/// (after the runner's reset, before the repository's dispose).
final class HarnessSession {
  HarnessSession({
    required DataRepository repository,
    required AutomationCatalog catalog,
    required OnlineCheck isOnline,
  }) : cache = WorkspaceCache(repository) {
    queries = QueryEngine(cache, results);
    aggregates = AggregateEngine(queries);
    committer = PlanCommitter(
      repository: repository,
      cache: cache,
      registry: registry,
      isOnline: isOnline,
      catalog: catalog,
    );
    final services = PlanServices(
      cache: cache,
      queries: queries,
      store: plans,
      registry: registry,
    );
    final ops = OperationRegistry();
    registerProtocolOps(ops);
    registerReadOps(
      ops,
      queries: queries,
      aggregates: aggregates,
      // A module run pages its own results and never evicts the chat's.
      thread: (ctx) => ctx.actor.kind == ActorKind.plugin
          ? 'run:${ctx.turnId}'
          : chatThread(),
    );
    registerUiOps(ops, queries: queries);
    registerPlanOps(ops, services);
    registerViewOps(ops, services);
    registerModuleOps(ops, catalog: catalog, services: services);
    host = HostServices(store: plans, committer: committer, journal: journal);
    registerHostOps(ops, host);
    harness = Harness(ops);
  }

  final WorkspaceCache cache;
  final ResultStore results = ResultStore();
  final FieldTypeRegistry registry = defaultFieldTypeRegistry();
  late final QueryEngine queries;
  late final AggregateEngine aggregates;
  final PlanStore plans = PlanStore();
  final Journal journal = Journal();
  late final PlanCommitter committer;
  late final HostServices host;
  late final Harness harness;

  /// The chat thread the assistant's reads store their results under; the
  /// assistant sets it (read per call, so switching threads needs nothing).
  String Function() chatThread = () => '';

  /// Binds the cache to [workspaceId]; the repository must already be
  /// initialized for it.
  void initialize(String workspaceId) => cache.initialize(workspaceId);

  /// Forgets turns, plans, journals and result handles, then unbinds the
  /// cache. [initialize] may follow.
  Future<void> reset() async {
    harness.reset();
    plans.reset();
    journal.reset();
    results.clear();
    await cache.reset();
  }
}
