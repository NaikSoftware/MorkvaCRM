import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/automation/automation.dart';

import 'fixtures.dart';

const _code = '(function(){ morkva.action("stamp", async () => "ok"); })();';
final _now = DateTime.utc(2026, 11, 12, 10);

List<String> _problems(String text) {
  try {
    decodeModuleBundle(text);
    return const [];
  } on ManifestProblems catch (e) {
    return [for (final p in e.problems) p.toString()];
  }
}

GrantRecord _consentTo(ModuleRecord module, {List<String>? caps}) =>
    GrantRecord(
      moduleId: module.id,
      codeHash: bundleHashOf(module.manifestJson, module.code),
      version: module.version,
      codeBytes: module.codeBytes,
      caps: caps ?? const ['schema:read', 'data:read', 'data:write'],
      collections: null,
      autoApply: false,
      grantedAt: _now,
      via: GrantVia.consentSheet,
    );

void main() {
  test('a bundle round-trips through its file text', () {
    final bundle = ModuleBundle.of(stampManifest(), _code);
    final text = bundle.encode();
    expect(text, contains('\n  "manifest": {'));
    final back = decodeModuleBundle(text);
    expect(back.manifestJson, bundle.manifestJson);
    expect(back.code, _code);
    expect(back.manifest, bundle.manifest);
    expect(
      bundleHashOf(back.manifestJson, back.code),
      bundleHashOf(bundle.manifestJson, bundle.code),
    );
  });

  test('canonicalJson sorts keys and writes whole doubles as ints', () {
    expect(
      canonicalJson({
        'b': 1,
        'a': {
          'd': 2.0,
          'c': [3.5, 4.0],
        },
      }),
      '{"a":{"c":[3.5,4],"d":2},"b":1}',
    );
  });

  test('the hash covers the manifest, not only the code', () {
    final base = bundleHashOf(stampManifest(), _code);
    expect(base, startsWith('sha256:'));
    expect(base, hasLength('sha256:'.length + 64));
    expect(
      bundleHashOf(stampManifest()..['name'] = 'Other', _code),
      isNot(base),
    );
    expect(
      bundleHashOf(stampManifest()..['timeoutMs'] = 30000, _code),
      isNot(base),
    );
    expect(bundleHashOf(stampManifest(), '$_code '), isNot(base));
    // Key order and 2 vs 2.0 do not matter.
    final reordered = Map.fromEntries(stampManifest().entries.toList().reversed)
      ..['apiVersion'] = 2.0;
    expect(bundleHashOf(reordered, _code), base);
  });

  group('decode refuses', () {
    test('anything that is not a module file', () {
      const notModule = 'This isn\'t a Morkva module file.';
      expect(_problems('not json'), [notModule]);
      expect(_problems('[]'), [notModule]);
      expect(
        _problems(jsonEncode({'manifest': stampManifest(), 'code': _code})),
        [notModule],
      );
      expect(
        _problems(
          jsonEncode({'morkva': 2, 'manifest': stampManifest(), 'code': _code}),
        ),
        [notModule],
      );
      expect(
        _problems(
          jsonEncode({
            'morkva': 1,
            'manifest': stampManifest(),
            'code': _code,
            'extra': 1,
          }),
        ),
        [notModule],
      );
    });

    test('code over 256 KB, with the manifest problems too', () {
      final text = jsonEncode({
        'morkva': 1,
        'manifest': stampManifest()..['name'] = 'Morkva',
        'code': 'x' * (256 * 1024 + 1),
      });
      expect(_problems(text), [
        'code: The code is 257 KB; the limit is 256 KB.',
        'name: Modules can\'t be named after Morkva or the assistant.',
      ]);
    });

    test('a file over 300 KB', () {
      expect(_problems('x' * (300 * 1024 + 1)), [
        'The file is 301 KB; the limit is 300 KB.',
      ]);
    });
  });

  group('module status', () {
    ModuleRecord module({
      Map<String, Object?>? manifest,
      String code = _code,
    }) => ModuleRecord(
      id: 'stamp-shipped-date',
      manifestJson: manifest ?? stampManifest(),
      code: code,
      codeHash: 'sha256:stale',
      source: ModuleSource.import,
      version: '1.0.0',
      name: 'Stamp shipped date',
      createdBy: 'user:u1',
      createdAt: _now,
      updatedAt: _now,
    );

    test('ok with a consent to this exact bundle', () {
      final m = module();
      expect(moduleStatusOf(m, _consentTo(m)), ModuleStatus.ok);
    });

    test('needs consent without one, on new code or a new manifest', () {
      final m = module();
      final consent = _consentTo(m);
      expect(moduleStatusOf(m, null), ModuleStatus.needsConsent);
      expect(
        moduleStatusOf(module(code: '$_code//2'), consent),
        ModuleStatus.needsConsent,
      );
      expect(
        moduleStatusOf(
          module(manifest: stampManifest()..['version'] = '1.0.1'),
          consent,
        ),
        ModuleStatus.needsConsent,
      );
    });

    test('a forged stored codeHash changes nothing', () {
      final consented = module();
      final consent = _consentTo(consented);
      final forged = ModuleRecord(
        id: consented.id,
        manifestJson: consented.manifestJson,
        code: '$_code/* evil */',
        codeHash: consent.codeHash,
        source: ModuleSource.import,
        version: '1.0.0',
        name: 'Stamp shipped date',
        createdBy: 'user:u1',
        createdAt: _now,
        updatedAt: _now,
      );
      expect(moduleStatusOf(forged, consent), ModuleStatus.needsConsent);
    });

    test('needs consent when the manifest asks for more than consented', () {
      final m = module();
      expect(
        moduleStatusOf(
          m,
          _consentTo(m, caps: const ['schema:read', 'data:read']),
        ),
        ModuleStatus.needsConsent,
      );
    });

    test('broken when the stored manifest no longer parses', () {
      final m = module(manifest: stampManifest()..['permissions'] = {});
      expect(m.manifest, isNull);
      expect(m.manifestProblems, isNotEmpty);
      expect(moduleStatusOf(m, _consentTo(m)), ModuleStatus.broken);
    });
  });

  test('a module record round-trips and keeps the rule keys', () {
    final bundle = ModuleBundle.of(stampManifest(), _code);
    final record = ModuleRecord.fromBundle(
      bundle,
      source: ModuleSource.assistant,
      createdBy: 'agent:assistant',
      now: _now,
    );
    expect(record.codeHash, bundleHashOf(stampManifest(), _code));
    final json = record.toJson();
    expect(
      json.keys,
      containsAll([
        'schema',
        'manifest',
        'code',
        'codeHash',
        'source',
        'version',
        'name',
        'createdBy',
        'createdAt',
        'updatedAt',
      ]),
    );
    expect(json['source'], 'assistant');
    expect(ModuleRecord.fromJson(record.id, json), record);
    expect(
      () => ModuleRecord.fromJson('x', {...json, 'code': 1}),
      throwsFormatException,
    );
  });
}
