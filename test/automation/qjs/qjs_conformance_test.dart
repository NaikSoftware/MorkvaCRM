// The engine conformance cases on QuickJS, through the gcc-built host lib
// (tool/build_qjs_test_lib.sh). Skipped unless FLUTTER_QJS_NEXT_LIBRARY is set.
@Tags(['qjs'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/api/automation/engine/quickjs/quickjs_script_engine.dart';

import '../conformance/cases.dart';

void main() {
  final lib = Platform.environment['FLUTTER_QJS_NEXT_LIBRARY'] ?? '';
  final skip = lib.isEmpty
      ? 'FLUTTER_QJS_NEXT_LIBRARY is unset (build it: tool/build_qjs_test_lib.sh)'
      : null;
  // ignore: avoid_print
  if (skip != null) print('QuickJS conformance skipped: $skip');
  final engine = QuickJsScriptEngine();
  for (final c in kConformanceCases) {
    test(
      c.name,
      () async => c.verify(await runConformanceCase(engine, c)),
      skip: skip,
    );
  }
}
