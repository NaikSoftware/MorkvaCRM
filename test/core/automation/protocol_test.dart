import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/automation/engine/protocol.dart';
import 'package:morkva_crm/core/automation/engine/script_engine.dart';

import '../../automation/fakes/fake_script_engine.dart';

final _violation = throwsA(isA<ProtocolViolation>());

String _nested(int depth) => jsonEncode({
  't': 'log',
  'level': 'info',
  'args': <String>[],
  'x': 0,
}).replaceFirst('0', '${'[' * (depth - 1)}${']' * (depth - 1)}');

ScriptLoad _load() => const ScriptLoad(
  moduleId: 'stamp',
  code: '',
  sdkCore: '',
  memoryLimitBytes: kScriptMemoryLimitBytes,
  budget: Duration(seconds: 20),
);

void main() {
  group('decodeFrame', () {
    test('a non-string frame is a violation', () {
      for (final raw in <Object?>[
        null,
        42,
        {'t': 'log', 'level': 'info', 'args': <String>[]},
        ['ready'],
      ]) {
        expect(() => decodeFrame(raw), _violation, reason: '$raw');
      }
    });

    test('size is capped at $kMaxFrameChars chars, before decoding', () {
      final head = '{"t":"log","level":"info","args":["';
      const tail = '"]}';
      final fits =
          '$head${'a' * (kMaxFrameChars - head.length - tail.length)}$tail';
      expect(fits.length, kMaxFrameChars);
      expect(decodeFrame(fits), isA<LogFrame>());
      // Not even JSON: rejected for its size, not its syntax.
      expect(
        () => decodeFrame('x' * (kMaxFrameChars + 1)),
        throwsA(
          isA<ProtocolViolation>().having(
            (e) => e.message,
            'message',
            contains('large'),
          ),
        ),
      );
    });

    test('nesting is capped at depth 64; brackets in strings do not count', () {
      expect(_nested(64), contains('[' * 63));
      expect(decodeFrame(_nested(64)), isA<LogFrame>());
      expect(() => decodeFrame(_nested(65)), _violation);
      final quoted = jsonEncode({
        't': 'log',
        'level': 'info',
        'args': ['[' * 100, r'\"{{{{', '{' * 100],
      });
      expect((decodeFrame(quoted) as LogFrame).args.first, '[' * 100);
    });

    test('a frame of nothing but brackets does not overflow the stack', () {
      expect(() => decodeFrame('[' * kMaxFrameChars), _violation);
    });

    test(
      'malformed JSON, non-maps and unknown or host types are violations',
      () {
        for (final raw in [
          '{"t":"log"',
          '[]',
          '"ready"',
          '{}',
          '{"t":"teapot"}',
          '{"t":"invoke","id":1,"action":"a","input":null,"ctx":{}}',
          '{"t":"result","id":1,"ok":true,"value":1}',
        ]) {
          expect(() => decodeFrame(raw), _violation, reason: raw);
        }
      },
    );

    test('numeric ids are read as num', () {
      final call = decodeFrame(
        '{"t":"call","id":3.0,"op":"cards.get","args":{"id":"c1"}}',
      );
      expect(call, isA<CallFrame>());
      call as CallFrame;
      expect(call.id, 3);
      expect(call.op, 'cards.get');
      expect(call.args, {'id': 'c1'});

      final done = decodeFrame(
        '{"t":"done","id":7.0,"ok":true,"value":"Stamped"}',
      );
      expect(done, isA<DoneFrame>().having((d) => d.id, 'id', 7));
      expect((done as DoneFrame).value, 'Stamped');
      expect(done.ok, isTrue);
    });

    test('a call with a bad op or args is delivered for invalid_args', () {
      for (final raw in [
        '{"t":"call","id":1,"op":5,"args":null}',
        '{"t":"call","id":1,"op":"","args":null}',
        '{"t":"call","id":1,"op":"cards.get","args":[1]}',
      ]) {
        expect(
          decodeFrame(raw),
          isA<InvalidCallFrame>().having((f) => f.id, 'id', 1),
          reason: raw,
        );
      }
      for (final id in ['1.5', '"1"', 'null', '1e400']) {
        expect(
          decodeFrame('{"t":"call","id":$id,"op":"cards.get"}'),
          isA<InvalidCallFrame>().having((f) => f.id, 'id', isNull),
          reason: id,
        );
      }
      expect(
        decodeFrame('{"t":"call","id":2,"op":"cards.get"}'),
        isA<CallFrame>().having((f) => f.args, 'args', isNull),
      );
    });

    test('done with an error carries a module_error and the stack', () {
      final done =
          decodeFrame(
                jsonEncode({
                  't': 'done',
                  'id': 1,
                  'ok': false,
                  'error': {
                    'code': 'x',
                    'message': 'boom',
                    'stack': 'at morkva-module/stamp.js:3',
                  },
                }),
              )
              as DoneFrame;
      expect(done.ok, isFalse);
      expect(done.error!.code, 'module_error');
      expect(done.error!.message, 'boom');
      expect(done.error!.stack, contains('morkva-module/stamp.js'));
      expect(() => decodeFrame('{"t":"done","id":1,"ok":"yes"}'), _violation);
      expect(() => decodeFrame('{"t":"done","id":1.5,"ok":true}'), _violation);
    });

    test('ready, loadError, log and progress', () {
      expect(
        decodeFrame('{"t":"ready","actions":["stamp","flag"]}'),
        isA<ReadyFrame>().having((f) => f.actions, 'actions', [
          'stamp',
          'flag',
        ]),
      );
      expect(
        decodeFrame('{"t":"loadError","error":{"message":"SyntaxError"}}'),
        isA<LoadErrorFrame>()
            .having((f) => f.error.code, 'code', 'load_error')
            .having((f) => f.error.message, 'message', 'SyntaxError'),
      );
      expect(
        decodeFrame('{"t":"log","level":"warn","args":["a","b"]}'),
        isA<LogFrame>().having((f) => f.level, 'level', 'warn').having(
          (f) => f.args,
          'args',
          ['a', 'b'],
        ),
      );
      expect(
        decodeFrame('{"t":"progress","done":2,"total":5,"label":"Orders"}'),
        isA<ProgressFrame>()
            .having((f) => f.done, 'done', 2)
            .having((f) => f.label, 'label', 'Orders'),
      );
      for (final raw in [
        '{"t":"ready","actions":[1]}',
        '{"t":"loadError","error":"x"}',
        '{"t":"log","level":"trace","args":[]}',
        '{"t":"log","level":"info","args":[{}]}',
        '{"t":"progress","done":"1","total":2}',
      ]) {
        expect(() => decodeFrame(raw), _violation, reason: raw);
      }
    });
  });

  group('host encoders', () {
    test('invoke, result and timer frames', () {
      expect(
        jsonDecode(encodeInvoke(1, 'stamp', {'f': 1}, {'runId': 'run_1'})),
        {
          't': 'invoke',
          'id': 1,
          'action': 'stamp',
          'input': {'f': 1},
          'ctx': {'runId': 'run_1'},
        },
      );
      expect(jsonDecode(encodeResult(2, value: [1])), {
        't': 'result',
        'id': 2,
        'ok': true,
        'value': [1],
      });
      expect(
        jsonDecode(encodeResult(3, error: {'code': 'dead', 'message': 'x'})),
        {
          't': 'result',
          'id': 3,
          'ok': false,
          'error': {'code': 'dead', 'message': 'x'},
        },
      );
      expect(jsonDecode(encodeTimer(4)), {'t': 'timer', 'id': 4});
    });
  });

  group('FakeScriptEngine', () {
    test('boot, call → reply, log, progress and done round trip', () async {
      final engine = FakeScriptEngine(
        actions: ['stamp'],
        action: (m, inv) async {
          m.log('info', ['start ${inv.ctx['runId']}']);
          final card = await m.call('cards.get', {'id': inv.input});
          m.progress(1, 1, label: 'Done');
          try {
            await m.call('plans.commit');
          } on FakeCallError catch (e) {
            return '${(card as Map)['title']} ${e.code}';
          }
          return 'unreachable';
        },
      );
      final session = await engine.start(_load()) as FakeScriptSession;
      expect(await session.ready, ['stamp']);
      final seen = <ModuleMessage>[];
      session.messages.listen((m) {
        seen.add(m);
        if (m case CallFrame(:final id, :final op)) {
          op == 'cards.get'
              ? session.reply(id, value: {'title': '#1042'})
              : session.reply(
                  id,
                  error: {'code': 'not_permitted', 'message': 'no'},
                );
        }
      });
      final value = await session.invoke('stamp', 'c1', {'runId': 'run_1'});
      expect(value, '#1042 not_permitted');
      expect(seen.map((m) => m.runtimeType), [
        LogFrame,
        CallFrame,
        ProgressFrame,
        CallFrame,
      ]);
      expect(session.invocations.single.input, 'c1');
      expect(session.replies, hasLength(2));
      expect(engine.loads.single.moduleId, 'stamp');
    });

    test('a thrown action fails the invoke with module_error', () async {
      final engine = FakeScriptEngine(
        action: (m, inv) async => throw StateError('boom'),
      );
      final session = await engine.start(_load());
      await session.ready;
      await expectLater(
        session.invoke('run', null, {}),
        throwsA(
          isA<ScriptFailure>()
              .having((f) => f.code, 'code', 'module_error')
              .having((f) => f.message, 'message', contains('boom'))
              .having((f) => f.stack, 'stack', isNotNull),
        ),
      );
    });

    test('an abusive frame kills the session and fails the invoke', () async {
      for (final raw in <Object?>[
        {'t': 'log'},
        'x' * (kMaxFrameChars + 1),
        '${'[' * 65}${']' * 65}',
      ]) {
        final hung = Completer<Object?>();
        final engine = FakeScriptEngine(
          action: (m, inv) {
            m.send(raw);
            return hung.future;
          },
        );
        final session = await engine.start(_load()) as FakeScriptSession;
        await session.ready;
        await expectLater(
          session.invoke('run', null, {}),
          throwsA(isA<ScriptFailure>().having((f) => f.code, 'code', 'abuse')),
        );
        expect(session.killedWith, 'abuse');
        session.reply(1, value: 1); // late replies are dropped
        expect(session.replies, isEmpty);
        expect(session.repliesAfterKill.single.callId, 1);
      }
    });

    test('kill before ready, load error, boot error and unavailable', () async {
      final hanging = FakeScriptEngine(boot: (_) {});
      final s1 = await hanging.start(_load());
      s1
        ..kill('timeout')
        ..kill('cancelled');
      await expectLater(
        s1.ready,
        throwsA(isA<ScriptFailure>().having((f) => f.code, 'code', 'timeout')),
      );

      final broken = FakeScriptEngine(boot: (m) => m.loadError('SyntaxError'));
      await expectLater(
        (await broken.start(_load())).ready,
        throwsA(
          isA<ScriptFailure>().having((f) => f.code, 'code', 'load_error'),
        ),
      );

      final crashed = FakeScriptEngine(
        boot: (m) => m.sandboxError('worker died'),
      );
      await expectLater(
        (await crashed.start(_load())).ready,
        throwsA(
          isA<ScriptFailure>().having((f) => f.code, 'code', 'boot_error'),
        ),
      );

      final none = FakeScriptEngine(engineStatus: EngineStatus.unavailable);
      expect(await none.status(), EngineStatus.unavailable);
    });

    test('FakeCrashMarker keeps the breadcrumb until cleared', () {
      final marker = FakeCrashMarker()..set('run_1', 'a1');
      expect(marker.leftover(), (runId: 'run_1', automationId: 'a1'));
      marker.clear();
      expect(marker.leftover(), isNull);
    });
  });
}
