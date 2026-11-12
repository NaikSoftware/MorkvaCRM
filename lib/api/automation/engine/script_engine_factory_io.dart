import 'dart:io' show Platform;

import 'quickjs/quickjs_script_engine.dart';
import 'stub_script_engine.dart';

export 'stub_script_engine.dart' show PlatformEngine;

/// QuickJS on Android and iOS; desktop and tests get the stub (no bundled
/// QuickJS library there).
PlatformEngine platformScriptEngine() => Platform.isAndroid || Platform.isIOS
    ? (
        engine: QuickJsScriptEngine(),
        crashMarker: null,
        device: Platform.isIOS ? 'ios' : 'android',
      )
    : (engine: const StubScriptEngine(), crashMarker: null, device: 'web');
