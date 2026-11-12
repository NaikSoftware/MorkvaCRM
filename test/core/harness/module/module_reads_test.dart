import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/automation/automation.dart';
import 'package:morkva_crm/core/harness/harness.dart';
import 'package:morkva_crm/core/harness/ops/module_ops.dart';

import 'module_fixture.dart';

void main() {
  late ModuleHarness m;

  setUp(() => m = ModuleHarness());
  tearDown(() => m.dispose());

  AutomationRecord automation({String collectionId = SeedIds.orders}) =>
      AutomationRecord(
        id: 'au_1',
        name: 'Stamp when shipped',
        enabled: true,
        moduleId: 'stamp-shipped-date',
        actionId: 'stamp',
        params: const {'dateField': OrderFields.created},
        trigger: EventTrigger(
          kind: TriggerKind.cardUpdated,
          collectionId: collectionId,
        ),
        apply: ApplyMode.ask,
        createdBy: 'user:u1',
        createdAt: fixtureNow,
        updatedAt: fixtureNow,
      );

  RunRecord run(String id, {RunStatus status = RunStatus.succeeded}) =>
      RunRecord(
        id: id,
        status: status,
        moduleId: 'stamp-shipped-date',
        moduleName: 'Stamp shipped date',
        moduleVersion: '1.0.0',
        codeHash: 'sha256:abc',
        actionId: 'stamp',
        actionLabel: 'Stamp shipped date',
        automationId: 'au_1',
        automationName: 'Stamp when shipped',
        trigger: const RunTrigger(
          kind: TriggerKind.cardUpdated,
          collectionId: SeedIds.orders,
          cardLabel: '#1001 · Shirt',
        ),
        apply: ApplyMode.ask,
        by: 'user:u1',
        device: 'web',
        sessionId: 't1',
        startedAt: fixtureNow,
        summary: 'Stamped 1 card',
        log: RunLog(
          console: [
            for (var i = 0; i < 40; i++)
              ConsoleLine(t: i, level: 'info', text: 'line $i ${'x' * 300}'),
          ],
        ),
      );

  group('modules.list', () {
    test('lists each module with its computed status', () async {
      await m.install();
      await m.install(
        manifest: manifestWith((j) => j['id'] = 'other-module'),
        consented: false,
      );
      m.fakes.modules.putRaw('broken-one', {
        ...(await m.catalog.getModule('stamp-shipped-date'))!.toJson(),
        'manifest': {'id': 'broken-one'},
      });
      await m.fakes.automations.save(automation());

      final modules =
          ((await m.p.ok('modules.list', const {}))['modules']! as List)
              .cast<Map<String, Object?>>();
      final byId = {for (final x in modules) x['id']: x};
      expect(byId['stamp-shipped-date']!['status'], 'ok');
      expect(byId['stamp-shipped-date']!['automationCount'], 1);
      expect(byId['stamp-shipped-date']!['caps'], [
        'schema:read',
        'data:read',
        'data:write',
      ]);
      expect(byId['stamp-shipped-date']!['actions'], [
        {'id': 'stamp', 'label': 'Stamp shipped date', 'scope': 'card'},
      ]);
      expect(byId['other-module']!['status'], 'needs_consent');
      expect(byId['broken-one']!['status'], 'broken');
    });

    test('a forged stored codeHash does not make a module ok', () async {
      final module = await m.install(consented: false);
      await m.fakes.grants.save(
        'u1',
        GrantRecord(
          moduleId: module.id,
          codeHash: 'sha256:forged',
          version: '1.0.0',
          codeBytes: 1,
          caps: const ['schema:read', 'data:read', 'data:write'],
          collections: null,
          autoApply: false,
          grantedAt: fixtureNow,
          via: GrantVia.consentSheet,
        ),
      );
      m.fakes.modules.putRaw(module.id, {
        ...module.toJson(),
        'codeHash': 'sha256:forged',
      });
      final modules = (await m.p.ok('modules.list', const {}))['modules']!;
      expect(((modules as List).single as Map)['status'], 'needs_consent');
    });
  });

  group('modules.get', () {
    test('returns the manifest, the computed hash and the consent', () async {
      final module = await m.install();
      final r = await m.p.ok('modules.get', {'id': module.id});
      expect(r['manifest'], stampManifest());
      expect(r['codeHash'], module.bundleHash);
      expect(r['source'], 'import');
      expect(r['status'], 'ok');
      expect(r['consent'], {
        'caps': ['schema:read', 'data:read', 'data:write'],
        'collections': [SeedIds.orders],
        'autoApply': false,
      });
      expect(r.containsKey('code'), isFalse);
    });

    test('code: true returns the code, cut at 64 KB', () async {
      final code = '// ${'x' * (kModuleCodeResultBytes + 10)}';
      final module = await m.install(code: code);
      final r = await m.p.ok('modules.get', {'id': module.id, 'code': true});
      expect(r['code'], hasLength(kModuleCodeResultBytes));
      expect(r['codeTruncated'], isTrue);
    });

    test('an unknown module lists the installed ones', () async {
      await m.install();
      final e = await m.p.error('modules.get', {'id': 'nope'});
      expect(e.code, ErrorCode.unknownObject);
      expect(e.candidates, ['stamp-shipped-date']);
    });
  });

  group('automations.list', () {
    test('lists with status, apply and up to 5 last checks', () async {
      await m.install();
      await m.fakes.automations.save(automation());
      m.withHooks();
      m.runner.lastChecksBy['au_1'] = [
        for (var i = 0; i < 8; i++)
          LastCheck(
            cardLabel: '#100$i',
            at: fixtureNow,
            result: LastCheckResult.notRun,
            why: 'Status was not Shipped',
          ),
      ];
      final list = (await m.p.ok('automations.list', {
        'collection': 'Orders',
      }))['automations']!;
      final row = (list as List).single as Map;
      expect(row['id'], 'au_1');
      expect(row['kind'], 'card.updated');
      expect(row['status'], 'active');
      expect(row['apply'], 'ask');
      expect(row['lastChecks'], hasLength(5));
      expect(((row['lastChecks']! as List).first as Map)['at'], isA<String>());
    });

    test(
      'filters by collection and module; a missing module is broken',
      () async {
        await m.fakes.automations.save(automation());
        final empty = await m.p.ok('automations.list', {
          'collection': 'Clients',
        });
        expect(empty['automations'], isEmpty);
        final other = await m.p.ok('automations.list', {'moduleId': 'x'});
        expect(other['automations'], isEmpty);
        final all = await m.p.ok('automations.list', const {});
        expect(
          ((all['automations']! as List).single as Map)['status'],
          'broken',
        );
      },
    );
  });

  group('runs', () {
    test('runs.list filters and caps', () async {
      for (var i = 0; i < 25; i++) {
        await m.fakes.runs.create(run('run_$i'));
      }
      await m.fakes.runs.create(run('run_failed', status: RunStatus.failed));
      final all = (await m.p.ok('runs.list', const {}))['runs']! as List;
      expect(all, hasLength(20));
      final row = all.first as Map;
      expect(row['startedAt'], fixtureNow.toIso8601String());
      expect(row['trigger'], {
        'kind': 'card.updated',
        'cardLabel': '#1001 · Shirt',
      });
      final failed = (await m.p.ok('runs.list', {'status': 'failed'}))['runs']!;
      expect(
        [for (final r in failed as List) (r as Map)['id']],
        ['run_failed'],
      );
    });

    test('runs.get decodes the log within 8 KB, dates as strings', () async {
      await m.fakes.runs.create(run('run_1'));
      final r = await m.p.ok('runs.get', {'id': 'run_1'});
      expect(r['id'], 'run_1');
      expect(r['startedAt'], fixtureNow.toIso8601String());
      final log = r['log']! as Map;
      expect(log['console'], isNotEmpty);
      expect(((log['dropped']! as Map)['console']! as int) > 0, isTrue);
    });

    test('runs.get of an unknown run is unknown_object', () async {
      final e = await m.p.error('runs.get', {'id': 'run_x'});
      expect(e.code, ErrorCode.unknownObject);
    });
  });

  test('rows outside the caller\'s collections stay hidden', () async {
    await m.install();
    await m.fakes.automations.save(automation());
    await m.fakes.runs.create(run('run_1'));
    final everywhere = Grants(kAssistantCaps);
    final clientsOnly = Grants(kAssistantCaps, collections: [SeedIds.clients]);

    // Control: unrestricted grants see the Orders rows.
    expect(
      (await m.p.ok(
        'automations.list',
        const {},
        grants: everywhere,
      ))['automations'],
      hasLength(1),
    );
    expect(
      (await m.p.ok('runs.list', const {}, grants: everywhere))['runs'],
      hasLength(1),
    );

    expect(
      (await m.p.ok(
        'automations.list',
        const {},
        grants: clientsOnly,
      ))['automations'],
      isEmpty,
    );
    expect(
      (await m.p.ok('runs.list', const {}, grants: clientsOnly))['runs'],
      isEmpty,
    );
    final get = await m.p.error('runs.get', {
      'id': 'run_1',
    }, grants: clientsOnly);
    expect(get.code, ErrorCode.unknownObject);
    final delete = await m.p.error('automations.delete', {
      'id': 'au_1',
    }, grants: clientsOnly);
    expect(delete.code, ErrorCode.unknownObject);
  });

  group('modules.testRun', () {
    Map<String, Object?> args({Object? card = '#1001'}) => {
      'moduleId': 'stamp-shipped-date',
      'actionId': 'stamp',
      'collection': 'Orders',
      'card': ?card,
      'params': {'dateField': OrderFields.created},
    };

    test('runs through the hooks with refs resolved', () async {
      await m.install();
      m.withHooks();
      final r = await m.p.ok('modules.testRun', args());
      expect(r['status'], 'succeeded');
      final (method, callArgs) = m.runner.calls.single;
      expect(method, 'testRun');
      final request = callArgs.single! as TestRunRequest;
      expect(request.cardId, SeedCards.order(1001));
      expect(request.collectionId, SeedIds.orders);
      expect(request.params, {
        'dateField': OrderFields.created,
        'overwrite': false,
        'days': 1,
        'mode': 'today',
      });
    });

    test(
      'refused without hooks, consent, or in an ungranted collection',
      () async {
        await m.install();
        expect(
          (await m.p.error('modules.testRun', args())).code,
          ErrorCode.unsupported,
        );
        m.withHooks();
        await m.fakes.grants.delete('u1', 'stamp-shipped-date');
        expect(
          (await m.p.error('modules.testRun', args())).code,
          ErrorCode.notPermitted,
        );
        await m.install(collections: const [SeedIds.clients]);
        // Orders is outside the module's consent, though the caller sees it.
        expect(
          (await m.p.error('modules.testRun', args())).code,
          ErrorCode.unknownCollection,
        );
      },
    );

    test('a failed dry run comes back as plain JSON', () async {
      await m.install();
      m.withHooks();
      m.runner.testRunResult = const TestRunResult(
        status: RunStatus.failed,
        reason: RunReason.moduleError,
        plan: [
          PlanLine(kind: 'updateCard', label: '#1001', change: '— → today'),
        ],
        log: RunLog(
          calls: [
            RunCall(
              t: 3,
              op: 'cards.get',
              kind: 'read',
              args: '{}',
              ok: true,
              result: '1 card',
              ms: 2,
            ),
          ],
          console: [ConsoleLine(t: 5, level: 'error', text: 'boom')],
        ),
        error: RunError(
          code: 'module_error',
          message: 'boom',
          stack: 'at morkva-module/stamp-shipped-date.js:1',
        ),
      );
      final r = await m.p.ok('modules.testRun', args());
      expect(r['status'], 'failed');
      expect(r['reason'], 'module_error');
      expect(r['plan'], [
        {'kind': 'updateCard', 'label': '#1001', 'change': '— → today'},
      ]);
      expect((r['log']! as Map)['console'], [
        {'t': 5, 'level': 'error', 'text': 'boom'},
      ]);
      expect((r['error']! as Map)['code'], 'module_error');
    });

    test('a card action needs a card', () async {
      await m.install();
      m.withHooks();
      final e = await m.p.error('modules.testRun', args(card: null));
      expect(e.code, ErrorCode.invalidArgs);
      expect(e.path, 'collection');
    });

    test('needs a turn', () async {
      await m.install();
      m.withHooks();
      final r = await m.p.call('modules.testRun', args(), noTurn: true);
      expect((r as HarnessFailure).error.code, ErrorCode.notPermitted);
      expect(m.runner.calls, isEmpty);
    });

    test('at most 5 per turn', () async {
      await m.install();
      m.withHooks();
      for (var i = 0; i < kMaxTestRunsPerTurn; i++) {
        await m.p.ok('modules.testRun', args());
      }
      final e = await m.p.error('modules.testRun', args());
      expect(e.code, ErrorCode.limitExceeded);
      m.p.newTurn();
      await m.p.ok('modules.testRun', args());
    });
  });
}
