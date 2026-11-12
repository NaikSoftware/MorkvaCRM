import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/automation/runner_api.dart';
import 'package:morkva_crm/core/domain/automation/automation.dart';
import 'package:morkva_crm/features/automation/bloc/modules_cubit.dart';
import 'package:morkva_crm/features/automation/widgets/reason_copy.dart';

import 'automation_fixtures.dart';

void main() {
  late FakeRunner runner;
  late FakeStores stores;
  late ModuleRecord module;

  setUp(() async {
    runner = FakeRunner();
    stores = FakeStores();
    module = stampModule();
    await stores.modules.save(module);
    await stores.grants.save(uid, consentTo(module));
    await stores.automations.save(
      automation(apply: ApplyMode.auto, autoBy: uid),
    );
    stores.modules.saves = 0;
    stores.automations.saves = 0;
  });

  tearDown(() async {
    await runner.dispose();
    await stores.dispose();
  });

  ModulesCubit build() =>
      ModulesCubit(runner, stores.stores, uid: uid, now: () => fixtureNow);

  blocTest<ModulesCubit, ModulesState>(
    'joins modules, consents and automations with their computed status',
    build: build,
    act: (_) => settle(),
    verify: (cubit) {
      final s = cubit.state;
      expect(s.loading, isFalse);
      expect(s.modules.single.status, ModuleStatus.ok);
      expect(s.modules.single.automations, 1);
      final a = s.automations.single;
      expect(a.status, AutomationStatus.active);
      // Stored Auto, but the consent's auto-apply is off.
      expect(a.apply, EffectiveApply.autoOff);
      expect(a.action?.id, 'stamp');
      expect(s.automationsIn('c_orders'), [a]);
      expect(s.automationsIn('c_clients'), isEmpty);
    },
  );

  test('new code needs consent again; a revoked consent too', () async {
    final cubit = build();
    await settle();
    await stores.modules.save(
      stampModule(
        bundle: stampBundle(code: 'changed()', version: '1.1.0'),
      ),
    );
    await settle();
    expect(cubit.state.modules.single.status, ModuleStatus.needsConsent);
    expect(
      cubit.state.automations.single.status,
      AutomationStatus.needsConsent,
    );
    await stores.grants.delete(uid, stampId);
    await settle();
    expect(cubit.state.modules.single.consent, isNull);
    await cubit.close();
  });

  test('the switch saves through the runner, never the store', () async {
    final cubit = build();
    await settle();
    expect(await cubit.setEnabled('a_1', false), isTrue);
    final (method, args) = runner.calls.single;
    expect(method, 'saveAutomation');
    final saved = args.single! as AutomationRecord;
    expect(saved.enabled, isFalse);
    expect(saved.apply, ApplyMode.auto);
    expect(stores.automations.saves, 0);
    await cubit.close();
  });

  test('refusals and save problems land in state', () async {
    final cubit = build();
    await settle();
    runner.failNext = const AutomationRefused('offline', 'You\'re offline.');
    expect(await cubit.resume('a_1'), isFalse);
    expect(cubit.state.error, 'You\'re offline.');

    runner.problems = const [
      AutomationProblem(
        'trigger',
        'invalid',
        'The module isn\'t allowed in Orders',
      ),
    ];
    expect(await cubit.setEnabled('a_1', true), isFalse);
    expect(cubit.state.error, 'The module isn\'t allowed in Orders');
    cubit.clearError();
    expect(cubit.state.error, isNull);
    await cubit.close();
  });

  group('import', () {
    test('a non-module file lists its problem', () async {
      final cubit = build();
      final preview = cubit.previewImport('{"hello": 1}');
      expect(preview.bundle, isNull);
      expect(
        preview.problems.single.message,
        'This isn\'t a Morkva module file.',
      );
      await cubit.close();
    });

    test('a module with an installed id says it replaces it', () async {
      final cubit = build();
      await settle();
      final file = stampBundle(code: 'v2()', version: '1.1.0').encode();
      final preview = cubit.previewImport(file);
      expect(preview.problems, isEmpty);
      expect(preview.bundle!.manifest.version, '1.1.0');
      expect(preview.replacing?.module.version, '1.0.0');
      expect(preview.replacing?.automations, 1);
      await cubit.close();
    });

    test('install sends exactly the previewed bundle and scope', () async {
      final cubit = build();
      final bundle = cubit.previewImport(stampBundle().encode()).bundle!;
      expect(
        await cubit.install(bundle, const ConsentScope.only({'c_orders'})),
        isTrue,
      );
      expect(runner.calls.single.$1, 'install');
      expect(identical(runner.calls.single.$2[0], bundle), isTrue);
      expect(runner.calls.single.$2[1], ['c_orders']);
      expect(stores.modules.saves, 0);
      await cubit.close();
    });
  });

  group('ConsentScope', () {
    test('an import preselects nothing unless it came from a collection', () {
      expect(ConsentScope.forImport().chosen, isFalse);
      expect(() => ConsentScope.forImport().collections, throwsStateError);
      final from = ConsentScope.forImport(fromCollection: 'c_orders');
      expect(from.collections, ['c_orders']);
      expect(from.toggle('c_orders').chosen, isFalse);
      expect(const ConsentScope.all().collections, isNull);
      expect(ConsentScope.of(consentTo(module, collections: null)).all, isTrue);
    });
  });

  group('consentViewOf', () {
    test('first consent: every asked capability, plain', () {
      final view = consentViewOf(stampBundle(), null);
      expect(view.reconsent, isFalse);
      expect(
        [for (final c in view.caps) c.cap],
        ['schema:read', 'data:read', 'data:write'],
      );
      expect(view.caps.every((c) => c.change == CapChange.kept), isTrue);
      expect(view.caps[2].title, 'Create and change cards');
    });

    test('re-consent tags new and removed capabilities', () {
      final old = consentTo(module, autoApply: true);
      final view = consentViewOf(
        stampBundle(
          version: '1.1.0',
          caps: ['data:read', 'data:write', 'data:delete'],
        ),
        old,
      );
      expect(view.reconsent, isTrue);
      expect(view.fromVersion, '1.0.0');
      expect(view.fromBytes, module.codeBytes);
      expect(view.autoApplyTurnsOff, isTrue);
      expect(
        {for (final c in view.caps) c.cap: c.change},
        {
          'schema:read': CapChange.removed,
          'data:read': CapChange.kept,
          'data:write': CapChange.kept,
          'data:delete': CapChange.added,
        },
      );
    });
  });
}
