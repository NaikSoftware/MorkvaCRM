import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/automation/store_catalog.dart';
import 'package:morkva_crm/core/harness/harness.dart';
import 'package:morkva_crm/core/harness/session/harness_session.dart';

import '../../../automation/fakes/fake_stores.dart';
import '../../../features/collections/fake_data_repository.dart';
import '../plan/plan_fixture.dart';

void main() {
  late FakeStores fakes;
  late FakeDataRepository repo;
  late StoreAutomationCatalog catalog;
  late HarnessSession session;

  setUp(() {
    fakes = FakeStores();
    repo = SeedWorkspace().repository();
    catalog = StoreAutomationCatalog(fakes.stores, uid: () => 'u1');
    session = HarnessSession(
      repository: repo,
      catalog: catalog,
      isOnline: () => true,
    )..initialize('w1');
  });
  tearDown(() async {
    await session.reset();
    await fakes.dispose();
  });

  var calls = 0;
  Future<HarnessResponse> call(
    String op,
    Map<String, Object?> args,
    Actor actor, {
    String? turnId,
    Grants? grants,
  }) => session.harness.call(
    HarnessRequest(op: op, args: args, callId: 's.${++calls}', turnId: turnId),
    HarnessContext(
      workspaceId: 'w1',
      actor: actor,
      grants: grants ?? Grants(kAssistantCaps),
      now: now,
      today: today,
    ),
  );

  Future<Map<String, Object?>> ok(
    String op,
    Map<String, Object?> args,
    Actor actor, {
    String? turnId,
    Grants? grants,
  }) async {
    final r = await call(op, args, actor, turnId: turnId, grants: grants);
    if (r is HarnessFailure) fail('$op failed: ${r.error.toJson()}');
    return (r as HarnessOk).result;
  }

  test('one harness with every op, module ops included; the committer '
      'writes through the catalog', () async {
    final ids = [for (final d in session.harness.descriptors) d.id];
    expect(ids, hasLength(38));
    expect(ids, containsAll(['modules.save', 'runs.get', 'plans.commit']));
    expect(session.committer.catalog, same(catalog));
    expect(session.queries.cache, same(session.cache));
  });

  test("a module run's reads go to its own run thread, the assistant's to "
      'the chat thread', () async {
    session.chatThread = () => 'chat-1';
    const plugin = Actor.plugin('stamp');
    final runTurn = session.harness.openTurn(plugin);

    final chat = await ok('cards.query', {
      'collection': 'Orders',
    }, Actor.assistant);
    final run = await ok(
      'cards.query',
      {'collection': 'Orders', 'limit': 3},
      plugin,
      turnId: runTurn,
      grants: Grants(kModuleGrantable),
    );

    final results = session.results;
    expect(results.get(chat['handle']! as String, thread: 'chat-1'), isNotNull);
    expect(
      results.get(run['handle']! as String, thread: 'run:$runTurn'),
      isNotNull,
    );
    expect(results.get(run['handle']! as String, thread: 'chat-1'), isNull);
  });

  test('reset forgets turns, plans, journals and results, then unbinds the '
      'cache; initialize binds again', () async {
    final turn = session.harness.openTurn(Actor.assistant);
    final order = SeedCards.order(1001);
    await ok(
      'cards.update',
      {
        'collection': 'Orders',
        'target': {
          'ids': [order],
        },
        'set': {'Item': 'Rush job'},
      },
      Actor.assistant,
      turnId: turn,
    );
    final sealed = await ok(
      'plans.seal',
      {'turnId': turn},
      Actor.assistant,
      turnId: turn,
    );
    final planId = sealed['planId']! as String;
    final receipt = await ok(
      'plans.commit',
      {'planId': planId},
      const Actor.user('u1'),
      grants: Grants.all(),
    );
    final journalId = receipt['journalId']! as String;
    final query = await ok('cards.query', {
      'collection': 'Orders',
    }, Actor.assistant);

    expect(session.journal.get(journalId), isNotNull);
    final pending = session.reset();

    // Turns, plans, journals and results go before the cache's async reset.
    expect(session.harness.ownsTurn(Actor.assistant, turn), isFalse);
    expect(session.plans.get(planId), isNull);
    expect(session.journal.get(journalId), isNull);
    expect(session.results.get(query['handle']! as String), isNull);
    await pending;
    expect(session.cache.workspaceId, isNull);

    session.initialize('w1');
    expect(session.cache.workspaceId, 'w1');
  });
}
