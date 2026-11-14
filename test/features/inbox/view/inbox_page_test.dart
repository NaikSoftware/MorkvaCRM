import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/inbox/inbox.dart';
import 'package:morkva_crm/design/design.dart';
import 'package:morkva_crm/features/inbox/inbox.dart';
import 'package:morkva_crm/features/inbox/reminders/reminder_toast_host.dart';

import 'inbox_view_harness.dart';

void main() {
  late InboxRig rig;

  setUp(() => rig = InboxRig());
  tearDown(() => rig.dispose());

  group('sections', () {
    setUp(() {
      rig.seed([
        item('over', 'Call Iryna', due: DateTime(2026, 11, 12), allDay: true),
        item(
          'timed',
          'Pay invoice',
          due: DateTime(2026, 11, 14, 9, 30),
          reminders: const [15, 0],
        ),
        item(
          'allday',
          'Prepare samples',
          due: DateTime(2026, 11, 14),
          allDay: true,
        ),
        item('note', 'Door code 4512', kind: InboxKind.note),
        item('later', 'Ship order', due: DateTime(2026, 11, 16), allDay: true),
        item(
          'done',
          'Old done',
          due: DateTime(2026, 11, 10),
          allDay: true,
          done: true,
          doneAt: DateTime(2026, 11, 14, 8),
        ),
      ]);
    });

    testWidgets('today: overdue, the day, no date, completed collapsed', (
      tester,
    ) async {
      await rig.pump(tester);

      expect(find.text('OVERDUE · 1'), findsOneWidget);
      expect(find.text('2 d late'), findsOneWidget);
      expect(find.text('TODAY · 2'), findsOneWidget);
      expect(find.text('09:30'), findsOneWidget);
      expect(find.text('15 min +1'), findsOneWidget);
      expect(find.text('NO DATE · 1'), findsOneWidget);
      expect(find.text('Door code 4512'), findsOneWidget);
      expect(find.text('COMPLETED · 1'), findsOneWidget);
      expect(find.text('Old done'), findsNothing);
      expect(find.text('Ship order'), findsNothing);
      // Timed first, then all-day.
      expect(
        tester.getTopLeft(find.text('Pay invoice')).dy,
        lessThan(tester.getTopLeft(find.text('Prepare samples')).dy),
      );

      await tester.tap(find.text('COMPLETED · 1'));
      await tester.pumpAndSettle();
      expect(find.text('Old done'), findsOneWidget);
    });
  });

  testWidgets('another day: its section, no overdue; Today returns', (
    tester,
  ) async {
    rig.seed([
      item('over', 'Call Iryna', due: DateTime(2026, 11, 12), allDay: true),
      item('note', 'Door code 4512', kind: InboxKind.note),
    ]);
    await rig.pump(tester);

    await tester.tap(find.byKey(const ValueKey('week-day-2026-11-13')));
    await tester.pumpAndSettle();

    expect(find.text('FRI 13'), findsOneWidget);
    expect(find.text('Nothing for Fri 13'), findsOneWidget);
    expect(find.text('OVERDUE · 1'), findsNothing);
    // AC8: a note shows under No date on every day.
    expect(find.text('Door code 4512'), findsOneWidget);

    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();
    expect(find.text('OVERDUE · 1'), findsOneWidget);
    expect(find.text('Nothing for today'), findsOneWidget);
  });

  testWidgets('week strip: weeks move, Today is disabled on today, ring', (
    tester,
  ) async {
    rig.seed([
      item('a', 'A', due: DateTime(2026, 11, 15), allDay: true),
      item('b', 'B', due: DateTime(2026, 11, 15), allDay: true),
    ]);
    await rig.pump(tester);

    OutlinedButton today() =>
        tester.widget(find.widgetWithText(OutlinedButton, 'Today'));
    expect(today().onPressed, isNull);
    expect(find.text('November 2026'), findsOneWidget);

    await tester.tap(find.byTooltip('Next week'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('week-day-2026-11-21')), findsOneWidget);
    expect(find.byKey(const ValueKey('week-day-2026-11-14')), findsNothing);
    expect(find.text('SAT 21'), findsOneWidget);
    expect(today().onPressed, isNotNull);

    await tester.tap(find.byTooltip('Previous week'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Previous week'));
    await tester.pumpAndSettle();
    expect(find.text('SAT 7'), findsOneWidget);

    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('week-day-2026-11-15')));
    await tester.pumpAndSettle();

    ShapeBorder shapeOf(String key) =>
        tester.widget<Material>(find.byKey(ValueKey(key))).shape!;
    final ring =
        (shapeOf('week-day-2026-11-14') as RoundedRectangleBorder).side;
    expect(ring.width, 2);
    expect(
      (shapeOf('week-day-2026-11-13') as RoundedRectangleBorder).side,
      BorderSide.none,
    );
    expect(
      tester
          .widget<Material>(find.byKey(const ValueKey('week-day-2026-11-15')))
          .color,
      AppTheme.light.colorScheme.primary,
    );
    expect(find.text('SUN 15 · 2'), findsOneWidget);
    expect(find.bySemanticsLabel('Sun 15 Nov, 2 open'), findsOneWidget);
  });

  testWidgets('week strip: a disabled Today reads as disabled', (tester) async {
    await rig.pump(tester);
    final scheme = AppTheme.light.colorScheme;
    final style = tester
        .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Today'))
        .style!;
    const off = {WidgetState.disabled};
    expect(
      style.foregroundColor!.resolve(off),
      scheme.onSurface.withValues(alpha: 0.38),
    );
    expect(
      style.side!.resolve(off)!.color,
      scheme.outline.withValues(alpha: 0.38),
    );
    expect(style.side!.resolve({})!.color, scheme.outline);
  });

  for (final (locale, month) in [
    (null, 'November 2026'),
    (const Locale('uk'), 'листопад 2026'),
  ]) {
    testWidgets('phone: "$month" gets all the width beside ‹ Today ›', (
      tester,
    ) async {
      await rig.pump(tester, size: kPhone, locale: locale);
      // The test font's 1 em glyphs overflow any phone row, so check the
      // label takes all the free width (the real font fits in it) rather
      // than half of it.
      final button = find.ancestor(
        of: find.text(month),
        matching: find.byType(TextButton),
      );
      expect(
        tester.getRect(button).right,
        moreOrLessEquals(
          tester
              .getRect(find.widgetWithIcon(IconButton, MorkvaIcons.chevronLeft))
              .left,
          epsilon: 2,
        ),
      );
    });
  }

  testWidgets('the month picker opens on a day outside its range', (
    tester,
  ) async {
    await rig.pump(tester, day: DateTime(1990));
    await tester.tap(find.text('January 1990'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(DatePickerDialog), findsOneWidget);
  });

  group('composer', () {
    Future<void> type(WidgetTester tester, String text) async {
      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), text);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
    }

    InboxItem created() {
      final (op, id, json) = rig.repo.writes.last;
      expect(op, 'create');
      return InboxItem.fromJson(id, json);
    }

    testWidgets('Enter adds a task for the selected day and keeps focus', (
      tester,
    ) async {
      await rig.pump(tester);
      expect(find.text('Add a task for Sat 14…'), findsOneWidget);

      await type(tester, '  Buy fabric ');

      final task = created();
      expect(task.kind, InboxKind.task);
      expect(task.title, 'Buy fabric');
      expect(task.dueAt, allDayDue(DateTime(2026, 11, 14)));
      expect(task.allDay, isTrue);
      expect(task.createdBy, 'me');
      expect(find.text('Buy fabric'), findsOneWidget); // listed
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, isEmpty);
      expect(field.focusNode!.hasFocus, isTrue);
    });

    testWidgets('blank does nothing', (tester) async {
      await rig.pump(tester);
      await type(tester, '   ');
      expect(rig.repo.writes, isEmpty);
    });

    testWidgets('a note defaults to no date; toggling flips back', (
      tester,
    ) async {
      await rig.pump(tester);
      await tester.tap(find.byTooltip('Task — switch to note'));
      await tester.pumpAndSettle();
      expect(find.text('Add a note…'), findsOneWidget);

      await type(tester, 'Door code');
      final note = created();
      expect(note.kind, InboxKind.note);
      expect(note.dueAt, isNull);

      await tester.tap(find.byTooltip('Note — switch to task'));
      await tester.pumpAndSettle();
      await type(tester, 'Call');
      expect(created().dueAt, allDayDue(DateTime(2026, 11, 14)));
    });

    testWidgets('a touched date survives the kind toggle', (tester) async {
      await rig.pump(tester);
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sat 14').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tomorrow'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Task — switch to note'));
      await tester.pumpAndSettle();

      await type(tester, 'Courier');
      final note = created();
      expect(note.kind, InboxKind.note);
      expect(note.dueAt, allDayDue(DateTime(2026, 11, 15)));
    });

    testWidgets('a past day defaults the task to today', (tester) async {
      await rig.pump(tester, day: DateTime(2026, 11, 10));
      expect(find.text('Add a task for today…'), findsOneWidget);
      await type(tester, 'Late idea');
      expect(created().dueAt, allDayDue(DateTime(2026, 11, 14)));
    });

    testWidgets('reminder chip sets reminders; a link chip links a card', (
      tester,
    ) async {
      await rig.pump(tester);
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Reminder'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Morning of'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Link a card'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Orders'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('#1042'));
      await tester.pumpAndSettle();
      expect(find.text('Orders · #1042'), findsOneWidget);

      await type(tester, 'Ship it');
      final task = created();
      expect(task.reminders, [InboxReminders.morningOf]);
      expect(
        task.link,
        const InboxLink(collectionId: 'orders', cardId: 'o1', label: '#1042'),
      );
    });
  });

  testWidgets('done moves to Completed with Undo', (tester) async {
    rig.seed([
      item('t', 'Prepare samples', due: DateTime(2026, 11, 14), allDay: true),
    ]);
    await rig.pump(tester);

    await tester.tap(find.byTooltip('Mark done'));
    await tester.pumpAndSettle();
    expect(rig.repo.writes.last.$3['done'], isTrue);
    expect(find.text('COMPLETED · 1'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(rig.repo.writes.last.$3['done'], isFalse);
    expect(find.text('TODAY · 1'), findsOneWidget);
    expect(find.text('COMPLETED · 1'), findsNothing);
  });

  testWidgets('move all to today, then Undo', (tester) async {
    final due = DateTime(2026, 11, 11, 9, 30);
    rig.seed([item('o', 'Call Iryna', due: due)]);
    await rig.pump(tester);

    await tester.tap(find.text('Move all to today'));
    await tester.pumpAndSettle();
    expect(
      rig.repo.writes.last.$3['dueAt'],
      DateTime(2026, 11, 14, 9, 30).toUtc(),
    );
    expect(find.text('OVERDUE · 1'), findsNothing);
    expect(find.text('Moved 1 task to today'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(rig.repo.writes.last.$3['dueAt'], due.toUtc());
    expect(find.text('OVERDUE · 1'), findsOneWidget);
  });

  testWidgets('first run, loading and load error with Retry', (tester) async {
    await rig.pump(tester);
    expect(find.text('Your Inbox is empty'), findsOneWidget);

    rig.repo.failWatch();
    await tester.pumpAndSettle();
    expect(find.text("Couldn't load your Inbox."), findsOneWidget);

    rig.repo.recover();
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Your Inbox is empty'), findsOneWidget);
  });

  testWidgets('a failed write shows one snackbar, from the shell host', (
    tester,
  ) async {
    await rig.pump(
      tester,
      home: ReminderToastHost(
        child: InboxPage(now: clock, notifier: rig.notifier),
      ),
    );
    rig.repo.failWrites = Exception('denied');
    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'X');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.textContaining("Couldn't save — "), findsOneWidget);
  });

  testWidgets('the page alone no longer reports failed writes', (tester) async {
    await rig.pump(tester);
    rig.repo.failWrites = Exception('denied');
    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'X');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.textContaining("Couldn't save — "), findsNothing);
  });

  testWidgets('speaks Ukrainian under the uk locale', (tester) async {
    rig.seed([
      item('o', 'Call Iryna', due: DateTime(2026, 11, 12), allDay: true),
      item('n', 'Door code', kind: InboxKind.note),
    ]);
    await rig.pump(tester, locale: const Locale('uk'));
    expect(find.text('Вхідні'), findsOneWidget);
    expect(find.text('ПРОСТРОЧЕНІ · 1'), findsOneWidget);
    expect(find.text('СЬОГОДНІ'), findsOneWidget);
    expect(find.text('БЕЗ ДАТИ · 1'), findsOneWidget);
    expect(find.text('Перенести всі на сьогодні'), findsOneWidget);
    expect(find.text('2 дн. прострочено'), findsOneWidget);
    expect(find.text('листопад 2026'), findsOneWidget);
    expect(find.text('сб'), findsOneWidget);
  });

  testWidgets('itemId opens its editor; an unknown id opens nothing', (
    tester,
  ) async {
    rig.seed([item('t', 'Prepare samples')]);
    await rig.pump(tester, itemId: 't');
    expect(find.text('Save'), findsOneWidget);
  });

  testWidgets('?item leaves the URL when its editor closes, so the same '
      'link opens it again', (tester) async {
    rig.seed([item('t', 'Prepare samples')]);
    await rig.pump(tester, location: '/?day=2026-11-14&item=t');
    expect(find.text('Save'), findsOneWidget);
    String location() =>
        rig.router.routerDelegate.currentConfiguration.uri.toString();
    expect(location(), '/?day=2026-11-14&item=t', reason: 'kept while open');

    Navigator.of(tester.element(find.byType(InboxItemEditor))).pop();
    await tester.pumpAndSettle();
    expect(location(), '/?day=2026-11-14');

    rig.router.go('/?day=2026-11-14&item=t');
    await tester.pumpAndSettle();
    expect(find.text('Save'), findsOneWidget);
  });

  testWidgets('?item missing from the cached list opens once the server '
      'list has it', (tester) async {
    await rig.pump(tester, location: '/?item=t', fromCache: true);
    expect(find.text('Save'), findsNothing);

    rig.repo.seed([item('t', 'Prepare samples')]);
    await tester.pumpAndSettle();
    expect(find.text('Save'), findsOneWidget);
  });

  testWidgets('an unknown itemId opens nothing', (tester) async {
    rig.seed([item('t', 'Prepare samples')]);
    await rig.pump(tester, itemId: 'nope');
    expect(find.text('Save'), findsNothing);
  });

  testWidgets('phone: meta under the title, label-only link chip', (
    tester,
  ) async {
    rig.seed([
      item(
        't',
        'Pay invoice',
        due: DateTime(2026, 11, 14, 15),
        reminders: const [0],
        link: const InboxLink(
          collectionId: 'orders',
          cardId: 'o1',
          label: '#1042',
        ),
      ),
    ]);
    await rig.pump(tester, size: kPhone);
    expect(find.text('Inbox'), findsNothing); // the shell's header
    expect(find.text('#1042'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('At time')).dy,
      greaterThan(tester.getBottomLeft(find.text('Pay invoice')).dy - 1),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('840 px: a long title and link label do not overflow', (
    tester,
  ) async {
    rig.seed([
      item(
        't',
        'A very long title ' * 10,
        due: DateTime(2026, 11, 14, 15),
        reminders: const [0, 15],
        link: InboxLink(
          collectionId: 'orders',
          cardId: 'o1',
          label: 'A long card label ' * 10,
        ),
      ),
    ]);
    await rig.pump(tester, size: const Size(840, 700));
    expect(tester.takeException(), isNull);
  });
}
