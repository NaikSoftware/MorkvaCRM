@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/features/inbox/reminders/reminder_platform.dart';
import 'package:morkva_crm/features/inbox/reminders/reminder_scheduler.dart';
import 'package:web/web.dart' as web;

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

  test('a key whose localStorage write throws reads from memory', () {
    final store = createReminderPlatform().store;
    final proto =
        (globalContext['Storage']! as JSObject)['prototype']! as JSObject;
    final setItem = proto['setItem'];
    final removeItem = proto['removeItem'];
    void restore() {
      proto['setItem'] = setItem;
      proto['removeItem'] = removeItem;
    }

    addTearDown(() {
      restore();
      web.window.localStorage.removeItem('morkva.full');
    });
    store.write('morkva.full', 'old');

    JSAny? full(JSAny? _, [JSAny? _]) => throw Exception('QuotaExceededError');
    proto['setItem'] = full.toJS;
    proto['removeItem'] = full.toJS;
    store.write('morkva.full', 'new');
    expect(store.read('morkva.full'), 'new');
    store.write('morkva.full', null);
    expect(store.read('morkva.full'), isNull);

    restore();
    store.write('morkva.full', 'back');
    expect(web.window.localStorage.getItem('morkva.full'), 'back');
    expect(store.read('morkva.full'), 'back');
  });
}
