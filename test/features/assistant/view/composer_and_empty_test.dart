import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/features/assistant/bloc/assistant_focus.dart';
import 'package:morkva_crm/features/assistant/bloc/assistant_state.dart';
import 'package:morkva_crm/features/assistant/view/thread_list_page.dart';
import 'package:morkva_crm/features/assistant/view/widgets/composer.dart';
import 'package:morkva_crm/features/assistant/view/widgets/empty_chat.dart';

import '../fakes/assistant_seeds.dart';
import 'assistant_view_harness.dart';

void main() {
  late RecordingActions actions;

  setUp(() => actions = RecordingActions());

  group('Composer', () {
    Future<void> pump(WidgetTester tester, AssistantState state) =>
        pumpInScope(tester, Composer(state: state), actions: actions);

    testWidgets('Send is disabled until there is text, then sends and clears', (
      tester,
    ) async {
      await pump(tester, AssistantSeeds.empty());
      expect(
        find.text('Ask about your data, or tell me what to change…'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Send'));
      expect(actions.calls, isEmpty);

      await tester.enterText(find.byType(TextField), '  How many orders?  ');
      await tester.pump();
      await tester.tap(find.byTooltip('Send'));
      await tester.pump();
      expect(actions.calls, ['submit(How many orders?)']);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '',
      );
    });

    testWidgets('Enter sends; Shift+Enter does not', (tester) async {
      await pump(tester, AssistantSeeds.empty());
      await tester.enterText(find.byType(TextField), 'Revenue by month');
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
      expect(actions.calls, isEmpty);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(actions.calls, ['submit(Revenue by month)']);
    });

    testWidgets('a running turn turns Send into Stop, and back', (
      tester,
    ) async {
      final streaming = AssistantSeeds.phoneStreaming();
      await pump(tester, streaming);
      expect(find.byTooltip('Stop generating'), findsOneWidget);
      expect(find.byTooltip('Send'), findsNothing);
      await tester.tap(find.byTooltip('Stop generating'));
      expect(actions.calls, ['stop()']);

      await pump(tester, streaming.copyWith(phase: const IdlePhase()));
      expect(find.byTooltip('Send'), findsOneWidget);
      expect(find.byTooltip('Stop generating'), findsNothing);
      expect(find.text('Ask a follow-up…'), findsOneWidget);
    });

    testWidgets('a pending plan explains how to skip it', (tester) async {
      await pump(tester, AssistantSeeds.main());
      expect(
        find.text(
          'Approve or reject the changes above — or send a new message to '
          'skip them.',
        ),
        findsOneWidget,
      );
      // Sending is still allowed: it skips the plan.
      await tester.enterText(find.byType(TextField), 'Actually, wait');
      await tester.pump();
      await tester.tap(find.byTooltip('Send'));
      expect(actions.calls, ['submit(Actually, wait)']);
    });

    testWidgets('a pending deletion names its noun', (tester) async {
      await pump(tester, AssistantSeeds.schema(now: testNow));
      expect(
        find.text(
          'Approve or keep the orders above — or send a new message to skip '
          'them.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('while changes apply, Send waits', (tester) async {
      await pump(
        tester,
        AssistantSeeds.main().copyWith(phase: const ApplyingPhase(1, 3)),
      );
      expect(find.text('Applying changes…'), findsOneWidget);
      expect(find.byTooltip('Stop generating'), findsNothing);
      await tester.enterText(find.byType(TextField), 'Next');
      await tester.pump();
      await tester.tap(find.byTooltip('Send'));
      expect(actions.calls, isEmpty);
    });

    testWidgets('offline disables the field and says why', (tester) async {
      await pump(
        tester,
        AssistantSeeds.main().copyWith(
          phase: const IdlePhase(),
          availability: const AvailabilityOffline(),
        ),
      );
      expect(
        find.text('You’re offline — Ask Morkva needs a connection.'),
        findsOneWidget,
      );
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    });

    testWidgets('the focus chip shows and clears the context', (tester) async {
      await pump(
        tester,
        AssistantSeeds.empty().copyWith(
          focus: const AssistantFocus(
            page: FocusPage.collection,
            collectionId: 'c_orders',
            collectionName: 'Orders',
            viewName: 'Unpaid',
            shownCount: 23,
          ),
        ),
      );
      expect(
        find.text('Looking at: Orders › Unpaid · 23 shown'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Remove context'));
      expect(actions.calls, ['clearFocus()']);
    });
  });

  group('EmptyChat', () {
    testWidgets('greets by name and fills suggestions with collections', (
      tester,
    ) async {
      await pumpInScope(
        tester,
        SizedBox(height: 900, child: EmptyChat(state: AssistantSeeds.empty())),
        actions: actions,
      );
      expect(find.text('Hi Olena. What should we look at?'), findsOneWidget);
      expect(
        find.textContaining('I can read all 8 of your collections'),
        findsOneWidget,
      );
      for (final group in ['ASK', 'ANALYZE', 'ACT']) {
        expect(find.text(group), findsOneWidget);
      }
      await tester.tap(find.text('Orders by month this year'));
      expect(actions.calls, ['suggest(Orders by month this year)']);
    });

    testWidgets('suggestions do nothing while sending is off', (tester) async {
      await pumpInScope(
        tester,
        SizedBox(
          height: 900,
          child: EmptyChat(
            state: AssistantSeeds.empty().copyWith(
              availability: const AvailabilityOffline(),
            ),
          ),
        ),
        actions: actions,
      );
      await tester.tap(find.text('Orders by month this year'));
      expect(actions.calls, isEmpty);
    });

    testWidgets('consent: disclosure and "Enable Ask Morkva"', (tester) async {
      await pumpInScope(
        tester,
        SizedBox(
          height: 900,
          child: EmptyChat(state: AssistantSeeds.consent()),
        ),
        actions: actions,
      );
      expect(find.text('ASK'), findsNothing);
      expect(find.textContaining('free tier'), findsOneWidget);
      await tester.ensureVisible(find.text('Enable Ask Morkva'));
      await tester.pump();
      await tester.tap(find.text('Enable Ask Morkva'));
      expect(actions.calls, ['grantConsent()']);
    });

    test('suggestions without collections are plain starters', () {
      final groups = suggestionGroups(const []);
      expect(groups.map((g) => g.title), ['Ask', 'Act']);
      expect(
        groups.expand((g) => g.items).every((s) => !s.contains('null')),
        isTrue,
      );
    });

    test('one collection fills every template', () {
      final items = suggestionGroups(const ['Clients']).expand((g) => g.items);
      expect(items, everyElement(contains('Clients')));
    });
  });

  group('ThreadListView', () {
    final threads = [
      for (final r in AssistantSeeds.threads(now: testNow))
        ThreadSummary.fromRecord(r),
    ];

    Future<void> pump(
      WidgetTester tester, {
      List<ThreadSummary>? list,
      bool disabled = false,
      List<String>? picked,
      List<String>? deleted,
    }) => pumpInScope(
      tester,
      SizedBox(
        height: 700,
        child: ThreadListView(
          threads: list ?? threads,
          currentId: 't_unpaid',
          disabled: disabled,
          onSelect: (id) => picked?.add(id),
          onDelete: (id) => deleted?.add(id),
          now: () => testNow,
        ),
      ),
      actions: actions,
    );

    testWidgets('groups by day with time and snippet', (tester) async {
      await pump(tester);
      expect(find.text('TODAY'), findsOneWidget);
      expect(find.text('YESTERDAY'), findsOneWidget);
      expect(find.text('12:40 · 3 changes applied'), findsOneWidget);
      expect(find.text('16:00'), findsOneWidget); // no snippet
    });

    testWidgets('search filters by title and snippet', (tester) async {
      await pump(tester);
      await tester.enterText(find.byType(TextField), 'chart');
      await tester.pump();
      expect(find.text('Revenue by month'), findsOneWidget);
      expect(find.text('Unpaid orders this month'), findsNothing);

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pump();
      expect(find.text('No conversations match “zzz”.'), findsOneWidget);
    });

    testWidgets('delete asks first', (tester) async {
      final deleted = <String>[];
      await pump(tester, deleted: deleted);
      await tester.tap(find.byTooltip('Delete “Revenue by month”'));
      await tester.pumpAndSettle();
      expect(find.text('Delete this conversation?'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(deleted, ['t_revenue']);
    });

    testWidgets('while applying, picking is blocked', (tester) async {
      final picked = <String>[];
      await pump(tester, disabled: true, picked: picked);
      expect(find.textContaining('Applying changes…'), findsOneWidget);
      await tester.tap(find.text('Revenue by month'));
      expect(picked, isEmpty);
    });

    testWidgets('empty: "No conversations yet"', (tester) async {
      await pump(tester, list: const []);
      expect(find.text('No conversations yet'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });

    test('ThreadSummary reads the record shape', () {
      final t = ThreadSummary.fromRecord({
        'id': 't1',
        'title': '  ',
        'updatedAt': '2026-11-10T10:00:00Z',
        'lastSnippet': 'chart',
      });
      expect(t.title, 'New conversation');
      expect(t.snippet, 'chart');
      expect(t.updatedAt, DateTime.utc(2026, 11, 10, 10).toLocal());
      expect(
        () => ThreadSummary.fromRecord({'title': 'x'}),
        throwsFormatException,
      );
    });

    test('dayLabel', () {
      expect(dayLabel(testNow, testNow), 'Today');
      expect(dayLabel(DateTime(2026, 11, 9, 23), testNow), 'Yesterday');
      expect(dayLabel(DateTime(2026, 11, 3), testNow), '3 Nov');
      expect(dayLabel(DateTime(2025, 12, 31), testNow), '31 Dec 2025');
    });
  });
}
