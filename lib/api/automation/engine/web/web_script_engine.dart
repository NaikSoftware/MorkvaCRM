// The web ScriptEngine (D1, port of the spike's createSandbox to package:web):
// a sandboxed srcdoc iframe (opaque origin, CSP meta) that only launches a
// blob worker running the shim + SDK core + module. All RPC goes over a
// MessageChannel port as JSON strings.
import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import '../../../../core/automation/engine/protocol.dart';
import '../../../../core/automation/engine/script_engine.dart';
import 'sandbox_sources.dart';

/// [csp] and [shim] are seams for tests (a permissive control, a shim
/// without its error handlers); production uses the defaults.
final class WebScriptEngine implements ScriptEngine {
  WebScriptEngine({this.csp = kSandboxCsp, this.shim = kShimJs});

  final String csp;
  final String shim;
  Future<EngineStatus>? _status;

  @override
  Future<EngineStatus> status() => _status ??= probeSandbox(csp).then(
    (p) => p.cspEnforced ? EngineStatus.available : EngineStatus.unavailable,
    onError: (Object _) => EngineStatus.unavailable,
  );

  /// Fails closed: a sandbox whose CSP did not pass the probe never runs
  /// module code.
  @override
  Future<ScriptSession> start(ScriptLoad load) async {
    if (await status() != EngineStatus.available) {
      throw const ScriptFailure(
        'engine_unavailable',
        'The browser cannot isolate modules',
      );
    }
    return _WebSession(load, csp, shim);
  }
}

/// What the probe worker saw under [csp]: `eval` must throw `EvalError` and
/// a `data:` import must be blocked, or the CSP did not reach the worker.
typedef ProbeSignals = ({String eval, String dataImport});

extension ProbeVerdict on ProbeSignals {
  bool get cspEnforced => eval == 'EvalError' && dataImport == 'blocked';
}

/// Boots a lockdown-free probe sandbox under [csp] once and reads its
/// signals. Throws when the worker does not start or does not answer.
Future<ProbeSignals> probeSandbox(
  String csp, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final done = Completer<ProbeSignals>();
  final frame = SandboxFrame(
    csp: csp,
    workerSource: kProbeJs,
    onMessage: (data) {
      if (done.isCompleted || data == null || !data.isA<JSString>()) return;
      try {
        final m = jsonDecode((data as JSString).toDart) as Map;
        done.complete((
          eval: m['eval'] as String,
          dataImport: m['dataImport'] as String,
        ));
      } catch (e) {
        done.completeError(StateError('Bad probe answer: $e'));
      }
    },
    onError: (message) {
      if (!done.isCompleted) done.completeError(StateError(message));
    },
  );
  try {
    return await done.future.timeout(timeout);
  } finally {
    frame.destroy();
  }
}

/// One hidden sandboxed iframe that boots one blob worker from
/// [workerSource] and owns the host end of its port. The handshake is
/// accepted only from this iframe's window.
final class SandboxFrame {
  SandboxFrame({
    required String csp,
    required String workerSource,
    Map<String, Object?> boot = const {},
    required void Function(JSAny? data) onMessage,
    required void Function(String message) onError,
    void Function()? onNavigated,
  }) : _onError = onError,
       _onNavigated = onNavigated {
    _boot = {...boot, 't': 'boot', 'shim': workerSource};
    // Exactly allow-scripts: allow-same-origin would hand the module the
    // app origin. No name attribute, empty permissions policy.
    iframe
      ..setAttribute('sandbox', 'allow-scripts')
      ..setAttribute('allow', '')
      ..setAttribute('aria-hidden', 'true')
      ..style.display = 'none'
      ..srcdoc = bootHtml(csp).toJS;
    _port.onmessage = ((web.MessageEvent e) => onMessage(e.data)).toJS;
    web.window.addEventListener('message', _onWindowMessage);
    iframe.addEventListener('load', _onLoad);
    web.document.body!.append(iframe);
  }

  final iframe = web.document.createElement('iframe') as web.HTMLIFrameElement;
  final _channel = web.MessageChannel();
  late final web.MessagePort _port = _channel.port1;
  late final Map<String, Object?> _boot;
  final void Function(String message) _onError;
  final void Function()? _onNavigated;
  late final JSFunction _onWindowMessage = _windowMessage.toJS;
  late final JSFunction _onLoad = _load.toJS;
  var _loads = 0;
  var _booted = false;
  var _destroyed = false;

  void _windowMessage(web.MessageEvent e) {
    // A Dart == between JS objects never matches under DDC.
    if (_destroyed || !e.source.strictEquals(iframe.contentWindow).toDart) {
      return;
    }
    final data = e.data;
    if (data == null || !data.isA<JSObject>()) return;
    final t = (data as JSObject)['t'];
    if (t == null || !t.isA<JSString>()) return;
    switch ((t as JSString).toDart) {
      case 'morkva-sandbox-ready':
        if (_booted || _loads > 1) return;
        _booted = true;
        // '*': the sandbox's origin is opaque ('null').
        iframe.contentWindow!.postMessage(
          _boot.jsify(),
          '*'.toJS,
          [_channel.port2].toJS,
        );
      case 'morkva-sandbox-error':
        final message = data['message'];
        _onError(
          message != null && message.isA<JSString>()
              ? (message as JSString).toDart
              : 'Sandbox error',
        );
    }
  }

  void _load(web.Event _) {
    if (++_loads > 1 && !_destroyed) _onNavigated?.call();
  }

  void post(String frame) {
    if (!_destroyed) _port.postMessage(frame.toJS);
  }

  /// Removing the iframe stops its worker, busy or not.
  void destroy() {
    if (_destroyed) return;
    _destroyed = true;
    web.window.removeEventListener('message', _onWindowMessage);
    iframe.removeEventListener('load', _onLoad);
    _port.close();
    iframe.remove();
  }
}

final class _WebSession implements ScriptSession {
  _WebSession(ScriptLoad load, String csp, String shim) {
    _ready.future.ignore(); // nobody may await ready before a kill
    _frame = SandboxFrame(
      csp: csp,
      workerSource: workerSource(shim, load.sdkCore),
      boot: {
        'code': load.code,
        'name': load.moduleId,
        'budgetMs': load.budget.inMilliseconds,
      },
      onMessage: _onPort,
      onError: _onSandboxError,
      onNavigated: () => kill('sandbox_navigated'),
    );
  }

  late final SandboxFrame _frame;
  final _ready = Completer<List<String>>();
  final _messages = StreamController<ModuleMessage>();
  final _invokes = <int, Completer<Object?>>{};
  var _nextInvokeId = 0;
  ScriptFailure? _dead;

  @override
  Future<List<String>> get ready => _ready.future;

  @override
  Stream<ModuleMessage> get messages => _messages.stream;

  void _onPort(JSAny? data) {
    if (_dead != null) return;
    // Checked before any conversion: no structured-clone graph is dartified.
    if (data == null || !data.isA<JSString>()) return kill('abuse');
    final ModuleFrame frame;
    try {
      frame = decodeFrame((data as JSString).toDart);
    } on ProtocolViolation {
      return kill('abuse');
    }
    switch (frame) {
      case ReadyFrame(:final actions):
        if (!_ready.isCompleted) _ready.complete(actions);
      case LoadErrorFrame(:final error):
        _end(error);
      case DoneFrame():
        final invoke = _invokes.remove(frame.id);
        if (invoke == null) return;
        if (frame.error case final error?) {
          invoke.completeError(error);
        } else {
          invoke.complete(frame.value);
        }
      case ModuleMessage():
        _messages.add(frame);
    }
  }

  /// `worker.onerror` reached the iframe: the worker failed to start, or an
  /// error got past the shim's handlers after `ready`.
  void _onSandboxError(String message) {
    if (_dead != null) return;
    if (!_ready.isCompleted) {
      return _end(ScriptFailure('boot_error', message));
    }
    _messages.add(LogFrame('error', ['Uncaught $message']));
    _end(ScriptFailure('module_error', message));
  }

  @override
  Future<Object?> invoke(
    String action,
    Object? input,
    Map<String, Object?> ctx,
  ) {
    if (_dead case final dead?) return Future.error(dead);
    final id = ++_nextInvokeId;
    final done = Completer<Object?>();
    _invokes[id] = done;
    _frame.post(encodeInvoke(id, action, input, ctx));
    return done.future;
  }

  @override
  void reply(int callId, {Object? value, HarnessErrorJson? error}) {
    if (_dead != null) return;
    String frame;
    try {
      frame = encodeResult(callId, value: value, error: error);
    } on JsonUnsupportedObjectError {
      frame = encodeResult(
        callId,
        error: {'code': 'internal', 'message': 'Internal error'},
      );
    }
    _frame.post(frame);
  }

  @override
  void kill(String reason) =>
      _end(ScriptFailure(reason, 'Sandbox killed: $reason'));

  void _end(ScriptFailure failure) {
    if (_dead != null) return;
    _dead = failure;
    _frame.destroy();
    if (!_ready.isCompleted) _ready.completeError(failure);
    for (final invoke in _invokes.values) {
      invoke.completeError(failure);
    }
    _invokes.clear();
    _messages.close();
  }
}
