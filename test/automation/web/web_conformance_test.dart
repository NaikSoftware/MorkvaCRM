@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/api/automation/engine/web/web_script_engine.dart';

import '../conformance/cases.dart';

void main() {
  final engine = WebScriptEngine();
  for (final c in kConformanceCases) {
    test(c.name, () async => c.verify(await runConformanceCase(engine, c)));
  }
}
