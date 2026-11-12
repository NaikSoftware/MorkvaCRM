/// The plan harness with the module ops over a [StoreAutomationCatalog] on
/// in-memory stores, and helpers that install modules and consents.
library;

import 'package:morkva_crm/core/automation/store_catalog.dart';
import 'package:morkva_crm/core/domain/automation/automation.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/core/harness/ops/module_ops.dart';
import 'package:morkva_crm/core/harness/ops/plan_protocol_ops.dart';

import '../../../automation/fakes/fake_runner.dart';
import '../../../automation/fakes/fake_stores.dart';
import '../../domain/automation/fixtures.dart';
import '../plan/plan_fixture.dart';

export '../../domain/automation/fixtures.dart' show fixtureNow, stampManifest;
export '../plan/plan_fixture.dart';

const String moduleCode =
    '(() => { morkva.action("stamp", async (ctx) => "ok"); })();';

final class ModuleHarness {
  ModuleHarness({String? uid = 'u1'}) : _uid = uid {
    catalog = StoreAutomationCatalog(fakes.stores, uid: () => _uid);
    registerModuleOps(
      p.registry,
      catalog: catalog,
      services: PlanServices(
        cache: p.cache,
        queries: p.queries,
        store: p.store,
        registry: defaultFieldTypeRegistry(),
      ),
    );
  }

  final p = PlanHarness();
  final fakes = FakeStores();
  final runner = FakeRunner();
  late final StoreAutomationCatalog catalog;
  final String? _uid;

  /// Plugs the fake runner in as the catalog's hooks.
  void withHooks() => catalog.hooks = runner;

  /// Installs [manifest] + [code] and, unless [consented] is false, the
  /// user's consent to exactly that bundle.
  Future<ModuleRecord> install({
    Map<String, Object?>? manifest,
    String code = moduleCode,
    bool consented = true,
    List<String>? collections = const [SeedIds.orders],
    bool autoApply = false,
  }) async {
    final bundle = ModuleBundle.of(manifest ?? stampManifest(), code);
    final module = ModuleRecord.fromBundle(
      bundle,
      source: ModuleSource.import,
      createdBy: 'user:u1',
      now: fixtureNow,
    );
    await fakes.modules.save(module);
    if (consented) {
      await fakes.grants.save(
        'u1',
        GrantRecord(
          moduleId: module.id,
          codeHash: module.bundleHash,
          version: module.version,
          codeBytes: module.codeBytes,
          caps: bundle.manifest.capabilities,
          collections: collections,
          autoApply: autoApply,
          grantedAt: fixtureNow,
          via: GrantVia.consentSheet,
        ),
      );
    }
    return module;
  }

  Future<void> dispose() async {
    await p.dispose();
    await fakes.dispose();
  }
}

/// [stampManifest] with [edit] applied to a copy.
Map<String, Object?> manifestWith(void Function(Map<String, Object?> m) edit) {
  final m = stampManifest();
  edit(m);
  return m;
}
