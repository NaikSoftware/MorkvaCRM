import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/harness/harness.dart';
import 'package:morkva_crm/core/harness/ops/protocol_ops.dart';

typedef _Json = Map<String, Object?>;
typedef _Run =
    FutureOr<OpResult> Function(
      _Json args,
      HarnessContext ctx,
      HarnessRequest r,
    );

/// A configurable op for pipeline tests.
final class _FakeOp extends Operation<_Json> {
  _FakeOp(this.descriptor, {_Run? run, this.decoder, this.extraCaps})
    : _run = run ?? ((args, ctx, r) => OpResult({'args': args}));

  @override
  final OperationDescriptor descriptor;
  final _Run _run;
  final _Json Function(_Json args, HarnessContext ctx)? decoder;
  final Iterable<Capability> Function(_Json args)? extraCaps;

  @override
  Iterable<Capability> requiredCapabilities(_Json args) => [
    ...super.requiredCapabilities(args),
    ...?extraCaps?.call(args),
  ];

  @override
  _Json decode(_Json args, HarnessContext ctx) =>
      decoder == null ? args : decoder!(args, ctx);

  @override
  Future<OpResult> run(
    _Json args,
    HarnessContext ctx,
    HarnessRequest r,
  ) async => _run(args, ctx, r);
}

OperationDescriptor _descriptor(
  String id, {
  OpKind kind = OpKind.read,
  Capability? capability = Capability.dataRead,
  String? exemption,
  String since = '2.0',
  Map<String, Object?>? args,
  Map<String, Object?>? result,
}) => OperationDescriptor(
  id: id,
  kind: kind,
  capability: capability,
  exemption: exemption,
  since: since,
  modelVisible: kind != OpKind.commit,
  summary: 'Test op $id.',
  argsSchema:
      args ??
      JsonSchema.object(
        {
          'collection': JsonSchema.string(),
          'limit': JsonSchema.integer(minimum: 1, maximum: 100),
        },
        required: ['collection'],
      ),
  resultSchema: result ?? {'type': 'object'},
);

final _today = DateTime(2026, 11, 10);

HarnessContext _ctx({
  Actor actor = Actor.assistant,
  Grants? grants,
  String? turnId,
  Sink<HarnessEvent>? events,
}) => HarnessContext(
  workspaceId: 'w1',
  actor: actor,
  grants: grants ?? Grants.all(),
  now: DateTime(2026, 11, 10, 14, 30),
  today: _today,
  timeZoneName: 'Europe/Kyiv',
  turnId: turnId,
  events: events,
);

HarnessRequest _req(
  String op, [
  _Json args = const {'collection': 'Orders'},
  String? turnId,
]) => HarnessRequest(op: op, args: args, callId: 'r1.1', turnId: turnId);

void main() {
  late OperationRegistry ops;
  late Harness harness;

  setUp(() {
    ops = OperationRegistry()
      ..register(_FakeOp(_descriptor('cards.query')))
      ..register(
        _FakeOp(
          _descriptor(
            'cards.create',
            kind: OpKind.plan,
            capability: Capability.dataWrite,
          ),
          run: (args, ctx, r) => OpResult({'turnId': ctx.turnId}),
          extraCaps: (args) => [
            if (args.containsKey('purge')) Capability.dataDelete,
          ],
        ),
      )
      ..register(
        _FakeOp(
          _descriptor(
            'plans.commit',
            kind: OpKind.commit,
            capability: Capability.hostCommit,
            args: JsonSchema.object(const {}),
          ),
          run: (args, ctx, r) {
            ctx.emit(ProgressEvent(callId: r.callId, done: 1, total: 2));
            ctx.emit(ProgressEvent(callId: r.callId, done: 2, total: 2));
            return const OpResult({'applied': 2});
          },
        ),
      )
      ..register(
        _FakeOp(
          _descriptor(
            'plans.seal',
            kind: OpKind.plan,
            capability: null,
            exemption: 'own turn',
          ),
        ),
      );
    registerProtocolOps(ops);
    harness = Harness(ops);
  });

  HarnessError errorOf(HarnessResponse response) =>
      (response as HarnessFailure).error;

  group('Harness.call', () {
    test('runs the op and reports meta', () async {
      ops.register(
        _FakeOp(
          _descriptor('cards.page'),
          run: (args, ctx, r) =>
              const OpResult({'rows': []}, generation: 41, truncated: true),
        ),
      );
      final response = await harness.call(_req('cards.page'), _ctx());
      expect(response, isA<HarnessOk>());
      final ok = response as HarnessOk;
      expect(ok.result, {'rows': <Object?>[]});
      expect(ok.meta.generation, 41);
      expect(ok.meta.truncated, isTrue);
      expect(ok.meta.ms, greaterThanOrEqualTo(0));
    });

    test('a request for another major version is unsupported', () async {
      final response = await harness.call(
        const HarnessRequest(
          v: 1,
          op: 'cards.query',
          args: {'collection': 'Orders'},
          callId: 'c',
        ),
        _ctx(),
      );
      expect(errorOf(response).code, ErrorCode.unsupportedVersion);
    });

    test('an unknown op lists the ops of its namespace', () async {
      final error = errorOf(await harness.call(_req('cards.serch'), _ctx()));
      expect(error.code, ErrorCode.unknownOp);
      expect(error.candidates, ['cards.create', 'cards.query']);
      expect(
        errorOf(await harness.call(_req('nothing'), _ctx())).candidates,
        isNull,
      );
    });

    group('actor check', () {
      test('an agent calling a commit op is not permitted', () async {
        final error = errorOf(
          await harness.call(_req('plans.commit', const {}), _ctx()),
        );
        expect(error.code, ErrorCode.notPermitted);
        expect(error.message, contains('agent:assistant'));
      });

      test('a plugin calling a commit op is not permitted', () async {
        final error = errorOf(
          await harness.call(
            _req('plans.commit', const {}),
            _ctx(actor: const Actor.plugin('p1')),
          ),
        );
        expect(error.code, ErrorCode.notPermitted);
      });

      test('the actor check runs before the args are looked at', () async {
        final error = errorOf(
          await harness.call(_req('plans.commit', const {'bogus': 1}), _ctx()),
        );
        expect(error.code, ErrorCode.notPermitted);
      });

      test('the user commits and progress events reach the sink', () async {
        final events = StreamController<HarnessEvent>();
        final received = events.stream.toList();
        final response = await harness.call(
          _req('plans.commit', const {}),
          _ctx(actor: const Actor.user('u1'), events: events.sink),
        );
        await events.close();
        expect(response, isA<HarnessOk>());
        expect(
          [for (final e in await received) e.toJson()],
          [
            {'event': 'progress', 'callId': 'r1.1', 'done': 1, 'total': 2},
            {'event': 'progress', 'callId': 'r1.1', 'done': 2, 'total': 2},
          ],
        );
      });

      test('a user without host:commit cannot commit', () async {
        final error = errorOf(
          await harness.call(
            _req('plans.commit', const {}),
            _ctx(
              actor: const Actor.user('u1'),
              grants: Grants(
                Capability.values.where((c) => c != Capability.hostCommit),
              ),
            ),
          ),
        );
        expect(error.code, ErrorCode.notPermitted);
        expect(error.message, contains('host:commit'));
      });
    });

    group('turns', () {
      test('a minted turn reaches the op for its actor', () async {
        final turnId = harness.openTurn(Actor.assistant);
        final response = await harness.call(
          _req('cards.create', const {'collection': 'Orders'}, turnId),
          _ctx(),
        );
        expect((response as HarnessOk).result['turnId'], turnId);
      });

      test('a turn on the context counts too', () async {
        final turnId = harness.openTurn(Actor.assistant);
        final response = await harness.call(
          _req('cards.create'),
          _ctx(turnId: turnId),
        );
        expect((response as HarnessOk).result['turnId'], turnId);
      });

      test('another actor presenting the turn is not permitted', () async {
        final turnId = harness.openTurn(Actor.assistant);
        final error = errorOf(
          await harness.call(
            _req('cards.create', const {'collection': 'Orders'}, turnId),
            _ctx(actor: const Actor.plugin('p1')),
          ),
        );
        expect(error.code, ErrorCode.notPermitted);
        expect(error.path, 'turnId');
      });

      test('an unknown, closed or reset turn is not permitted', () async {
        Future<ErrorCode?> codeFor(String turnId) async {
          final response = await harness.call(
            _req('cards.create', const {'collection': 'Orders'}, turnId),
            _ctx(),
          );
          return response is HarnessFailure ? response.error.code : null;
        }

        expect(await codeFor('t_forged'), ErrorCode.notPermitted);
        final closed = harness.openTurn(Actor.assistant);
        harness.closeTurn(closed);
        expect(await codeFor(closed), ErrorCode.notPermitted);
        final reset = harness.openTurn(Actor.assistant);
        expect(await codeFor(reset), isNull);
        harness.reset();
        expect(await codeFor(reset), ErrorCode.notPermitted);
      });

      test(
        'a request turn that differs from the context turn is refused',
        () async {
          final mine = harness.openTurn(Actor.assistant);
          final other = harness.openTurn(Actor.assistant);
          final error = errorOf(
            await harness.call(
              _req('cards.create', const {'collection': 'Orders'}, other),
              _ctx(turnId: mine),
            ),
          );
          expect(error.code, ErrorCode.notPermitted);
        },
      );

      test('turn ids are opaque and unique', () {
        final ids = {
          for (var i = 0; i < 200; i++) harness.openTurn(Actor.assistant),
        };
        expect(ids, hasLength(200));
        expect(ids.every(RegExp(r'^t_[0-9a-f]{16}$').hasMatch), isTrue);
        expect(harness.ownsTurn(Actor.assistant, ids.first), isTrue);
        expect(harness.ownsTurn(const Actor.user('u1'), ids.first), isFalse);
      });
    });

    group('capabilities', () {
      test(
        'a missing capability is not permitted, named in the message',
        () async {
          final error = errorOf(
            await harness.call(
              _req('cards.create'),
              _ctx(grants: Grants([Capability.dataRead])),
            ),
          );
          expect(error.code, ErrorCode.notPermitted);
          expect(error.message, contains('data:write'));
        },
      );

      test('an argument can require an extra capability', () async {
        final grants = Grants([Capability.dataWrite]);
        expect(
          await harness.call(_req('cards.create'), _ctx(grants: grants)),
          isA<HarnessOk>(),
        );
        final error = errorOf(
          await harness.call(
            _req('cards.create', const {'collection': 'Orders', 'purge': true}),
            _ctx(grants: grants),
          ),
        );
        expect(error.code, ErrorCode.notPermitted);
        expect(error.message, contains('data:delete'));
      });

      test('capabilities are checked before the args schema', () async {
        final error = errorOf(
          await harness.call(
            _req('cards.create', const {'limit': 'x'}),
            _ctx(grants: Grants(const [])),
          ),
        );
        expect(error.code, ErrorCode.notPermitted);
      });

      test('an exempt op needs no capability', () async {
        expect(
          await harness.call(
            _req('plans.seal'),
            _ctx(grants: Grants(const [])),
          ),
          isA<HarnessOk>(),
        );
      });
    });

    test('bad args fail invalid_args with every problem in details', () async {
      final error = errorOf(
        await harness.call(
          _req('cards.query', const {'limit': 500, 'colection': 'Orders'}),
          _ctx(),
        ),
      );
      expect(error.code, ErrorCode.invalidArgs);
      expect(error.details, hasLength(3));
      expect(
        error.details!.map((d) => d.path),
        containsAll(['collection', 'limit', 'colection']),
      );
      expect(error.hint, contains('cards.query'));
    });

    test('a HarnessException from decode becomes the error', () async {
      ops.register(
        _FakeOp(
          _descriptor('collections.get', capability: Capability.schemaRead),
          decoder: (args, ctx) => throw HarnessException.of(
            ErrorCode.unknownCollection,
            'No collection "Ordrs".',
            path: 'collection',
            candidates: const ['Orders'],
          ),
        ),
      );
      final error = errorOf(
        await harness.call(
          _req('collections.get', const {'collection': 'Ordrs'}),
          _ctx(),
        ),
      );
      expect(error.code, ErrorCode.unknownCollection);
      expect(error.candidates, ['Orders']);
    });

    test('never throws: an unexpected error becomes internal', () async {
      ops.register(
        _FakeOp(
          _descriptor('cards.get'),
          run: (args, ctx, r) => throw StateError('boom'),
        ),
      );
      final error = errorOf(await harness.call(_req('cards.get'), _ctx()));
      expect(error.code, ErrorCode.internal);
      expect(error.message, contains('boom'));
      expect(error.retryable, isFalse);
    });

    test('a non-JSON result is caught as internal', () async {
      ops.register(
        _FakeOp(
          _descriptor('cards.find'),
          run: (args, ctx, r) => OpResult({'at': DateTime(2026)}),
        ),
      );
      expect(
        errorOf(await harness.call(_req('cards.find'), _ctx())).code,
        ErrorCode.internal,
      );
    });

    test('the context carries the injected day, never the clock', () {
      final ctx = HarnessContext(
        workspaceId: 'w1',
        actor: Actor.assistant,
        grants: Grants.all(),
        now: DateTime(2026, 3, 1, 23, 59),
        today: DateTime(2026, 2, 28, 18, 45),
      );
      expect(ctx.today, DateTime(2026, 2, 28));
      expect(ctx.withTurn('t_1').today, DateTime(2026, 2, 28));
    });
  });

  group('harness.describe', () {
    late Map<String, Object?> result;

    setUp(() async {
      final response = await harness.call(
        const HarnessRequest(op: 'harness.describe', callId: 'h.1'),
        _ctx(),
      );
      result = (response as HarnessOk).result;
    });

    test('reports the version, codes, capabilities and events', () {
      expect(result['apiVersion'], '2.0');
      expect(result['errorCodes'], hasLength(ErrorCode.values.length));
      expect(
        result['errorCodes'],
        containsAll(['count_mismatch', 'no_change']),
      );
      expect(
        result['capabilities'],
        containsAll([
          'modules:read',
          'modules:write',
          'automations:write',
          'host:commit',
        ]),
      );
      expect(result['events'], ['progress']);
    });

    test('lists every op sorted by id, itself not model-visible', () {
      final listed = result['ops']! as List;
      expect(
        [for (final op in listed) (op as Map)['id']],
        [
          'cards.create',
          'cards.query',
          'harness.describe',
          'plans.commit',
          'plans.seal',
        ],
      );
      final describe = listed.cast<Map>().firstWhere(
        (op) => op['id'] == 'harness.describe',
      );
      expect(describe['modelVisible'], isFalse);
      expect(describe['capability'], 'schema:read');
      final seal = listed.cast<Map>().firstWhere(
        (op) => op['id'] == 'plans.seal',
      );
      expect(seal['capability'], isNull);
      expect(seal['exempt'], 'own turn');
    });

    test('its result matches its own result schema', () {
      final schema = ops.lookup('harness.describe')!.descriptor.resultSchema;
      expect(JsonSchema.validate(schema, result), isEmpty);
    });

    test('rejects args', () async {
      final response = await harness.call(
        const HarnessRequest(
          op: 'harness.describe',
          args: {'verbose': true},
          callId: 'h.1',
        ),
        _ctx(),
      );
      expect(errorOf(response).code, ErrorCode.invalidArgs);
      expect(errorOf(response).message, contains('takes no arguments'));
      expect(errorOf(response).candidates, isNull);
    });
  });

  group('OperationRegistry', () {
    test('every op name is a valid Gemini function name', () {
      for (final id in ops.ids) {
        expect(
          OperationRegistry.toolName(id),
          matches(OperationRegistry.toolNamePattern),
        );
      }
      expect(
        OperationRegistry.toolName('plans.retryFailed'),
        'plans_retryFailed',
      );
    });

    test('descriptors are sorted and match lookups', () {
      final descriptors = harness.descriptors;
      expect([for (final d in descriptors) d.id], ops.ids);
      for (final d in descriptors) {
        expect(ops.lookup(d.id)!.descriptor, same(d));
      }
    });

    test('refuses a malformed descriptor', () {
      void expectRefused(OperationDescriptor d) => expect(
        () => OperationRegistry().register(_FakeOp(d)),
        throwsArgumentError,
        reason: d.id,
      );

      expectRefused(_descriptor('Cards.query'));
      expectRefused(_descriptor('query'));
      expectRefused(_descriptor('cards.query_all'));
      expectRefused(_descriptor('cards.${'x' * 60}'));
      expectRefused(_descriptor('cards.next', since: '2.1'));
      expectRefused(_descriptor('cards.next', since: '3.0'));
      expectRefused(_descriptor('cards.next', since: 'soon'));
      expectRefused(_descriptor('cards.next', args: JsonSchema.string()));
      expectRefused(
        _descriptor('cards.next', args: {'type': 'object', r'$defs': {}}),
      );
      expectRefused(_descriptor('cards.next', result: {'type': 'array'}));
    });

    test('refuses a duplicate id', () {
      expect(
        () => ops.register(_FakeOp(_descriptor('cards.query'))),
        throwsArgumentError,
      );
    });
  });
}
