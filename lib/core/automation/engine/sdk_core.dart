// The SDK core: one JS source both engines run before the module (spec
// "SDK core and transport adapters"). It defines `morkva`, `console`,
// `setTimeout`/`clearTimeout`, the action table, error shaping and frame
// encoding, and evaluates to an installer:
//
//   (function install(send, timer) { …; return receive; })
//
// - `send(frame: string)`: the adapter's transport to the host. Every frame
//   the core sends is a JSON string built by concatenation from values it
//   coerced itself, so module values can never make a malformed frame (which
//   `decodeFrame` treats as abuse).
// - `timer(id: number, ms: number)`: arms an adapter-local timer; when it
//   fires the adapter calls `receive('{"t":"timer","id":<id>}')`. `ms` is
//   already clamped to [0, kSdkMaxDelayMs]; the adapter may clamp it further
//   to the run's budget.
// - `receive(frame: string)`: the host's only way in. Besides the host
//   frames of protocol.dart (`invoke`, `result`) it takes these
//   adapter-local frames, which never cross to the host:
//     {t:'timer', id}                          a timer armed through `timer`
//     {t:'loaded'}                             the module evaluated: send `ready`
//     {t:'loaded', error:{message, stack?}}    the module failed to evaluate:
//                                              send `loadError`
//     {t:'uncaught', error:{message, stack?}, fatal:bool}
//                                              an error the core could not
//                                              catch; logged, and when fatal
//                                              every running action fails
//                                              `module_error`
//
// The core captures every intrinsic it uses at install time, before the
// module loads, and keeps its tables on null-prototype objects, so module
// code that patches prototypes or JSON cannot change the frames or reach
// `send`. ES2020 only (no worker or browser globals): QuickJS runs it too.

/// `morkva.version`.
const kSdkVersion = '2.0';

/// Timer delays above this are clamped (the longest run a manifest may ask).
const kSdkMaxDelayMs = 60000;

/// The adapter-local frame telling the core the module evaluated.
const kSdkLoadedFrame = '{"t":"loaded"}';

const kSdkCoreJs =
    r'''(function install(send, timer) {
  'use strict';
  var G = globalThis;
  var apply = Reflect.apply, create = Object.create, freeze = Object.freeze,
      define = Object.defineProperty;
  var S = JSON.stringify, P = JSON.parse;
  var Str = String, Num = Number, finite = Number.isFinite;
  var slice = String.prototype.slice, then = Promise.prototype.then;
  var Prom = Promise, Err = Error, TypeErr = TypeError, RangeErr = RangeError;
  var VERSION = '''
    "'$kSdkVersion'"
    r''';
  var MAX_LINE = 500, MAX_ARGS = 50, MAX_LABEL = 60, MAX_TIMERS = 100,
      MAX_DELAY = '''
    '$kSdkMaxDelayMs'
    r''', MAX_VALUE = 900000,
      MAX_MESSAGE = 2000, MAX_STACK = 8000;

  // The QuickJS channel global (quickjs_runtime2.dart): never left to modules.
  try { delete G.sendMessage; } catch (_) {}

  function cut(s, n) {
    return s.length > n ? apply(slice, s, [0, n - 1]) + '…' : s;
  }

  function isObj(v) {
    return v !== null && (typeof v === 'object' || typeof v === 'function');
  }

  // {message, stack} of anything thrown; never throws.
  function shape(e) {
    var message = null, stack = null;
    try {
      if (isObj(e)) {
        var m = e.message;
        if (m !== undefined && m !== null) message = Str(m);
        var n = e.name;
        if (message !== null && typeof n === 'string' && n !== '' && n !== 'Error') {
          message = n + ': ' + message;
        }
        var st = e.stack;
        if (typeof st === 'string') stack = st;
      }
    } catch (_) {}
    if (message === null) message = text(e);
    return { message: message, stack: stack };
  }

  // A printable string for any value; never throws.
  function text(v) {
    try {
      if (typeof v === 'string') return v;
      if (v === undefined) return 'undefined';
      if (typeof v === 'function') return '[function]';
      if (typeof v === 'symbol' || typeof v === 'bigint') return Str(v);
      if (v instanceof Err) {
        var en = v.name, em = v.message;
        return (typeof en === 'string' && en !== '' ? en + ': ' : '') +
            (em === undefined || em === null ? '' : Str(em));
      }
      var j = S(v);
      if (typeof j === 'string') return j;
    } catch (_) {}
    try {
      var s = Str(v);
      if (typeof s === 'string') return s;
    } catch (_) {}
    return '[unprintable]';
  }

  function errJson(e, code) {
    var s = shape(e);
    return '{"code":' + S(code) + ',"message":' + S(cut(s.message, MAX_MESSAGE)) +
        (s.stack === null ? '' : ',"stack":' + S(cut(s.stack, MAX_STACK))) + '}';
  }

  function num(v) {
    try {
      var n = Num(v);
      return finite(n) ? n : 0;
    } catch (_) {
      return 0;
    }
  }

  // --- logs -----------------------------------------------------------------

  function logLine(level, args) {
    var out = '', n = args.length;
    if (n > MAX_ARGS) n = MAX_ARGS;
    for (var i = 0; i < n; i++) {
      out += (i === 0 ? '' : ',') + S(cut(text(args[i]), MAX_LINE));
    }
    send('{"t":"log","level":' + S(level) + ',"args":[' + out + ']}');
  }

  function logger(level) {
    return function () { logLine(level, arguments); };
  }

  // --- actions --------------------------------------------------------------

  var loaded = false, actions = create(null), ids = create(null), nIds = 0;
  var running = create(null);

  function action(id, handler) {
    if (loaded) {
      logLine('warn', ['morkva.action(' + S(text(id)) +
          ') ignored: register actions at the top level of the module']);
      return;
    }
    if (typeof id !== 'string' || id === '') {
      throw new TypeErr('morkva.action: the id must be a non-empty string');
    }
    if (typeof handler !== 'function') {
      throw new TypeErr('morkva.action: the handler must be a function');
    }
    if (actions[id] === undefined) ids[nIds++] = id;
    actions[id] = handler;
  }

  function onLoaded(error) {
    if (loaded) return;
    loaded = true;
    if (isObj(error)) {
      send('{"t":"loadError","error":' + errJson(error, 'load_error') + '}');
      return;
    }
    var out = '';
    for (var i = 0; i < nIds; i++) out += (i === 0 ? '' : ',') + S(ids[i]);
    send('{"t":"ready","actions":[' + out + ']}');
  }

  function finish(id, ok, v) {
    if (running[id] !== true) return;
    delete running[id];
    if (!ok) {
      send('{"t":"done","id":' + S(id) + ',"ok":false,"error":' +
          errJson(v, 'module_error') + '}');
      return;
    }
    var j;
    try {
      j = S(v);
      if (typeof j !== 'string') j = 'null';
    } catch (_) {
      j = null;
    }
    if (j === null) {
      logLine('warn', ['The action returned a value that is not JSON; it was ignored']);
      j = 'null';
    } else if (j.length > MAX_VALUE) {
      logLine('warn', ['The action returned more than 900 KB; it was ignored']);
      j = 'null';
    }
    send('{"t":"done","id":' + S(id) + ',"ok":true,"value":' + j + '}');
  }

  function invoke(m) {
    var id = num(m.id), name = m.action, handler = actions[name], r;
    running[id] = true;
    function ok(v) { finish(id, true, v); }
    function bad(e) { finish(id, false, e); }
    try {
      if (handler === undefined) throw new Err('Unknown action: ' + text(name));
      r = handler(m.input, m.ctx);
    } catch (e) {
      bad(e);
      return;
    }
    if (!isObj(r)) {
      ok(r);
      return;
    }
    // A native promise settles through the captured `then`, so a patched
    // Promise.prototype.then cannot hold the result back.
    try {
      apply(then, r, [ok, bad]);
      return;
    } catch (_) {}
    apply(then, new Prom(function (res) { res(r); }), [ok, bad]);
  }

  // --- host calls -----------------------------------------------------------

  var nextCall = 0, pending = create(null);

  function morkvaError(e) {
    var er = new Err(isObj(e) && typeof e.message === 'string' ? e.message : 'Error');
    er.name = 'MorkvaError';
    er.code = isObj(e) && typeof e.code === 'string' ? e.code : 'internal';
    if (isObj(e)) {
      if (e.details !== undefined) er.details = e.details;
      if (e.path !== undefined) er.path = e.path;
      if (e.candidates !== undefined) er.candidates = e.candidates;
    }
    return er;
  }

  function call(op, args) {
    var a = 'null', bad = null;
    if (args !== undefined && args !== null) {
      try {
        a = S(args);
        if (typeof a !== 'string') bad = 'args must be a JSON object';
      } catch (e) {
        bad = 'args are not JSON: ' + text(e);
      }
    }
    if (bad !== null) {
      return new Prom(function (_, rej) {
        rej(morkvaError({ code: 'invalid_args', message: bad }));
      });
    }
    var id = ++nextCall, opName = text(op);
    return new Prom(function (res, rej) {
      pending[id] = { res: res, rej: rej };
      send('{"t":"call","id":' + S(id) + ',"op":' + S(opName) + ',"args":' + a + '}');
    });
  }

  function result(m) {
    var id = num(m.id), p = pending[id];
    if (p === undefined) return;
    delete pending[id];
    if (m.ok === true) p.res(m.value);
    else p.rej(morkvaError(m.error));
  }

  // --- progress -------------------------------------------------------------

  function progress(p) {
    var done = 0, total = 0, label = null;
    try {
      if (isObj(p)) {
        done = num(p.done);
        total = num(p.total);
        var l = p.label;
        if (l !== undefined && l !== null) label = cut(text(l), MAX_LABEL);
      }
    } catch (_) {}
    send('{"t":"progress","done":' + S(done) + ',"total":' + S(total) +
        (label === null ? '' : ',"label":' + S(label)) + '}');
  }

  // --- timers ---------------------------------------------------------------

  var timers = create(null), nTimers = 0, nextTimer = 0;

  function setTimeout(fn, ms) {
    if (typeof fn !== 'function') {
      throw new TypeErr('setTimeout: the callback must be a function');
    }
    if (nTimers >= MAX_TIMERS) {
      throw new RangeErr('Too many pending timers (at most ' + MAX_TIMERS + ')');
    }
    var delay = num(ms);
    if (delay < 0) delay = 0;
    if (delay > MAX_DELAY) delay = MAX_DELAY;
    var extra = [], n = arguments.length;
    for (var i = 2; i < n; i++) extra[i - 2] = arguments[i];
    var id = ++nextTimer;
    timers[id] = { fn: fn, args: extra };
    nTimers++;
    timer(id, delay);
    return id;
  }

  function clearTimeout(id) {
    if (typeof id !== 'number' || timers[id] === undefined) return;
    delete timers[id];
    nTimers--;
  }

  function fire(id) {
    var t = timers[id];
    if (t === undefined) return;
    delete timers[id];
    nTimers--;
    try {
      apply(t.fn, G, t.args);
    } catch (e) {
      uncaught(e, true);
    }
  }

  function uncaught(e, fatal) {
    logLine('error', ['Uncaught ' + shape(e).message]);
    if (!fatal) return;
    for (var id in running) finish(num(id), false, e);
  }

  // --- globals --------------------------------------------------------------

  var hidden = { writable: true, enumerable: false, configurable: true };
  define(G, 'morkva', {
    value: freeze({
      action: action,
      call: call,
      log: logger('info'),
      progress: progress,
      version: VERSION,
    }),
    writable: false, enumerable: false, configurable: false,
  });
  hidden.value = freeze({
    log: logger('log'), info: logger('info'), warn: logger('warn'),
    error: logger('error'), debug: logger('debug'),
  });
  define(G, 'console', hidden);
  hidden.value = setTimeout;
  define(G, 'setTimeout', hidden);
  hidden.value = clearTimeout;
  define(G, 'clearTimeout', hidden);

  return function receive(frame) {
    if (typeof frame !== 'string') return;
    var m;
    try {
      m = P(frame);
    } catch (_) {
      return;
    }
    if (!isObj(m)) return;
    var t = m.t;
    if (t === 'invoke') invoke(m);
    else if (t === 'result') result(m);
    else if (t === 'timer') fire(num(m.id));
    else if (t === 'loaded') onLoaded(m.error);
    else if (t === 'uncaught') uncaught(m.error, m.fatal === true);
  };
})''';
