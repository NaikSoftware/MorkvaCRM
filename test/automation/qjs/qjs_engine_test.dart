// QuickJsScriptEngine specifics (the shared JS cases are in
// qjs_conformance_test.dart): the owned isolate really exits on a kill, the
// interrupt slice, the memory limit, the captured-function transport and
// abuse. Runs on the gcc-built host lib (tool/build_qjs_test_lib.sh);
// skipped unless FLUTTER_QJS_NEXT_LIBRARY is set.
@Tags(['qjs'])
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/api/automation/engine/quickjs/quickjs_script_engine.dart';
import 'package:morkva_crm/core/automation/engine/protocol.dart';
import 'package:morkva_crm/core/automation/engine/script_engine.dart';
import 'package:morkva_crm/core/automation/engine/sdk_core.dart';

final _engine = QuickJsScriptEngine();

Future<QuickJsSession> _start(
  String code, {
  String sdkCore = kSdkCoreJs,
  Duration budget = const Duration(seconds: 5),
  int memoryLimitBytes = kScriptMemoryLimitBytes,
}) async =>
    await _engine.start(
          ScriptLoad(
            moduleId: 'qjs',
            code: code,
            sdkCore: sdkCore,
            memoryLimitBytes: memoryLimitBytes,
            budget: budget,
          ),
        )
        as QuickJsSession;

Future<ScriptFailure> _failure(Future<Object?> f) async {
  try {
    await f;
  } on ScriptFailure catch (e) {
    return e;
  }
  fail('expected a ScriptFailure');
}

/// Invokes `run`, kills the session `timeout` at [budget] like the runner,
/// and measures until the worker isolate has exited.
Future<({ScriptFailure failure, Duration exitedAfter})> _killRun(
  String code, {
  Duration budget = const Duration(seconds: 1),
}) async {
  final session = await _start(code, budget: budget);
  await session.ready;
  final sw = Stopwatch()..start();
  final timer = Timer(budget, () => session.kill('timeout'));
  final failure = await _failure(session.invoke('run', null, const {}));
  await session.exited.timeout(budget + const Duration(seconds: 3));
  timer.cancel();
  return (failure: failure, exitedAfter: sw.elapsed);
}

/// A minimal SDK core for transport tests: `ready` with one action, and
/// every `invoke` handed to [onInvoke] (JS, with `send` and `m` in scope).
String _core(String onInvoke) =>
    '''
(function (send, timer) {
  return function (f) {
    var m = JSON.parse(f);
    if (m.t === 'loaded') send('{"t":"ready","actions":["run"]}');
    if (m.t === 'invoke') { $onInvoke }
  };
})''';

void main() {
  final lib = Platform.environment['FLUTTER_QJS_NEXT_LIBRARY'] ?? '';
  final skip = lib.isEmpty
      ? 'FLUTTER_QJS_NEXT_LIBRARY is unset (build it: tool/build_qjs_test_lib.sh)'
      : null;
  // ignore: avoid_print
  if (skip != null) print('QuickJS engine tests skipped: $skip');

  group('QuickJsScriptEngine', skip: skip, () {
    test('the native library loads: status is available', () async {
      expect(await _engine.status(), EngineStatus.available);
    });

    test('a finished run frees its runtime and exits without a forced '
        'kill', () async {
      final session = await _start("morkva.action('run', () => 1);");
      await session.ready;
      expect(await session.invoke('run', null, const {}), 1);
      final sw = Stopwatch()..start();
      session.kill('finished');
      await session.exited.timeout(const Duration(seconds: 2));
      // The forced kill comes after a 500 ms grace.
      expect(sw.elapsedMilliseconds, lessThan(400));
    });

    group('kills land within budget + 1 s', () {
      test('a sync loop in an action', () async {
        final r = await _killRun(
          "morkva.action('run', () => { while (true) {} });",
        );
        expect(r.failure.code, anyOf('timeout', 'limit_exceeded'));
        expect(r.exitedAfter, lessThan(const Duration(seconds: 2)));
      });

      test('a sync loop after an await', () async {
        final r = await _killRun(
          "morkva.action('run', async () => { await 0; while (true) {} });",
        );
        expect(r.failure.code, anyOf('timeout', 'limit_exceeded'));
        expect(r.exitedAfter, lessThan(const Duration(seconds: 2)));
      });

      test('an await loop', () async {
        final r = await _killRun(
          "morkva.action('run', async () => { for (;;) await 0; });",
        );
        expect(r.failure.code, 'timeout');
        expect(r.exitedAfter, lessThan(const Duration(seconds: 2)));
      });

      test('a chain of slow jobs (the stop is read between jobs)', () async {
        final r = await _killRun('''
          morkva.action('run', async () => {
            for (;;) {
              const t = Date.now();
              while (Date.now() - t < 700) {}
              await 0;
            }
          });
        ''');
        expect(r.failure.code, 'timeout');
        expect(r.exitedAfter, lessThan(const Duration(seconds: 2)));
      });

      test('an endless promise chain', () async {
        final r = await _killRun('''
          morkva.action('run', () => {
            const spin = () => Promise.resolve().then(spin);
            spin();
            return new Promise(() => {});
          });
        ''');
        expect(r.failure.code, 'timeout');
        expect(r.exitedAfter, lessThan(const Duration(seconds: 2)));
      });

      test('a sync loop at the top level fails ready', () async {
        final sw = Stopwatch()..start();
        final session = await _start('while (true) {}');
        final failure = await _failure(session.ready);
        expect(failure.code, 'limit_exceeded');
        await session.exited.timeout(const Duration(seconds: 3));
        expect(sw.elapsed, lessThan(const Duration(seconds: 2)));
      });
    });

    group('the 1 s slice', () {
      test('a sync stretch over 1 s fails limit_exceeded long before the '
          'budget', () async {
        final session = await _start(
          "morkva.action('run', () => { while (true) {} });",
          budget: const Duration(seconds: 20),
        );
        await session.ready;
        final sw = Stopwatch()..start();
        final failure = await _failure(session.invoke('run', null, const {}));
        expect(failure.code, 'limit_exceeded');
        expect(failure.message, 'Busy for more than 1 s without awaiting');
        expect(sw.elapsed, lessThan(const Duration(seconds: 3)));
        await session.exited.timeout(const Duration(seconds: 2));
      });

      // An async function turns the interrupt into its own rejection, and a
      // module may try to catch it or loop on in `finally`: none of these
      // may outlive the slice.
      for (final (name, body) in [
        ('after an await', 'async () => { await 0; while (true) {} }'),
        (
          'caught in a loop',
          '() => { for (;;) { try { while (true) {} } catch (e) {} } }',
        ),
        (
          'caught in a loop after an await',
          'async () => { await 0; for (;;) { try { while (true) {} } '
              'catch (e) {} } }',
        ),
        (
          'looping in finally',
          'async () => { await 0; try { while (true) {} } '
              'finally { for (;;) {} } }',
        ),
      ]) {
        test('$name too', () async {
          final session = await _start(
            "morkva.action('run', $body);",
            budget: const Duration(seconds: 20),
          );
          await session.ready;
          final sw = Stopwatch()..start();
          final failure = await _failure(session.invoke('run', null, const {}));
          expect(failure.code, 'limit_exceeded');
          expect(sw.elapsed, lessThan(const Duration(seconds: 3)));
          await session.exited.timeout(const Duration(seconds: 2));
        });
      }

      test('each await starts a new slice', () async {
        final session = await _start('''
          morkva.action('run', async () => {
            for (let i = 0; i < 3; i++) {
              const t = Date.now();
              while (Date.now() - t < 600) {}
              await morkva.call('echo');
            }
            return 'done';
          });
        ''', budget: const Duration(seconds: 20));
        session.messages.listen((m) {
          if (m is CallFrame) session.reply(m.id, value: null);
        });
        await session.ready;
        expect(await session.invoke('run', null, const {}), 'done');
        session.kill('finished');
      });
    });

    test('the memory limit stops an allocating action and the session '
        'still dies', () async {
      final session = await _start('''
        morkva.action('run', () => {
          const keep = [];
          for (;;) keep.push('x'.repeat(100000) + keep.length);
        });
      ''', memoryLimitBytes: 8 * 1024 * 1024);
      await session.ready;
      final failure = await _failure(session.invoke('run', null, const {}));
      expect(failure.code, 'module_error');
      expect(failure.message, contains('out of memory'));
      session.kill('finished');
      await session.exited.timeout(const Duration(seconds: 2));
    });

    test('a thrown error names the module in its stack', () async {
      final session = await _start('''
        function boom() { throw new Error('deep'); }
        morkva.action('run', () => boom());
      ''');
      await session.ready;
      final failure = await _failure(session.invoke('run', null, const {}));
      expect(failure.message, 'deep');
      expect(failure.stack, contains('morkva-module/qjs.js'));
      session.kill('finished');
    });

    test('timers are clamped to the run budget', () async {
      final session = await _start('''
        morkva.action('run', () => new Promise((r) => setTimeout(() => r('fired'), 30000)));
      ''', budget: const Duration(milliseconds: 300));
      await session.ready;
      final sw = Stopwatch()..start();
      expect(await session.invoke('run', null, const {}), 'fired');
      expect(sw.elapsed, lessThan(const Duration(seconds: 2)));
      session.kill('finished');
    });

    group('transport', () {
      test('the captured send/receive pair carries string frames both '
          'ways', () async {
        final session = await _start(
          '',
          sdkCore: _core(
            "send(JSON.stringify({ t: 'done', id: m.id, ok: true, "
            'value: { action: m.action, input: m.input, ctx: m.ctx } }));',
          ),
        );
        expect(await session.ready, ['run']);
        expect(await session.invoke('run', 7, {'k': 'v'}), {
          'action': 'run',
          'input': 7,
          'ctx': {'k': 'v'},
        });
        session.kill('finished');
      });

      for (final (name, js) in [
        ('an object', "send({ t: 'done', id: m.id, ok: true });"),
        ('a number', 'send(42);'),
        ('a function', 'send(function () {});'),
        ('a string over 1 MB', "send('x'.repeat(1024 * 1024 + 1));"),
      ]) {
        test('$name sent as a frame kills the run abuse', () async {
          final session = await _start('', sdkCore: _core(js));
          await session.ready;
          final failure = await _failure(session.invoke('run', null, const {}));
          expect(failure.code, 'abuse');
          await session.exited.timeout(const Duration(seconds: 2));
        });
      }

      test('a broken SDK core is a boot error', () async {
        final session = await _start('', sdkCore: '42');
        expect((await _failure(session.ready)).code, 'boot_error');
        await session.exited.timeout(const Duration(seconds: 2));
      });

      test('a kill before the worker is up still stops it', () async {
        final session = await _start("morkva.action('run', () => 1);");
        session.kill('cancelled');
        expect((await _failure(session.ready)).code, 'cancelled');
        await session.exited.timeout(const Duration(seconds: 2));
      });
    });
  });
}
