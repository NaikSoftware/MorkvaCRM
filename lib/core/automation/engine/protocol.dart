// The frame protocol between a module sandbox and the host, shared by both
// engines (web, QuickJS) and the bridge. Frames are JSON strings in both
// directions; everything a module sends is untrusted until [decodeFrame]
// has typed it.
import 'dart:convert';

// --- Caps (spec "Bridge rules" 5) -------------------------------------------

/// A module frame longer than this (UTF-16 code units) kills the sandbox.
const kMaxFrameChars = 1024 * 1024;

/// JSON nesting deeper than this kills the sandbox.
const kMaxFrameDepth = 64;

const kMaxFramesPerSecond = 2000;
const kMaxCallArgsBytes = 256 * 1024;
const kMaxRunArgsBytes = 2 * 1024 * 1024;
const kMaxCallsInFlight = 8;
const kMaxHeavyReadsInFlight = 2;
const kMaxCallsPerRun = 500;
const kMaxHarnessTimePerRun = Duration(seconds: 5);
const kMaxLogLinesPerRun = 500;
const kMaxLogLineChars = 500;
const kMaxProgressPerSecond = 10;
const kMaxProgressLabelChars = 60;
const kMaxPendingTimers = 100;
const kMaxReturnValueBytes = 16 * 1024;

/// From `start` to the module's `ready` frame.
const kBootBudget = Duration(seconds: 5);
const kScriptMemoryLimitBytes = 64 * 1024 * 1024;

/// The error a host `result` frame carries: `HarnessError.toJson()` after
/// the bridge's rewriting (`{code, message, details?, path?, candidates?}`).
typedef HarnessErrorJson = Map<String, Object?>;

/// A sandbox run that ended without a value: boot or load failed, the action
/// threw, or the session was killed (then [code] is the kill reason, e.g.
/// `timeout`, `cancelled`, `abuse`, `limit_exceeded`).
final class ScriptFailure implements Exception {
  const ScriptFailure(this.code, this.message, {this.stack});

  /// `load_error`, `boot_error`, `module_error` or a kill reason.
  final String code;
  final String message;
  final String? stack;

  @override
  String toString() => 'ScriptFailure($code: $message)';
}

/// A module frame that breaks the protocol: the host kills the sandbox and
/// fails the run `abuse`.
final class ProtocolViolation implements Exception {
  const ProtocolViolation(this.message);

  final String message;

  @override
  String toString() => 'ProtocolViolation: $message';
}

// --- module → host ----------------------------------------------------------

sealed class ModuleFrame {
  const ModuleFrame();
}

/// The frames a [ScriptSession] streams to the bridge (everything but
/// `ready`, `loadError` and `done`, which the session itself consumes).
sealed class ModuleMessage extends ModuleFrame {
  const ModuleMessage();
}

/// `{t:'ready', actions:[id]}`
final class ReadyFrame extends ModuleFrame {
  const ReadyFrame(this.actions);
  final List<String> actions;
}

/// `{t:'loadError', error}`
final class LoadErrorFrame extends ModuleFrame {
  const LoadErrorFrame(this.error);

  /// Code `load_error`.
  final ScriptFailure error;
}

/// `{t:'done', id, ok, value | error}`
final class DoneFrame extends ModuleFrame {
  const DoneFrame(this.id, {this.value, this.error});
  final int id;
  final Object? value;

  /// Set when the action threw; code `module_error`.
  final ScriptFailure? error;
  bool get ok => error == null;
}

/// A well-formed `{t:'call', id, op, args}`.
final class CallFrame extends ModuleMessage {
  const CallFrame(this.id, this.op, this.args);
  final int id;
  final String op;
  final Map<String, Object?>? args;
}

/// A `call` whose `op` or `args` is malformed. It is not abuse: the bridge
/// answers it `invalid_args` (bridge rule 2), or drops it when [id] is null
/// because there is nothing to answer.
final class InvalidCallFrame extends ModuleMessage {
  const InvalidCallFrame(this.id, this.reason);
  final int? id;
  final String reason;
}

/// `{t:'log', level, args:[string]}`
final class LogFrame extends ModuleMessage {
  const LogFrame(this.level, this.args);

  /// One of [kLogLevels].
  final String level;
  final List<String> args;
}

const kLogLevels = {'log', 'info', 'warn', 'error', 'debug'};

/// `{t:'progress', done, total, label?}`
final class ProgressFrame extends ModuleMessage {
  const ProgressFrame(this.done, this.total, this.label);
  final num done;
  final num total;
  final String? label;
}

/// Types a raw module frame or throws [ProtocolViolation] when it is not a
/// string, longer than [kMaxFrameChars], not JSON, nested deeper than
/// [kMaxFrameDepth], or not a map with a known `t`. Size and depth are
/// checked before `jsonDecode`, so a hostile frame never reaches the parser.
/// Known frames with malformed fields are violations too (only the trusted
/// SDK core builds frames), except `call`: see [InvalidCallFrame].
ModuleFrame decodeFrame(Object? raw) {
  if (raw is! String) throw const ProtocolViolation('Frame is not a string');
  if (raw.length > kMaxFrameChars) {
    throw const ProtocolViolation('Frame is too large');
  }
  if (_tooDeep(raw)) throw const ProtocolViolation('Frame is nested too deep');
  final Object? json;
  try {
    json = jsonDecode(raw);
  } on FormatException {
    throw const ProtocolViolation('Frame is not JSON');
  }
  if (json is! Map<String, Object?>) {
    throw const ProtocolViolation('Frame is not an object');
  }
  return switch (json['t']) {
    'ready' => ReadyFrame(_strings(json['actions'], 'actions')),
    'loadError' => LoadErrorFrame(_failure(json['error'], 'load_error')),
    'done' => _done(json),
    'call' => _call(json),
    'log' => _log(json),
    'progress' => _progress(json),
    _ => throw const ProtocolViolation('Unknown frame type'),
  };
}

DoneFrame _done(Map<String, Object?> json) {
  final id = _id(json['id']);
  if (id == null) throw const ProtocolViolation('done: bad id');
  return switch (json['ok']) {
    true => DoneFrame(id, value: json['value']),
    false => DoneFrame(id, error: _failure(json['error'], 'module_error')),
    _ => throw const ProtocolViolation('done: ok is not a bool'),
  };
}

ModuleMessage _call(Map<String, Object?> json) {
  final id = _id(json['id']);
  final op = json['op'];
  final args = json['args'];
  if (id == null) return const InvalidCallFrame(null, 'id is not an integer');
  if (op is! String || op.isEmpty) {
    return InvalidCallFrame(id, 'op is not a string');
  }
  if (args != null && args is! Map<String, Object?>) {
    return InvalidCallFrame(id, 'args is not an object');
  }
  return CallFrame(id, op, args as Map<String, Object?>?);
}

LogFrame _log(Map<String, Object?> json) {
  final level = json['level'];
  if (level is! String || !kLogLevels.contains(level)) {
    throw const ProtocolViolation('log: bad level');
  }
  return LogFrame(level, _strings(json['args'], 'args'));
}

ProgressFrame _progress(Map<String, Object?> json) {
  final done = json['done'];
  final total = json['total'];
  final label = json['label'];
  if (done is! num || total is! num || (label != null && label is! String)) {
    throw const ProtocolViolation('progress: bad fields');
  }
  return ProgressFrame(done, total, label as String?);
}

/// Ids arrive as `num`: dart2js has no ints, so `3` may decode as `3.0`.
int? _id(Object? v) =>
    v is num && v.isFinite && v == v.truncateToDouble() ? v.toInt() : null;

List<String> _strings(Object? v, String name) {
  if (v is List && v.every((e) => e is String)) return List.unmodifiable(v);
  throw ProtocolViolation('$name is not a list of strings');
}

ScriptFailure _failure(Object? v, String code) {
  if (v is! Map<String, Object?>) {
    throw const ProtocolViolation('error is not an object');
  }
  final message = v['message'];
  final stack = v['stack'];
  return ScriptFailure(
    code,
    message is String ? message : 'Error',
    stack: stack is String ? stack : null,
  );
}

/// Whether [s] nests `[`/`{` deeper than [kMaxFrameDepth], brackets inside
/// JSON strings not counted. A linear scan: a recursive walk after decoding
/// would overflow the stack on a 1 MB frame of `[`.
bool _tooDeep(String s) {
  var depth = 0;
  var inString = false;
  for (var i = 0; i < s.length; i++) {
    final c = s.codeUnitAt(i);
    if (inString) {
      if (c == 0x5C) {
        i++; // skip the escaped char
      } else if (c == 0x22) {
        inString = false;
      }
    } else if (c == 0x22) {
      inString = true;
    } else if (c == 0x5B || c == 0x7B) {
      if (++depth > kMaxFrameDepth) return true;
    } else if (c == 0x5D || c == 0x7D) {
      depth--;
    }
  }
  return false;
}

// --- host → module ----------------------------------------------------------

/// `{t:'invoke', id, action, input, ctx}`
String encodeInvoke(
  int id,
  String action,
  Object? input,
  Map<String, Object?> ctx,
) => jsonEncode({
  't': 'invoke',
  'id': id,
  'action': action,
  'input': input,
  'ctx': ctx,
});

/// `{t:'result', id, ok, value | error}`; ok when [error] is null.
String encodeResult(int id, {Object? value, HarnessErrorJson? error}) =>
    jsonEncode({
      't': 'result',
      'id': id,
      'ok': error == null,
      if (error == null) 'value': value else 'error': error,
    });

/// `{t:'timer', id}`: local to the QuickJS adapter, never crosses isolates.
String encodeTimer(int id) => jsonEncode({'t': 'timer', 'id': id});
