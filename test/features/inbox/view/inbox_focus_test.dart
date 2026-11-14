import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/features/inbox/inbox.dart';
import 'package:morkva_crm/features/inbox/reminders/reminder_scheduler.dart';
import 'package:morkva_crm/features/inbox/reminders/reminder_toast_host.dart';

import 'inbox_view_harness.dart';

class _Store implements ReminderStore {
  final data = <String, String>{};

  @override
  String? read(String key) => data[key];

  @override
  void write(String key, String? value) =>
      value == null ? data.remove(key) : data[key] = value;

  @override
  Stream<String> get changes => const Stream.empty();
}

class _Focused implements Attention {
  @override
  bool get focused => true;

  @override
  Stream<void> get changes => const Stream.empty();
}

void main() {
  late InboxRig rig;
  late ReminderScheduler scheduler;

  // Web uses mouse semantics: the field drops focus on a tap outside.
  final desktop = TargetPlatformVariant.only(TargetPlatform.linux);

  setUp(() => rig = InboxRig());
  tearDown(() async {
    scheduler.dispose();
    await rig.dispose();
  });

  /// 11:00 today: the fired reminders' time.
  final fired = DateTime(2026, 11, 14, 11);

  /// The Inbox page under the toast host, with [toasts] fired. Focus
  /// history: the composer must not come back once the user clicked away.
  Future<void> pump(
    WidgetTester tester, {
    List<String> toasts = const [],
  }) async {
    final store = _Store();
    store.data[ReminderScheduler.lastTickKey] =
        '${kNow.millisecondsSinceEpoch}';
    store.data[ReminderScheduler.pendingKey] = jsonEncode({
      'entries': [
        for (final id in toasts)
          PendingReminder(
            key: '$id@${fired.millisecondsSinceEpoch}',
            itemId: id,
            fireAt: fired,
            catchUp: false,
          ).toJson(),
      ],
    });
    scheduler = ReminderScheduler(
      now: clock,
      attention: _Focused(),
      store: store,
      notifier: rig.notifier,
      bodyOf: (i) => i.title,
      onOpen: (_) {},
    );
    await rig.pump(
      tester,
      home: RepositoryProvider.value(
        value: scheduler,
        child: ReminderToastHost(
          child: InboxPage(now: clock, notifier: rig.notifier),
        ),
      ),
    );
    scheduler.updateItems(rig.inbox.items);
    await tester.pumpAndSettle();
  }

  FocusNode composer(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField)).focusNode!;

  /// The browser takes focus out of the Flutter view (another window, the
  /// semantics DOM): Flutter parks focus on the root scope.
  void blurView(WidgetTester tester) => tester.binding.handleViewFocusChanged(
    ViewFocusEvent(
      viewId: tester.view.viewId,
      state: ViewFocusState.unfocused,
      direction: ViewFocusDirection.undefined,
    ),
  );

  /// Focus the composer; focus leaves the view; the user clicks the empty
  /// page below the sections.
  Future<void> focusThenClickOutside(WidgetTester tester) async {
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(composer(tester).hasFocus, isTrue);
    blurView(tester);
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(700, 880));
    await tester.pumpAndSettle();
    expect(composer(tester).hasFocus, isFalse);
  }

  /// A click on a web button focuses it when semantics are on.
  Future<void> click(WidgetTester tester, Finder button) async {
    Focus.of(tester.element(button)).requestFocus();
    await tester.pump();
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets('Done on a reminder toast leaves the composer unfocused', (
    tester,
  ) async {
    rig.seed([
      item('a', 'Pay invoice', due: fired, reminders: const [0]),
    ]);
    await pump(tester, toasts: ['a']);
    await focusThenClickOutside(tester);

    await click(tester, find.text('Done'));
    expect(find.text('Done'), findsNothing); // the toast is gone
    expect(composer(tester).hasFocus, isFalse);
  }, variant: desktop);

  testWidgets('a row checkbox leaves the composer unfocused', (tester) async {
    rig.seed([
      item('t', 'Prepare samples', due: DateTime(2026, 11, 14), allDay: true),
    ]);
    await pump(tester);
    await focusThenClickOutside(tester);

    await click(tester, find.byTooltip('Mark done'));
    expect(find.text('COMPLETED · 1'), findsOneWidget);
    expect(composer(tester).hasFocus, isFalse);
  }, variant: desktop);

  testWidgets('a chip menu pick keeps a focused composer focused', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sat 14').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tomorrow'));
    await tester.pumpAndSettle();
    expect(find.text('Sun 15'), findsWidgets);
    expect(composer(tester).hasFocus, isTrue);
  }, variant: desktop);

  testWidgets('a hovered chip menu pick gives the composer focus back', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sat 14').last);
    await tester.pumpAndSettle();
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.text('Tomorrow')));
    await tester.pumpAndSettle();
    expect(composer(tester).hasFocus, isFalse); // the hovered item has it
    await mouse.down(tester.getCenter(find.text('Tomorrow')));
    await mouse.up();
    await tester.pumpAndSettle();
    expect(composer(tester).hasFocus, isTrue);
  }, variant: desktop);

  group('a picker', () {
    Future<void> pickTime(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Time'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    }

    testWidgets('gives a focused composer its focus back', (tester) async {
      await pump(tester);
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      await pickTime(tester);
      expect(composer(tester).hasFocus, isTrue);
    }, variant: desktop);

    testWidgets('leaves an unfocused composer unfocused', (tester) async {
      await pump(tester);
      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'Ship'); // chips stay
      await tester.tapAt(const Offset(700, 880));
      await tester.pumpAndSettle();
      expect(composer(tester).hasFocus, isFalse);
      await pickTime(tester);
      expect(composer(tester).hasFocus, isFalse);
    }, variant: desktop);
  });
}
