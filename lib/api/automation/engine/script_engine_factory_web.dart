import 'stub_script_engine.dart' show PlatformEngine;
import 'web/crash_marker_web.dart';
import 'web/web_script_engine.dart';

export 'stub_script_engine.dart' show PlatformEngine;

PlatformEngine platformScriptEngine() =>
    (engine: WebScriptEngine(), crashMarker: WebCrashMarker(), device: 'web');
