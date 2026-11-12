import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/automation/store_catalog.dart';
import 'package:morkva_crm/core/domain/automation/automation.dart';

import '../../automation/fakes/fake_runner.dart';
import '../../automation/fakes/fake_stores.dart';
import '../domain/automation/fixtures.dart';

void main() {
  late FakeStores fakes;
  String? uid;
  late StoreAutomationCatalog catalog;

  final module = ModuleRecord.fromBundle(
    ModuleBundle.of(stampManifest(), '(() => {})();'),
    source: ModuleSource.import,
    createdBy: 'user:u1',
    now: fixtureNow,
  );

  setUp(() {
    fakes = FakeStores();
    uid = 'u1';
    catalog = StoreAutomationCatalog(fakes.stores, uid: () => uid);
  });
  tearDown(() => fakes.dispose());

  test('modules, automations and runs round-trip through the stores', () async {
    expect(await catalog.listModules(), isEmpty);
    await catalog.saveModule(module);
    expect(await catalog.getModule(module.id), module);
    expect(await catalog.listModules(), [module]);

    final a = automation();
    await catalog.saveAutomation(a);
    expect(await catalog.getAutomation(a.id), a);
    expect(await catalog.listAutomations(), [a]);
    await catalog.deleteAutomation(a.id);
    expect(await catalog.getAutomation(a.id), isNull);

    expect(await catalog.listRuns(), isEmpty);
    expect(await catalog.getRun('run_x'), isNull);
  });

  test('consents are the bound member\'s; signed out reads none', () async {
    final c = consent();
    await catalog.saveConsent('u1', c);
    expect(await catalog.liveConsent(c.moduleId), c);

    uid = 'u2';
    expect(await catalog.liveConsent(c.moduleId), isNull);
    uid = null;
    expect(await catalog.liveConsent(c.moduleId), isNull);
  });

  test('a malformed consent reads as none', () async {
    fakes.grants.putRaw('u1', 'stamp-shipped-date', {
      ...consent().toJson(),
      'caps': ['*'],
    });
    expect(await catalog.liveConsent('stamp-shipped-date'), isNull);
  });

  test('hooks are late-bound', () {
    expect(catalog.hooks, isNull);
    final runner = FakeRunner();
    catalog.hooks = runner;
    expect(catalog.hooks, same(runner));
  });
}
