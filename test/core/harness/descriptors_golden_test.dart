// Freezes `harness.describe` (every registered op's descriptor, the error
// codes, capabilities and events) as goldens/descriptors.json, so any API
// change shows up as a deliberate diff in review. Regenerate with
// `flutter test --update-goldens test/core/harness/descriptors_golden_test.dart`.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/automation/store_catalog.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/core/harness/harness.dart';
import 'package:morkva_crm/core/harness/ops/module_ops.dart';
import 'package:morkva_crm/core/harness/ops/plan_protocol_ops.dart';
import 'package:morkva_crm/core/harness/ops/protocol_ops.dart';
import 'package:morkva_crm/core/harness/ops/read_ops.dart';
import 'package:morkva_crm/core/harness/ops/ui_ops.dart';
import 'package:morkva_crm/core/harness/query/aggregate_engine.dart';

import '../../automation/fakes/fake_stores.dart';
import 'plan/commit_fixture.dart';

const _golden = 'test/core/harness/goldens/descriptors.json';

void main() {
  late CommitHarness h;
  final stores = FakeStores();

  setUp(() {
    // Plan, view and host ops come with the commit harness.
    h = CommitHarness();
    final ops = h.p.registry;
    registerReadOps(
      ops,
      queries: h.p.queries,
      aggregates: AggregateEngine(h.p.queries),
      thread: (_) => 't1',
    );
    registerUiOps(ops, queries: h.p.queries);
    registerProtocolOps(ops);
    registerModuleOps(
      ops,
      catalog: StoreAutomationCatalog(stores.stores, uid: () => null),
      services: PlanServices(
        cache: h.p.cache,
        queries: h.p.queries,
        store: h.p.store,
        registry: defaultFieldTypeRegistry(),
      ),
    );
  });
  tearDown(() => h.dispose());

  test('harness.describe matches the descriptors golden', () async {
    final described = await h.p.ok('harness.describe', const {});
    final ops = (described['ops']! as List).cast<Map<String, Object?>>();
    final visible = ops.where((o) => o['modelVisible'] == true).toList();
    final commit = ops.where((o) => o['kind'] == 'commit').toList();
    // 30 tools for the model, 3 protocol ops and 5 host-only commit ops.
    expect(ops, hasLength(38));
    expect(visible, hasLength(30));
    expect(
      [for (final o in commit) o['id']],
      [
        'journal.restore',
        'journal.undo',
        'plans.commit',
        'plans.reject',
        'plans.retryFailed',
      ],
    );
    expect(
      commit.every(
        (o) => o['capability'] == 'host:commit' && o['modelVisible'] == false,
      ),
      isTrue,
    );
    expect(described['apiVersion'], '2.0');
    expect(described['errorCodes'], contains('no_change'));
    expect(
      described['capabilities'],
      containsAll(['modules:read', 'modules:write', 'automations:write']),
    );
    for (final o in ops) {
      // Every op of apiVersion 2 is new in 2.0; an additive op says 2.1 and
      // bumps kHarnessMinor.
      expect(o['since'], '2.0', reason: '${o['id']}');
      expect(
        OperationRegistry.toolNamePattern.hasMatch(
          OperationRegistry.toolName(o['id']! as String),
        ),
        isTrue,
        reason: '${o['id']}',
      );
    }

    final text = '${const JsonEncoder.withIndent('  ').convert(described)}\n';
    final file = File(_golden);
    if (autoUpdateGoldenFiles) {
      file
        ..createSync(recursive: true)
        ..writeAsStringSync(text);
      return;
    }
    expect(
      file.existsSync(),
      isTrue,
      reason: 'Missing $_golden; run with --update-goldens.',
    );
    expect(
      text,
      file.readAsStringSync(),
      reason: 'The harness API changed; review and run with --update-goldens.',
    );
  });
}
