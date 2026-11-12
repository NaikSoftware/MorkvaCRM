// The engine conformance suite (spec "Testing strategy"): the same JS cases
// run on every ScriptEngine (web: web_conformance_test.dart under chrome;
// QuickJS: qjs_conformance_test.dart, tag qjs). A case may not be
// engine-specific: web-only names are guarded with `typeof`. Imports only
// core and flutter_test, so the VM suite can run it.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/automation/engine/protocol.dart';
import 'package:morkva_crm/core/automation/engine/script_engine.dart';
import 'package:morkva_crm/core/automation/engine/sdk_core.dart';

final class ConformanceCase {
  const ConformanceCase(
    this.name,
    this.code,
    this.verify, {
    this.action = 'run',
    this.input,
    this.budget = const Duration(seconds: 5),
  });

  final String name;
  final String code;
  final String action;
  final Object? input;

  /// The run timer: the runner kills the session `timeout` when it expires.
  final Duration budget;
  final void Function(ConformanceResult r) verify;
}

final class ConformanceResult {
  /// Registered actions, or null when the module failed to load.
  List<String>? actions;
  ScriptFailure? loadError;
  Object? value;
  ScriptFailure? error;
  final logs = <LogFrame>[];
  final progress = <ProgressFrame>[];
  final calls = <CallFrame>[];

  /// From invoke to the action's end (value, error or kill).
  Duration elapsed = Duration.zero;

  /// `level: arg arg …` per log line.
  List<String> get lines => [
    for (final l in logs) '${l.level}: ${l.args.join(' ')}',
  ];
}

/// The `ctx` every case's action receives.
const kConformanceCtx = <String, Object?>{
  'runId': 'run_conf',
  'module': {'id': 'conf', 'version': '1.0.0'},
  'automation': null,
  'trigger': {'kind': 'test'},
  'card': null,
  'today': '2026-11-12',
  'now': '2026-11-12T10:00:00.000Z',
  'timeZone': 'UTC',
};

/// Boots [c] on [engine], invokes its action and answers its calls like a
/// scripted host: `echo` → the args, `delay` → the args after `args.ms`,
/// `fail` → a `not_permitted` error with every error field, anything else
/// → `unknown_op`.
Future<ConformanceResult> runConformanceCase(
  ScriptEngine engine,
  ConformanceCase c,
) async {
  final r = ConformanceResult();
  final session = await engine.start(
    ScriptLoad(
      moduleId: 'conf',
      code: c.code,
      sdkCore: kSdkCoreJs,
      memoryLimitBytes: kScriptMemoryLimitBytes,
      budget: c.budget,
    ),
  );
  final sub = session.messages.listen((m) {
    switch (m) {
      case CallFrame():
        r.calls.add(m);
        _answer(session, m);
      case InvalidCallFrame(:final id?):
        session.reply(id, error: {'code': 'invalid_args', 'message': m.reason});
      case InvalidCallFrame():
        break;
      case LogFrame():
        r.logs.add(m);
      case ProgressFrame():
        r.progress.add(m);
    }
  });
  try {
    r.actions = await session.ready.timeout(kBootBudget);
  } on ScriptFailure catch (e) {
    r.loadError = e;
  }
  if (r.actions != null) {
    final sw = Stopwatch()..start();
    final timer = Timer(c.budget, () => session.kill('timeout'));
    try {
      r.value = await session.invoke(c.action, c.input, kConformanceCtx);
    } on ScriptFailure catch (e) {
      r.error = e;
    }
    r.elapsed = sw.elapsed;
    timer.cancel();
  }
  // Frames sent before `done` are already queued; let them be delivered.
  await Future<void>.delayed(const Duration(milliseconds: 20));
  session.kill('finished');
  await sub.cancel();
  return r;
}

void _answer(ScriptSession session, CallFrame call) {
  final args = call.args;
  switch (call.op) {
    case 'echo':
      session.reply(call.id, value: args);
    case 'delay':
      Timer(
        Duration(milliseconds: (args?['ms'] as num? ?? 0).toInt()),
        () => session.reply(call.id, value: args),
      );
    case 'fail':
      session.reply(
        call.id,
        error: {
          'code': 'not_permitted',
          'message': 'Nope',
          'details': [
            {'k': 1},
          ],
          'path': 'args.x',
          'candidates': ['a', 'b'],
        },
      );
    default:
      session.reply(
        call.id,
        error: {'code': 'unknown_op', 'message': 'Unknown op ${call.op}'},
      );
  }
}

void _ok(ConformanceResult r, Object? value) {
  expect(r.loadError, isNull, reason: 'load error: ${r.loadError}');
  expect(r.error, isNull, reason: 'action error: ${r.error}');
  expect(r.value, value);
}

void _failed(ConformanceResult r, String code, {Pattern? message}) {
  expect(r.loadError, isNull, reason: 'load error: ${r.loadError}');
  expect(r.error, isNotNull, reason: 'expected the action to fail');
  expect(r.error!.code, code);
  if (message != null) expect(r.error!.message, contains(message));
}

/// Expected to resolve to `true` for every key: `{ name: boolean }`.
void _allTrue(ConformanceResult r) {
  _ok(r, isA<Map>());
  final failing = [
    for (final e in (r.value! as Map).entries)
      if (e.value != true) e.key,
  ];
  expect(failing, isEmpty);
}

final kConformanceCases = <ConformanceCase>[
  ConformanceCase('guaranteed globals exist', '''
    const g = {
      Object: typeof Object === 'function', Array: typeof Array === 'function',
      Map: typeof Map === 'function', Set: typeof Set === 'function',
      Promise: typeof Promise === 'function', JSON: typeof JSON === 'object',
      Math: typeof Math === 'object', Date: typeof Date === 'function',
      RegExp: typeof RegExp === 'function', globalThis: typeof globalThis === 'object',
      morkva: typeof morkva === 'object', console: typeof console === 'object',
      setTimeout: typeof setTimeout === 'function',
      clearTimeout: typeof clearTimeout === 'function',
      consoleLevels: ['log', 'info', 'warn', 'error', 'debug']
          .every((l) => typeof console[l] === 'function'),
    };
    morkva.action('run', () => g);
  ''', _allTrue),
  ConformanceCase('network, worker and transport globals are undefined', '''
    const names = ['fetch', 'XMLHttpRequest', 'WebSocket', 'EventSource',
      'importScripts', 'Worker', 'setInterval', 'sendMessage', '__morkvaTransport'];
    const g = {};
    for (const n of names) g[n] = typeof globalThis[n] === 'undefined';
    morkva.action('run', () => g);
  ''', _allTrue),
  ConformanceCase('morkva is frozen and not replaceable', '''
    const before = morkva;
    try { morkva.call = () => 'hijacked'; } catch (_) {}
    try { morkva = {}; } catch (_) {}
    try { globalThis.morkva = {}; } catch (_) {}
    try { delete globalThis.morkva; } catch (_) {}
    morkva.action('run', async () => ({
      frozen: Object.isFrozen(morkva),
      same: morkva === before,
      call: (await morkva.call('echo', { v: 1 })).v === 1,
    }));
  ''', _allTrue),
  ConformanceCase(
    'morkva.version is the SDK version',
    "morkva.action('run', () => morkva.version);",
    (r) => _ok(r, kSdkVersion),
  ),
  ConformanceCase(
    'morkva.call resolves with the op result',
    '''
    morkva.action('run', async () => morkva.call('echo', { a: 1, b: [true, null, 'x'] }));
  ''',
    (r) {
      _ok(r, {
        'a': 1,
        'b': [true, null, 'x'],
      });
      expect(r.calls.single.op, 'echo');
    },
  ),
  ConformanceCase(
    'morkva.call rejects with a MorkvaError carrying the code',
    '''
    morkva.action('run', async () => {
      try {
        await morkva.call('fail', {});
        return 'resolved';
      } catch (e) {
        return { isError: e instanceof Error, name: e.name, code: e.code,
          message: e.message, details: e.details, path: e.path,
          candidates: e.candidates };
      }
    });
  ''',
    (r) {
      _ok(r, {
        'isError': true,
        'name': 'MorkvaError',
        'code': 'not_permitted',
        'message': 'Nope',
        'details': [
          {'k': 1},
        ],
        'path': 'args.x',
        'candidates': ['a', 'b'],
      });
    },
  ),
  ConformanceCase(
    'morkva.call without args sends null args',
    '''
    morkva.action('run', async () => {
      await morkva.call('echo');
      await morkva.call('echo', null);
      return 'ok';
    });
  ''',
    (r) {
      _ok(r, 'ok');
      expect(r.calls.map((c) => c.args), [null, null]);
    },
  ),
  ConformanceCase(
    'morkva.call with non-JSON args rejects invalid_args locally',
    '''
    morkva.action('run', async () => {
      const cyclic = {};
      cyclic.self = cyclic;
      const codes = [];
      for (const args of [cyclic, { n: 10n }]) {
        try { await morkva.call('echo', args); codes.push('resolved'); }
        catch (e) { codes.push(e.code); }
      }
      return codes;
    });
  ''',
    (r) {
      _ok(r, ['invalid_args', 'invalid_args']);
      expect(r.calls, isEmpty);
    },
  ),
  ConformanceCase('morkva.call with array args is answered invalid_args', '''
    morkva.action('run', async () => {
      try { await morkva.call('echo', [1]); return 'resolved'; }
      catch (e) { return e.code; }
    });
  ''', (r) => _ok(r, 'invalid_args')),
  ConformanceCase('concurrent calls settle independently', '''
    morkva.action('run', async () => Promise.all([
      morkva.call('delay', { ms: 40, v: 'slow' }),
      morkva.call('echo', { v: 'fast' }),
    ]).then((rs) => rs.map((x) => x.v)));
  ''', (r) => _ok(r, ['slow', 'fast'])),
  ConformanceCase(
    'input and ctx reach the action as sent',
    '''
    morkva.action('run', (input, ctx) => ({ input, ctx }));
  ''',
    (r) {
      _ok(r, {
        'input': {
          'n': 2,
          'list': ['a'],
        },
        'ctx': kConformanceCtx,
      });
    },
    input: const {
      'n': 2,
      'list': ['a'],
    },
  ),
  ConformanceCase(
    'registration after the top level is ignored with a warning',
    '''
    morkva.action('run', () => {
      morkva.action('late', () => 'late');
      return 'ok';
    });
  ''',
    (r) {
      _ok(r, 'ok');
      expect(r.actions, ['run']);
      expect(r.lines.single, startsWith('warn: morkva.action("late") ignored'));
    },
  ),
  ConformanceCase(
    'an unknown action fails module_error',
    "morkva.action('run', () => 'ok');",
    (r) => _failed(r, 'module_error', message: 'Unknown action: nope'),
    action: 'nope',
  ),
  ConformanceCase(
    'a bad registration at the top level is a load error',
    "morkva.action('run', 'not a function');",
    (r) {
      expect(r.loadError?.code, 'load_error');
      expect(r.loadError?.message, contains('handler must be a function'));
    },
  ),
  ConformanceCase(
    'a top-level throw is a load error',
    "throw new RangeError('broken module');",
    (r) {
      expect(r.loadError?.code, 'load_error');
      expect(r.loadError?.message, contains('broken module'));
    },
  ),
  ConformanceCase(
    'a syntax error is a load error',
    'morkva.action("run", () => {',
    (r) {
      expect(r.loadError?.code, 'load_error');
    },
  ),
  ConformanceCase('setTimeout fires with its extra arguments', '''
    morkva.action('run', () => new Promise((resolve) => {
      setTimeout((a, b) => resolve([a, b]), 10, 'x', 2);
    }));
  ''', (r) => _ok(r, ['x', 2])),
  ConformanceCase('clearTimeout cancels a timer', '''
    morkva.action('run', () => new Promise((resolve) => {
      let fired = false;
      const id = setTimeout(() => { fired = true; }, 5);
      clearTimeout(id);
      clearTimeout(undefined);
      setTimeout(() => resolve(fired), 50);
    }));
  ''', (r) => _ok(r, false)),
  ConformanceCase('odd delays are clamped, not fired at once or lost', '''
    morkva.action('run', () => new Promise((resolve) => {
      const fired = [];
      setTimeout(() => fired.push('negative'), -100);
      setTimeout(() => fired.push('nan'), 'soon');
      setTimeout(() => fired.push('huge'), 1e12);
      setTimeout(() => resolve(fired), 80);
    }));
  ''', (r) => _ok(r, ['negative', 'nan'])),
  ConformanceCase(
    'at most 100 pending timers; a cleared one frees its slot',
    '''
    morkva.action('run', () => {
      const ids = [];
      for (let i = 0; i < 100; i++) ids.push(setTimeout(() => {}, 30000));
      let first = 'none';
      try { setTimeout(() => {}, 1); } catch (e) { first = e.name; }
      clearTimeout(ids.pop());
      let second = 'none';
      try { ids.push(setTimeout(() => {}, 30000)); } catch (e) { second = e.name; }
      ids.forEach(clearTimeout);
      return [first, second];
    });
  ''',
    (r) => _ok(r, ['RangeError', 'none']),
  ),
  ConformanceCase('setTimeout with a non-function throws TypeError', '''
    morkva.action('run', () => {
      try { setTimeout('1 + 1', 0); return 'accepted'; } catch (e) { return e.name; }
    });
  ''', (r) => _ok(r, 'TypeError')),
  ConformanceCase(
    'an error thrown in a timer fails the action module_error',
    '''
    morkva.action('run', () => new Promise(() => {
      setTimeout(() => { throw new Error('timer boom'); }, 5);
    }));
  ''',
    (r) {
      _failed(r, 'module_error', message: 'timer boom');
      expect(r.lines.single, startsWith('error: Uncaught'));
    },
  ),
  ConformanceCase(
    'return values cross as JSON; undefined becomes null',
    '''
    morkva.action('run', () => ({ s: 'x', n: 1.5, b: false, z: null, a: [1, { d: 'y' }],
      u: undefined, date: new Date(0) }));
  ''',
    (r) => _ok(r, {
      's': 'x',
      'n': 1.5,
      'b': false,
      'z': null,
      'a': [
        1,
        {'d': 'y'},
      ],
      'date': '1970-01-01T00:00:00.000Z',
    }),
  ),
  ConformanceCase(
    'undefined return is null',
    "morkva.action('run', async () => {});",
    (r) => _ok(r, null),
  ),
  ConformanceCase(
    'a non-JSON return value is dropped with a warning',
    '''
    morkva.action('run', () => { const c = {}; c.c = c; return c; });
  ''',
    (r) {
      _ok(r, null);
      expect(r.lines.single, startsWith('warn: The action returned a value'));
    },
  ),
  ConformanceCase(
    'a thrown Error fails module_error with message and stack',
    '''
    morkva.action('run', () => { throw new TypeError('bad input'); });
  ''',
    (r) {
      _failed(r, 'module_error', message: 'TypeError: bad input');
      expect(r.error!.stack, isNotNull);
    },
  ),
  ConformanceCase('a thrown non-Error and a rejection fail module_error', '''
    morkva.action('run', async () => { await null; throw 'plain boom'; });
  ''', (r) => _failed(r, 'module_error', message: 'plain boom')),
  ConformanceCase(
    'console and morkva.log become string log lines',
    '''
    morkva.action('run', () => {
      console.log('a', 1, { b: 2 }, [3], null, undefined, true);
      console.info('i'); console.warn('w'); console.error('e'); console.debug('d');
      morkva.log('m', new Error('err'));
      const c = {}; c.c = c;
      console.log(c, Symbol('s'), 10n, () => 1, Object.create(null));
      console.log('x'.repeat(2000));
      return 'ok';
    });
  ''',
    (r) {
      _ok(r, 'ok');
      expect(r.lines.take(6), [
        'log: a 1 {"b":2} [3] null undefined true',
        'info: i',
        'warn: w',
        'error: e',
        'debug: d',
        'info: m Error: err',
      ]);
      expect(r.logs[6].args, hasLength(5));
      expect(r.logs[6].args[1], 'Symbol(s)');
      expect(r.logs[7].args.single.length, kMaxLogLineChars);
    },
  ),
  ConformanceCase(
    'progress is coerced to finite numbers and a short label',
    '''
    morkva.action('run', () => {
      morkva.progress({ done: 1, total: 4, label: 'one' });
      morkva.progress({ done: NaN, total: Infinity, label: { x: 1 } });
      morkva.progress({ done: '2', total: 4, label: 'l'.repeat(200) });
      morkva.progress(undefined);
      morkva.progress({ done: Symbol('x') });
      return 'ok';
    });
  ''',
    (r) {
      _ok(r, 'ok');
      expect(
        [
          for (final p in r.progress) [p.done, p.total, p.label],
        ],
        [
          [1, 4, 'one'],
          [0, 0, '{"x":1}'],
          [2, 4, hasLength(kMaxProgressLabelChars)],
          [0, 0, null],
          [0, 0, null],
        ],
      );
    },
  ),
  ConformanceCase(
    'prototype poisoning does not change frames or leak the transport',
    '''
    let captured;
    if (typeof MessagePort !== 'undefined') {
      MessagePort.prototype.postMessage = function () { captured = this; };
    }
    JSON.stringify = () => ({ not: 'a string' });
    JSON.parse = () => ({ t: 'result', id: 1, ok: true, value: 'forged' });
    Promise.prototype.then = function () { return this; };
    Function.prototype.apply = function () { return 'poisoned'; };
    Function.prototype.call = function () { return 'poisoned'; };
    String.prototype.slice = () => ({ not: 'a string' });
    Array.prototype.join = () => 42;
    Object.defineProperty(Array.prototype, '0', { set(v) {}, configurable: true });
    morkva.action('run', async () => {
      morkva.log('still', 'strings');
      morkva.progress({ done: 1, total: 2 });
      const r = await morkva.call('echo', { v: 1 });
      return { r, captured: typeof captured, transport: typeof sendMessage };
    });
  ''',
    (r) {
      _ok(r, {
        'r': {'v': 1},
        'captured': 'undefined',
        'transport': 'undefined',
      });
      expect(r.lines.single, 'info: still strings');
      expect(r.progress, hasLength(1));
    },
  ),
  ConformanceCase('import(url) rejects', '''
    morkva.action('run', async () => {
      try { await import('https://example.com/x.js'); return 'loaded'; }
      catch (e) { return 'rejected'; }
    });
  ''', (r) => _ok(r, 'rejected')),
  ConformanceCase('a 0.8 s synchronous stretch succeeds', '''
    morkva.action('run', () => {
      const t = Date.now();
      let n = 0;
      while (Date.now() - t < 800) n++;
      return n > 0;
    });
  ''', (r) => _ok(r, true)),
  ConformanceCase(
    'an await loop is killed within budget + 1 s',
    "morkva.action('run', async () => { for (;;) await 0; });",
    (r) {
      _failed(r, 'timeout');
      expect(r.elapsed, lessThan(const Duration(seconds: 2)));
    },
    budget: const Duration(seconds: 1),
  ),
  ConformanceCase(
    'an endless promise chain is killed within budget + 1 s',
    '''
    morkva.action('run', () => {
      const spin = () => Promise.resolve().then(spin);
      spin();
      return new Promise(() => {});
    });
  ''',
    (r) {
      _failed(r, 'timeout');
      expect(r.elapsed, lessThan(const Duration(seconds: 2)));
    },
    budget: const Duration(seconds: 1),
  ),
];
