// The docs/sdk examples on QuickJS through the real bridge on the seed
// workspace (the shared tests are in ../sdk_examples_rig.dart). Runs on the
// gcc-built host lib (tool/build_qjs_test_lib.sh); skipped unless
// FLUTTER_QJS_NEXT_LIBRARY is set.
@Tags(['qjs'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/api/automation/engine/quickjs/quickjs_script_engine.dart';

import '../sdk_examples_rig.dart';

void main() {
  final lib = Platform.environment['FLUTTER_QJS_NEXT_LIBRARY'] ?? '';
  final engine = QuickJsScriptEngine();
  sdkExampleTests(
    () => engine,
    skip: lib.isEmpty
        ? 'FLUTTER_QJS_NEXT_LIBRARY is unset (build it: '
              'tool/build_qjs_test_lib.sh)'
        : null,
  );
}
