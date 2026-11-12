import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/api/data/data_repository.dart';
import 'package:morkva_crm/core/automation/host_commits.dart';
import 'package:morkva_crm/core/automation/store_catalog.dart';
import 'package:morkva_crm/core/domain/automation/automation.dart';
import 'package:morkva_crm/core/harness/harness.dart';
import 'package:morkva_crm/core/harness/session/harness_session.dart';

import '../../automation/fakes/fake_stores.dart';
import '../../features/collections/fake_data_repository.dart';
import '../harness/plan/plan_fixture.dart';

const _module = 'stamp';
const _plugin = Actor.plugin(_module);

void main() {
  late FakeStores fakes;
  late FakeDataRepository repo;
  late HarnessSession session;
  late HostCommits host;
  late List<CardChange> changes;
  var online = true;
  final order = SeedCards.order(1001);

  setUp(() {
    online = true;
    fakes = FakeStores();
    repo = SeedWorkspace().repository();
    session = HarnessSession(
      repository: repo,
      catalog: StoreAutomationCatalog(fakes.stores, uid: () => 'u1'),
      isOnline: () => online,
    )..initialize('w1');
    host = HostCommits(
      session,
      uid: () => 'u1',
      workspaceId: () => 'w1',
      now: () => now,
    );
    changes = [];
    repo.changes.listen(changes.add);
  });
  tearDown(() async {
    await session.reset();
    await fakes.dispose();
  });

  /// A plan [actor] sealed in its own turn: one update of order 1001.
  Future<String> plan({Actor actor = _plugin}) async {
    final turn = session.harness.openTurn(actor);
    HarnessContext ctx() => HarnessContext(
      workspaceId: 'w1',
      actor: actor,
      grants: Grants(kModuleGrantable),
      now: now,
      today: today,
      turnId: turn,
    );
    final planned = await session.harness.call(
      HarnessRequest(
        op: 'cards.update',
        args: {
          'collection': 'Orders',
          'target': {
            'ids': [order],
          },
          'set': {'Item': 'Stamped'},
        },
        callId: 'm.1',
        turnId: turn,
      ),
      ctx(),
    );
    expect(planned, isA<HarnessOk>());
    final sealed = await session.harness.call(
      HarnessRequest(
        op: 'plans.seal',
        args: {'turnId': turn},
        callId: 'm.2',
        turnId: turn,
      ),
      ctx(),
    );
    return (sealed as HarnessOk).result['planId']! as String;
  }

  RunRecord run(String planId, {String moduleId = _module}) => RunRecord(
    id: 'run_1',
    status: RunStatus.applying,
    moduleId: moduleId,
    moduleName: 'Stamp',
    moduleVersion: '1.0.0',
    codeHash: 'sha256:x',
    actionId: 'stamp',
    actionLabel: 'Stamp',
    trigger: const RunTrigger(
      kind: TriggerKind.button,
      collectionId: SeedIds.orders,
    ),
    apply: ApplyMode.ask,
    by: 'user:u1',
    device: 'web',
    sessionId: 't_1',
    startedAt: now,
    depth: 2,
    chain: const ['a_0', 'a_1'],
    planId: planId,
  );

  test('commits as the user with the run origin keyed by the plan, drops '
      'the plan once nothing failed, and undo writes as undo', () async {
    final planId = await plan();
    final record = run(planId);
    final progress = <(int, int)>[];
    final committed = await host.commit(
      record,
      onProgress: (d, t) => progress.add((d, t)),
    );
    final result = (committed as HarnessOk).result;
    expect(result['applied'], hasLength(1));
    await pumpEventQueue();
    final origin = changes.single.origin;
    expect(origin.kind, WriteKind.automation);
    expect(origin.actor, 'plugin:$_module');
    expect(origin.runId, 'run_1');
    expect(origin.commitId, planId);
    expect(origin.depth, 2);
    expect(origin.chain, ['a_0', 'a_1']);
    expect(session.plans.get(planId), isNull);
    // The journal is the user's: undo passes the actor check.
    final journalId = result['journalId']! as String;
    expect(session.journal.get(journalId)!.actor, 'user:u1');

    final undone = await host.undo(
      RunRecord.fromJson('run_1', {
        ...record.toJson(),
        'status': 'succeeded',
        'journalId': journalId,
      }),
    );
    expect(undone, isA<HarnessOk>());
    await pumpEventQueue();
    expect(changes.last.origin.kind, WriteKind.undo);
    expect(changes.last.origin.runId, 'run_1');
  });

  test("refuses a plan that is not the run's module's", () async {
    final planId = await plan(actor: Actor.assistant);
    final refused = await host.commit(run(planId));
    expect((refused as HarnessFailure).error.code, ErrorCode.internal);
    expect(session.plans.get(planId), isNotNull, reason: 'nothing committed');

    final gone = await host.commit(run('p_missing'));
    expect((gone as HarnessFailure).error.code, ErrorCode.planExpired);
  });

  test('offline: the commit fails before writing and the plan stays for a '
      'later approve; reject drops it', () async {
    final planId = await plan();
    online = false;
    final refused = await host.commit(run(planId));
    expect((refused as HarnessFailure).error.code, ErrorCode.offline);
    expect(changes, isEmpty);
    expect(session.plans.get(planId), isNotNull);

    expect(await host.reject(planId, skipped: true), isA<HarnessOk>());
    expect(session.plans.get(planId), isNull);
  });

  test('retryFailed retries the failed items, then drops the plan', () async {
    final planId = await plan();
    repo.batchWriteError = (_) => 'unavailable';
    final first = await host.commit(run(planId));
    expect((first as HarnessOk).result['failed'], hasLength(1));
    expect(session.plans.get(planId), isNotNull, reason: 'kept for a retry');

    repo.batchWriteError = null;
    final retried = await host.retryFailed(run(planId));
    expect((retried as HarnessOk).result['applied'], hasLength(1));
    expect(session.plans.get(planId), isNull);
  });
}
