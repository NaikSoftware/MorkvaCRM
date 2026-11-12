import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/api/data/data_repository.dart';
import 'package:morkva_crm/core/automation/automation_runner.dart';
import 'package:morkva_crm/core/automation/engine/protocol.dart';
import 'package:morkva_crm/core/automation/engine/script_engine.dart';
import 'package:morkva_crm/core/automation/runner_api.dart';
import 'package:morkva_crm/core/automation/store_catalog.dart';
import 'package:morkva_crm/core/domain/automation/automation.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/core/domain/ids.dart';
import 'package:morkva_crm/core/harness/session/harness_session.dart';

import '../../automation/fakes/fake_script_engine.dart';
import '../../automation/fakes/fake_stores.dart';
import '../../features/collections/fake_data_repository.dart';
import '../domain/automation/fixtures.dart' show stampManifest;
import '../harness/fixtures/seed_workspace.dart';

const _orders = SeedIds.orders;
const _code = '(() => { morkva.action("stamp", async (ctx) => "ok"); })();';

/// A run store whose writes never resolve, like Firestore offline.
final class OfflineRunStore implements RunStore {
  OfflineRunStore(this.inner);
  final RunStore inner;
  var writes = 0;

  @override
  Stream<List<RunRecord>> watchRecent() => inner.watchRecent();
  @override
  Future<RunRecord?> get(String runId) => inner.get(runId);
  @override
  Future<void> create(RunRecord run) {
    writes++;
    return Completer<void>().future;
  }

  @override
  Future<void> update(RunRecord run, {required Set<String> fields}) {
    writes++;
    return Completer<void>().future;
  }

  @override
  Future<int> prune({int keep = RunStore.kWindow}) => Completer<int>().future;
}

/// The runner over the seed workspace, the in-memory stores and the fake
/// engine; the stamp module is installed and consented.
final class Rig {
  Rig({
    String sessionId = 't_1',
    FakeCrashMarker? marker,
    bool offlineRuns = false,
  }) : marker = marker ?? FakeCrashMarker() {
    repo = seed.repository();
    final runs = offlineRuns ? OfflineRunStore(fakes.runs) : fakes.runs;
    offline = runs is OfflineRunStore ? runs : null;
    stores = AutomationStores(
      modules: fakes.modules,
      automations: fakes.automations,
      runs: runs,
      grants: fakes.grants,
    );
    final catalog = StoreAutomationCatalog(stores, uid: () => 'u1');
    session = HarnessSession(
      repository: repo,
      catalog: catalog,
      isOnline: () => online,
    )..initialize('w1');
    runner = AutomationRunner(
      session: session,
      repository: repo,
      stores: stores,
      engine: engine,
      sessionId: sessionId,
      crashMarker: this.marker,
      now: () => clock ?? DateTime.now(),
      ids: IdGenerator(random: Random(9)),
      settleTimeout: const Duration(seconds: 2),
    );
    catalog.hooks = runner;
    runner.finished.listen(finished.add);
  }

  final seed = SeedWorkspace();
  late final FakeDataRepository repo;
  final fakes = FakeStores();
  late final AutomationStores stores;
  OfflineRunStore? offline;
  late final HarnessSession session;
  final engine = FakeScriptEngine(actions: const ['stamp']);
  final FakeCrashMarker marker;
  late final AutomationRunner runner;
  final finished = <RunView>[];
  bool online = true;
  DateTime? clock;
  late ModuleRecord module;

  /// Installs the stamp module (scope `any`) and the user's consent.
  Future<void> install({
    bool autoApply = false,
    int? timeoutMs,
    bool consented = true,
  }) async {
    final manifest = stampManifest();
    ((manifest['actions']! as List).first as Map)['scope'] = 'any';
    if (timeoutMs != null) manifest['timeoutMs'] = timeoutMs;
    module = ModuleRecord.fromBundle(
      ModuleBundle.of(manifest, _code),
      source: ModuleSource.import,
      createdBy: 'user:u1',
      now: DateTime.utc(2026, 11, 12),
    );
    await fakes.modules.save(module);
    if (consented) await fakes.grants.save('u1', consentFor(autoApply));
  }

  GrantRecord consentFor(bool autoApply, {List<String>? caps}) => GrantRecord(
    moduleId: module.id,
    codeHash: module.bundleHash,
    version: module.version,
    codeBytes: module.codeBytes,
    caps: caps ?? module.manifest!.capabilities,
    collections: const [_orders],
    autoApply: autoApply,
    grantedAt: DateTime.utc(2026, 11, 12),
    via: GrantVia.consentSheet,
  );

  Future<AutomationRecord> automation({
    String id = 'a_1',
    TriggerSpec trigger = const ButtonTrigger(
      scope: ButtonScope.card,
      collectionId: _orders,
    ),
    ApplyMode apply = ApplyMode.ask,
    bool enabled = true,
  }) async {
    final a = AutomationRecord(
      id: id,
      name: 'Stamp $id',
      enabled: enabled,
      moduleId: module.id,
      actionId: 'stamp',
      params: const {'dateField': OrderFields.delivery},
      trigger: trigger,
      button: trigger is ButtonTrigger
          ? const ButtonSpec(label: 'Stamp')
          : null,
      apply: apply,
      autoBy: apply == ApplyMode.auto ? 'u1' : null,
      createdBy: 'user:u1',
      createdAt: DateTime.utc(2026, 11, 12),
      updatedAt: DateTime.utc(2026, 11, 12),
    );
    await fakes.automations.save(a);
    return a;
  }

  /// Binds the runner and waits for the first store emissions.
  Future<void> start() async {
    runner.initialize(workspaceId: 'w1', uid: 'u1');
    await pumpEventQueue();
    await session.cache.ready;
  }

  /// The module plans `Item = [item]` on the run's card.
  void stamps({String item = 'Stamped', String? message = 'Stamped'}) =>
      engine.action = (m, inv) async {
        final card = inv.ctx['card']! as Map;
        await m.call('cards.update', {
          'collection': 'Orders',
          'target': {
            'ids': [card['id']],
          },
          'set': {'Item': item},
        });
        return message;
      };

  MorkvaObject card(String id) =>
      repo.objectsOf(_orders).firstWhere((o) => o.id == id);

  String? item(String id) =>
      (card(id)[OrderFields.item]! as TextFieldValue).text;

  Future<RunRecord?> doc(String runId) => fakes.runs.get(runId);

  Future<List<RunRecord>> docs() => fakes.runs.watchRecent().first;

  RunView? live(String runId) =>
      runner.activity.runs.where((r) => r.runId == runId).firstOrNull;

  Future<void> dispose() async {
    await runner.dispose();
    await session.reset();
    await fakes.dispose();
  }
}

/// Polls [test] until it holds (real time; the runner waits on real
/// timers and the cache).
Future<void> until(
  FutureOr<bool> Function() test, {
  Duration timeout = const Duration(seconds: 5),
  String? reason,
}) async {
  final end = DateTime.now().add(timeout);
  while (!await test()) {
    if (DateTime.now().isAfter(end)) fail('timed out: ${reason ?? ''}');
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

final _order = SeedCards.order(1001);

void main() {
  late Rig rig;

  setUp(() {
    rig = Rig();
  });
  tearDown(() => rig.dispose());

  Future<RunRecord> settled(String runId) async {
    await until(
      () async => (await rig.doc(runId))?.status.terminal ?? false,
      reason: 'run $runId ends',
    );
    return (await rig.doc(runId))!;
  }

  Future<RunRecord> awaitingReview(String runId) async {
    await until(
      () => rig.live(runId)?.status == RunStatus.awaitingReview,
      reason: 'run $runId awaits review',
    );
    return (await rig.doc(runId))!;
  }

  group('button runs', () {
    setUp(() async {
      await rig.install();
      await rig.automation();
      await rig.start();
      rig.stamps();
    });

    test('Ask: the plan waits for review in this session, extended to 8 h, '
        'and releases the queue', () async {
      final first = await rig.runner.pressCard('a_1', cardId: _order);
      final doc = await awaitingReview(first);
      expect(doc.sessionId, 't_1');
      expect(doc.planId, isNotNull);
      expect(doc.planTitle, isNotNull);
      expect(doc.log.policy, 'review: the automation asks first');
      expect(doc.trigger.cardId, _order);
      final plan = rig.session.plans.get(doc.planId!)!;
      expect(
        plan.expiresAt.difference(DateTime.now()).inMinutes,
        greaterThan(7 * 60),
      );
      expect(rig.runner.reviewPlan(first)!['planId'], doc.planId);
      expect(rig.runner.activity.needsReview, 1);
      expect(rig.finished.single.status, RunStatus.awaitingReview);

      // The second press runs although the first still awaits review.
      final second = await rig.runner.pressCard('a_1', cardId: _order);
      await awaitingReview(second);
      expect(rig.runner.activity.needsReview, 2);
    });

    test('approve writes applyStartedAt first, applies as the user, and '
        'undo reverts it', () async {
      final runId = await rig.runner.pressCard('a_1', cardId: _order);
      await awaitingReview(runId);
      final changes = <CardChange>[];
      rig.repo.changes.listen(changes.add);

      await rig.runner.approve(runId);
      final doc = await settled(runId);
      expect(doc.status, RunStatus.succeeded);
      expect(doc.receipt!.applied, 1);
      expect(doc.touchedCardIds, [_order]);
      expect(doc.journalId, isNotNull);
      expect(doc.summary, 'Stamped');
      expect(rig.item(_order), 'Stamped');
      expect(rig.fakes.runs.updates.map((u) => u.$2), [
        {'applyStartedAt'},
        kFinalRunKeys,
      ]);
      expect(changes.single.origin.kind, WriteKind.automation);
      expect(changes.single.origin.runId, runId);
      expect(rig.runner.reviewPlan(runId), isNull);

      expect(rig.runner.canUndo(runId), isTrue);
      await rig.runner.undo(runId);
      expect(rig.item(_order), isNot('Stamped'));
      expect((await rig.doc(runId))!.undoneAt, isNotNull);
      expect(rig.fakes.runs.updates.last.$2, {'undoneAt'});
      expect(changes.last.origin.kind, WriteKind.undo);
      expect(rig.runner.canUndo(runId), isFalse);
    });

    test('a review past its 8 h expires: approve is refused', () async {
      final runId = await rig.runner.pressCard('a_1', cardId: _order);
      await awaitingReview(runId);
      rig.clock = DateTime.now().add(const Duration(hours: 9));
      expect(rig.runner.reviewPlan(runId), isNull);
      await expectLater(
        rig.runner.approve(runId),
        throwsA(
          isA<AutomationRefused>().having((e) => e.code, 'code', 'expired'),
        ),
      );
      final doc = await settled(runId);
      expect(doc.status, RunStatus.expired);
      expect(rig.item(_order), isNot('Stamped'));
    });

    test('new module code rejects the waiting review code_changed', () async {
      final runId = await rig.runner.pressCard('a_1', cardId: _order);
      await awaitingReview(runId);
      await rig.fakes.modules.save(
        ModuleRecord.fromBundle(
          ModuleBundle.of(rig.module.manifestJson, '$_code // v2'),
          source: ModuleSource.import,
          createdBy: 'user:u1',
          now: DateTime.utc(2026, 11, 12),
        ),
      );
      final doc = await settled(runId);
      expect(doc.status, RunStatus.rejected);
      expect(doc.reason, RunReason.codeChanged);
    });

    test('reject drops the plan and ends the run rejected', () async {
      final runId = await rig.runner.pressCard('a_1', cardId: _order);
      final planId = (await awaitingReview(runId)).planId!;
      await rig.runner.reject(runId);
      final doc = await settled(runId);
      expect(doc.status, RunStatus.rejected);
      expect(rig.session.plans.get(planId), isNull);
      expect(rig.item(_order), isNot('Stamped'));
    });

    test('approve re-checks the live consent and refuses offline', () async {
      final runId = await rig.runner.pressCard('a_1', cardId: _order);
      await awaitingReview(runId);

      rig.online = false;
      await expectLater(
        rig.runner.approve(runId),
        throwsA(
          isA<AutomationRefused>().having((e) => e.code, 'code', 'offline'),
        ),
      );
      rig.online = true;

      // The consent lost a capability between seal and approve.
      await rig.fakes.grants.save(
        'u1',
        rig.consentFor(false, caps: const ['schema:read', 'data:read']),
      );
      await expectLater(
        rig.runner.approve(runId),
        throwsA(
          isA<AutomationRefused>()
              .having((e) => e.code, 'code', 'needs_consent')
              .having((e) => e.message, 'message', kPermissionsChanged),
        ),
      );
      expect(rig.item(_order), isNot('Stamped'));
    });

    test('the applyStartedAt guard: a review replaced in another window '
        'is refused', () async {
      final runId = await rig.runner.pressCard('a_1', cardId: _order);
      final doc = await awaitingReview(runId);
      rig.fakes.runs.putRaw(runId, {
        ...doc.toJson(),
        'applyStartedAt': DateTime.now(),
      });
      await expectLater(
        rig.runner.approve(runId),
        throwsA(
          isA<AutomationRefused>().having((e) => e.code, 'code', 'replaced'),
        ),
      );
      expect(rig.item(_order), isNot('Stamped'));
    });

    test('an approve that fails offline mid-way returns to review', () async {
      final runId = await rig.runner.pressCard('a_1', cardId: _order);
      await awaitingReview(runId);
      // Online at the gate (checked before approve's first await), offline
      // by the time the committer checks.
      final approving = rig.runner.approve(runId);
      rig.online = false;
      await expectLater(
        approving,
        throwsA(
          isA<AutomationRefused>().having((e) => e.code, 'code', 'offline'),
        ),
      );
      rig.online = true;
      expect(rig.live(runId)!.status, RunStatus.awaitingReview);
      final doc = (await rig.doc(runId))!;
      expect(doc.status, RunStatus.awaitingReview);
      expect(doc.applyStartedAt, isNull);
    });

    test('a hung action times out at the manifest timeout', () async {
      await rig.install(timeoutMs: 1000);
      rig.engine.action = (m, inv) => Completer<Object?>().future;
      final doc = await settled(
        await rig.runner.pressCard('a_1', cardId: _order),
      );
      expect(doc.status, RunStatus.timedOut);
      expect(rig.engine.sessions.single.killedWith, 'timeout');
      expect(rig.runner.activity.runs, isEmpty, reason: 'the slot is free');
    });

    test('a module error keeps its stack', () async {
      rig.engine.action = (m, inv) async => throw StateError('boom');
      final failed = await settled(
        await rig.runner.pressCard('a_1', cardId: _order),
      );
      expect(failed.status, RunStatus.failed);
      expect(failed.reason, RunReason.moduleError);
      expect(failed.error!.message, contains('boom'));
      expect(failed.error!.stack, isNotNull);
      expect(rig.marker.leftover(), isNull, reason: 'cleared at finish');
    });

    test(
      'Stop: a queued run is skipped, a running one fails cancelled',
      () async {
        final gate = Completer<void>();
        rig.engine.action = (m, inv) async {
          await gate.future;
          return null;
        };
        final running = await rig.runner.pressCard('a_1', cardId: _order);
        await until(() => rig.engine.sessions.isNotEmpty);
        final queued = await rig.runner.pressCard('a_1', cardId: _order);
        expect(rig.live(queued)!.status, RunStatus.queued);
        expect(rig.live(queued)!.queuedAhead, 1);

        rig.runner.stop(queued);
        final skipped = await settled(queued);
        expect(skipped.status, RunStatus.skipped);
        expect(skipped.reason, RunReason.cancelled);

        rig.runner.stop(running);
        final stopped = await settled(running);
        expect(stopped.status, RunStatus.failed);
        expect(stopped.reason, RunReason.cancelled);
        expect(rig.engine.sessions.single.killedWith, 'cancelled');
      },
    );

    test(
      'engine unavailable: skipped and logged, the indicator knows',
      () async {
        rig.engine.engineStatus = EngineStatus.unavailable;
        final doc = await settled(
          await rig.runner.pressCard('a_1', cardId: _order),
        );
        expect(doc.reason, RunReason.engineUnavailable);
        expect(rig.runner.activity.engineUnavailable, isTrue);
        expect(rig.engine.loads, isEmpty);

        // The start itself failing reads the same way.
        rig.engine
          ..engineStatus = EngineStatus.available
          ..startError = const ScriptFailure(
            'engine_unavailable',
            'No sandbox',
          );
        final again = await settled(
          await rig.runner.pressCard('a_1', cardId: _order),
        );
        expect(again.status, RunStatus.skipped);
        expect(again.reason, RunReason.engineUnavailable);
      },
    );

    test('a forged stored codeHash does not pass consent: the hash of the '
        'code itself counts', () async {
      final forged = ModuleRecord(
        id: rig.module.id,
        manifestJson: rig.module.manifestJson,
        code: '$_code // changed',
        codeHash: rig.module.bundleHash, // claims the consented hash
        source: ModuleSource.import,
        version: rig.module.version,
        name: rig.module.name,
        createdBy: 'user:u1',
        createdAt: rig.module.createdAt,
        updatedAt: rig.module.updatedAt,
      );
      await rig.fakes.modules.save(forged);
      final doc = await settled(
        await rig.runner.pressCard('a_1', cardId: _order),
      );
      expect(doc.reason, RunReason.needsConsent);
      expect(rig.engine.loads, isEmpty);
    });

    test('the code that ran is the code whose hash was checked', () async {
      await awaitingReview(await rig.runner.pressCard('a_1', cardId: _order));
      expect(rig.engine.loads.single.code, rig.module.code);
    });

    test('a deleted card is skipped card_gone', () async {
      final doc = await settled(
        await rig.runner.pressCard('a_1', cardId: 'b_missing'),
      );
      expect(doc.reason, RunReason.cardGone);
    });

    test('the run docs never block the queue when writes wait for the '
        'server', () async {
      await rig.dispose();
      rig = Rig(offlineRuns: true);
      await rig.install();
      await rig.automation();
      await rig.start();
      rig.engine.action = (m, inv) async => throw StateError('boom');
      await rig.runner.pressCard('a_1', cardId: _order);
      await rig.runner.pressCard('a_1', cardId: _order);
      await until(() => rig.finished.length == 2);
      expect(rig.runner.activity.runs, isEmpty);
      expect(rig.offline!.writes, 2);
    });
  });

  group('auto apply and the queue', () {
    setUp(() async {
      await rig.install(autoApply: true);
      await rig.automation(apply: ApplyMode.auto);
      await rig.start();
      rig.stamps();
    });

    test('an auto run is created applying, commits and holds the slot '
        'until its writes settled', () async {
      final order2 = SeedCards.order(1002);
      String? seenBySecond;
      rig.engine.action = (m, inv) async {
        final card = (inv.ctx['card']! as Map)['id']! as String;
        if (card == order2) {
          // What the second run plans against: the first one's commit.
          final item = rig.session.cache.current(_orders)![_order]!;
          seenBySecond = (item[OrderFields.item]! as TextFieldValue).text;
        }
        await m.call('cards.update', {
          'collection': 'Orders',
          'target': {
            'ids': [card],
          },
          'set': {'Item': 'Stamped'},
        });
        return 'Stamped';
      };
      final first = await rig.runner.pressCard('a_1', cardId: _order);
      final second = await rig.runner.pressCard('a_1', cardId: order2);
      expect(rig.live(second)!.queuedAhead, 1);
      final a = await settled(first);
      expect(a.status, RunStatus.succeeded);
      expect(a.apply, ApplyMode.auto);
      expect(a.applyStartedAt, isNotNull);
      expect(rig.item(_order), 'Stamped');
      // Created as applying, then the final update only.
      expect(rig.fakes.runs.updates.where((u) => u.$1 == first).single.$2, {
        ...kFinalRunKeys,
      });
      final b = await settled(second);
      expect(b.status, RunStatus.succeeded);
      expect(rig.item(order2), 'Stamped');
      expect(seenBySecond, 'Stamped');
    });

    test(
      'a plan that would blank a field goes to review with the reason',
      () async {
        rig.engine.action = (m, inv) async {
          await m.call('cards.update', {
            'collection': 'Orders',
            'target': {
              'ids': [_order],
            },
            'clear': ['Price'],
          });
          return null;
        };
        final runId = await rig.runner.pressCard('a_1', cardId: _order);
        final doc = await awaitingReview(runId);
        expect(doc.log.policy, 'review: it would clear Price');
        expect(rig.runner.activity.needsReview, 1);
      },
    );

    test('auto-apply turned off while the run ran: the live consent sends '
        'it to review', () async {
      rig.engine.action = (m, inv) async {
        await rig.fakes.grants.save('u1', rig.consentFor(false));
        await m.call('cards.update', {
          'collection': 'Orders',
          'target': {
            'ids': [_order],
          },
          'set': {'Item': 'Stamped'},
        });
        return null;
      };
      final doc = await awaitingReview(
        await rig.runner.pressCard('a_1', cardId: _order),
      );
      expect(doc.log.policy, 'review: auto-apply is off for this module');
      expect(rig.item(_order), isNot('Stamped'));
    });

    test('an auto commit offline fails offline', () async {
      rig.online = false;
      final doc = await settled(
        await rig.runner.pressCard('a_1', cardId: _order),
      );
      expect(doc.status, RunStatus.failed);
      expect(doc.reason, RunReason.offline);
    });

    test('retryFailed retries the failed items of an applied run', () async {
      rig.engine.action = (m, inv) async {
        await m.call('cards.create', {
          'collection': 'Orders',
          'cards': [
            {
              'values': {'Item': 'Fresh'},
            },
          ],
        });
        await m.call('cards.update', {
          'collection': 'Orders',
          'target': {
            'ids': [_order],
          },
          'set': {'Item': 'Stamped'},
        });
        return null;
      };
      rig.repo.batchWriteError = (chunk) =>
          chunk.any((w) => w is ObjectUpdate) ? 'unavailable' : null;
      final runId = await rig.runner.pressCard('a_1', cardId: _order);
      final doc = await settled(runId);
      expect(doc.status, RunStatus.succeeded);
      expect(doc.receipt!.failed, 1);

      rig.repo.batchWriteError = null;
      await rig.runner.retryFailed(runId);
      expect(
        rig.fakes.runs.updates.last.$2,
        kAppliedRunKeys,
        reason: 'the succeeded update set',
      );
      expect((await rig.doc(runId))!.receipt!.failed, 0);
    });
  });

  group('event runs', () {
    late MorkvaObject target;

    setUp(() async {
      await rig.install(autoApply: true);
      target = rig.seed.orderCards.firstWhere(
        (o) =>
            (o[OrderFields.status] as SingleSelectFieldValue?)?.optionId !=
            SeedOptions.shipped,
      );
    });

    Future<void> setStatus(String optionId) => rig.repo.saveObject(
      rig
          .card(target.id)
          .copyWith(
            values: {
              ...rig.card(target.id).values,
              OrderFields.status: SingleSelectFieldValue(optionId),
            },
            updatedAt: DateTime.now(),
          ),
      schema: rig.seed.orders,
    );

    const shipped = EventTrigger(
      kind: TriggerKind.cardUpdated,
      collectionId: _orders,
      where: [
        {
          'field': OrderFields.status,
          'op': 'anyOf',
          'value': [SeedOptions.shipped],
        },
      ],
    );

    test(
      'enters fires once; Ask lands in review with the trigger snapshot',
      () async {
        await rig.automation(trigger: shipped);
        await rig.start();
        rig.stamps();
        await setStatus(SeedOptions.shipped);
        await until(() => rig.runner.activity.needsReview == 1);
        final run = rig.runner.activity.runs.single;
        expect(run.isButton, isFalse);
        final doc = (await rig.doc(run.runId))!;
        expect(doc.trigger.kind, TriggerKind.cardUpdated);
        expect(doc.trigger.changedFields, contains(OrderFields.status));
        expect(doc.trigger.before, contains(OrderFields.status));
        expect(doc.log.triggerEval, contains('became true'));
        final ctx = rig.engine.sessions.single.invocations.single.ctx;
        final trigger = ctx['trigger']! as Map;
        expect(trigger['kind'], 'card.updated');
        expect((trigger['after']! as Map)['id'], target.id);
        expect((trigger['before']! as Map)['id'], target.id);
        expect((ctx['automation']! as Map)['id'], 'a_1');
        // Already shipped: an unrelated write does not enter again.
        await rig.repo.saveObject(
          rig
              .card(target.id)
              .copyWith(
                values: {
                  ...rig.card(target.id).values,
                  OrderFields.item: const TextFieldValue('Other'),
                },
                updatedAt: DateTime.now(),
              ),
          schema: rig.seed.orders,
        );
        await until(
          () =>
              rig.runner.lastChecks('a_1').first.result ==
              LastCheckResult.notRun,
        );
        expect(rig.engine.sessions, hasLength(1));
      },
    );

    test("a direct self-trigger is not persisted; the parent's log counts "
        'it', () async {
      await rig.automation(
        trigger: const EventTrigger(
          kind: TriggerKind.cardUpdated,
          collectionId: _orders,
        ),
        apply: ApplyMode.auto,
      );
      await rig.start();
      rig.stamps();
      await setStatus(SeedOptions.shipped);
      await until(() async {
        final docs = await rig.docs();
        return docs.isNotEmpty && docs.single.status.terminal;
      });
      await pumpEventQueue();
      final docs = await rig.docs();
      expect(docs.single.status, RunStatus.succeeded);
      expect(
        docs.single.log.console.map((c) => c.text),
        contains("1 change by this run didn't re-trigger it"),
      );
      expect(rig.engine.sessions, hasLength(1));
    });

    test('Run again of an event run: the current card, the stored before, '
        'a manual run; a deleted card is card_gone', () async {
      await rig.automation(trigger: shipped);
      await rig.start();
      rig.engine.action = (m, inv) async => throw StateError('boom');
      await setStatus(SeedOptions.shipped);
      await until(() async => (await rig.docs()).isNotEmpty);
      final failed = await settled((await rig.docs()).single.id);
      expect(failed.reason, RunReason.moduleError);

      rig.stamps();
      final again = await rig.runner.runAgain(failed.id);
      final doc = await awaitingReview(again);
      expect(doc.parentRunId, failed.id);
      expect(doc.depth, 1);
      expect(doc.chain, ['a_1']);
      final trigger =
          rig.engine.sessions.last.invocations.single.ctx['trigger']! as Map;
      String? status(Object? image) =>
          ((image! as Map)['values']! as Map)[OrderFields.status] as String?;
      expect(status(trigger['after']), isNot(status(trigger['before'])));
      expect((trigger['after']! as Map)['id'], target.id);

      await rig.repo.deleteObject(_orders, target.id);
      final gone = await settled(await rig.runner.runAgain(failed.id));
      expect(gone.reason, RunReason.cardGone);
    });

    test('an indirect loop through real commits stops with a loop row '
        'that shows the chain', () async {
      await rig.automation(
        id: 'a_A',
        trigger: const EventTrigger(
          kind: TriggerKind.cardUpdated,
          collectionId: _orders,
          fields: [OrderFields.status],
        ),
        apply: ApplyMode.auto,
      );
      await rig.automation(
        id: 'a_B',
        trigger: const EventTrigger(
          kind: TriggerKind.cardUpdated,
          collectionId: _orders,
          fields: [OrderFields.item],
        ),
        apply: ApplyMode.auto,
      );
      await rig.start();
      rig.engine.action = (m, inv) async {
        final a = (inv.ctx['automation']! as Map)['id'];
        await m.call('cards.update', {
          'collection': 'Orders',
          'target': {
            'ids': [target.id],
          },
          'set': a == 'a_A' ? {'Item': 'Looped'} : {'Status': 'Done'},
        });
        return null;
      };
      await setStatus(SeedOptions.shipped);
      await until(() async {
        final docs = await rig.docs();
        return docs.any((d) => d.reason == RunReason.loop);
      });
      final docs = await rig.docs();
      final loop = docs.singleWhere((d) => d.reason == RunReason.loop);
      expect(loop.automationId, 'a_A');
      expect(loop.chain, ['a_A', 'a_B', 'a_A']);
      expect(loop.depth, 3);
      final b = docs.singleWhere((d) => d.automationId == 'a_B');
      expect(b.status, RunStatus.succeeded);
      expect(b.depth, 2);
      expect(b.chain, ['a_A', 'a_B']);
      expect(rig.engine.sessions, hasLength(2));
    });

    test('a module that needs consent writes one coalesced row', () async {
      await rig.automation(trigger: shipped);
      await rig.fakes.grants.delete('u1', rig.module.id);
      await rig.start();
      await setStatus(SeedOptions.shipped);
      await setStatus(SeedOptions.packing);
      await setStatus(SeedOptions.shipped);
      await until(() async {
        final docs = await rig.docs();
        return docs.length == 1 && docs.single.count == 3;
      });
      final doc = (await rig.docs()).single;
      expect(doc.reason, RunReason.needsConsent);
      expect(rig.fakes.runs.updates.map((u) => u.$2).toSet(), {
        {'count', 'endedAt'},
      });
    });

    test('a broken condition pauses the automation broken', () async {
      await rig.automation(
        trigger: const EventTrigger(
          kind: TriggerKind.cardUpdated,
          collectionId: _orders,
          where: [
            {
              'field': OrderFields.status,
              'op': 'anyOf',
              'value': ['o_gone'],
            },
          ],
        ),
      );
      await rig.start();
      await setStatus(SeedOptions.shipped);
      await until(
        () async =>
            (await rig.fakes.automations.get('a_1'))!.pausedReason ==
            PausedReason.broken,
      );
      final doc = (await rig.docs()).single;
      expect(doc.reason, RunReason.broken);
      expect(rig.engine.loads, isEmpty);
    });

    test('changes before the automations load are buffered and evaluated '
        'in order', () async {
      await rig.automation(trigger: shipped);
      rig.stamps();
      // Initialize, then write before the store emissions arrive.
      rig.runner.initialize(workspaceId: 'w1', uid: 'u1');
      await rig.session.cache.ready;
      await setStatus(SeedOptions.shipped);
      await until(() => rig.runner.activity.needsReview == 1);
    });

    test('button runs start ahead of waiting event runs', () async {
      await rig.automation(trigger: shipped);
      await rig.automation(
        id: 'a_btn',
        trigger: const ButtonTrigger(
          scope: ButtonScope.card,
          collectionId: _orders,
        ),
      );
      await rig.start();
      final gate = Completer<void>();
      final order = <String>[];
      rig.engine.action = (m, inv) async {
        order.add((inv.ctx['automation']! as Map)['id']! as String);
        if (order.length == 1) await gate.future;
        return null;
      };
      final blocker = await rig.runner.pressCard('a_btn', cardId: _order);
      await until(() => order.length == 1);
      await setStatus(SeedOptions.shipped);
      await until(() => rig.runner.activity.runs.length == 2);
      final button = await rig.runner.pressCard('a_btn', cardId: _order);
      expect(
        rig.runner.activity.runs.map((r) => r.runId).toList()[1],
        button,
        reason: 'the button waits ahead of the event run',
      );
      gate.complete();
      await until(() => order.length == 3);
      expect(order, ['a_btn', 'a_btn', 'a_1']);
      await settled(blocker);
    });
  });

  group('start-up and cleanup', () {
    RunRecord row(
      String id,
      RunStatus status, {
      String sessionId = 't_1',
      DateTime? startedAt,
      DateTime? applyStartedAt,
    }) => RunRecord(
      id: id,
      status: status,
      moduleId: 'stamp-shipped-date',
      moduleName: 'Stamp',
      moduleVersion: '1.0.0',
      codeHash: 'sha256:x',
      actionId: 'stamp',
      actionLabel: 'Stamp',
      automationId: 'a_1',
      automationName: 'Stamp',
      trigger: const RunTrigger(
        kind: TriggerKind.button,
        collectionId: _orders,
      ),
      apply: ApplyMode.ask,
      by: 'user:u1',
      device: 'web',
      sessionId: sessionId,
      startedAt: startedAt ?? DateTime.now(),
      applyStartedAt: applyStartedAt,
      planId: 'p_old',
    );

    test('own reviews expire, own applying runs finalize as interrupted, '
        'foreign reviews wait until 8 h', () async {
      await rig.install();
      for (final r in [
        row('run_own', RunStatus.awaitingReview),
        row('run_applying', RunStatus.applying),
        row(
          'run_approving',
          RunStatus.awaitingReview,
          applyStartedAt: DateTime.now(),
        ),
        row('run_foreign', RunStatus.awaitingReview, sessionId: 't_other'),
        row(
          'run_old',
          RunStatus.awaitingReview,
          sessionId: 't_other',
          startedAt: DateTime.now().subtract(const Duration(hours: 9)),
        ),
      ]) {
        await rig.fakes.runs.create(r);
      }
      await rig.start();
      await until(() async => (await rig.doc('run_old'))!.status.terminal);
      expect((await rig.doc('run_own'))!.status, RunStatus.expired);
      expect((await rig.doc('run_applying'))!.reason, RunReason.interrupted);
      expect((await rig.doc('run_approving'))!.reason, RunReason.interrupted);
      expect((await rig.doc('run_foreign'))!.status, RunStatus.awaitingReview);
      expect((await rig.doc('run_old'))!.status, RunStatus.expired);
    });

    test(
      'Run again on a foreign review supersedes it and runs manually',
      () async {
        await rig.install();
        await rig.automation();
        await rig.fakes.runs.create(
          RunRecord.fromJson('run_foreign', {
            ...row(
              'run_foreign',
              RunStatus.awaitingReview,
              sessionId: 't_other',
            ).toJson(),
            'trigger': {
              'kind': 'button',
              'collectionId': _orders,
              'cardId': _order,
            },
          }),
        );
        await rig.start();
        rig.stamps();
        final again = await rig.runner.runAgain('run_foreign');
        final old = (await rig.doc('run_foreign'))!;
        expect(old.status, RunStatus.expired);
        expect(old.reason, RunReason.superseded);
        final doc = await awaitingReview(again);
        expect(doc.parentRunId, 'run_foreign');
        expect(doc.depth, 1);
      },
    );

    test(
      'Run again is refused when the outcome is unknown or offline',
      () async {
        await rig.install();
        await rig.automation();
        await rig.fakes.runs.create(row('run_x', RunStatus.applying));
        await rig.start();
        await expectLater(
          rig.runner.runAgain('run_x'),
          throwsA(isA<AutomationRefused>()),
        );
      },
    );

    test(
      'a crash breadcrumb pauses the automation and writes the row',
      () async {
        await rig.dispose();
        rig = Rig(
          marker: FakeCrashMarker((runId: 'run_crashed', automationId: 'a_1')),
        );
        await rig.install();
        await rig.automation();
        await rig.start();
        await until(() async => await rig.doc('run_crashed') != null);
        final doc = (await rig.doc('run_crashed'))!;
        expect(doc.status, RunStatus.failed);
        expect(doc.reason, RunReason.crashed);
        await until(
          () async =>
              (await rig.fakes.automations.get('a_1'))!.pausedReason ==
              PausedReason.crashed,
        );
        expect(rig.marker.leftover(), isNull);
      },
    );

    test('uninstall skips queued runs, rejects reviews and deletes the '
        'automations and the consent', () async {
      await rig.install();
      await rig.automation();
      await rig.start();
      rig.stamps();
      final review = await rig.runner.pressCard('a_1', cardId: _order);
      final planId = (await awaitingReview(review)).planId!;
      final gate = Completer<void>();
      rig.engine.action = (m, inv) => gate.future.then((_) => null);
      final running = await rig.runner.pressCard('a_1', cardId: _order);
      final queued = await rig.runner.pressCard('a_1', cardId: _order);
      await until(() => rig.live(running)?.status == RunStatus.running);

      await rig.runner.uninstall(rig.module.id);
      expect((await settled(queued)).reason, RunReason.needsConsent);
      final rejected = await settled(review);
      expect(rejected.status, RunStatus.rejected);
      expect(rejected.reason, RunReason.uninstalled);
      expect(rig.session.plans.get(planId), isNull);
      expect(await rig.fakes.automations.get('a_1'), isNull);
      expect(await rig.fakes.grants.get('u1', rig.module.id), isNull);
      expect(await rig.fakes.modules.get(rig.module.id), isNull);
      gate.complete();
    });

    test('revoke skips queued runs and rejects reviews', () async {
      await rig.install();
      await rig.automation();
      await rig.start();
      rig.stamps();
      final review = await rig.runner.pressCard('a_1', cardId: _order);
      await awaitingReview(review);
      await rig.runner.revoke(rig.module.id);
      final doc = await settled(review);
      expect(doc.status, RunStatus.rejected);
      expect(doc.reason, RunReason.needsConsent);
    });

    test('schema revalidation marks an automation broken at once', () async {
      await rig.install();
      await rig.automation(
        trigger: const EventTrigger(
          kind: TriggerKind.cardUpdated,
          collectionId: _orders,
          where: [
            {
              'field': OrderFields.status,
              'op': 'anyOf',
              'value': [SeedOptions.shipped],
            },
          ],
        ),
      );
      await rig.start();
      final orders = rig.session.cache.collection(_orders)!;
      await rig.repo.saveCollection(
        rig.seed.orders.copyWith(
          fields: [
            for (final f in rig.seed.orders.fields)
              if (f.id != OrderFields.status) f,
          ],
        ),
      );
      expect(orders, isNotNull);
      await until(
        () async =>
            (await rig.fakes.automations.get('a_1'))!.pausedReason ==
            PausedReason.broken,
      );
      expect((await rig.fakes.automations.get('a_1'))!.brokenDetail, isNotNull);
    });

    test(
      'reset, then the session and the runner bind again: a press runs',
      () async {
        await rig.install();
        await rig.automation();
        await rig.start();
        await rig.runner.reset();
        await rig.session.reset();
        rig.session.initialize('w1');
        await rig.start();
        rig.stamps();
        await awaitingReview(await rig.runner.pressCard('a_1', cardId: _order));
      },
    );

    test('a press before the automations load still runs', () async {
      await rig.install();
      await rig.automation();
      rig.stamps();
      rig.runner.initialize(workspaceId: 'w1', uid: 'u1');
      final runId = await rig.runner.pressCard('a_1', cardId: _order);
      await awaitingReview(runId);
    });

    test('reset drops the live run without writing its doc', () async {
      await rig.install();
      await rig.automation();
      await rig.start();
      final gate = Completer<void>();
      rig.engine.action = (m, inv) => gate.future.then((_) => null);
      final runId = await rig.runner.pressCard('a_1', cardId: _order);
      await until(() => rig.engine.sessions.isNotEmpty);
      await rig.runner.reset();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(await rig.doc(runId), isNull);
      expect(rig.runner.activity, RunActivity.idle);
      expect(rig.marker.leftover(), isNull);
      expect(rig.engine.sessions.single.killed, isTrue);
    });

    test('a review backlog of 50 skips the next review', () async {
      await rig.install();
      await rig.automation();
      await rig.start();
      rig.stamps();
      for (var i = 0; i < kReviewBacklog; i++) {
        await rig.runner.pressCard('a_1', cardId: _order);
      }
      await until(
        () => rig.runner.activity.needsReview == kReviewBacklog,
        timeout: const Duration(seconds: 20),
      );
      final next = await rig.runner.pressCard('a_1', cardId: _order);
      final doc = await settled(next);
      expect(doc.reason, RunReason.reviewBacklog);
    });

    test('a test run builds a plan, keeps nothing and writes no doc', () async {
      await rig.install();
      await rig.start();
      rig.stamps();
      final result = await rig.runner.testRun(
        TestRunRequest(
          moduleId: rig.module.id,
          actionId: 'stamp',
          cardId: _order,
          collectionId: _orders,
        ),
      );
      expect(result.status, RunStatus.succeeded);
      expect(result.plan, hasLength(1));
      expect(await rig.docs(), isEmpty);
      expect(rig.item(_order), isNot('Stamped'));
      final trigger =
          rig.engine.sessions.single.invocations.single.ctx['trigger']! as Map;
      expect(trigger['kind'], 'test');
      expect(trigger['as'], containsPair('cardId', _order));
    });
  });
}
