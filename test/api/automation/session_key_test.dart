import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/api/automation/session_key.dart';
import 'package:morkva_crm/api/automation/session_key_stub.dart';

void main() {
  test('one session id per app start off web', () {
    expect(sessionKey, startsWith('t_'));
    expect(sessionKey, same(sessionKey));
    expect(mintSessionKey(), isNot(sessionKey));
  });
}
