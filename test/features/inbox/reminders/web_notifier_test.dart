@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/features/inbox/reminders/reminder_platform.dart';
import 'package:morkva_crm/features/inbox/reminders/reminder_scheduler.dart';

void main() {
  test('the web platform reads permission, focus and localStorage', () {
    final p = createReminderPlatform();

    expect(NotificationPermission.values, contains(p.notifier.permission));
    expect(p.attention.focused, isA<bool>());
    final subs = [
      p.attention.changes.listen((_) {}),
      p.store.changes.listen((_) {}),
    ];
    addTearDown(() => Future.wait([for (final s in subs) s.cancel()]));
    // Headless Chrome is never granted, but show must not throw either way.
    expect(
      p.notifier.show(tag: 't@1', title: 'T', body: 'B', onClick: () {}),
      isA<bool>(),
    );

    p.store.write('morkva.test', 'v');
    expect(p.store.read('morkva.test'), 'v');
    p.store.write('morkva.test', null);
    expect(p.store.read('morkva.test'), isNull);
  });
}
