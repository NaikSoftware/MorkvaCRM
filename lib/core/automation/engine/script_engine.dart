// The engine seam (D1). Implementations live in lib/api/automation/engine
// (web sandbox, QuickJS, stub). `actor`, `grants` and `turnId` are absent on
// purpose: only the bridge holds them.
import 'protocol.dart';

enum EngineStatus { available, unavailable }

abstract interface class ScriptEngine {
  /// Probed lazily at the first run and cached per session; any thrown
  /// Object (an FFI load failure is a StateError) means [unavailable].
  Future<EngineStatus> status();

  /// A fresh sandbox running [ScriptLoad.sdkCore] then [ScriptLoad.code].
  /// Never reused across runs.
  Future<ScriptSession> start(ScriptLoad load);
}

final class ScriptLoad {
  const ScriptLoad({
    required this.moduleId,
    required this.code,
    required this.sdkCore,
    required this.memoryLimitBytes,
    required this.budget,
  });

  final String moduleId;
  final String code;
  final String sdkCore;

  /// [kScriptMemoryLimitBytes] unless a test says otherwise.
  final int memoryLimitBytes;

  /// The run's wall-clock timeout (manifest `timeoutMs`); timers inside the
  /// sandbox are clamped to what is left of it.
  final Duration budget;
}

abstract interface class ScriptSession {
  /// Registered action ids, or throws [ScriptFailure] (`load_error`,
  /// `boot_error`, or the kill reason when killed first).
  Future<List<String>> get ready;

  /// Sends `{t:'invoke'}`; completes with the action's value or throws
  /// [ScriptFailure] (`module_error` with the stack, or the kill reason).
  Future<Object?> invoke(
    String action,
    Object? input,
    Map<String, Object?> ctx,
  );

  /// Decoded module frames other than `done` and `ready`: calls, logs,
  /// progress. Closes when the session is killed.
  Stream<ModuleMessage> get messages;

  /// Answers a module `call`. Ignored once killed.
  void reply(int callId, {Object? value, HarnessErrorJson? error});

  /// Idempotent; rejects `ready` and in-flight invokes with
  /// `ScriptFailure(reason)`. A frame that fails [decodeFrame] kills the
  /// session with `abuse`.
  void kill(String reason);
}

/// A per-device breadcrumb that survives a tab crash (web: localStorage;
/// elsewhere a no-op).
abstract interface class CrashMarker {
  /// Before invoke; never throws.
  void set(String runId, String automationId);

  /// At finish.
  void clear();

  ({String runId, String automationId})? leftover();
}
