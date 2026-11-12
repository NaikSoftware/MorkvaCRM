// The web sandbox's sources (port of the spike's morkva-sandbox.js): the
// srcdoc CSP, the iframe boot page, the worker shim (web transport adapter of
// the SDK core) and the CSP probe worker.

/// The srcdoc CSP; inherited by the blob worker, it is the network wall.
/// No `'unsafe-eval'`: eval/new Function/Wasm compile are blocked too.
const kSandboxCsp =
    "default-src 'none'; script-src 'unsafe-inline' blob:; "
    "worker-src blob:; connect-src 'none'; form-action 'none'; "
    "base-uri 'none'";

/// The iframe page. Its only job: on the parent's `boot` message start the
/// blob worker from `shim` and hand it the port with `code`, `name` and
/// `budgetMs`. Module code never runs on this thread.
String bootHtml(String csp) =>
    '<!doctype html><meta http-equiv="Content-Security-Policy" '
    'content="$csp"><script>$_bootJs</script>';

const _bootJs = r'''
(function () {
  var started = false;
  addEventListener('message', function (e) {
    if (e.source !== parent || started) return;
    var d = e.data || {};
    if (d.t !== 'boot' || !e.ports[0]) return;
    started = true;
    try {
      var w = new Worker(URL.createObjectURL(new Blob([d.shim], { type: 'text/javascript' })));
      w.onerror = function (ev) {
        parent.postMessage({ t: 'morkva-sandbox-error', message: String(ev.message) }, '*');
      };
      w.postMessage({ code: d.code, name: d.name, budgetMs: d.budgetMs }, [e.ports[0]]);
    } catch (err) {
      parent.postMessage({ t: 'morkva-sandbox-error', message: String(err) }, '*');
    }
  });
  parent.postMessage({ t: 'morkva-sandbox-ready' }, '*');
})();
''';

/// The worker source: [shim] wrapping the SDK core installer. Concatenated,
/// not evaluated: the CSP has no `'unsafe-eval'`. The newlines keep a
/// trailing line comment in either part from swallowing the call.
String workerSource(String shim, String sdkCore) =>
    '(function (install) {\n$shim\n})(\n$sdkCore\n);\n';

/// The web transport adapter, run with `install` (the SDK core installer) in
/// scope before anything else in the worker. It captures what it needs, locks
/// down the worker global, installs the core with the port, then loads the
/// module through `importScripts(blob:)` so stacks name
/// `morkva-module/<id>.js`. The error handlers between the `uncaught`
/// markers keep worker errors off the iframe's `worker.onerror`.
const kShimJs = r'''
'use strict';
var G = self, apply = Reflect.apply, S = JSON.stringify, Str = String;
var load = G.importScripts.bind(G), mkUrl = URL.createObjectURL,
    revoke = URL.revokeObjectURL, B = Blob, T = G.setTimeout.bind(G),
    encode = encodeURIComponent;
// Read through captured accessors: a module could redefine them to reach
// the event's target (the port) or to keep errors from being cancelled.
var dataOf = Object.getOwnPropertyDescriptor(MessageEvent.prototype, 'data').get;
var portsOf = Object.getOwnPropertyDescriptor(MessageEvent.prototype, 'ports').get;
var prevent = Event.prototype.preventDefault;

function lock(name, seal) {
  for (var o = G; o; o = Object.getPrototypeOf(o)) {
    if (Object.prototype.hasOwnProperty.call(o, name)) {
      try { delete o[name]; } catch (_) {}
    }
  }
  if (!seal) return;
  try {
    Object.defineProperty(G, name,
        { value: undefined, writable: false, enumerable: false, configurable: false });
  } catch (_) {}
}
['fetch', 'XMLHttpRequest', 'WebSocket', 'WebSocketStream', 'EventSource',
 'WebTransport', 'RTCPeerConnection', 'FontFace', 'Worker', 'SharedWorker',
 'importScripts', 'setInterval', 'clearInterval'].forEach(function (n) { lock(n, true); });
// The SDK core defines its own timers over the captured native one.
lock('setTimeout', false);
lock('clearTimeout', false);

function errFrame(t, e, extra) {
  var message = 'Error', stack = null;
  try {
    if (e !== null && typeof e === 'object') {
      message = Str(e.message);
      if (typeof e.name === 'string' && e.name !== 'Error') message = e.name + ': ' + message;
      if (typeof e.stack === 'string') stack = e.stack;
    } else {
      message = Str(e);
    }
  } catch (_) {}
  return '{"t":' + S(t) + extra + ',"error":{"message":' + S(message) +
      (stack === null ? '' : ',"stack":' + S(stack)) + '}}';
}

G.onmessage = function (e) {
  G.onmessage = null;
  var d = apply(dataOf, e, []), port = apply(portsOf, e, [])[0];
  if (!port || !d || typeof d.code !== 'string') return;
  var post = port.postMessage.bind(port);
  var budget = d.budgetMs > 0 ? d.budgetMs : 60000;
  var receive = install(function (s) { post(s); }, function (id, ms) {
    T(function () { receive('{"t":"timer","id":' + id + '}'); }, ms < budget ? ms : budget);
  });
  port.onmessage = function (ev) {
    var v = apply(dataOf, ev, []);
    if (typeof v === 'string') receive(v);
  };
  /*uncaught{*/
  G.addEventListener('error', function (ev) {
    apply(prevent, ev, []);
    receive(errFrame('uncaught', ev.error != null ? ev.error : ev.message, ',"fatal":true'));
  });
  G.addEventListener('unhandledrejection', function (ev) {
    apply(prevent, ev, []);
    receive(errFrame('uncaught', ev.reason, ',"fatal":false'));
  });
  /*}uncaught*/
  var url = mkUrl(new B([d.code + '\n//# sourceURL=morkva-module/' + encode(d.name) + '.js'],
      { type: 'text/javascript' }));
  try {
    load(url);
    receive('{"t":"loaded"}');
  } catch (err) {
    receive(errFrame('loaded', err, ''));
  }
  revoke(url);
};
''';

/// The `status()` probe worker: no lockdown, no SDK. Reports two
/// network-free signs that the CSP reached the worker: `eval` throws
/// `EvalError`, and a `data:` import is blocked.
const kProbeJs = r'''
self.onmessage = function (e) {
  var port = e.ports[0], ev = 'allowed';
  try { (0, eval)('1'); } catch (err) { ev = String(err && err.name); }
  function report(imp) {
    port.postMessage(JSON.stringify({ t: 'probe', eval: ev, dataImport: imp }));
  }
  try {
    import('data:text/javascript,export default 1')
        .then(function () { report('allowed'); }, function () { report('blocked'); });
  } catch (err) {
    report('blocked');
  }
};
''';
