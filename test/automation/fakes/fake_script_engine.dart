// A scripted ScriptEngine for VM tests of the bridge and the runner. The
// module side speaks the real wire protocol: every frame it sends is a raw
// value passed through [decodeFrame], so non-string, oversize and deep frames
// kill the session `abuse` exactly as the real engines do.
import 'dart:async';
import 'dart:convert';

import 'package:morkva_crm/core/automation/engine/protocol.dart';
import 'package:morkva_crm/core/automation/engine/script_engine.dart';

/// Boots the module; the default sends `ready` with the engine's actions.
/// A boot that sends nothing hangs (the runner's boot budget applies).
typedef FakeBoot = FutureOr<void> Function(FakeModule module);

/// Runs one invoke. The returned value becomes `done ok`; a throw becomes
/// `done` with a `module_error`. Never completing = a hung action.
typedef FakeAction =
    Future<Object?> Function(FakeModule module, FakeInvocation invocation);

final class FakeInvocation {
  const FakeInvocation(this.id, this.action, this.input, this.ctx);
  final int id;
  final String action;
  final Object? input;
  final Map<String, Object?> ctx;
}

typedef FakeReply = ({int callId, Object? value, HarnessErrorJson? error});

class FakeScriptEngine implements ScriptEngine {
  FakeScriptEngine({
    this.engineStatus = EngineStatus.available,
    this.actions = const ['run'],
    this.boot,
    this.action,
    this.startError,
  });

  EngineStatus engineStatus;
  List<String> actions;
  FakeBoot? boot;
  FakeAction? action;

  /// Thrown by [start] when set.
  Object? startError;

  final loads = <ScriptLoad>[];
  final sessions = <FakeScriptSession>[];
  var statusCalls = 0;

  @override
  Future<EngineStatus> status() async {
    statusCalls++;
    return engineStatus;
  }

  @override
  Future<ScriptSession> start(ScriptLoad load) async {
    loads.add(load);
    if (startError case final error?) throw error;
    final session = FakeScriptSession._(this, load);
    sessions.add(session);
    unawaited(
      Future(() async {
        final boot = this.boot;
        if (boot != null) return boot(session.module);
        session.module.ready(actions);
      }),
    );
    return session;
  }
}

class FakeScriptSession implements ScriptSession {
  FakeScriptSession._(this._engine, this.load) {
    _ready.future.ignore(); // nobody may await ready before a kill
  }

  final FakeScriptEngine _engine;
  final ScriptLoad load;
  late final module = FakeModule._(this);

  final _ready = Completer<List<String>>();
  final _messages = StreamController<ModuleMessage>();
  final _invokes = <int, Completer<Object?>>{};
  var _nextInvokeId = 0;

  final invocations = <FakeInvocation>[];
  final replies = <FakeReply>[];

  /// Replies sent after the kill: recorded (the `dead` answers and late
  /// harness results tests assert on) but never delivered.
  final repliesAfterKill = <FakeReply>[];

  /// The first kill reason, or null while alive.
  String? killedWith;
  bool get killed => killedWith != null;

  @override
  Future<List<String>> get ready => _ready.future;

  @override
  Stream<ModuleMessage> get messages => _messages.stream;

  @override
  Future<Object?> invoke(
    String action,
    Object? input,
    Map<String, Object?> ctx,
  ) {
    if (killedWith case final reason?) {
      return Future.error(ScriptFailure(reason, 'Sandbox killed: $reason'));
    }
    final id = ++_nextInvokeId;
    // What the module sees is what crossed the wire.
    final wire = jsonDecode(encodeInvoke(id, action, input, ctx)) as Map;
    final invocation = FakeInvocation(
      id,
      action,
      wire['input'],
      (wire['ctx'] as Map).cast<String, Object?>(),
    );
    invocations.add(invocation);
    final done = Completer<Object?>();
    _invokes[id] = done;
    unawaited(
      Future(() async {
        try {
          final value = await _engine.action?.call(module, invocation);
          module.send(
            jsonEncode({'t': 'done', 'id': id, 'ok': true, 'value': value}),
          );
        } catch (e, stack) {
          module.send(
            jsonEncode({
              't': 'done',
              'id': id,
              'ok': false,
              'error': {
                'code': 'module_error',
                'message': '$e',
                'stack': '$stack',
              },
            }),
          );
        }
      }),
    );
    return done.future;
  }

  @override
  void reply(int callId, {Object? value, HarnessErrorJson? error}) {
    final reply = (callId: callId, value: value, error: error);
    if (killed) return repliesAfterKill.add(reply);
    replies.add(reply);
    module._receive(encodeResult(callId, value: value, error: error));
  }

  @override
  void kill(String reason) {
    if (killed) return;
    killedWith = reason;
    _failAll(ScriptFailure(reason, 'Sandbox killed: $reason'));
    _messages.close();
  }

  void _failAll(ScriptFailure failure) {
    if (!_ready.isCompleted) _ready.completeError(failure);
    for (final invoke in _invokes.values) {
      invoke.completeError(failure);
    }
    _invokes.clear();
  }

  void _fromModule(Object? raw) {
    if (killed) return;
    final ModuleFrame frame;
    try {
      frame = decodeFrame(raw);
    } on ProtocolViolation {
      kill('abuse');
      return;
    }
    switch (frame) {
      case ReadyFrame(:final actions):
        if (!_ready.isCompleted) _ready.complete(actions);
      case LoadErrorFrame(:final error):
        if (!_ready.isCompleted) _ready.completeError(error);
      case DoneFrame(:final id, :final value, :final error):
        final invoke = _invokes.remove(id);
        if (invoke == null) return;
        error == null ? invoke.complete(value) : invoke.completeError(error);
      case ModuleMessage():
        _messages.add(frame);
    }
  }
}

/// A `result` the host sent for a module call with `ok: false`.
final class FakeCallError implements Exception {
  const FakeCallError(this.error);
  final Map<String, Object?> error;
  String get code => error['code'] as String;

  @override
  String toString() => '$code: ${error['message']}';
}

/// The module side of a [FakeScriptSession]: what the SDK core would send.
class FakeModule {
  FakeModule._(this._session);

  final FakeScriptSession _session;
  final _calls = <int, Completer<Object?>>{};
  var _nextCallId = 0;

  /// Any raw frame, through [decodeFrame] like a real engine's transport.
  void send(Object? raw) => _session._fromModule(raw);

  void ready(List<String> actions) =>
      send(jsonEncode({'t': 'ready', 'actions': actions}));

  void loadError(String message, {String? stack}) => send(
    jsonEncode({
      't': 'loadError',
      'error': {'code': 'load_error', 'message': message, 'stack': stack},
    }),
  );

  /// An engine-level sandbox error (web `morkva-sandbox-error`): before
  /// ready it fails boot, after ready the in-flight invokes `module_error`.
  void sandboxError(String message) {
    if (_session.killed) return;
    _session._failAll(
      ScriptFailure(
        _session._ready.isCompleted ? 'module_error' : 'boot_error',
        message,
      ),
    );
  }

  /// `morkva.call`: completes with the reply's value or throws
  /// [FakeCallError]; never completes once the session is killed.
  Future<Object?> call(String op, [Map<String, Object?>? args]) {
    final id = ++_nextCallId;
    final result = Completer<Object?>();
    _calls[id] = result;
    send(jsonEncode({'t': 'call', 'id': id, 'op': op, 'args': args}));
    return result.future;
  }

  void log(String level, List<String> args) =>
      send(jsonEncode({'t': 'log', 'level': level, 'args': args}));

  void progress(num done, num total, {String? label}) => send(
    jsonEncode({
      't': 'progress',
      'done': done,
      'total': total,
      'label': ?label,
    }),
  );

  void _receive(String frame) {
    final json = jsonDecode(frame) as Map<String, Object?>;
    final result = _calls.remove((json['id'] as num).toInt());
    if (result == null) return;
    if (json['ok'] == true) {
      result.complete(json['value']);
    } else {
      result.completeError(
        FakeCallError((json['error'] as Map).cast<String, Object?>()),
      );
    }
  }
}

/// In-memory [CrashMarker]; [leftover] is what a restart would find.
class FakeCrashMarker implements CrashMarker {
  FakeCrashMarker([this._value]);

  ({String runId, String automationId})? _value;

  @override
  void set(String runId, String automationId) =>
      _value = (runId: runId, automationId: automationId);

  @override
  void clear() => _value = null;

  @override
  ({String runId, String automationId})? leftover() => _value;
}
