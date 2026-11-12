import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/automation/bridge.dart';
import 'package:morkva_crm/core/automation/engine/protocol.dart';
import 'package:morkva_crm/core/automation/engine/sdk_core.dart';
import 'package:morkva_crm/core/automation/run_log_builder.dart';
import 'package:morkva_crm/core/automation/runner_api.dart' show RunProgress;
import 'package:morkva_crm/core/domain/automation/automation.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/core/harness/cache/result_store.dart';
import 'package:morkva_crm/core/harness/harness.dart';
import 'package:morkva_crm/core/harness/ops/read_ops.dart';
import 'package:morkva_crm/core/harness/ops/ui_ops.dart';
import 'package:morkva_crm/core/harness/plan/plan_store.dart';
import 'package:morkva_crm/core/harness/query/aggregate_engine.dart';
import 'package:morkva_crm/core/harness/query/cache_workspace_reader.dart';

import '../../automation/fakes/fake_script_engine.dart';
import '../harness/plan/plan_fixture.dart';

const _module = 'stamp';
const _actor = Actor.plugin(_module);
const _code = 'morkva.action("run", () => {});';
const _ctx = {'runId': 'run_1', 'today': '2026-11-10'};
final _order = SeedCards.order(1001);

/// A test op that waits for [gate] (open by default when [open]), then runs
/// [body].
final class GateOp extends Operation<Map<String, Object?>> {
  GateOp(String id, {OpKind kind = OpKind.read, bool open = false, this.body})
    : descriptor = OperationDescriptor(
        id: id,
        kind: kind,
        exemption: 'test',
        summary: 'A test op.',
        argsSchema: const {'type': 'object'},
        resultSchema: const {'type': 'object'},
        modelVisible: false,
      ) {
    if (open) gate.complete();
  }

  @override
  final OperationDescriptor descriptor;
  final FutureOr<Map<String, Object?>?> Function(HarnessContext ctx)? body;
  final gate = Completer<void>();
  var entered = 0;
  var finished = 0;

  @override
  Map<String, Object?> decode(Map<String, Object?> args, HarnessContext ctx) =>
      args;

  @override
  Future<OpResult> run(
    Map<String, Object?> args,
    HarnessContext ctx,
    HarnessRequest request,
  ) async {
    entered++;
    await gate.future;
    final result = await body?.call(ctx);
    finished++;
    return OpResult(result ?? const {'summary': 'gated'});
  }
}

/// A bridge over the seed workspace's plan, read and UI ops ([seed]) or
/// over [ops] alone.
final class Rig {
  Rig({
    bool seed = true,
    List<Operation<Object?>> ops = const [],
    Duration bootBudget = const Duration(seconds: 2),
    Duration drainBudget = const Duration(seconds: 2),
  }) {
    if (seed) {
      final h = this.h = PlanHarness();
      registerReadOps(
        h.registry,
        queries: h.queries,
        aggregates: AggregateEngine(h.queries),
        thread: (ctx) => 'run:${ctx.turnId}',
      );
      registerUiOps(h.registry, queries: h.queries);
      registry = h.registry;
      harness = h.harness;
      plans = h.store;
      results = h.queries.results;
    } else {
      registry = OperationRegistry();
      harness = Harness(registry);
      plans = PlanStore();
      results = ResultStore();
    }
    ops.forEach(registry.register);
    bridge = ScriptBridge(
      harness: harness,
      plans: plans,
      results: results,
      engine: engine,
      now: () => clock,
      bootBudget: bootBudget,
      drainBudget: drainBudget,
    );
  }

  PlanHarness? h;
  late final OperationRegistry registry;
  late final Harness harness;
  late final PlanStore plans;
  late final ResultStore results;
  late final ScriptBridge bridge;
  final engine = FakeScriptEngine();
  DateTime clock = now;

  BridgeRun start(
    FakeAction action, {
    Grants? grants,
    Duration timeout = const Duration(seconds: 5),
    void Function(RunProgress)? onProgress,
  }) {
    engine.action = action;
    return bridge.start(
      BridgeRequest(
        moduleId: _module,
        code: _code,
        actionId: 'run',
        input: const {'dateField': 'f_shipped'},
        context: _ctx,
        grants: grants ?? Grants(kModuleGrantable),
        workspaceId: 'w1',
        today: today,
        timeout: timeout,
        onProgress: onProgress,
      ),
    );
  }

  Future<BridgeOutcome> run(
    FakeAction action, {
    Grants? grants,
    Duration timeout = const Duration(seconds: 5),
  }) => start(action, grants: grants, timeout: timeout).outcome;

  FakeScriptSession get session => engine.sessions.single;

  Future<void> dispose() async => h?.dispose();
}

Future<void> until(bool Function() condition) async {
  for (var i = 0; i < 2000 && !condition(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  expect(condition(), isTrue, reason: 'condition never held');
}

Map<String, Object?> _update(Object qty) => {
  'collection': 'Orders',
  'target': {
    'ids': [_order],
  },
  'set': {'Qty': qty},
};

/// The module's error for a call that must fail.
Future<Map<String, Object?>> _refused(
  FakeModule m,
  String op, [
  Map<String, Object?>? args,
]) async {
  try {
    await m.call(op, args);
  } on FakeCallError catch (e) {
    return e.error;
  }
  fail('$op should have been refused');
}

void main() {
  late Rig r;
  tearDown(() => r.dispose());

  group('identity and sealing', () {
    test(
      'the host sets actor, grants and turn; the plan is the plugin\'s',
      () async {
        r = Rig();
        final grants = Grants(
          [Capability.schemaRead, Capability.dataRead, Capability.dataWrite],
          collections: [SeedIds.orders],
        );
        final run = r.start((m, _) async {
          await m.call('cards.update', _update(9));
          return 'Stamped 1';
        }, grants: grants);
        final out = await run.outcome;

        expect(out.status, RunStatus.sealing, reason: '${out.error}');
        final plan = out.plan!;
        expect(plan.createdBy.actor, _actor);
        expect(plan.createdBy.grants.caps, grants.caps);
        expect(plan.createdBy.grants.collections, {SeedIds.orders});
        expect(r.plans.get(plan.planId), same(plan));
        expect(out.summary, 'Stamped 1');
        expect(out.log.plan.single.kind, 'updateCard');
        expect(out.log.calls.single.op, 'cards.update');

        final load = r.engine.loads.single;
        expect(
          (load.moduleId, load.code, load.sdkCore),
          (_module, _code, kSdkCoreJs),
        );
        expect(load.budget, const Duration(seconds: 5));
        final invoked = r.session.invocations.single;
        expect(invoked.ctx, _ctx);
        expect(invoked.input, {'dateField': 'f_shipped'});
        expect(r.harness.ownsTurn(_actor, run.turnId), isFalse);
        expect(r.plans.overlayOf(_actor, run.turnId), isNull);
      },
    );

    test(
      'a call the action did not await still lands before the seal',
      () async {
        r = Rig();
        final out = await r.run((m, _) async {
          unawaited(m.call('cards.update', _update(9)));
          return null;
        });
        expect(out.status, RunStatus.sealing);
        expect(out.plan!.items, hasLength(1));
        expect(out.summary, isNull);
      },
    );

    test('the run\'s stored query results are dropped at the end', () async {
      r = Rig();
      String? handle;
      final out = await r.run((m, _) async {
        final rows = await m.call('cards.query', {'collection': 'Orders'});
        handle = (rows! as Map)['handle'] as String;
        expect(r.results.get(handle!), isNotNull);
        return null;
      });
      expect(out.status, RunStatus.succeeded);
      expect(r.results.get(handle!), isNull);
    });

    test('ui.open becomes a link of the run', () async {
      r = Rig();
      final out = await r.run((m, _) async {
        await m.call('ui.open', {'collection': 'Orders', 'card': _order});
        return null;
      });
      expect(out.log.ui.single.kind, 'card');
      expect(out.log.ui.single.ref, '${SeedIds.orders}/$_order');
    });
  });

  group('plan calls', () {
    test(
      'a plan call the harness refused before the op ran fails the run',
      () async {
        r = Rig();
        late BridgeRun run;
        run = r.start((m, _) async {
          final bad = await _refused(m, 'cards.update', {
            'collection': 'Orders',
          });
          expect(bad['code'], 'invalid_args');
          await m.call('cards.update', _update(9));
          return 'ok';
        });
        final out = await run.outcome;
        expect(out.status, RunStatus.failed);
        expect(out.reason, RunReason.planRefused);
        expect(out.error!.message, contains('cards.update'));
        expect(out.error!.message, contains('invalid_args'));
        expect(out.plan, isNull);
        expect(r.plans.overlayOf(_actor, run.turnId), isNull);
      },
    );

    test(
      'no_change is the call\'s answer but neither recorded nor a plan',
      () async {
        r = Rig();
        final qty =
            (r.h!.seed.orderCards.firstWhere(
                      (o) => o.id == _order,
                    )[OrderFields.qty]!
                    as NumberFieldValue)
                .value!;
        final out = await r.run((m, _) async {
          final same = await _refused(m, 'cards.update', _update(qty));
          expect(same['code'], 'no_change');
          return null;
        });
        expect(out.status, RunStatus.succeeded);
        expect(out.summary, 'No changes');
        expect(out.plan, isNull);
        final row = out.log.calls.single;
        expect((row.ok, row.result), (true, kNoChangeText));

        final mixed = await r.run((m, _) async {
          await _refused(m, 'cards.update', _update(qty));
          await m.call('cards.update', {
            ..._update(9),
            'set': {'Paid': true},
          });
          return null;
        });
        expect(mixed.status, RunStatus.sealing, reason: '${mixed.error}');
        expect(mixed.plan!.items, hasLength(1));
      },
    );

    test('denylisted ops are refused before the harness; a plan-kind one '
        'fails the run', () async {
      final save = GateOp('modules.save', kind: OpKind.plan, open: true);
      r = Rig(ops: [save]);
      final codes = <Object?>[];
      final out = await r.run((m, _) async {
        for (final op in [
          'plans.get',
          'plans.commit',
          'journal.undo',
          'automations.list',
          'runs.get',
        ]) {
          final e = await _refused(m, op, {'turnId': 'x'});
          codes.add((e['code'], e['message']));
        }
        return 'read only';
      });
      expect(codes.toSet(), {
        ('not_permitted', 'The runtime seals and applies the plan.'),
      });
      expect(out.status, RunStatus.succeeded);
      expect(out.summary, 'read only');

      for (final op in ['modules.save', 'plans.seal']) {
        final planned = await r.run((m, _) async {
          await _refused(m, op, const {});
          return null;
        });
        expect(planned.reason, RunReason.planRefused, reason: op);
      }
      expect(save.entered, 0);
    });
  });

  group('error text', () {
    test('an ungranted and a missing collection look the same', () async {
      r = Rig();
      final errors = <String>[];
      await r.run((m, _) async {
        for (final c in [SeedIds.clients, 'c_nope', 'Clients', 'Nope']) {
          final e = await _refused(m, 'cards.get', {
            'collection': c,
            'ids': ['x'],
          });
          errors.add(jsonEncode(e));
        }
        return null;
      }, grants: Grants(kModuleGrantable, collections: [SeedIds.orders]));
      expect(errors.toSet(), hasLength(1), reason: '$errors');
      final error = jsonDecode(errors.first) as Map<String, Object?>;
      expect(error['code'], 'not_permitted');
      expect(error['message'], kCollectionNotAvailable);
      expect(error, isNot(contains('candidates')));
    });

    test('a missing capability keeps its own message', () async {
      r = Rig();
      late Map<String, Object?> error;
      await r.run((m, _) async {
        error = await _refused(m, 'cards.get', {
          'collection': 'Orders',
          'ids': [_order],
        });
        return null;
      }, grants: Grants([Capability.schemaRead]));
      expect(error['code'], 'not_permitted');
      expect(error['message'], contains('data:read'));
    });

    test('internal errors reach the module as "Internal error" only', () async {
      r = Rig(
        seed: false,
        ops: [
          GateOp(
            'test.boom',
            open: true,
            body: (_) => throw StateError('secret detail'),
          ),
        ],
      );
      late Map<String, Object?> error;
      final out = await r.run((m, _) async {
        error = await _refused(m, 'test.boom');
        return null;
      });
      expect(error, {
        'code': 'internal',
        'message': 'Internal error',
        'retryable': false,
      });
      expect(out.log.calls.single.result, contains('secret detail'));
    });
  });

  group('caps', () {
    test('a ninth call in flight is answered limit_exceeded', () async {
      final wait = GateOp('test.wait');
      r = Rig(seed: false, ops: [wait]);
      final out = await r.run((m, _) async {
        final calls = [for (var i = 0; i < 9; i++) m.call('test.wait')];
        await expectLater(
          calls.last,
          throwsA(
            isA<FakeCallError>().having(
              (e) => e.code,
              'code',
              'limit_exceeded',
            ),
          ),
        );
        wait.gate.complete();
        await Future.wait(calls.take(8));
        return null;
      });
      expect(out.status, RunStatus.succeeded);
      expect(wait.entered, 8);
      expect(out.log.calls.where((c) => !c.ok), hasLength(1));
    });

    test('heavy reads queue two at a time instead of being refused', () async {
      final query = GateOp('cards.query');
      r = Rig(seed: false, ops: [query]);
      final run = r.start((m, _) async {
        await Future.wait([for (var i = 0; i < 3; i++) m.call('cards.query')]);
        return null;
      });
      await until(() => query.entered == 2);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(query.entered, 2);
      query.gate.complete();
      final out = await run.outcome;
      expect(out.status, RunStatus.succeeded);
      expect(query.entered, 3);
    });

    test('the call after the ${kMaxCallsPerRun}th fails the run', () async {
      r = Rig(seed: false, ops: [GateOp('test.fast', open: true)]);
      Object? last;
      final out = await r.run((m, _) async {
        for (var i = 0; i <= kMaxCallsPerRun; i++) {
          try {
            await m.call('test.fast');
          } on FakeCallError catch (e) {
            last = e.code;
          }
        }
        return null;
      });
      expect(last, 'limit_exceeded');
      expect(
        (out.status, out.reason),
        (RunStatus.failed, RunReason.limitExceeded),
      );
    });

    test(
      'one call over 256 KB is refused; over 2 MB in all fails the run',
      () async {
        final fast = GateOp('test.fast', open: true);
        r = Rig(seed: false, ops: [fast]);
        final big = await r.run((m, _) async {
          final e = await _refused(m, 'test.fast', {'blob': 'x' * 300000});
          expect(e['code'], 'limit_exceeded');
          return null;
        });
        expect(big.status, RunStatus.succeeded);
        expect(big.log.calls.single.ok, isFalse);
        expect(fast.entered, 0);

        final total = await r.run((m, _) async {
          for (var i = 0; i < 9; i++) {
            await m.call('test.fast', {'blob': 'x' * 250000});
          }
          return null;
        });
        expect(total.reason, RunReason.limitExceeded);
        expect(fast.entered, 8);
      },
    );

    test('more than 5 s of harness time fails the run', () async {
      r = Rig(seed: false);
      r.registry.register(
        GateOp(
          'test.slow',
          open: true,
          body: (_) {
            r.clock = r.clock.add(const Duration(seconds: 3));
            return null;
          },
        ),
      );
      final out = await r.run((m, _) async {
        for (var i = 0; i < 3; i++) {
          await m.call('test.slow');
        }
        return null;
      });
      expect(out.reason, RunReason.limitExceeded);
    });

    test('over $kMaxFramesPerSecond frames a second is abuse', () async {
      r = Rig(seed: false);
      final out = await r.run((m, _) async {
        for (var i = 0; i <= kMaxFramesPerSecond; i++) {
          m.log('info', ['$i']);
        }
        await Completer<void>().future;
        return null;
      });
      expect(out.reason, RunReason.abuse);
      expect(r.session.killedWith, 'abuse');
    });

    test('a non-string frame is abuse', () async {
      r = Rig(seed: false);
      final out = await r.run((m, _) async {
        m.send(42);
        await Completer<void>().future;
        return null;
      });
      expect(out.reason, RunReason.abuse);
    });

    test('a malformed call with an id is answered invalid_args', () async {
      r = Rig(seed: false);
      final out = await r.run((m, _) async {
        m.send(
          jsonEncode({
            't': 'call',
            'id': 7,
            'op': 'test.fast',
            'args': [1],
          }),
        );
        await Future<void>.delayed(const Duration(milliseconds: 5));
        return null;
      });
      expect(out.status, RunStatus.succeeded);
      final reply = r.session.replies.single;
      expect(reply.callId, 7);
      expect(reply.error!['code'], 'invalid_args');
    });

    test('progress is throttled to $kMaxProgressPerSecond/s with the label '
        'cut', () async {
      r = Rig(seed: false);
      final seen = <RunProgress>[];
      final run = r.start((m, _) async {
        for (var i = 0; i < 15; i++) {
          m.progress(i + 0.5, 15, label: 'L' * 80);
        }
        await Future<void>.delayed(const Duration(milliseconds: 5));
        return null;
      }, onProgress: seen.add);
      await run.outcome;
      expect(seen, hasLength(kMaxProgressPerSecond));
      expect(seen.first.done, 0);
      expect(seen.first.label!.length, kMaxProgressLabelChars);
    });
  });

  group('ending', () {
    test('on timeout pending calls are answered dead and late results are '
        'dropped', () async {
      final wait = GateOp('test.wait');
      r = Rig(
        seed: false,
        ops: [wait],
        drainBudget: const Duration(milliseconds: 50),
      );
      final out = await r.run((m, _) async {
        await m.call('test.wait');
        return null;
      }, timeout: const Duration(milliseconds: 50));
      expect(out.status, RunStatus.timedOut);
      expect(r.session.killedWith, 'timeout');
      final dead = r.session.repliesAfterKill.single;
      expect(dead.error!['code'], 'dead');

      wait.gate.complete();
      await until(() => wait.finished == 1);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(r.session.repliesAfterKill, hasLength(1));
      expect(r.session.replies, isEmpty);
    });

    test('Stop closes the turn, awaits the call already past it, then '
        'discards the overlay it re-created', () async {
      late GateOp plan;
      r = Rig();
      final h = r.h!;
      plan = GateOp(
        'test.plan',
        kind: OpKind.plan,
        body: (ctx) {
          h.store.overlay(
            ctx.actor,
            ctx.turnId!,
            grants: ctx.grants,
            base: CacheWorkspaceReader(h.cache),
            now: ctx.now,
          );
          return null;
        },
      );
      r.registry.register(plan);
      var done = false;
      final run = r.start((m, _) async {
        await m.call('test.plan');
        return null;
      });
      unawaited(run.outcome.then((_) => done = true));
      await until(() => plan.entered == 1);
      run.stop();
      await until(() => !r.harness.ownsTurn(_actor, run.turnId));
      expect(done, isFalse, reason: 'waits for the call in flight');
      plan.gate.complete();
      final out = await run.outcome;
      expect(plan.finished, 1);
      expect((out.status, out.reason), (RunStatus.failed, RunReason.cancelled));
      expect(out.error!.message, 'Stopped by you.');
      expect(r.plans.overlayOf(_actor, run.turnId), isNull);
      expect(r.session.repliesAfterKill.single.error!['code'], 'dead');
    });

    test(
      'a straggler past the drain budget is discarded when it ends',
      () async {
        late GateOp plan;
        r = Rig(drainBudget: const Duration(milliseconds: 30));
        final h = r.h!;
        plan = GateOp(
          'test.plan',
          kind: OpKind.plan,
          body: (ctx) {
            h.store.overlay(
              ctx.actor,
              ctx.turnId!,
              grants: ctx.grants,
              base: CacheWorkspaceReader(h.cache),
              now: ctx.now,
            );
            return null;
          },
        );
        r.registry.register(plan);
        final run = r.start((m, _) async {
          await m.call('test.plan');
          return null;
        });
        await until(() => plan.entered == 1);
        run.stop();
        await run.outcome;
        plan.gate.complete();
        await until(() => plan.finished == 1);
        await Future<void>.delayed(const Duration(milliseconds: 5));
        expect(r.plans.overlayOf(_actor, run.turnId), isNull);
      },
    );

    test('boot: no ready in time, a load error, an unregistered action, an '
        'engine that cannot start', () async {
      r = Rig(seed: false, bootBudget: const Duration(milliseconds: 30));
      r.engine.boot = (_) {};
      final silent = await r.run((_, _) async => null);
      expect(silent.reason, RunReason.loadTimeout);

      r.engine.boot = (m) => m.loadError('SyntaxError: x', stack: 'at 1:1');
      final broken = await r.run((_, _) async => null);
      expect(broken.reason, RunReason.loadError);
      expect(broken.error!.message, 'SyntaxError: x');

      r.engine
        ..boot = null
        ..actions = ['other'];
      final missing = await r.run((_, _) async => null);
      expect(missing.reason, RunReason.loadError);
      expect(missing.error!.message, contains('"run"'));

      r.engine.startError = const ScriptFailure('engine_unavailable', 'no');
      final unavailable = r.start((_, _) async => null);
      expect((await unavailable.outcome).reason, RunReason.engineUnavailable);
      expect(r.harness.ownsTurn(_actor, unavailable.turnId), isFalse);
    });

    test('an action that throws fails module_error with its stack', () async {
      r = Rig(seed: false);
      final out = await r.run((_, _) async => throw StateError('boom'));
      expect(out.reason, RunReason.moduleError);
      expect(out.error!.message, contains('boom'));
      expect(out.error!.stack, isNotNull);
      expect(r.session.killed, isTrue);
    });
  });
}
