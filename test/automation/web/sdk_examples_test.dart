// The docs/sdk examples through the real web engine and bridge on the seed
// workspace (the shared tests are in ../sdk_examples_rig.dart).
@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/api/automation/engine/web/web_script_engine.dart';

import '../sdk_examples_rig.dart';

void main() {
  final engine = WebScriptEngine();
  sdkExampleTests(() => engine);
}
