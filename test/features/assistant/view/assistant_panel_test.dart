import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/agent/agent_event.dart'
    show FailedItem, Receipt;
import 'package:morkva_crm/design/design.dart';
import 'package:morkva_crm/features/assistant/bloc/assistant_state.dart';
import 'package:morkva_crm/features/assistant/bloc/chat_item.dart';
import 'package:morkva_crm/features/assistant/view/assistant_page.dart';
import 'package:morkva_crm/features/assistant/view/assistant_panel.dart';
import 'package:morkva_crm/features/assistant/view/thread_list_page.dart';
import 'package:morkva_crm/features/assistant/view/widgets/chat_list.dart';
import 'package:morkva_crm/features/assistant/view/widgets/chat_view.dart';

import '../fakes/assistant_seeds.dart';
import '../fakes/fake_assistant_bloc.dart';
import 'assistant_view_harness.dart';

void main() {
  late RecordingActions actions;

  setUp(() => actions = RecordingActions());

  test(
    'a turn reads intro first: trailing intro text goes above its table',
    () {
      const user = UserItem(id: 'u', text: 'Unpaid orders?');
      const steps = StepsItem(id: 's', steps: []);
      const table = TableItem(id: 't', title: 'Unpaid');
      const chart = ChartItem(id: 'c', title: 'By month');
      const intro = AssistantTextItem(id: 'x', text: 'Here are the 2 orders:');
      const after = AssistantTextItem(id: 'y', text: 'Both are from October.');
      List<String> ids(List<ChatItem> items) => [
        for (final i in displayOrder(items)) i.id,
      ];

      expect(ids([user, steps, table, intro]), ['u', 's', 'x', 't']);
      // The turn's only text moves too, above the first result.
      expect(ids([user, steps, table, chart, after]), [
        'u',
        's',
        'y',
        't',
        'c',
      ]);
      // A closing remark after an intro stays below; text first stays first.
      expect(ids([user, table, after, intro]), ['u', 'x', 't', 'y']);
      expect(ids([user, intro, table, after]), ['u', 'x', 't', 'y']);
      // Turns are separate: a later turn's text never crosses its question.
      expect(
        ids([user, table, const UserItem(id: 'u2', text: 'And?'), after]),
        ['u', 't', 'u2', 'y'],
      );
    },
  );

  test('the undo snackbar names the count and the verb, not the title', () {
    String text(String title, int n, {List<FailedItem> failed = const []}) =>
        snackText(
          PlanView(planId: 'p', title: title),
          Receipt(
            planId: 'p',
            applied: [for (var i = 0; i < n; i++) 'i$i'],
            failed: failed,
            summary: title,
          ),
        );
    expect(text('Set Status to Done · 14 orders', 12), '12 orders updated');
    expect(text('Clear Notes · 3 orders', 3), '3 orders updated');
    expect(text('Update 3 orders', 1), '1 order updated');
    expect(text('Add 3 orders', 3), '3 orders created');
    expect(
      text('Delete 2 cards from “Big Co”', 2),
      '2 cards from “Big Co” deleted',
    );
    // Not a card plan, or partly failed: the receipt's own summary.
    expect(
      text('Create view “Late” in Orders', 1),
      'Create view “Late” in Orders',
    );
    expect(
      text(
        'Update 3 orders',
        2,
        failed: const [FailedItem('i9', 'offline', 'Needs a connection')],
      ),
      'Update 3 orders',
    );
  });

  group('AssistantPanel', () {
    testWidgets('is 440 px wide and shows the thread title', (tester) async {
      await pumpPanel(tester, FakeAssistantBloc.main(), actions: actions);
      await tester.pumpAndSettle();

      expect(tester.getSize(find.byType(AssistantPanel)).width, 440);
      expect(find.text('Ask Morkva'), findsOneWidget);
      expect(find.text('Unpaid orders this month'), findsOneWidget);
    });

    testWidgets('opens at the latest message', (tester) async {
      await pumpPanel(tester, FakeAssistantBloc.main(), actions: actions);
      await tester.pumpAndSettle();

      // The pending plan (last item) is on screen; the first question has
      // scrolled away.
      expect(find.text('Approve 3 changes'), findsOneWidget);
      final approve = tester.getRect(find.text('Approve 3 changes'));
      expect(approve.bottom, lessThan(900 - 150));
      expect(find.text('Jump to latest'), findsNothing);
    });

    testWidgets('shows "Jump to latest" after scrolling up, and returns', (
      tester,
    ) async {
      await pumpPanel(tester, FakeAssistantBloc.main(), actions: actions);
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ListView), const Offset(0, 400));
      await tester.pumpAndSettle();
      expect(find.text('Jump to latest'), findsOneWidget);

      await tester.tap(find.text('Jump to latest'));
      await tester.pumpAndSettle();
      expect(find.text('Jump to latest'), findsNothing);
      expect(find.text('Approve 3 changes'), findsOneWidget);
    });

    testWidgets('Esc and the close button close it', (tester) async {
      var closed = 0;
      await pumpPanel(
        tester,
        FakeAssistantBloc.empty(),
        actions: actions,
        autofocus: true,
        onClose: () => closed++,
      );
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      expect(closed, 1);

      await tester.tap(find.byTooltip('Close assistant'));
      expect(closed, 2);
    });

    testWidgets('autofocus puts the cursor in the composer', (tester) async {
      await pumpPanel(
        tester,
        FakeAssistantBloc.empty(),
        actions: actions,
        autofocus: true,
      );
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.focusNode!.hasFocus, isTrue);
    });

    testWidgets('"New conversation" shows once there are messages', (
      tester,
    ) async {
      final bloc = FakeAssistantBloc.empty();
      await pumpPanel(tester, bloc, actions: actions);
      await tester.pumpAndSettle();
      expect(find.byTooltip('New conversation'), findsNothing);

      bloc.set(AssistantSeeds.main());
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('New conversation'));
      expect(actions.calls, ['newThread()']);
    });

    testWidgets('a newly applied plan raises the undo snackbar', (
      tester,
    ) async {
      final full = AssistantSeeds.analyze(now: testNow);
      final applied = full.items.whereType<AppliedItem>().single;
      // The plan card being written, then replaced in place by its receipt.
      final bloc = FakeAssistantBloc(
        full.copyWith(
          items: [
            ...full.items.takeWhile((i) => i is! AppliedItem),
            PlanItem(
              id: applied.id,
              plan: applied.plan,
              selected: const {},
              status: PlanStatus.committing,
            ),
          ],
        ),
      );
      await pumpPanel(tester, bloc, actions: actions);
      // The committing card spins: pump instead of settling.
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(SnackBar), findsNothing);

      bloc.set(full);
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(SnackBar, '12 orders updated'),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(SnackBarAction, 'Undo'));
      expect(actions.calls, ['undo(j_done)']);
    });

    group('the undo snackbar', () {
      /// The analyze thread with its plan still committing, then applied.
      Future<(FakeAssistantBloc, AssistantState)> raise(
        WidgetTester tester,
      ) async {
        final full = AssistantSeeds.analyze(now: testNow);
        final applied = full.items.whereType<AppliedItem>().single;
        final bloc = FakeAssistantBloc(
          full.copyWith(
            items: [
              ...full.items.takeWhile((i) => i is! AppliedItem),
              PlanItem(
                id: applied.id,
                plan: applied.plan,
                selected: const {},
                status: PlanStatus.committing,
              ),
            ],
          ),
        );
        await pumpPanel(tester, bloc, actions: actions);
        await tester.pump(const Duration(seconds: 1));
        bloc.set(full);
        await tester.pumpAndSettle();
        expect(find.byType(SnackBar), findsOneWidget);
        return (bloc, full);
      }

      testWidgets('goes away by itself after 6 s', (tester) async {
        await raise(tester);
        // Undo stays on the applied card.
        expect(find.widgetWithText(SnackBarAction, 'Undo'), findsOneWidget);
        await tester.pump(const Duration(seconds: 5));
        expect(find.byType(SnackBar), findsOneWidget);
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();
        expect(find.byType(SnackBar), findsNothing);
        expect(find.text('Undo'), findsOneWidget);
      });

      testWidgets('never covers the latest card', (tester) async {
        await raise(tester);
        final last = tester.getRect(find.byType(ChatItemView).last);
        final bar = tester.getRect(find.byType(SnackBar));
        expect(last.bottom, lessThanOrEqualTo(bar.top));
      });

      testWidgets('hides as soon as a new plan is proposed', (tester) async {
        final (bloc, full) = await raise(tester);
        bloc.set(
          full.copyWith(
            items: [
              ...full.items,
              PlanItem.proposed(id: 'next', plan: AssistantSeeds.shipPlan),
            ],
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(SnackBar), findsNothing);
        // The new plan's buttons are in the clear.
        expect(find.text('Approve 3 changes').hitTestable(), findsOneWidget);
      });

      testWidgets('hides as soon as a message is sent', (tester) async {
        final (bloc, full) = await raise(tester);
        bloc.set(
          full.copyWith(
            items: [
              ...full.items,
              const UserItem(id: 'u_next', text: 'And the rest?'),
            ],
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(SnackBar), findsNothing);
      });
    });

    testWidgets('a thread loaded in two steps raises no snackbar', (
      tester,
    ) async {
      final bloc = FakeAssistantBloc.main();
      await pumpPanel(tester, bloc, actions: actions);
      await tester.pumpAndSettle();

      final other = AssistantSeeds.analyze(now: testNow);
      bloc.set(other.copyWith(items: const []));
      await tester.pumpAndSettle();
      bloc.set(other);
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('an applied plan loaded with the thread raises no snackbar', (
      tester,
    ) async {
      await pumpPanel(
        tester,
        FakeAssistantBloc.analyze(now: testNow),
        actions: actions,
      );
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('the history pane lists threads and returns on pick', (
      tester,
    ) async {
      final threads = [
        for (final r in AssistantSeeds.threads(now: testNow))
          ThreadSummary.fromRecord(r),
      ];
      final picked = <String>[];
      await pumpPanel(
        tester,
        FakeAssistantBloc.main(),
        actions: actions,
        historyBuilder: (context, back) => ThreadListView(
          threads: threads,
          onSelect: (id) {
            picked.add(id);
            back();
          },
          onDelete: (_) {},
          now: () => testNow,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Conversation history'));
      await tester.pumpAndSettle();
      expect(find.text('Revenue by month'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget); // search, no composer

      await tester.tap(find.text('Revenue by month'));
      await tester.pumpAndSettle();
      expect(picked, ['t_revenue']);
      expect(find.text('Approve 3 changes'), findsOneWidget);
    });

    testWidgets('a disabled flag hides the chat and the composer', (
      tester,
    ) async {
      await pumpPanel(
        tester,
        FakeAssistantBloc(
          const AssistantState(availability: AvailabilityDisabledByFlag()),
        ),
        actions: actions,
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Ask Morkva isn’t enabled for your account.'),
        findsOneWidget,
      );
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('quota exhausted shows the daily banner without retry', (
      tester,
    ) async {
      await pumpPanel(
        tester,
        FakeAssistantBloc(
          AssistantSeeds.main().copyWith(
            phase: const IdlePhase(),
            availability: AvailabilityQuotaExhausted(DateTime(2026, 11, 11, 9)),
          ),
        ),
        actions: actions,
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Today’s free AI limit is used up. It resets at 09:00.'),
        findsOneWidget,
      );
      expect(find.text('Retry now'), findsNothing);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.enabled, isFalse);
    });

    testWidgets('dark theme renders the same chat', (tester) async {
      await pumpPanel(
        tester,
        FakeAssistantBloc.main(),
        actions: actions,
        theme: AppTheme.dark,
      );
      await tester.pumpAndSettle();
      expect(find.text('Approve 3 changes'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('AssistantPage (phone)', () {
    Future<void> pumpPage(
      WidgetTester tester,
      FakeAssistantBloc bloc, {
      VoidCallback? onBack,
      VoidCallback? onOpenHistory,
    }) async {
      await setSurface(tester, const Size(390, 844));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: AssistantPage(
            bloc: bloc,
            actions: actions,
            onBack: onBack ?? () {},
            onOpenHistory: onOpenHistory,
            now: () => testNow,
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('streams through the live text and shows Stop', (tester) async {
      final live = ValueNotifier(AssistantSeeds.phoneStreamingText);
      await pumpPage(tester, FakeAssistantBloc.phoneStreaming(live: live));

      expect(find.byTooltip('Stop generating'), findsOneWidget);
      expect(find.byKey(const ValueKey('assistant-caret')), findsOneWidget);

      live.value = '${live.value}, so reorder it first.';
      await tester.pump();
      expect(
        find.textContaining('so reorder it first.', findRichText: true),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip('Stop generating'));
      expect(actions.calls, ['stop()']);
    });

    testWidgets('"New conversation" follows availability', (tester) async {
      final bloc = FakeAssistantBloc.main();
      await pumpPage(tester, bloc);
      expect(find.byTooltip('New conversation'), findsOneWidget);

      bloc.set(bloc.state.copyWith(availability: const AvailabilityOffline()));
      await tester.pump();
      expect(find.byTooltip('New conversation'), findsNothing);

      bloc.set(bloc.state.copyWith(availability: const AvailabilityEnabled()));
      await tester.pump();
      expect(find.byTooltip('New conversation'), findsOneWidget);
    });

    testWidgets('back and history reach the host', (tester) async {
      var back = 0;
      var history = 0;
      await pumpPage(
        tester,
        FakeAssistantBloc.phoneStreaming(),
        onBack: () => back++,
        onOpenHistory: () => history++,
      );

      await tester.tap(find.byTooltip('Back'));
      await tester.tap(find.byTooltip('Conversation history'));
      expect((back, history), (1, 1));
    });

    testWidgets('uses 15 px message text', (tester) async {
      await pumpPage(tester, FakeAssistantBloc.phoneStreaming());
      final bubble = tester.widget<Text>(
        find.text('Which fabrics are running low?'),
      );
      expect(bubble.style?.fontSize, 15);
    });
  });
}
