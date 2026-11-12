import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/automation/store_catalog.dart';
import 'package:morkva_crm/core/domain/automation/automation.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/core/harness/harness.dart';
import 'package:morkva_crm/core/harness/ops/module_ops.dart';
import 'package:morkva_crm/core/harness/ops/plan_protocol_ops.dart';
import 'package:morkva_crm/core/harness/plan/plan.dart';
import 'package:morkva_crm/core/harness/plan/plan_committer.dart';

import '../../../automation/fakes/fake_stores.dart';
import '../../domain/automation/fixtures.dart' as fx;
import 'commit_fixture.dart';

const String _code =
    '(() => { morkva.action("stamp", async (ctx) => "ok"); })();';
const String _moduleId = 'stamp-shipped-date';

void main() {
  late FakeStores fakes;
  late _RecordingCatalog catalog;
  late CommitHarness h;

  setUp(() {
    fakes = FakeStores();
    catalog = _RecordingCatalog(
      StoreAutomationCatalog(fakes.stores, uid: () => 'u1'),
    );
    h = CommitHarness(catalog: catalog);
    registerModuleOps(
      h.p.registry,
      catalog: catalog,
      services: PlanServices(
        cache: h.p.cache,
        queries: h.p.queries,
        store: h.p.store,
        registry: defaultFieldTypeRegistry(),
      ),
    );
  });
  tearDown(() async {
    await h.dispose();
    await fakes.dispose();
  });

  // Within the plan's 15-minute TTL.
  final later = now.add(const Duration(minutes: 5));

  Map<String, Object?> saveModule({String code = _code}) => {
    'manifest': fx.stampManifest(),
    'code': code,
    'collections': ['Orders'],
  };

  Map<String, Object?> saveAutomation() => {
    'name': 'Stamp when shipped',
    'moduleId': _moduleId,
    'actionId': 'stamp',
    'trigger': {
      'kind': 'card.updated',
      'collection': 'Orders',
      'where': [
        {'field': 'Status', 'op': 'equals', 'value': 'Shipped'},
      ],
    },
    'params': {'dateField': 'Delivery slot'},
  };

  /// Plans [calls] in one assistant turn (under [grants]) and seals it.
  Future<Plan> plan(
    List<(String, Map<String, Object?>)> calls, {
    Grants? grants,
  }) async {
    h.p.newTurn();
    for (final (op, args) in calls) {
      await h.p.ok(op, args, grants: grants);
    }
    final plan = await h.p.sealPlan();
    catalog.log.clear();
    return plan;
  }

  Future<ModuleRecord> install({String code = _code}) async {
    final module = ModuleRecord.fromBundle(
      ModuleBundle.of(fx.stampManifest(), code),
      source: ModuleSource.import,
      createdBy: 'user:u1',
      now: fx.fixtureNow,
    );
    await fakes.modules.save(module);
    return module;
  }

  /// [plan] with its items replaced and its creator set.
  Plan rebuilt(Plan plan, {List<PlanItem>? items, PlanCreator? createdBy}) =>
      Plan(
        planId: plan.planId,
        turnId: plan.turnId,
        title: plan.title,
        createdBy: createdBy ?? plan.createdBy,
        items: items ?? plan.items,
        createdAt: plan.createdAt,
        expiresAt: plan.expiresAt,
      );

  Future<Map<String, ItemOutcome>> commitDirect(Plan plan, {Actor? actor}) => h
      .committer
      .commit(plan, h.userContext(actor: actor ?? user), callId: 'c1')
      .then((r) => r.outcomes);

  test('writes the module, then its consent, then the automation; nothing '
      'is journaled', () async {
    final p = await plan([
      ('modules.save', saveModule()),
      ('automations.save', saveAutomation()),
    ]);
    final [moduleItem, automationItem] = p.items;

    final r = await h.commit(p, at: later);
    expect(r['applied'], [moduleItem.itemId, automationItem.itemId]);
    expect(r['journalId'], isNull);
    final automationId = automationItem.targetId!;
    expect(catalog.log, [
      'getModule $_moduleId',
      'saveModule $_moduleId',
      'saveConsent u1 $_moduleId',
      'getAutomation $automationId',
      'saveAutomation $automationId',
    ]);

    final module = (await fakes.modules.get(_moduleId))!;
    expect(module.updatedAt.isAtSameMomentAs(later), isTrue);
    expect(module.codeHash, module.bundleHash);
    final consent = (await fakes.grants.get('u1', _moduleId))!;
    expect(consent.codeHash, module.bundleHash);
    expect(consent.autoApply, isFalse);
    expect(consent.via, GrantVia.assistantPlan);
    expect(consent.collections, [SeedIds.orders]);
    expect(consent.grantedAt.isAtSameMomentAs(later), isTrue);
    final automation = (await fakes.automations.get(automationId))!;
    expect(automation.apply, ApplyMode.ask);
    expect(automation.moduleId, _moduleId);
    expect(automation.updatedAt.isAtSameMomentAs(later), isTrue);
  });

  test('the consent never grants auto-apply and belongs to the approving '
      'user', () async {
    final p = await plan([('modules.save', saveModule())]);
    final item = p.items.single as SaveModuleItem;
    final greedy = SaveModuleItem(
      itemId: item.itemId,
      callId: item.callId,
      label: item.label,
      risk: item.risk,
      module: item.module,
      consent: item.consent.copyWith(autoApply: true),
    );

    final outcomes = await commitDirect(
      rebuilt(p, items: [greedy]),
      actor: const Actor.user('u2'),
    );
    expect(outcomes[item.itemId], ItemOutcome.applied);
    expect((await fakes.grants.get('u2', _moduleId))!.autoApply, isFalse);
    expect(await fakes.grants.get('u1', _moduleId), isNull);
  });

  test('module and automation items pass under grants pinned to a '
      'collection', () async {
    final pinned = Grants(kAssistantCaps, collections: [SeedIds.orders]);
    final p = await plan([
      ('modules.save', saveModule()),
      ('automations.save', saveAutomation()),
    ], grants: pinned);
    expect(p.createdBy.grants.collections, {SeedIds.orders});

    final r = await h.commit(p);
    expect(r['applied'], [for (final i in p.items) i.itemId]);
    expect(r['failed'], isEmpty);
  });

  test('a plan a module created cannot install or bind modules', () async {
    final p = await plan([
      ('modules.save', saveModule()),
      ('automations.save', saveAutomation()),
    ]);
    final outcomes = await commitDirect(
      rebuilt(
        p,
        createdBy: PlanCreator(const Actor.plugin('other'), Grants.all()),
      ),
    );
    for (final i in p.items) {
      expect(outcomes[i.itemId]!.code, ErrorCode.notPermitted.wire);
    }
    expect(catalog.log, isEmpty);
    expect(await fakes.modules.get(_moduleId), isNull);
  });

  test('without the capability the item is not permitted', () async {
    final p = await plan([('modules.save', saveModule())]);
    final outcomes = await commitDirect(
      rebuilt(
        p,
        createdBy: PlanCreator(
          Actor.assistant,
          Grants([Capability.schemaRead, Capability.dataRead]),
        ),
      ),
    );
    expect(outcomes[p.items.single.itemId]!.code, ErrorCode.notPermitted.wire);
  });

  test('a bundle changed since the preview is changed elsewhere; its '
      'consent and dependent automation are not written', () async {
    await install();
    final p = await plan([
      ('modules.save', saveModule(code: '$_code // v2')),
      ('automations.save', saveAutomation()),
    ]);
    final [moduleItem, automationItem] = p.items;
    expect((moduleItem as SaveModuleItem).beforeCodeHash, isNotNull);
    final elsewhere = await install(code: '$_code // edited elsewhere');

    final r = await h.commit(p);
    expect(r['stale'], [
      {'itemId': moduleItem.itemId, 'reason': kChangedElsewhere},
    ]);
    expect(
      [for (final f in r['failed']! as List) (f as Map)['itemId']],
      [automationItem.itemId],
    );
    expect((await fakes.modules.get(_moduleId))!.code, elsewhere.code);
    expect(await fakes.grants.get('u1', _moduleId), isNull);
    expect(await fakes.automations.get(automationItem.targetId!), isNull);
  });

  test('an automation delete: missing once gone, changed elsewhere once '
      'edited', () async {
    await fakes.automations.save(fx.automation());
    final p = await plan([
      ('automations.delete', {'id': 'a_1'}),
    ]);
    final id = p.items.single.itemId;

    await fakes.automations.save(
      AutomationRecord.fromJson('a_1', {
        ...fx.automation().toJson(),
        'updatedAt': later,
      }),
    );
    expect((await commitDirect(p))[id], ItemOutcome.changedElsewhere);

    await fakes.automations.delete('a_1');
    expect((await commitDirect(p))[id], ItemOutcome.missing);
  });

  test('a consent write that failed is retried: the module written by the '
      'first attempt is not "elsewhere"', () async {
    final p = await plan([('modules.save', saveModule())]);
    final id = p.items.single.itemId;
    catalog.failConsent = true;
    final first = await h.commit(p);
    expect(
      [for (final f in first['failed']! as List) (f as Map)['itemId']],
      [id],
    );
    expect(await fakes.modules.get(_moduleId), isNotNull);
    expect(await fakes.grants.get('u1', _moduleId), isNull);

    catalog.failConsent = false;
    final retry = await h.ok('plans.retryFailed', {'planId': p.planId});
    expect(retry['applied'], [id]);
    expect(await fakes.grants.get('u1', _moduleId), isNotNull);
  });
}

/// The catalog the committer writes through, recording each call.
final class _RecordingCatalog implements AutomationCatalog {
  _RecordingCatalog(this._inner);

  final AutomationCatalog _inner;
  final List<String> log = [];

  /// When true, [saveConsent] throws.
  bool failConsent = false;

  @override
  RunnerHooks? get hooks => _inner.hooks;

  @override
  set hooks(RunnerHooks? value) => _inner.hooks = value;

  @override
  Future<List<ModuleRecord>> listModules() => _inner.listModules();

  @override
  Future<ModuleRecord?> getModule(String moduleId) {
    log.add('getModule $moduleId');
    return _inner.getModule(moduleId);
  }

  @override
  Future<GrantRecord?> liveConsent(String moduleId) =>
      _inner.liveConsent(moduleId);

  @override
  Future<List<AutomationRecord>> listAutomations() => _inner.listAutomations();

  @override
  Future<AutomationRecord?> getAutomation(String automationId) {
    log.add('getAutomation $automationId');
    return _inner.getAutomation(automationId);
  }

  @override
  Future<List<RunRecord>> listRuns() => _inner.listRuns();

  @override
  Future<RunRecord?> getRun(String runId) => _inner.getRun(runId);

  @override
  Future<void> saveModule(ModuleRecord module) {
    log.add('saveModule ${module.id}');
    return _inner.saveModule(module);
  }

  @override
  Future<void> saveConsent(String uid, GrantRecord consent) async {
    log.add('saveConsent $uid ${consent.moduleId}');
    if (failConsent) throw StateError('consent write refused');
    return _inner.saveConsent(uid, consent);
  }

  @override
  Future<void> saveAutomation(AutomationRecord automation) {
    log.add('saveAutomation ${automation.id}');
    return _inner.saveAutomation(automation);
  }

  @override
  Future<void> deleteAutomation(String automationId) {
    log.add('deleteAutomation $automationId');
    return _inner.deleteAutomation(automationId);
  }
}
