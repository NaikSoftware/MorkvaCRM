// dart2js compiles a null check (`x!`) as a read of `x.toString`; on the
// sandbox's cross-origin window that read throws a SecurityError, so the
// handshake died in release builds while DDC (debug, chrome tests) passed.
// Web e2e 2026-11-12. No chrome test runs dart2js, hence a source check.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the web engine never null-checks a cross-origin window with !', () {
    final source = File(
      'lib/api/automation/engine/web/web_script_engine.dart',
    ).readAsStringSync();
    expect(source, isNot(matches(RegExp(r'(contentWindow|source)!'))));
  });
}
