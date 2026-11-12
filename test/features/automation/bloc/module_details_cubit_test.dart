import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/automation/runner_api.dart';
import 'package:morkva_crm/core/domain/automation/automation.dart';
import 'package:morkva_crm/features/automation/bloc/module_details_cubit.dart';
import 'package:morkva_crm/features/automation/bloc/modules_cubit.dart';

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
  });

  tearDown(() async {
    await runner.dispose();
    await stores.dispose();
  });

  ModuleDetailsCubit build() =>
      ModuleDetailsCubit(runner, stores.stores, uid: uid, moduleId: stampId);

  Future<ModuleDetailsCubit> loaded() async {
    final cubit = build();
    await settle();
    return cubit;
  }

  blocTest<ModuleDetailsCubit, ModuleDetailsState>(
    'never consented: the allow banner; no test run, auto-apply disabled',
    build: build,
    act: (_) => settle(),
    verify: (cubit) {
      final s = cubit.state;
      expect(s.loading, isFalse);
      expect(s.status, ModuleStatus.needsConsent);
      expect(s.banner, ModuleBanner.allow);
      expect(s.canTestRun, isFalse);
      expect(s.autoApplyOffered, isTrue);
      expect(s.autoApplyEnabled, isFalse);
    },
  );

  test('consent to an older bundle: the changed banner and its diff', () async {
    await stores.grants.save(uid, consentTo(module, autoApply: true));
    await stores.modules.save(
      stampModule(
        bundle: stampBundle(code: 'v2()', version: '1.1.0'),
      ),
    );
    final cubit = await loaded();
    expect(cubit.state.banner, ModuleBanner.changed);
    final view = cubit.consentView()!;
    expect(view.fromVersion, '1.0.0');
    expect(view.bundle.manifest.version, '1.1.0');
    expect(view.autoApplyTurnsOff, isTrue);
    await cubit.close();
  });

  test('a manifest that no longer parses is broken; no export', () async {
    stores.modules.putRaw(stampId, {
      ...module.toJson(),
      'manifest': {'id': stampId},
    });
    final cubit = await loaded();
    expect(cubit.state.banner, ModuleBanner.broken);
    expect(cubit.state.module!.manifestProblems, isNotEmpty);
    expect(cubit.consentView(), isNull);
    expect(cubit.exportFile(), isNull);
    await cubit.close();
  });

  test('a module gone elsewhere reads as null once loaded', () async {
    final cubit = await loaded();
    await stores.modules.delete(stampId);
    await settle();
    expect(cubit.state.loading, isFalse);
    expect(cubit.state.entry, isNull);
    await cubit.close();
  });

  test('its automations and its last 5 runs only', () async {
    await stores.automations.save(automation());
    for (var i = 0; i < 7; i++) {
      await stores.runs.create(
        runRecord('run_$i', startedAt: fixtureNow.add(Duration(minutes: i))),
      );
    }
    await stores.runs.create(runRecord('run_other', moduleId: 'other'));
    final cubit = await loaded();
    expect(cubit.state.automations.single.automation.id, 'a_1');
    expect(
      [for (final r in cubit.state.recentRuns) r.id],
      ['run_6', 'run_5', 'run_4', 'run_3', 'run_2'],
    );
    await cubit.close();
  });

  test('allow sends the bundle the sheet showed, not a newer one', () async {
    final cubit = await loaded();
    final view = cubit.consentView()!;
    await stores.modules.save(
      stampModule(
        bundle: stampBundle(code: 'sneaky()', version: '9.0.0'),
      ),
    );
    await settle();
    expect(
      await cubit.allow(view, const ConsentScope.only({'c_orders'})),
      isTrue,
    );
    final (method, args) = runner.calls.single;
    expect(method, 'allow');
    final sent = args[0]! as ModuleBundle;
    expect(identical(sent, view.bundle), isTrue);
    expect(sent.code, isNot('sneaky()'));
    expect(args[1], ['c_orders']);
    expect(stores.grants.get(uid, stampId), completion(isNull));
    await cubit.close();
  });

  test(
    'change access, revoke, auto-apply and uninstall go to the runner',
    () async {
      await stores.grants.save(uid, consentTo(module));
      final cubit = await loaded();
      expect(cubit.state.status, ModuleStatus.ok);
      await cubit.changeAccess(const ConsentScope.all());
      await cubit.setAutoApply(true);
      await cubit.revoke();
      await cubit.uninstall();
      expect(runner.methods, [
        'changeAccess',
        'setAutoApply',
        'revoke',
        'uninstall',
      ]);
      expect(runner.calls[0].$2, [stampId, null]);
      expect(runner.calls[1].$2, [stampId, true]);
      await cubit.close();
    },
  );

  blocTest<ModuleDetailsCubit, ModuleDetailsState>(
    'a refused action shows its sentence and frees the buttons',
    build: build,
    act: (cubit) async {
      await settle();
      runner.failNext = const AutomationRefused('offline', 'You\'re offline.');
      await cubit.revoke();
    },
    skip: 1,
    expect: () => [
      isA<ModuleDetailsState>().having((s) => s.busy, 'busy', isTrue),
      isA<ModuleDetailsState>()
          .having((s) => s.busy, 'busy', isFalse)
          .having((s) => s.error, 'error', 'You\'re offline.'),
    ],
  );

  test(
    'auto-apply confirms on, and off only while automations use Auto',
    () async {
      await stores.grants.save(uid, consentTo(module, autoApply: true));
      final cubit = await loaded();
      expect(cubit.state.autoApplyOn, isTrue);
      expect(cubit.autoApplyConfirm(true)?.confirm, 'Turn on');
      expect(cubit.autoApplyConfirm(false), isNull);
      await stores.automations.save(
        automation(apply: ApplyMode.auto, autoBy: uid),
      );
      await settle();
      final off = cubit.autoApplyConfirm(false)!;
      expect(off.body, '1 automation will ask first.');
      expect(off.confirm, 'Turn off');
      await cubit.close();
    },
  );

  test('a module that can delete never offers auto-apply', () async {
    await stores.modules.save(
      stampModule(
        bundle: stampBundle(caps: ['data:read', 'data:write', 'data:delete']),
      ),
    );
    final cubit = await loaded();
    expect(cubit.state.autoApplyOffered, isFalse);
    await cubit.close();
  });

  test('export writes <id>.morkva.json that imports back', () async {
    final cubit = await loaded();
    final file = cubit.exportFile()!;
    expect(file.name, 'stamp-shipped-date.morkva.json');
    final back = decodeModuleBundle(file.text);
    expect(bundleHashOf(back.manifestJson, back.code), module.bundleHash);
    await cubit.close();
  });

  test(
    'test run: running, then the result; a refusal reads as failed',
    () async {
      await stores.grants.save(uid, consentTo(module));
      final cubit = await loaded();
      const request = TestRunRequest(
        moduleId: stampId,
        actionId: 'stamp',
        cardId: 'b_1042',
      );
      final run = cubit.testRun(request);
      expect(cubit.state.testRun?.running, isTrue);
      await run;
      expect(cubit.state.testRun?.result?.summary, 'No changes');

      runner.failNext = const AutomationRefused(
        'needs_consent',
        'Allow this module first',
      );
      await cubit.testRun(request);
      expect(cubit.state.testRun?.result?.status, RunStatus.failed);
      expect(
        cubit.state.testRun?.result?.error?.message,
        'Allow this module first',
      );
      cubit.closeTestRun();
      expect(cubit.state.testRun, isNull);
      await cubit.close();
    },
  );

  test('an unexpected throw still frees the buttons', () async {
    final cubit = await loaded();
    runner.failNext = StateError('boom');
    await expectLater(cubit.revoke(), throwsStateError);
    expect(cubit.state.busy, isFalse);
    runner.failNext = StateError('boom');
    await cubit.testRun(
      const TestRunRequest(moduleId: stampId, actionId: 'stamp'),
    );
    expect(cubit.state.testRun?.result?.status, RunStatus.failed);
    await cubit.close();
  });

  test('an auto-apply consent to replaced code reads as off', () async {
    await stores.grants.save(uid, consentTo(module, autoApply: true));
    await stores.modules.save(
      stampModule(
        bundle: stampBundle(code: 'v2()', version: '1.1.0'),
      ),
    );
    final cubit = await loaded();
    expect(cubit.state.autoApplyOn, isFalse);
    await cubit.close();
  });

  test('engine unavailable follows the runner', () async {
    final cubit = await loaded();
    expect(cubit.state.engineUnavailable, isFalse);
    runner.activity = const RunActivity(engineUnavailable: true);
    await settle();
    expect(cubit.state.engineUnavailable, isTrue);
    await cubit.close();
  });
}
