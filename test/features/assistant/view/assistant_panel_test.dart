import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/design/design.dart';
import 'package:morkva_crm/features/assistant/bloc/assistant_state.dart';
import 'package:morkva_crm/features/assistant/bloc/chat_item.dart';
import 'package:morkva_crm/features/assistant/view/assistant_page.dart';
import 'package:morkva_crm/features/assistant/view/assistant_panel.dart';
import 'package:morkva_crm/features/assistant/view/thread_list_page.dart';

import '../fakes/assistant_seeds.dart';
import '../fakes/fake_assistant_bloc.dart';
import 'assistant_view_harness.dart';

void main() {
  late RecordingActions actions;

  setUp(() => actions = RecordingActions());

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
