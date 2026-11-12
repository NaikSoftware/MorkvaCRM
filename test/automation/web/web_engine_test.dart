@TestOn('browser')
library;

import 'dart:async';
import 'dart:js_interop';

import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/api/automation/engine/web/crash_marker_web.dart';
import 'package:morkva_crm/api/automation/engine/web/sandbox_sources.dart';
import 'package:morkva_crm/api/automation/engine/web/web_script_engine.dart';
import 'package:morkva_crm/core/automation/engine/protocol.dart';
import 'package:morkva_crm/core/automation/engine/script_engine.dart';
import 'package:morkva_crm/core/automation/engine/sdk_core.dart';
import 'package:web/web.dart' as web;

ScriptLoad _load(String code, {String id = 'mod', int budgetMs = 5000}) =>
    ScriptLoad(
      moduleId: id,
      code: code,
      sdkCore: kSdkCoreJs,
      memoryLimitBytes: kScriptMemoryLimitBytes,
      budget: Duration(milliseconds: budgetMs),
    );

List<web.HTMLIFrameElement> _iframes() {
  final list = web.document.querySelectorAll('iframe');
  return [
    for (var i = 0; i < list.length; i++)
      list.item(i)! as web.HTMLIFrameElement,
  ];
}

Future<ScriptFailure> _failure(Future<Object?> f) async {
  try {
    await f;
  } on ScriptFailure catch (e) {
    return e;
  }
  fail('expected a ScriptFailure');
}

/// Collects messages and answers every call with [answer].
List<ModuleMessage> _host(
  ScriptSession session, {
  Object? Function(CallFrame call)? answer,
}) {
  final seen = <ModuleMessage>[];
  session.messages.listen((m) {
    seen.add(m);
    if (m is CallFrame) session.reply(m.id, value: answer?.call(m) ?? m.args);
  });
  return seen;
}

void main() {
  final engine = WebScriptEngine();

  test('boots, registers actions and round-trips a call', () async {
    final session = await engine.start(
      _load('''
        morkva.action('count', async (input, ctx) => {
          const r = await morkva.call('cards.query', { collectionId: input.c, actor: 'user' });
          console.log('got', r.items.length);
          morkva.progress({ done: 1, total: 2, label: 'half' });
          return { count: r.items.length, runId: ctx.runId };
        });
      '''),
    );
    final seen = _host(
      session,
      answer: (_) => {
        'items': [1, 2, 3],
      },
    );
    expect(await session.ready, ['count']);
    final value = await session.invoke(
      'count',
      {'c': 'orders'},
      {'runId': 'run_1'},
    );
    expect(value, {'count': 3, 'runId': 'run_1'});
    final call = seen.whereType<CallFrame>().single;
    expect(call.op, 'cards.query');
    expect(call.args, {'collectionId': 'orders', 'actor': 'user'});
    final log = seen.whereType<LogFrame>().single;
    expect(log.level, 'log');
    expect(log.args, ['got', '3']);
    final progress = seen.whereType<ProgressFrame>().single;
    expect([progress.done, progress.total, progress.label], [1, 2, 'half']);
    session.kill('done');
  });

  test(
    'the iframe has exactly the sandbox attributes and goes on kill',
    () async {
      final before = _iframes().length;
      final session = await engine.start(_load("morkva.action('a', () => 1);"));
      await session.ready;
      final iframe = _iframes().last;
      expect(_iframes(), hasLength(before + 1));
      expect(iframe.getAttribute('sandbox'), 'allow-scripts');
      expect(iframe.hasAttribute('name'), isFalse);
      expect(iframe.getAttribute('allow'), '');
      expect(iframe.getAttribute('aria-hidden'), 'true');
      expect(iframe.style.display, 'none');
      expect(iframe.srcdoc.toString(), contains(kSandboxCsp));
      session.kill('done');
      expect(_iframes(), hasLength(before));
      expect(iframe.isConnected, isFalse);
    },
  );

  test('status is available under the sandbox CSP and cached', () async {
    final e = WebScriptEngine();
    expect(await e.status(), EngineStatus.available);
    expect(identical(e.status(), e.status()), isTrue);
  });

  test('a worker that cannot start makes the engine unavailable', () async {
    final e = WebScriptEngine(
      csp: kSandboxCsp.replaceFirst('worker-src blob:', "worker-src 'none'"),
    );
    expect(await e.status(), EngineStatus.unavailable);
    final f = await _failure(e.start(_load("morkva.action('a', () => 1);")));
    expect(f.code, 'engine_unavailable');
  });

  test('a sandbox whose CSP is not enforced is refused', () async {
    final e = WebScriptEngine(
      csp: "default-src * 'unsafe-inline' 'unsafe-eval' data: blob:",
    );
    expect(await e.status(), EngineStatus.unavailable);
  });

  test('the lockdown leaves no web-only network or worker API', () async {
    final session = await engine.start(
      _load('''
        const names = ['fetch', 'XMLHttpRequest', 'WebSocket', 'WebSocketStream',
          'EventSource', 'WebTransport', 'RTCPeerConnection', 'FontFace', 'Worker',
          'SharedWorker', 'importScripts', 'setInterval', 'clearInterval',
          'window', 'parent', 'document'];
        const seen = {};
        for (const n of names) seen[n] = typeof self[n];
        morkva.action('a', async () => ({
          seen,
          origin: self.origin,
          idb: await new Promise((r) => {
            try {
              const q = indexedDB.open('x');
              q.onsuccess = () => r('opened');
              q.onerror = () => r('denied');
            } catch (e) { r('denied'); }
          }),
        }));
      '''),
    );
    await session.ready;
    final r = await session.invoke('a', null, {}) as Map;
    expect((r['seen'] as Map).values.toSet(), {'undefined'});
    expect(r['origin'], 'null');
    expect(r['idb'], 'denied');
    session.kill('done');
  });

  test(
    'a busy loop is killed by the run timer while the host keeps ticking',
    () async {
      final session = await engine.start(
        _load("morkva.action('spin', () => { while (true) {} });"),
      );
      await session.ready;
      final sw = Stopwatch()..start();
      var last = 0, maxGap = 0;
      final ticker = Timer.periodic(const Duration(milliseconds: 10), (_) {
        final now = sw.elapsedMilliseconds;
        if (now - last > maxGap) maxGap = now - last;
        last = now;
      });
      final killer = Timer(
        const Duration(milliseconds: 800),
        () => session.kill('timeout'),
      );
      final f = await _failure(session.invoke('spin', null, {}));
      ticker.cancel();
      killer.cancel();
      expect(f.code, 'timeout');
      expect(sw.elapsedMilliseconds, lessThan(1800));
      expect(maxGap, lessThan(200));
      expect(_failure(session.invoke('spin', null, {})), completes);
    },
  );

  test('a syntax error or a top-level throw is a load_error', () async {
    final syntax = await engine.start(_load("morkva.action('x', () => {"));
    expect((await _failure(syntax.ready)).code, 'load_error');
    final thrown = await engine.start(_load("throw new TypeError('nope');"));
    final f = await _failure(thrown.ready);
    expect(f.code, 'load_error');
    expect(f.message, contains('nope'));
  });

  test('a module stack names morkva-module/<id>.js', () async {
    final session = await engine.start(
      _load(
        "morkva.action('boom', () => { throw new Error('boom'); });",
        id: 'stack_mod',
      ),
    );
    await session.ready;
    final f = await _failure(session.invoke('boom', null, {}));
    expect(f.code, 'module_error');
    expect(f.message, 'boom');
    expect(f.stack, contains('morkva-module/stack_mod.js'));
  });

  test(
    'a forged handshake from another frame is ignored; the real one boots',
    () async {
      // The evil frame keeps posting both handshake messages and reports any
      // port it is handed. A missing source check would boot the wrong frame or
      // kill the real session with boot_error.
      final evilPorts = <int>[];
      final onEvil = ((web.MessageEvent e) {
        final d = e.data;
        if (d != null && d.isA<JSString>()) {
          final s = (d as JSString).toDart;
          if (s.startsWith('evil:')) evilPorts.add(int.parse(s.substring(5)));
        }
      }).toJS;
      web.window.addEventListener('message', onEvil);
      final evil = web.document.createElement('iframe') as web.HTMLIFrameElement
        ..setAttribute('sandbox', 'allow-scripts')
        ..srcdoc =
            '''<script>
        addEventListener('message', (e) => parent.postMessage('evil:' + e.ports.length, '*'));
        setInterval(() => {
          parent.postMessage({ t: 'morkva-sandbox-ready' }, '*');
          parent.postMessage({ t: 'morkva-sandbox-error', message: 'forged' }, '*');
        }, 1);
      </script>'''
                .toJS;
      web.document.body!.append(evil);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      try {
        final session = await engine.start(
          _load("morkva.action('p', () => 'pong');"),
        );
        expect(await session.ready, ['p']);
        expect(await session.invoke('p', null, {}), 'pong');
        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(evilPorts, isEmpty);
        session.kill('done');
      } finally {
        web.window.removeEventListener('message', onEvil);
        evil.remove();
      }
    },
  );

  group('errors after ready', () {
    const lateThrow = '''
      morkva.action('a', () => new Promise(() => {
        const ch = new MessageChannel();
        ch.port1.onmessage = () => { throw new Error('late boom'); };
        ch.port2.postMessage(0);
      }));
    ''';

    test('an uncaught error fails the running action module_error', () async {
      final session = await engine.start(_load(lateThrow));
      final seen = _host(session);
      await session.ready;
      final f = await _failure(session.invoke('a', null, {}));
      expect(f.code, 'module_error');
      expect(f.message, contains('late boom'));
      final log = seen.whereType<LogFrame>().single;
      expect(log.level, 'error');
      expect(log.args.single, contains('Uncaught'));
    });

    test(
      'a sandbox error past the shim is module_error, not boot_error',
      () async {
        final bare = WebScriptEngine(
          shim: kShimJs.replaceAll(
            RegExp(r'/\*uncaught\{\*/[\s\S]*/\*\}uncaught\*/'),
            '',
          ),
        );
        expect(bare.shim, isNot(contains('unhandledrejection')));
        final session = await bare.start(_load(lateThrow));
        final seen = _host(session);
        await session.ready;
        final f = await _failure(session.invoke('a', null, {}));
        expect(f.code, 'module_error');
        expect(f.message, contains('late boom'));
        expect(
          seen.whereType<LogFrame>().single.args.single,
          contains('Uncaught'),
        );
      },
    );

    test('an unhandled rejection is only logged', () async {
      final session = await engine.start(
        _load('''
          morkva.action('a', async () => {
            Promise.reject(new Error('ignored'));
            await new Promise((r) => setTimeout(r, 50));
            return 'ok';
          });
        '''),
      );
      final seen = _host(session);
      await session.ready;
      expect(await session.invoke('a', null, {}), 'ok');
      expect(
        seen.whereType<LogFrame>().single.args.single,
        contains('ignored'),
      );
      session.kill('done');
    });
  });

  test('patched event accessors do not hand the module the port', () async {
    final session = await engine.start(
      _load('''
        let leaked = 'none';
        const grab = (ev) => { if (ev && ev.target) leaked = String(ev.target); };
        const d = Object.getOwnPropertyDescriptor(MessageEvent.prototype, 'data');
        Object.defineProperty(MessageEvent.prototype, 'data', {
          get() { grab(this); return d.get.call(this); }, configurable: true,
        });
        MessagePort.prototype.postMessage = function () { leaked = 'postMessage'; };
        Event.prototype.preventDefault = function () { leaked = 'preventDefault'; };
        morkva.action('a', async () => {
          const r = await morkva.call('echo', { v: 1 });
          console.log('after');
          return { r, leaked };
        });
      '''),
    );
    final seen = _host(session);
    await session.ready;
    expect(await session.invoke('a', null, {}), {
      'r': {'v': 1},
      'leaked': 'none',
    });
    expect(seen.whereType<LogFrame>().single.args, ['after']);
    session.kill('done');
  });

  test('a non-string frame kills the session abuse', () async {
    final rogue = WebScriptEngine(
      shim:
          "self.onmessage = (e) => e.ports[0].postMessage({ t: 'ready', actions: [] });",
    );
    final session = await rogue.start(_load(''));
    expect((await _failure(session.ready)).code, 'abuse');
  });

  test('a second iframe load kills the session', () async {
    final session = await engine.start(
      _load("morkva.action('a', () => new Promise(() => {}));"),
    );
    await session.ready;
    final pending = session.invoke('a', null, {});
    _iframes().last.srcdoc = '<p>elsewhere</p>'.toJS;
    expect((await _failure(pending)).code, 'sandbox_navigated');
  });

  test('crash marker survives in localStorage until cleared', () {
    final marker = WebCrashMarker()..clear();
    expect(marker.leftover(), isNull);
    marker.set('run_1', 'a_1');
    expect(WebCrashMarker().leftover(), (runId: 'run_1', automationId: 'a_1'));
    web.window.localStorage.setItem(WebCrashMarker.key, '{bad');
    expect(marker.leftover(), isNull);
    marker.clear();
    expect(marker.leftover(), isNull);
  });
}
