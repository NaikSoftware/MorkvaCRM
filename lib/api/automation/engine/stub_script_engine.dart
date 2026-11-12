import '../../../core/automation/engine/protocol.dart';
import '../../../core/automation/engine/script_engine.dart';

/// Where no sandbox exists (desktop, tests): every run is skipped as
/// `engine_unavailable`.
final class StubScriptEngine implements ScriptEngine {
  const StubScriptEngine();

  @override
  Future<EngineStatus> status() async => EngineStatus.unavailable;

  @override
  Future<ScriptSession> start(ScriptLoad load) => throw const ScriptFailure(
    'engine_unavailable',
    "Automations can't run on this device",
  );
}

/// The engine, crash breadcrumb and run-doc `device` of this platform.
typedef PlatformEngine = ({
  ScriptEngine engine,
  CrashMarker? crashMarker,
  String device,
});

/// No platform engine here (the conditional import's fallback).
PlatformEngine platformScriptEngine() =>
    (engine: const StubScriptEngine(), crashMarker: null, device: 'web');
