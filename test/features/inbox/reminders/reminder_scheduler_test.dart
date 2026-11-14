import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/inbox/inbox_item.dart';
import 'package:morkva_crm/features/inbox/reminders/reminder_scheduler.dart';

/// `localStorage` shared by all tabs; a write notifies only the other tabs,
/// like the browser's `storage` event.
class FakeBrowser {
  final data = <String, String>{};
  final _tabs = <FakeStore>[];

  FakeStore tab() {
    final s = FakeStore(this);
    _tabs.add(s);
    return s;
  }
}

class FakeStore implements ReminderStore {
  FakeStore(this.browser);

  final FakeBrowser browser;
  final _changes = StreamController<String>.broadcast(sync: true);

  @override
  String? read(String key) => browser.data[key];

  @override
  void write(String key, String? value) {
    value == null ? browser.data.remove(key) : browser.data[key] = value;
    for (final t in browser._tabs) {
      if (t != this) t._changes.add(key);
    }
  }

  @override
  Stream<String> get changes => _changes.stream;
}

class FakeAttention implements Attention {
  bool _focused = true;
  final _changes = StreamController<void>.broadcast(sync: true);

  @override
  bool get focused => _focused;

  set focused(bool v) {
    _focused = v;
    _changes.add(null);
  }

  /// Changes focus without the event (the scheduler reads it on its tick).
  void setQuietly(bool v) => _focused = v;

  @override
  Stream<void> get changes => _changes.stream;
}

class FakeNotifier implements SystemNotifier {
  NotificationPermission value = NotificationPermission.granted;
  bool succeeds = true;
  final shown = <({String tag, String title, String body})>[];
  final clicks = <void Function()>[];

  @override
  NotificationPermission get permission => value;

  @override
  Future<NotificationPermission> requestPermission() async => value;

  @override
  bool show({
    required String tag,
    required String title,
    required String body,
    required void Function() onClick,
  }) {
    if (!succeeds) return false;
    shown.add((tag: tag, title: title, body: body));
    clicks.add(onClick);
    return true;
  }
}

final t0 = DateTime.utc(2026, 11, 14, 10);

InboxItem task(
  String id, {
  required DateTime due,
  List<int> reminders = const [InboxReminders.atTime],
  bool done = false,
  DateTime? updated,
}) => InboxItem(
  id: id,
  kind: InboxKind.task,
  title: 'Task $id',
  dueAt: due,
  reminders: reminders,
  assigneeUid: 'u',
  createdBy: 'u',
  done: done,
  createdAt: _longAgo,
  updatedAt: updated ?? _longAgo,
);

final _longAgo = DateTime.utc(2026, 10);

String key(String id, DateTime at) => '$id@${at.millisecondsSinceEpoch}';

class Tab {
  Tab(this.browser, {DateTime Function()? now}) {
    scheduler = ReminderScheduler(
      now: now ?? () => clock,
      attention: attention,
      store: browser.tab(),
      notifier: notifier,
      bodyOf: (i) => 'body ${i.id}',
      onOpen: opened.add,
    );
  }

  final FakeBrowser browser;
  final attention = FakeAttention();
  final notifier = FakeNotifier();
  final opened = <String>[];
  late final ReminderScheduler scheduler;
  DateTime clock = t0;

  List<PendingReminder> get pending => scheduler.currentPending;
}

void main() {
  late FakeBrowser browser;
  late Tab tab;

  setUp(() {
    browser = FakeBrowser();
    tab = Tab(browser);
  });

  tearDown(() => tab.scheduler.dispose());

  /// Puts the mark at [last], then ticks at [now] with [items] loaded.
  void tickWindow(DateTime last, DateTime now, List<InboxItem> items) {
    browser.data[ReminderScheduler.lastTickKey] =
        '${last.millisecondsSinceEpoch}';
    tab.clock = now;
    tab.scheduler.updateItems(items);
  }

  test('first run sets the mark and fires nothing', () {
    tab.scheduler.updateItems([task('a', due: t0)]);

    expect(tab.pending, isEmpty);
    expect(tab.notifier.shown, isEmpty);
    expect(
      browser.data[ReminderScheduler.lastTickKey],
      '${t0.millisecondsSinceEpoch}',
    );
  });

  test('fires exactly the window (last, now]', () {
    final last = t0.subtract(const Duration(seconds: 20));
    tickWindow(last, t0, [
      task('atLast', due: last),
      task('inside', due: last.add(const Duration(milliseconds: 1))),
      task('atNow', due: t0),
      task('future', due: t0.add(const Duration(milliseconds: 1))),
    ]);

    expect(tab.pending.map((e) => e.itemId), ['inside', 'atNow']);
    expect(tab.pending.last.key, key('atNow', t0));
    expect(tab.pending.every((e) => !e.catchUp), isTrue);
    expect(
      browser.data[ReminderScheduler.lastTickKey],
      '${t0.millisecondsSinceEpoch}',
    );
  });

  test('a done task never fires', () {
    tickWindow(t0.subtract(const Duration(seconds: 20)), t0, [
      task('a', due: t0, done: true),
    ]);

    expect(tab.pending, isEmpty);
  });

  test('a reminder edited into the past does not fire', () {
    tickWindow(t0.subtract(const Duration(seconds: 20)), t0, []);
    tab.clock = t0.add(const Duration(seconds: 5));

    tab.scheduler.updateItems([
      task('a', due: t0.subtract(const Duration(minutes: 1))),
    ]);

    expect(tab.pending, isEmpty);
  });

  test('a fire time earlier than the item\'s last edit does not fire', () {
    final last = t0.subtract(const Duration(seconds: 20));
    final fire = t0.subtract(const Duration(seconds: 10));
    tickWindow(last, t0, [
      task(
        'edited',
        due: fire,
        updated: t0.subtract(const Duration(seconds: 1)),
      ),
      task('atEdit', due: fire, updated: fire),
    ]);

    expect(tab.pending.map((e) => e.itemId), ['atEdit']);
  });

  test('a cached list shows toasts but neither fires nor moves the mark '
      'until a server list arrives', () {
    final last = t0.subtract(const Duration(minutes: 1));
    final items = [task('a', due: t0.subtract(const Duration(seconds: 30)))];
    browser.data[ReminderScheduler.pendingKey] = jsonEncode({
      'entries': [
        PendingReminder(
          key: key('a', items[0].fireTimes.single),
          itemId: 'a',
          fireAt: items[0].fireTimes.single,
        ).toJson(),
      ],
    });
    browser.data[ReminderScheduler.lastTickKey] =
        '${last.millisecondsSinceEpoch}';

    tab.scheduler.updateItems(items, settled: false);
    expect(tab.pending.map((e) => e.itemId), ['a'], reason: 'shown');
    browser.data.remove(ReminderScheduler.pendingKey);
    tab.scheduler.updateItems(items, settled: false);
    tab.scheduler.tickNow();
    expect(tab.pending, isEmpty);
    expect(
      browser.data[ReminderScheduler.lastTickKey],
      '${last.millisecondsSinceEpoch}',
    );

    tab.scheduler.updateItems(items);
    expect(tab.pending.single.itemId, 'a');

    // Settled for good: a later cached list (offline) still fires.
    tab.clock = t0.add(const Duration(seconds: 20));
    tab.scheduler.updateItems([
      ...items,
      task('b', due: t0.add(const Duration(seconds: 10))),
    ], settled: false);
    expect(tab.pending.map((e) => e.itemId), ['a', 'b']);
  });

  test('the window is capped at 24 h and a long one is one catch-up group', () {
    tab.attention.setQuietly(false);
    tickWindow(t0.subtract(const Duration(hours: 48)), t0, [
      task('old', due: t0.subtract(const Duration(hours: 30))),
      task('a', due: t0.subtract(const Duration(hours: 23))),
      task('b', due: t0.subtract(const Duration(minutes: 1))),
    ]);

    expect(tab.pending.map((e) => e.itemId), unorderedEquals(['a', 'b']));
    expect(tab.pending.every((e) => e.catchUp), isTrue);
    expect(tab.notifier.shown, isEmpty);
  });

  test('a window just over 2 min is catch-up, 2 min exactly is not', () {
    tickWindow(t0.subtract(const Duration(minutes: 2)), t0, [
      task('a', due: t0),
    ]);
    expect(tab.pending.single.catchUp, isFalse);

    final later = t0.add(const Duration(minutes: 2, milliseconds: 1));
    tab.clock = later;
    tab.scheduler.updateItems([task('a', due: t0), task('b', due: later)]);
    expect(tab.pending.last.itemId, 'b');
    expect(tab.pending.last.catchUp, isTrue);
  });

  group('on fire', () {
    final last = t0.subtract(const Duration(seconds: 20));

    test('focused: a toast and no system notification', () {
      tickWindow(last, t0, [task('a', due: t0)]);

      expect(tab.pending.single.key, key('a', t0));
      expect(tab.notifier.shown, isEmpty);
    });

    test('unfocused + granted: one notification with the tag, no toast', () {
      tab.attention.setQuietly(false);
      tickWindow(last, t0, [task('a', due: t0)]);

      expect(tab.pending, isEmpty);
      expect(tab.notifier.shown, [
        (tag: key('a', t0), title: 'Task a', body: 'body a'),
      ]);
      tab.notifier.clicks.single();
      expect(tab.opened, ['a']);
    });

    test('unfocused + granted but show fails: a toast', () {
      tab.attention.setQuietly(false);
      tab.notifier.succeeds = false;
      tickWindow(last, t0, [task('a', due: t0)]);

      expect(tab.pending.single.key, key('a', t0));
    });

    for (final p in [
      NotificationPermission.denied,
      NotificationPermission.defaultState,
      NotificationPermission.unsupported,
    ]) {
      test('unfocused + ${p.name}: a toast', () {
        tab.attention.setQuietly(false);
        tab.notifier.value = p;
        tickWindow(last, t0, [task('a', due: t0)]);

        expect(tab.pending.single.key, key('a', t0));
        expect(tab.notifier.shown, isEmpty);
      });
    }
  });

  group('pending toasts', () {
    final last = t0.subtract(const Duration(seconds: 20));
    final items = [
      task('a', due: t0),
      task('b', due: t0.subtract(const Duration(seconds: 5))),
    ];

    test('dismissing in one tab closes it in the other', () async {
      final other = Tab(browser);
      addTearDown(other.scheduler.dispose);
      tab.scheduler.start();
      other.scheduler
        ..updateItems(items)
        ..start();
      tickWindow(last, t0, items);
      expect(other.pending.map((e) => e.itemId), ['a', 'b']);

      final seen = <List<String>>[];
      final sub = other.scheduler.pending.listen(
        (p) => seen.add([for (final e in p) e.itemId]),
      );
      addTearDown(sub.cancel);
      await pumpEventQueue();

      tab.scheduler.dismiss(key('a', t0));
      await pumpEventQueue();

      expect(tab.pending.map((e) => e.itemId), ['b']);
      expect(other.pending.map((e) => e.itemId), ['b']);
      expect(seen, [
        ['a', 'b'],
        ['b'],
      ]);

      other.scheduler.dismissItem('b');
      expect(tab.pending, isEmpty);
      expect(browser.data[ReminderScheduler.pendingKey], isNull);
    });

    test('a second tick of the same window does not duplicate', () {
      tickWindow(last, t0, items);
      tickWindow(last, t0, items);

      expect(tab.pending, hasLength(2));
    });

    test('vanish when the item is done, deleted or rescheduled', () {
      tickWindow(last, t0, items);
      expect(tab.pending, hasLength(2));

      tab.scheduler.updateItems([items[0].copyWith(done: true), items[1]]);
      expect(tab.pending.map((e) => e.itemId), ['b']);

      tab.scheduler.updateItems([items[0], items[1]]);
      expect(tab.pending, hasLength(2), reason: 'undone brings it back');

      tab.scheduler.updateItems([items[0]]);
      expect(tab.pending.map((e) => e.itemId), ['a']);

      tab.scheduler.updateItems([
        items[0].copyWith(dueAt: () => t0.add(const Duration(hours: 1))),
      ]);
      expect(tab.pending, isEmpty);
    });

    test('entries older than 7 days are dropped', () {
      tickWindow(last, t0, items);
      tab.clock = t0.add(const Duration(days: 7, seconds: 1));

      tab.scheduler.updateItems(items);

      expect(tab.pending, isEmpty);
    });

    test('a corrupt store reads as empty', () {
      browser.data[ReminderScheduler.pendingKey] = '{not json';
      browser.data[ReminderScheduler.lastTickKey] = 'x';

      tab.scheduler.updateItems(items);
      expect(tab.pending, isEmpty);

      tickWindow(last, t0, items);
      expect(tab.pending, hasLength(2));
    });

    test('nothing shows until the items load', () {
      tickWindow(last, t0, items);
      final fresh = Tab(browser);
      addTearDown(fresh.scheduler.dispose);

      fresh.scheduler.start();
      expect(fresh.pending, isEmpty);

      fresh.scheduler.updateItems([items[1]]);
      expect(fresh.pending.map((e) => e.itemId), ['b']);
    });

    test('the stream starts with the current list', () async {
      tickWindow(last, t0, items);

      expect(await tab.scheduler.pending.first, hasLength(2));
    });
  });

  test('a mark over 24 h ahead is reset without firing', () {
    tickWindow(t0.add(const Duration(days: 2)), t0, [task('a', due: t0)]);
    expect(
      browser.data[ReminderScheduler.lastTickKey],
      '${t0.millisecondsSinceEpoch}',
    );

    tab.clock = t0.add(const Duration(seconds: 20));
    tab.scheduler.updateItems([task('b', due: tab.clock)]);
    expect(tab.pending.single.itemId, 'b');
  });

  group('ticking', () {
    test('ticks on attention changes', () {
      tab.scheduler.start();
      tickWindow(t0.subtract(const Duration(seconds: 20)), t0, []);
      tab.scheduler.updateItems([
        task('a', due: t0.add(const Duration(seconds: 5))),
      ]);
      tab.clock = t0.add(const Duration(seconds: 6));

      tab.attention.focused = true;

      expect(tab.pending.single.itemId, 'a');
    });

    test('ticks every 20 s', () {
      fakeAsync((async) {
        final timed = Tab(browser, now: () => t0.add(async.elapsed));
        timed.scheduler
          ..updateItems([task('a', due: t0.add(const Duration(seconds: 30)))])
          ..start();

        async.elapse(const Duration(seconds: 20));
        expect(timed.pending, isEmpty);
        async.elapse(const Duration(seconds: 20));
        expect(timed.pending.single.itemId, 'a');
        timed.scheduler.dispose();
      });
    });

    test('waits for the first items before moving the mark', () {
      fakeAsync((async) {
        final away = t0.subtract(const Duration(hours: 1));
        browser.data[ReminderScheduler.lastTickKey] =
            '${away.millisecondsSinceEpoch}';
        final timed = Tab(browser, now: () => t0.add(async.elapsed));
        timed.scheduler.start();

        async.elapse(const Duration(minutes: 1));
        expect(
          browser.data[ReminderScheduler.lastTickKey],
          '${away.millisecondsSinceEpoch}',
        );

        timed.scheduler.updateItems([
          task('a', due: t0.subtract(const Duration(minutes: 30))),
          task('b', due: t0.subtract(const Duration(minutes: 10))),
        ]);
        expect(timed.pending.map((e) => e.catchUp), [true, true]);
        timed.scheduler.dispose();
      });
    });

    test('a clock moved back does not refire', () {
      tickWindow(t0.subtract(const Duration(seconds: 20)), t0, [
        task('a', due: t0),
      ]);
      tab.scheduler.dismiss(key('a', t0));

      tab.clock = t0.subtract(const Duration(minutes: 5));
      tab.scheduler.updateItems([task('a', due: t0)]);
      tab.clock = t0;
      tab.scheduler.updateItems([task('a', due: t0)]);

      expect(tab.pending, isEmpty);
    });
  });
}
