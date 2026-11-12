// QuickJS pulls in dart:ffi and dart:isolate, the web engine package:web, so
// each sits behind its own platform import.
export 'stub_script_engine.dart'
    if (dart.library.js_interop) 'script_engine_factory_web.dart'
    if (dart.library.io) 'script_engine_factory_io.dart'
    show PlatformEngine, platformScriptEngine;
