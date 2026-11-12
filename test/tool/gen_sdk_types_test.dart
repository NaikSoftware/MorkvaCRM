// The SDK docs are generated (tool/gen_sdk_types.dart): this fails while any
// generated file is stale, and checks each example bundle against its
// sources.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/automation/automation.dart';

import '../../tool/gen_sdk_types.dart';

void main() {
  test('generated SDK files match tool/gen_sdk_types.dart', () {
    final files = generateSdkFiles('.');
    expect(
      files.keys,
      containsAll(['docs/sdk/api.md', 'docs/sdk/morkva.d.ts']),
    );
    for (final MapEntry(key: path, value: content) in files.entries) {
      final file = File(path);
      expect(
        file.existsSync() && file.readAsStringSync() == content,
        isTrue,
        reason: '$path is stale: run `dart run tool/gen_sdk_types.dart`',
      );
    }
  });

  test('each example bundle is its manifest.json and module.js', () {
    final dirs = Directory(kExamplesDir).listSync().whereType<Directory>();
    expect(
      dirs.map((d) => d.uri.pathSegments[d.uri.pathSegments.length - 2]),
      unorderedEquals([
        'copy-order-total',
        'low-stock-flag',
        'stamp-shipped-date',
      ]),
    );
    for (final dir in dirs) {
      final id = dir.uri.pathSegments[dir.uri.pathSegments.length - 2];
      final bundle = decodeModuleBundle(
        File('${dir.path}/$id.morkva.json').readAsStringSync(),
      );
      expect(bundle.manifest.id, id);
      expect(bundle.code, File('${dir.path}/module.js').readAsStringSync());
      expect(
        bundle.manifestJson,
        jsonDecode(File('${dir.path}/manifest.json').readAsStringSync()),
      );
    }
  });

  test("manifest.md has every capability in the app's words", () {
    final md = File('docs/sdk/manifest.md').readAsStringSync();
    for (final MapEntry(:key, :value) in kCapabilityCopy.entries) {
      expect(
        md,
        contains('| `$key` | ${value.title} | ${value.explanation} |'),
      );
    }
    for (final icon in kActionIconIds) {
      expect(md, contains('`$icon`'));
    }
  });

  test('module-callable ops leave out the runtime-only namespaces', () {
    final describe =
        jsonDecode(File(kDescriptorsPath).readAsStringSync())
            as Map<String, Object?>;
    final ids = [for (final op in moduleCallableOps(describe)) op['id']];
    expect(
      ids,
      containsAll([
        'cards.query',
        'cards.update',
        'collections.get',
        'harness.describe',
        'ui.open',
        'views.update',
        'workspace.describe',
      ]),
    );
    for (final id in ids) {
      expect(
        '$id',
        isNot(matches(r'^(plans|journal|modules|automations|runs)\.')),
      );
    }
    final dts = File('docs/sdk/morkva.d.ts').readAsStringSync();
    for (final id in ids) {
      expect(dts, contains("call(op: '$id'"));
    }
  });
}
