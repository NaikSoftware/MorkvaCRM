import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/automation/automation.dart';
import 'package:morkva_crm/core/harness/harness.dart';
import 'package:morkva_crm/core/harness/plan/plan.dart';

import 'module_fixture.dart';

void main() {
  late ModuleHarness m;

  setUp(() => m = ModuleHarness());
  tearDown(() => m.dispose());

  Map<String, Object?> save({
    Map<String, Object?>? manifest,
    String code = moduleCode,
    Object collections = const ['Orders'],
  }) => {
    'manifest': manifest ?? stampManifest(),
    'code': code,
    'collections': collections,
  };

  test('installs a new module: one saveModule item with the consent', () async {
    final r = await m.p.ok('modules.save', save());
    expect(r['status'], 'planned');
    final plan = await m.p.sealPlan();
    final item = plan.items.single as SaveModuleItem;

    expect(plan.title, 'Install “Stamp shipped date”');
    expect(item.kind.scoped, isFalse);
    expect(item.collectionId, '');
    expect(item.risk, Risk.high);
    expect(item.beforeCodeHash, isNull);
    expect(item.module.id, 'stamp-shipped-date');
    expect(item.module.createdBy, 'agent:assistant');
    expect(item.consent.autoApply, isFalse);
    expect(item.consent.via, GrantVia.assistantPlan);
    expect(item.consent.collections, [SeedIds.orders]);
    expect(item.consent.codeHash, item.module.bundleHash);
    // The consent surface: kCapabilityCopy titles verbatim, then the rest.
    expect(
      [for (final c in item.changes) c.field],
      [
        kCapabilityCopy['schema:read']!.title,
        kCapabilityCopy['data:read']!.title,
        kCapabilityCopy['data:write']!.title,
        'Collections',
        'Actions',
        'Code',
      ],
    );
    expect(item.changes.first.afterText, 'Orders');
    expect(item.changes[4].afterText, 'Stamp shipped date (on a card)');
    expect(
      item.changes[5].afterText,
      matches(RegExp(r'^\d+ B · sha256:[0-9a-f]{4}…$')),
    );
    expect(item.changes.every((c) => c.beforeText == null), isTrue);
    expect(plan.warnings.single.code, 'grants_permissions');
    expect(
      plan.warnings.single.message,
      'Approving installs this module and lets it use these permissions. '
      'Auto-apply stays off.',
    );
    expect(plan.undo, UndoSupport.none);
  });

  test('the compact plan never carries code; the full plan does', () async {
    await m.p.ok('modules.save', save());
    final compact = await m.p.seal();
    final row = (compact['items']! as List).single as Map;
    expect(row.containsKey('code'), isFalse);
    expect(row['codeBytes'], moduleCode.length);
    expect(row['codeHash'], startsWith('sha256:'));

    final full = await m.p.ok('plans.get', {'planId': compact['planId']});
    final item = (full['items']! as List).single as Map;
    expect(item['code'], moduleCode);
    expect(item['kind'], 'saveModule');
    expect(item['collections'], [SeedIds.orders]);
  });

  test('"all" consents to every collection', () async {
    await m.p.ok('modules.save', save(collections: 'all'));
    final item = (await m.p.sealPlan()).items.single as SaveModuleItem;
    expect(item.consent.collections, isNull);
    expect(item.changes.first.afterText, 'All collections');
  });

  test('every manifest problem comes back in details', () async {
    final e = await m.p.error(
      'modules.save',
      save(
        manifest: manifestWith((j) {
          j['name'] = 'Morkva helper';
          j['permissions'] = {
            'capabilities': ['data:read', 'host:commit'],
          };
          j['network'] = true;
        }),
      ),
    );
    expect(e.code, ErrorCode.invalidArgs);
    final paths = [for (final d in e.details!) d.path];
    expect(paths, containsAll(['manifest.name', 'manifest.network']));
    expect(paths.any((p) => p.startsWith('manifest.permissions')), isTrue);
  });

  test('code over 256 KB is limit_exceeded', () async {
    final e = await m.p.error(
      'modules.save',
      save(code: 'x' * (kCodeMaxBytes + 1)),
    );
    expect(e.code, ErrorCode.limitExceeded);
    expect(e.path, 'code');
  });

  test('an unknown collection is refused with candidates', () async {
    final e = await m.p.error('modules.save', save(collections: ['Invoices']));
    expect(e.code, ErrorCode.unknownCollection);
    expect(e.path, 'collections[0]');
  });

  test(
    'an update shows the permission diff and turns auto-apply off',
    () async {
      final old = await m.install(autoApply: true);
      final manifest = manifestWith((j) {
        j['version'] = '1.1.0';
        j['permissions'] = {
          'capabilities': [
            'schema:read',
            'data:read',
            'data:write',
            'data:delete',
          ],
        };
      });
      await m.p.ok(
        'modules.save',
        save(manifest: manifest, collections: ['Orders', 'Clients']),
      );
      final plan = await m.p.sealPlan();
      final item = plan.items.single as SaveModuleItem;

      expect(plan.title, 'Update “Stamp shipped date”');
      expect(item.detail, 'v1.0.0 → v1.1.0');
      expect(item.beforeCodeHash, old.bundleHash);
      final byField = {for (final c in item.changes) c.field: c};
      final write = byField[kCapabilityCopy['data:write']!.title]!;
      expect(write.beforeText, 'Orders');
      expect(write.afterText, 'Orders, Clients');
      final delete = byField[kCapabilityCopy['data:delete']!.title]!;
      expect(delete.beforeText, isNull, reason: 'a new permission');
      expect(delete.afterText, 'Orders, Clients');
      // The hash pins the manifest too, so the code row changes with it.
      expect(byField['Code']!.beforeText, isNot(byField['Code']!.afterText));
      expect(byField['Actions']!.beforeText, isNull, reason: 'same actions');
      expect(
        plan.warnings.single.message,
        'Auto-apply turns off for the new version. Turn it on again in module '
        'details.',
      );
      expect(item.consent.autoApply, isFalse);
    },
  );

  test(
    'saving the installed bundle with the same consent is no_change',
    () async {
      await m.install();
      final e = await m.p.error('modules.save', save());
      expect(e.code, ErrorCode.noChange);
    },
  );

  test(
    'a module (or anyone without modules:write) cannot plan installs',
    () async {
      final e = await m.p.error(
        'modules.save',
        save(),
        grants: Grants(kModuleGrantable),
      );
      expect(e.code, ErrorCode.notPermitted);
    },
  );
}
