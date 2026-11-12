// The QuickJS ScriptEngine (D1, Android/iOS): one worker isolate per run,
// owned by the session, hosting QuickJsRuntime2 directly (IsolateQjs keeps no
// Isolate handle and its job drain never yields, so it cannot be killed). The
// worker installs the SDK core with two captured Dart closures (spec "SDK core
// and transport adapters"), evaluates the module and pumps its own job queue.
// Frames cross the isolate boundary as JSON strings only.
import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:flutter_qjs_next/flutter_qjs.dart';

import '../../../../core/automation/engine/protocol.dart';
import '../../../../core/automation/engine/script_engine.dart';
import '../../../../core/automation/engine/sdk_core.dart';

/// The per-native-call interrupt slice: a synchronous stretch of JS longer
/// than this is stopped (`limit_exceeded`), so a kill can always land.
const kQuickJsSliceMs = 1000;
const _stackSize = 1024 * 1024;

/// Jobs drained between yields to the worker's event loop.
const _jobsPerYield = 1000;
const _maxDrainSlice = Duration(milliseconds: 100);

/// How long a stopping worker may take to free its runtime before it is
/// killed outright (leaking the native heap).
const _disposeGrace = Duration(milliseconds: 500);

final class QuickJsScriptEngine implements ScriptEngine {
  Future<EngineStatus>? _status;

  /// Loads the native library and evaluates a script on a throwaway isolate;
  /// a missing or stale library throws there (StateError/ArgumentError).
  @override
  Future<EngineStatus> status() => _status ??= Isolate.run(_probe).then(
    (ok) => ok ? EngineStatus.available : EngineStatus.unavailable,
    onError: (Object _) => EngineStatus.unavailable,
  );

  @override
  Future<ScriptSession> start(ScriptLoad load) async {
    if (await status() != EngineStatus.available) {
      throw const ScriptFailure(
        'engine_unavailable',
        'This device cannot run modules',
      );
    }
    return QuickJsSession(load);
  }
}

bool _probe() {
  final rt = QuickJsRuntime2(
    timeout: kQuickJsSliceMs,
    webApis: const JsWebApis.none(),
    autoExecutePendingJobs: false,
  );
  try {
    return rt.evaluate('6 * 7').rawResult == 42;
  } finally {
    rt.dispose();
  }
}

/// The host half of one run. Public for tests: [exited] says when the worker
/// isolate is really gone, which `invoke` failing on a kill does not.
final class QuickJsSession implements ScriptSession {
  QuickJsSession(ScriptLoad load) {
    _ready.future.ignore(); // nobody may await ready before a kill
    _inbox.listen(_onWorker);
    _exitPort.listen((_) {
      _exitPort.close();
      if (!_exited.isCompleted) _exited.complete();
      _end(
        ScriptFailure(
          _ready.isCompleted ? 'module_error' : 'boot_error',
          'The script engine stopped',
        ),
      );
    });
    _spawn(load);
  }

  final _inbox = ReceivePort();
  final _exitPort = ReceivePort();
  final _exited = Completer<void>();
  final _ready = Completer<List<String>>();
  final _messages = StreamController<ModuleMessage>();
  final _invokes = <int, Completer<Object?>>{};
  final _queued = <String>[];
  Isolate? _isolate;
  SendPort? _worker;
  var _nextInvokeId = 0;
  ScriptFailure? _dead;

  /// Completes when the worker isolate has exited.
  Future<void> get exited => _exited.future;

  @override
  Future<List<String>> get ready => _ready.future;

  @override
  Stream<ModuleMessage> get messages => _messages.stream;

  Future<void> _spawn(ScriptLoad load) async {
    try {
      _isolate = await Isolate.spawn(
        _workerMain,
        _Boot(
          _inbox.sendPort,
          moduleId: load.moduleId,
          code: load.code,
          sdkCore: load.sdkCore,
          memoryLimitBytes: load.memoryLimitBytes,
          budgetMs: load.budget.inMilliseconds,
        ),
        onExit: _exitPort.sendPort,
        debugName: 'morkva-module-${load.moduleId}',
      );
      if (_dead != null) _stop(); // killed while spawning
    } catch (e) {
      _exitPort.close();
      if (!_exited.isCompleted) _exited.complete();
      _end(ScriptFailure('boot_error', 'The script engine did not start: $e'));
    }
  }

  void _onWorker(Object? m) {
    if (_dead != null) return;
    if (m is SendPort) {
      _worker = m;
      _queued.forEach(m.send);
      _queued.clear();
      return;
    }
    if (m is ScriptFailure) return _end(m);
    final ModuleFrame frame;
    try {
      frame = decodeFrame(m);
    } on ProtocolViolation {
      return kill('abuse');
    }
    switch (frame) {
      case ReadyFrame(:final actions):
        if (!_ready.isCompleted) _ready.complete(actions);
      case LoadErrorFrame(:final error):
        _end(error);
      case DoneFrame():
        // The slice interrupt is uncatchable in JS, but an async function
        // turns it into its own rejection, which arrives as a `done`.
        if (frame.error?.message.startsWith(_interruptedMessage) ?? false) {
          return _end(_sliceExceeded);
        }
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

  void _post(String frame) {
    if (_worker case final worker?) {
      worker.send(frame);
    } else {
      _queued.add(frame);
    }
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
    _post(encodeInvoke(id, action, input, ctx));
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
    _post(frame);
  }

  @override
  void kill(String reason) =>
      _end(ScriptFailure(reason, 'Sandbox killed: $reason'));

  void _end(ScriptFailure failure) {
    if (_dead != null) return;
    _dead = failure;
    _stop();
    _inbox.close();
    if (!_ready.isCompleted) _ready.completeError(failure);
    for (final invoke in _invokes.values) {
      invoke.completeError(failure);
    }
    _invokes.clear();
    _messages.close();
  }

  /// Asks the worker to free its runtime and exit (Isolate.kill skips
  /// jsFreeRuntime: the package has no finalizer, so up to the memory limit
  /// would leak per run), then kills it if it has not exited in time.
  void _stop() {
    final isolate = _isolate;
    if (isolate == null || _exited.isCompleted) return;
    _worker?.send(null);
    final force = Timer(
      _worker == null ? Duration.zero : _disposeGrace,
      () => isolate.kill(priority: Isolate.immediate),
    );
    _exited.future.then((_) => force.cancel());
  }
}

final class _Boot {
  const _Boot(
    this.host, {
    required this.moduleId,
    required this.code,
    required this.sdkCore,
    required this.memoryLimitBytes,
    required this.budgetMs,
  });

  final SendPort host;
  final String moduleId;
  final String code;
  final String sdkCore;
  final int memoryLimitBytes;
  final int budgetMs;
}

/// The worker isolate: everything below runs off the host's isolate. It
/// sends the host its port, then module frames (a String, or `null` for a
/// value that is not a frame-sized string: the host's decodeFrame kills it
/// as abuse) and at most one [ScriptFailure]. A `null` from the host means
/// stop.
Future<void> _workerMain(_Boot boot) async {
  final host = boot.host;
  final inbox = ReceivePort();
  host.send(inbox.sendPort);

  Object? jobError;
  // executePendingJob logs a failing job's exception instead of returning it.
  FlutterQjsLogger.handler = (level, message, error) {
    if (level == FlutterQjsLogLevel.error) jobError = error;
  };

  QuickJsRuntime2? rt;
  JSInvokable? receive;
  var dead = false;
  var draining = false;

  void fail(ScriptFailure f) {
    if (dead) return;
    dead = true;
    host.send(f);
  }

  Future<void> drain() async {
    final runtime = rt;
    if (draining || dead || runtime == null) return;
    draining = true;
    final sinceYield = Stopwatch()..start();
    try {
      for (var n = 1; !dead; n++) {
        jobError = null;
        final r = runtime.executePendingJob();
        if (r < 0) return fail(_fatal(jobError));
        if (r == 0) return;
        // By time too: a chain of slow jobs must not keep the stop unread.
        if (n % _jobsPerYield == 0 || sinceYield.elapsed > _maxDrainSlice) {
          await Future<void>(() {});
          sinceYield.reset();
        }
      }
    } catch (e) {
      fail(_fatal(e));
    } finally {
      draining = false;
    }
  }

  void deliver(String frame) {
    final r = receive;
    if (dead || r == null) return;
    try {
      r.invoke([frame]);
    } catch (e) {
      return fail(_fatal(e));
    }
    drain();
  }

  // Events only run once the synchronous boot below has finished.
  inbox.listen((m) {
    if (m is String) return deliver(m);
    inbox.close();
    // dispose() drains pending jobs without a bound, so an endless promise
    // chain would hang it. shortcut: a run stopped with jobs pending leaks
    // its native heap; free the runtime without draining if the package
    // ever exposes that.
    if (rt?.hasPendingJobs == false) {
      try {
        rt?.dispose();
      } catch (_) {}
    }
    Isolate.exit();
  });

  void send(Object? frame) => host.send(
    frame is String && frame.length <= kMaxFrameChars ? frame : null,
  );

  void timer(Object? id, Object? ms) {
    if (id is! num || ms is! num) return;
    final delay = math.max(math.min(ms.toInt(), boot.budgetMs), 0);
    Timer(
      Duration(milliseconds: delay),
      () => deliver(encodeTimer(id.toInt())),
    );
  }

  final QuickJsRuntime2 runtime;
  try {
    runtime = rt = QuickJsRuntime2(
      timeout: kQuickJsSliceMs,
      memoryLimit: boot.memoryLimitBytes,
      stackSize: _stackSize,
      webApis: const JsWebApis.none(),
      autoExecutePendingJobs: false,
      // QuickJS reports a rejection before a handler can attach (an async
      // action that throws at once), so tracking it would log false errors.
      hostPromiseRejectionHandler: (_) {},
    );
    final install = runtime.evaluate(boot.sdkCore, name: 'morkva-sdk.js');
    final installer = install.rawResult;
    if (install.isError || installer is! JSInvokable) {
      return fail(
        ScriptFailure('boot_error', 'SDK core: ${install.stringResult}'),
      );
    }
    receive = installer.invoke([send, timer]) as JSInvokable;
  } catch (e) {
    return fail(ScriptFailure('boot_error', 'The script engine failed: $e'));
  }

  // `void 0`: evaluate marshals the completion value, and a module ending in
  // a promise or an Error must not become a Dart Future or a false error.
  final loaded = runtime.evaluate(
    '${boot.code}\n;void 0',
    name: 'morkva-module/${boot.moduleId}.js',
  );
  if (!loaded.isError) return deliver(kSdkLoadedFrame);
  final error = loaded.rawResult;
  if (_interrupted(error)) return fail(_fatal(error));
  final (:message, :stack) = _describe(error);
  deliver(
    jsonEncode({
      't': 'loaded',
      'error': {'message': message, 'stack': ?stack},
    }),
  );
}

const _interruptedMessage = 'InternalError: interrupted';

const _sliceExceeded = ScriptFailure(
  'limit_exceeded',
  'Busy for more than 1 s without awaiting',
);

bool _interrupted(Object? e) =>
    e is JSError && e.message.startsWith(_interruptedMessage);

/// An error that escaped the SDK core (which catches everything a module
/// can throw): the slice interrupt, an out-of-memory, or a broken engine.
ScriptFailure _fatal(Object? e) {
  if (_interrupted(e)) return _sliceExceeded;
  final (:message, :stack) = _describe(e);
  return ScriptFailure('module_error', message, stack: stack);
}

/// Message and JS stack of anything QuickJS threw; a stack that is a Dart
/// StackTrace (the error had none) is dropped.
({String message, String? stack}) _describe(Object? e) {
  if (e is! JSError) return (message: '$e', stack: null);
  final message = e.message.startsWith('Error: ')
      ? e.message.substring(7)
      : e.message;
  final stack = e.stack.trim();
  return (
    message: message,
    stack: stack.isEmpty || stack.startsWith('#0') ? null : stack,
  );
}
