/// The read and UI ops registered on a real [Harness] over the seed
/// workspace, called the way the agent calls them (schema checks included).
library;

import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/core/harness/harness.dart';
import 'package:morkva_crm/core/harness/ops/read_ops.dart';
import 'package:morkva_crm/core/harness/ops/ui_ops.dart';

import '../query/query_fixture.dart';

export '../query/query_fixture.dart';

final class OpsHarness {
  OpsHarness([SeedWorkspace? seed])
    : q = QueryHarness(seed ?? SeedWorkspace()) {
    registry = OperationRegistry();
    registerReadOps(
      registry,
      queries: q.queries,
      aggregates: q.aggregates,
      thread: (_) => thread,
    );
    registerUiOps(registry, queries: q.queries);
    harness = Harness(registry);
  }

  final QueryHarness q;
  late final OperationRegistry registry;
  late final Harness harness;

  /// The thread the ops store result handles under.
  String thread = 't1';

  Future<HarnessResponse> call(
    String op,
    Map<String, Object?> args, {
    ScreenContext? focus,
    Grants? grants,
  }) => harness.call(
    HarnessRequest(op: op, args: args, callId: 'c1'),
    context(focus: focus, grants: grants),
  );

  /// The result of a call that must succeed.
  Future<Map<String, Object?>> ok(
    String op,
    Map<String, Object?> args, {
    ScreenContext? focus,
    Grants? grants,
  }) async {
    final r = await call(op, args, focus: focus, grants: grants);
    if (r is HarnessFailure) throw StateError('$op failed: ${r.error}');
    return (r as HarnessOk).result;
  }

  /// The error of a call that must fail.
  Future<HarnessError> fails(
    String op,
    Map<String, Object?> args, {
    ScreenContext? focus,
    Grants? grants,
  }) async {
    final r = await call(op, args, focus: focus, grants: grants);
    if (r is HarnessOk) throw StateError('$op succeeded: ${r.result}');
    return (r as HarnessFailure).error;
  }

  Future<void> dispose() => q.dispose();
}

/// The Orders screen: the Unpaid board, cards searched for "dress".
ScreenContext unpaidDresses({String? openCardId}) => ScreenContext(
  page: ScreenPage.collection,
  collectionId: SeedIds.orders,
  viewId: 'v_or_unpaid',
  viewName: 'Unpaid',
  mode: 'board',
  filters: const [ViewFilter(fieldId: OrderFields.paid, op: FilterOp.isFalse)],
  search: 'dress',
  openCardId: openCardId,
);
