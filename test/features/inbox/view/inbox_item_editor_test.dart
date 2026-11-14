import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/inbox/inbox.dart';
import 'package:morkva_crm/features/inbox/inbox.dart';
import 'package:morkva_crm/features/inbox/reminders/reminder_scheduler.dart';

import 'inbox_view_harness.dart';

void main() {
  late InboxRig rig;

  setUp(() => rig = InboxRig());
  tearDown(() => rig.dispose());

  const link = InboxLink(collectionId: 'orders', cardId: 'o1', label: '#1042');

  Future<void> open(
    WidgetTester tester,
    String title, {
    Size size = kWide,
  }) async {
    await rig.pump(tester, size: size);
    await tester.tap(find.text(title));
    await tester.pumpAndSettle();
    expect(find.text('Save'), findsOneWidget);
  }

  (String, String, Map<String, Object?>) lastWrite() => rig.repo.writes.last;

  group('save writes only the changed fields', () {
    setUp(
      () => rig.seed([
        item(
          't',
          'Pay invoice',
          due: DateTime(2026, 11, 14, 9, 30),
          reminders: const [15],
          link: link,
        ),
      ]),
    );

    testWidgets('title', (tester) async {
      await open(tester, 'Pay invoice');
      await tester.enterText(
        find.widgetWithText(TextField, 'Pay invoice'),
        'Pay the Textile Co invoice',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final (op, id, fields) = lastWrite();
      expect((op, id), ('update', 't'));
      expect(fields.keys.toSet(), {'title', 'updatedAt'});
      expect(fields['title'], 'Pay the Textile Co invoice');
      expect(find.text('Save'), findsNothing);
    });

    testWidgets('a date preset keeps the time', (tester) async {
      await open(tester, 'Pay invoice');
      expect(find.text('Sat 14 Nov'), findsOneWidget);
      expect(find.text('09:30'), findsWidgets);

      await tester.tap(find.text('Tomorrow'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final (_, _, fields) = lastWrite();
      expect(fields.keys.toSet(), {'dueAt', 'updatedAt'});
      expect(fields['dueAt'], DateTime(2026, 11, 15, 9, 30).toUtc());
    });

    testWidgets('reminders, kind and link', (tester) async {
      await open(tester, 'Pay invoice');
      await tester.tap(find.byTooltip('Add a reminder'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1 h before'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Note'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Remove link'));
      await tester.pumpAndSettle();
      expect(find.text('Link a card'), findsOneWidget);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      final (_, _, fields) = lastWrite();
      expect(fields.keys.toSet(), {'kind', 'reminders', 'link', 'updatedAt'});
      expect(fields['kind'], 'note');
      expect(fields['reminders'], [15, 60]);
      expect(fields['link'], isNull);
    });

    testWidgets('a × clears from anywhere in its 44 px box', (tester) async {
      await open(tester, 'Pay invoice');
      // 18 px above the glyph: outside the 28/32 px pill, inside 44.
      Future<void> tapAbove(String tooltip) async {
        await tester.tapAt(
          tester.getCenter(find.byTooltip(tooltip)) - const Offset(0, 18),
        );
        await tester.pumpAndSettle();
      }

      await tapAbove('Remove link');
      expect(find.text('Link a card'), findsOneWidget);
      await tapAbove('Clear time');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      final (_, _, fields) = lastWrite();
      expect(fields['link'], isNull);
      // All-day now: stored as UTC midnight.
      expect(fields['dueAt'], DateTime.utc(2026, 11, 14));
    });

    testWidgets('clearing the date drops time and reminders', (tester) async {
      await open(tester, 'Pay invoice');
      await tester.tap(find.byTooltip('Clear date'));
      await tester.pumpAndSettle();
      expect(find.text('No date'), findsOneWidget);
      expect(find.text('Set a date to add reminders'), findsOneWidget);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      final (_, _, fields) = lastWrite();
      expect(fields.keys.toSet(), {'dueAt', 'reminders', 'updatedAt'});
      expect(fields['dueAt'], isNull);
      expect(fields['reminders'], isEmpty);
    });

    testWidgets('unchanged: nothing is written', (tester) async {
      await open(tester, 'Pay invoice');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(rig.repo.writes, isEmpty);
    });

    testWidgets('dirty close asks to discard', (tester) async {
      await open(tester, 'Pay invoice');
      await tester.enterText(
        find.widgetWithText(TextField, 'Pay invoice'),
        'X',
      );
      await tester.pump();
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);

      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(find.text('Save'), findsNothing);
      expect(rig.repo.writes, isEmpty);
    });

    testWidgets('delete, then Undo restores it', (tester) async {
      await open(tester, 'Pay invoice');
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(lastWrite().$1, 'delete');
      expect(find.text('Pay invoice'), findsNothing);
      expect(find.text('Deleted'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect((lastWrite().$1, lastWrite().$2), ('create', 't'));
      expect(find.text('Pay invoice'), findsOneWidget);
    });

    testWidgets('phone: a sheet under a 40 px peek', (tester) async {
      await open(tester, 'Pay invoice', size: kPhone);
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(tester.getTopLeft(find.byType(BottomSheet)).dy, 40);
      expect(
        tester.widget<BottomSheet>(find.byType(BottomSheet)).showDragHandle,
        isNot(isTrue),
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Tomorrow'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(lastWrite().$3.keys.toSet(), {'dueAt', 'updatedAt'});
    });

    testWidgets('phone: the footer sits at the sheet bottom', (tester) async {
      await open(tester, 'Pay invoice', size: kPhone);
      expect(
        tester.getBottomLeft(find.text('Save')).dy,
        greaterThan(kPhone.height - 80),
      );
    });
  });

  testWidgets('a time turns all-day reminders into "At time"', (tester) async {
    rig.seed([
      item(
        'a',
        'All day',
        due: DateTime(2026, 11, 14),
        allDay: true,
        reminders: const [InboxReminders.morningOf],
      ),
    ]);
    await open(tester, 'All day');
    Finder inEditor(String text) => find.descendant(
      of: find.byType(InboxItemEditor),
      matching: find.text(text),
    );
    expect(inEditor('Morning of'), findsOneWidget);

    await tester.tap(find.byTooltip('Add a time'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(inEditor('09:00'), findsOneWidget);
    expect(inEditor('At time'), findsOneWidget);
    expect(inEditor('Morning of'), findsNothing);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final (_, _, fields) = lastWrite();
    expect(fields.keys.toSet(), {'dueAt', 'allDay', 'reminders', 'updatedAt'});
    expect(fields['dueAt'], DateTime(2026, 11, 14, 9).toUtc());
    expect(fields['allDay'], isFalse);
    expect(fields['reminders'], [InboxReminders.atTime]);
  });

  group('permission line', () {
    setUp(
      () => rig.seed([
        item('t', 'Dated', due: DateTime(2026, 11, 14), allDay: true),
        item('n', 'Undated', kind: InboxKind.note),
      ]),
    );

    testWidgets('default: "Turn on notifications" asks once', (tester) async {
      await open(tester, 'Dated');
      final rich = find.textContaining('Turn on notifications');
      expect(rich, findsOneWidget);
      // Morning of / Day before only for an all-day item.
      await tester.tap(find.byTooltip('Add a reminder'));
      await tester.pumpAndSettle();
      expect(find.text('Morning of'), findsOneWidget);
      expect(find.text('15 min before'), findsNothing);
      await tester.tap(find.byTooltip('Add a reminder'));
      await tester.pumpAndSettle();

      final span = tester.widget<Text>(rich).textSpan! as TextSpan;
      final link = span.children!.whereType<TextSpan>().firstWhere(
        (s) => s.text == 'Turn on notifications',
      );
      (link.recognizer! as TapGestureRecognizer).onTap!();
      await tester.pumpAndSettle();
      expect(rig.notifier.requests, 1);
      expect(
        find.text('Reminders pop up while Morkva is open in a tab.'),
        findsOneWidget,
      );
    });

    testWidgets('denied and undated', (tester) async {
      rig.notifier.permission = NotificationPermission.denied;
      await open(tester, 'Dated');
      expect(
        find.textContaining('Notifications are blocked for this site'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Undated'));
      await tester.pumpAndSettle();
      expect(find.text('Set a date to add reminders'), findsOneWidget);
      expect(
        find.textContaining('Notifications are blocked for this site'),
        findsNothing,
      );
    });
  });

  testWidgets('a new pre-linked item from showInboxItemEditor', (tester) async {
    await rig.pump(
      tester,
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showInboxItemEditor(
            context,
            link: link,
            now: clock,
            notifier: rig.notifier,
          ),
          child: const Text('Add to Inbox…'),
        ),
      ),
    );
    await tester.tap(find.text('Add to Inbox…'));
    await tester.pumpAndSettle();
    expect(find.text('Orders · #1042'), findsOneWidget);
    expect(find.text('No date'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Call');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final (op, id, json) = lastWrite();
    expect(op, 'create');
    final created = InboxItem.fromJson(id, json);
    expect(created.kind, InboxKind.task);
    expect(created.link, link);
    expect(created.dueAt, isNull);
    expect(created.assigneeUid, 'me');
  });
}
