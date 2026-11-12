// The docs/sdk examples run end to end on a real ScriptEngine: the bundle
// as the docs ship it (sdk_examples.g.dart), the real ScriptBridge, the
// harness read/plan/ui ops, and an action context built like the runner's
// (CardShaper) under grants taken from the example's own manifest. The web
// suite (web/sdk_examples_test.dart) and the QuickJS suite
// (qjs/sdk_examples_qjs_test.dart) share these tests. Imports neither
// engine nor dart:io.
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/automation/bridge.dart';
import 'package:morkva_crm/core/automation/card_shaper.dart';
import 'package:morkva_crm/core/automation/engine/script_engine.dart';
import 'package:morkva_crm/core/domain/automation/automation.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/core/harness/harness.dart';
import 'package:morkva_crm/core/harness/ops/read_ops.dart';
import 'package:morkva_crm/core/harness/ops/ui_ops.dart';
import 'package:morkva_crm/core/harness/plan/plan.dart';
import 'package:morkva_crm/core/harness/query/aggregate_engine.dart';

import '../core/harness/plan/plan_fixture.dart';
import 'web/sdk_examples.g.dart';

/// The fields the examples write, added to the seed workspace.
abstract final class ExampleFields {
  static const String shippedOn = 'f_or_shipped_on';
  static const String lastOrderTotal = 'f_cl_last_order_total';
  static const String lowStock = 'f_fb_low_stock';
}

/// The seed workspace plus Orders "Shipped on", Clients "Last order total"
/// and Fabrics "Low stock".
SeedWorkspace exampleWorkspace() {
  final seed = SeedWorkspace();
  Collection plus(Collection c, FieldDefinition f) {
    final fields = [...c.fields, f];
    return c.copyWith(
      fields: fields,
      layout: CardLayout.synthesize([for (final f in fields) f.id]),
    );
  }

  seed.collections
    ..[0] = plus(
      seed.clients,
      const NumberFieldDefinition(
        id: ExampleFields.lastOrderTotal,
        name: 'Last order total',
      ),
    )
    ..[1] = plus(
      seed.orders,
      const DateFieldDefinition(
        id: ExampleFields.shippedOn,
        name: 'Shipped on',
      ),
    )
    ..[2] = plus(
      seed.fabrics,
      const BooleanFieldDefinition(
        id: ExampleFields.lowStock,
        name: 'Low stock',
      ),
    );
  return seed;
}

final class ExampleRig {
  ExampleRig(ScriptEngine engine) : h = PlanHarness(exampleWorkspace()) {
    registerReadOps(
      h.registry,
      queries: h.queries,
      aggregates: AggregateEngine(h.queries),
      thread: (ctx) => 'run:${ctx.turnId}',
    );
    registerUiOps(h.registry, queries: h.queries);
    bridge = ScriptBridge(
      harness: h.harness,
      plans: h.store,
      results: h.queries.results,
      engine: engine,
      now: () => now,
    );
    shaper = CardShaper(h.cache);
  }

  final PlanHarness h;
  late final ScriptBridge bridge;
  late final CardShaper shaper;

  /// The example's effective grants: its manifest capabilities in
  /// [collections] (null = all).
  Grants grantsOf(ModuleBundle bundle, {Set<String>? collections}) => Grants([
    for (final c in bundle.manifest.capabilities) Capability.fromWire(c)!,
  ], collections: collections);

  /// Runs [action] of example [id] with [params] (defaults filled in like
  /// the runner) on a card button of [cardId] or a collection button over
  /// [cardIds]; [test] wraps the trigger like a test run.
  Future<BridgeOutcome> run(
    String id,
    String action, {
    required String collectionId,
    required Map<String, Object?> params,
    String? cardId,
    List<String>? cardIds,
    bool test = false,
    Set<String>? collections,
  }) async {
    final bundle = decodeModuleBundle(kSdkExamples[id]!);
    final spec = bundle.manifest.actions.firstWhere((a) => a.id == action);
    final grants = grantsOf(bundle, collections: collections);
    final button = cardId != null
        ? {
            'kind': 'button',
            'scope': 'card',
            'collectionId': collectionId,
            'cardId': cardId,
          }
        : {
            'kind': 'button',
            'scope': 'collection',
            'collectionId': collectionId,
            'viewId': null,
            'cardIds': cardIds ?? const <String>[],
          };
    final card = cardId == null
        ? null
        : await shaper.current(collectionId, cardId, grants, today: today);
    final run = bridge.start(
      BridgeRequest(
        moduleId: bundle.manifest.id,
        code: bundle.code,
        actionId: action,
        input: spec.input?.withDefaults(params) ?? params,
        context: {
          'runId': 'run_example',
          'module': {
            'id': bundle.manifest.id,
            'version': bundle.manifest.version,
          },
          'automation': test ? null : {'id': 'au_example', 'name': 'Example'},
          'trigger': test ? {'kind': 'test', 'as': button} : button,
          'card': card,
          'today': '2026-11-10',
          'now': now.toUtc().toIso8601String(),
          'timeZone': 'UTC',
        },
        grants: grants,
        workspaceId: 'w1',
        today: today,
        timeout: Duration(milliseconds: bundle.manifest.timeoutMs),
      ),
    );
    return run.outcome;
  }

  /// The value of [fieldId] on card [cardId] as `ctx.card` shows it.
  Future<Object?> shown(
    String collectionId,
    String cardId,
    String fieldId,
  ) async {
    final card = await shaper.current(
      collectionId,
      cardId,
      Grants.all(),
      today: today,
    );
    return (card!['values']! as Map)[fieldId];
  }

  Future<void> dispose() => h.dispose();
}

String _failure(BridgeOutcome o) =>
    '${o.status} ${o.reason} ${o.error?.message} console=${o.log.console} '
    'calls=${o.log.calls}';

/// The updates of a sealed outcome, by card id.
Map<String, UpdateCardItem> sealedUpdates(BridgeOutcome o) {
  expect(o.status, RunStatus.sealing, reason: _failure(o));
  return updatesOf(o.plan!);
}

/// The example tests, on the engine [engine] builds.
void sdkExampleTests(ScriptEngine Function() engine, {String? skip}) {
  late ExampleRig rig;
  final order = SeedCards.order(kFirstOrderNumber);

  setUp(() => rig = ExampleRig(engine()));
  tearDown(() => rig.dispose());

  test('every example bundle decodes', () {
    expect(kSdkExamples.keys, [
      'copy-order-total',
      'low-stock-flag',
      'stamp-shipped-date',
    ]);
    for (final text in kSdkExamples.values) {
      expect(decodeModuleBundle(text).manifest.actions, isNotEmpty);
    }
  }, skip: skip);

  test('stamp-shipped-date plans today into an empty date field', () async {
    final o = await rig.run(
      'stamp-shipped-date',
      'stamp',
      collectionId: SeedIds.orders,
      cardId: order,
      params: {'dateField': ExampleFields.shippedOn},
    );
    final item = sealedUpdates(o)[order]!;
    expect(item.changes.single.fieldId, ExampleFields.shippedOn);
    expect(item.changes.single.after, isNotNull);
    expect(o.summary, startsWith('Set Shipped on to 2026-11-10 on '));
  }, skip: skip);

  test('stamp-shipped-date leaves a filled date alone', () async {
    final o = await rig.run(
      'stamp-shipped-date',
      'stamp',
      collectionId: SeedIds.orders,
      cardId: order,
      params: {'dateField': OrderFields.created},
    );
    expect(o.status, RunStatus.succeeded, reason: _failure(o));
    expect(o.plan, isNull);
    expect(o.summary, startsWith('Created is already set on '));
  }, skip: skip);

  test('copy-order-total plans the total onto the linked client', () async {
    final seedOrder = rig.h.seed.card(SeedIds.orders, order);
    final client = (seedOrder[OrderFields.client]! as ReferenceFieldValue)
        .objectIds
        .single;
    final total = await rig.shown(SeedIds.orders, order, OrderFields.total);
    expect(total, isA<num>());
    final o = await rig.run(
      'copy-order-total',
      'copyTotal',
      collectionId: SeedIds.orders,
      cardId: order,
      params: {
        'clientField': OrderFields.client,
        'totalField': OrderFields.total,
      },
      collections: {SeedIds.orders, SeedIds.clients},
    );
    final updates = sealedUpdates(o);
    expect(updates.keys, [client]);
    expect(updates[client]!.collectionId, SeedIds.clients);
    expect(updates[client]!.afterValues, {ExampleFields.lastOrderTotal: total});
    expect(o.summary, startsWith('Copied $total to '));
  }, skip: skip);

  test('copy-order-total fails without Clients in its consent', () async {
    final o = await rig.run(
      'copy-order-total',
      'copyTotal',
      collectionId: SeedIds.orders,
      cardId: order,
      params: {
        'clientField': OrderFields.client,
        'totalField': OrderFields.total,
      },
      collections: {SeedIds.orders},
    );
    expect(o.status, RunStatus.failed, reason: _failure(o));
    expect(o.reason, RunReason.moduleError);
    expect(o.error!.message, contains(kCollectionNotAvailable));
    expect(o.plan, isNull);
  }, skip: skip);

  group('low-stock-flag', () {
    late Set<String> low;
    late List<String> all;

    setUp(() {
      final fabrics = rig.h.seed.fabricCards;
      all = [for (final f in fabrics) f.id];
      low = {
        for (final f in fabrics)
          if ((f[FabricFields.stock] as NumberFieldValue?)?.value case final s?
              when s < 20)
            f.id,
      };
      expect(low, isNotEmpty);
      expect(low.length, lessThan(all.length));
    });

    test('flags the shown cards below the threshold in one update', () async {
      final o = await rig.run(
        'low-stock-flag',
        'flagLow',
        collectionId: SeedIds.fabrics,
        cardIds: all,
        params: {
          'stockField': FabricFields.stock,
          'flagField': ExampleFields.lowStock,
        },
      );
      final updates = sealedUpdates(o);
      expect(updates.keys.toSet(), low);
      for (final u in updates.values) {
        expect(u.afterValues, {ExampleFields.lowStock: true});
      }
      expect(
        o.summary,
        'Flagged ${low.length} product${low.length == 1 ? '' : 's'}',
      );
    }, skip: skip);

    test('a button run sees only the shown cards', () async {
      final one = low.first;
      final o = await rig.run(
        'low-stock-flag',
        'flagLow',
        collectionId: SeedIds.fabrics,
        cardIds: [one, ...all.where((id) => !low.contains(id))],
        params: {
          'stockField': FabricFields.stock,
          'flagField': ExampleFields.lowStock,
        },
      );
      expect(sealedUpdates(o).keys, [one]);
      expect(o.summary, 'Flagged 1 product');
    }, skip: skip);

    test('a test run checks the whole collection', () async {
      final o = await rig.run(
        'low-stock-flag',
        'flagLow',
        collectionId: SeedIds.fabrics,
        test: true,
        params: {
          'stockField': FabricFields.stock,
          'flagField': ExampleFields.lowStock,
        },
      );
      expect(sealedUpdates(o).keys.toSet(), low);
    }, skip: skip);

    test('a button run on an empty view plans nothing', () async {
      final o = await rig.run(
        'low-stock-flag',
        'flagLow',
        collectionId: SeedIds.fabrics,
        cardIds: const [],
        params: {
          'stockField': FabricFields.stock,
          'flagField': ExampleFields.lowStock,
        },
      );
      expect(o.status, RunStatus.succeeded, reason: _failure(o));
      expect(o.plan, isNull);
      expect(o.summary, 'No products shown');
    }, skip: skip);
  });
}
