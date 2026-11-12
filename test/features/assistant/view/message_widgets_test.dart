import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/agent/agent_event.dart';
import 'package:morkva_crm/features/assistant/bloc/assistant_state.dart';
import 'package:morkva_crm/features/assistant/bloc/chat_item.dart';
import 'package:morkva_crm/features/assistant/view/widgets/applied_card.dart';
import 'package:morkva_crm/features/assistant/view/widgets/assistant_text.dart';
import 'package:morkva_crm/features/assistant/view/widgets/error_row.dart';
import 'package:morkva_crm/features/assistant/view/widgets/limit_banner.dart';
import 'package:morkva_crm/features/assistant/view/widgets/object_chip.dart';
import 'package:morkva_crm/features/assistant/view/widgets/result_chart_card.dart';
import 'package:morkva_crm/features/assistant/view/widgets/result_table_card.dart';
import 'package:morkva_crm/features/assistant/view/widgets/tool_steps.dart';

import '../fakes/assistant_seeds.dart';
import 'assistant_view_harness.dart';

T _item<T extends ChatItem>(AssistantState state) =>
    state.items.whereType<T>().first;

void main() {
  late RecordingActions actions;

  setUp(() => actions = RecordingActions());

  group('AssistantText', () {
    test('boldSpans renders ** as bold and hides the markers', () {
      final spans = boldSpans('Five orders have **Paid** unticked.');
      expect(spans.map((s) => s.text), [
        'Five orders have ',
        'Paid',
        ' unticked.',
      ]);
      expect(spans[1].style?.fontWeight, FontWeight.w700);
      expect(spans[0].style, isNull);
    });

    test('an unclosed ** (mid-stream) bolds the rest', () {
      final spans = boldSpans('The lowest is **Linen, sa');
      expect(spans.last.text, 'Linen, sa');
      expect(spans.last.style?.fontWeight, FontWeight.w700);
    });

    testWidgets('stopped and cut-short answers say so', (tester) async {
      await pumpInScope(
        tester,
        const Column(
          children: [
            AssistantText(
              item: AssistantTextItem(id: 'a', text: 'Half', stopped: true),
            ),
            AssistantText(
              item: AssistantTextItem(id: 'b', text: 'Long', cutShort: true),
            ),
          ],
        ),
        actions: actions,
      );
      expect(find.text('Stopped'), findsOneWidget);
      expect(find.text('Cut short — ask me to continue'), findsOneWidget);
      expect(find.byKey(const ValueKey('assistant-caret')), findsNothing);
    });
  });

  group('ToolSteps', () {
    testWidgets('done steps collapse to the headline and expand on tap', (
      tester,
    ) async {
      await pumpInScope(
        tester,
        ToolSteps(item: _item<StepsItem>(AssistantSeeds.main())),
        actions: actions,
      );
      expect(
        find.text('Looked at Orders · filtered 148 → 5 · summed Total'),
        findsOneWidget,
      );

      await tester.tap(find.byType(ToolSteps));
      await tester.pump();
      expect(find.text('filtered 148 → 5'), findsOneWidget);
      expect(find.text('summed Total'), findsOneWidget);
    });

    testWidgets('a running step keeps the list open with the step in bold', (
      tester,
    ) async {
      await pumpInScope(
        tester,
        ToolSteps(item: _item<StepsItem>(AssistantSeeds.phoneStreaming())),
        actions: actions,
      );
      final running = tester.widget<Text>(
        find.text('Filtering 36 fabrics where Metres left < 5…'),
      );
      expect(running.style?.fontWeight, FontWeight.w600);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('a failed step shows its reason', (tester) async {
      await pumpInScope(
        tester,
        const ToolSteps(
          item: StepsItem(
            id: 's',
            steps: [
              StepView(
                callId: 'r1',
                label: 'Reading Orders…',
                status: StepStatus.failed,
                summary: 'no such field “Paid on”',
                errorCode: 'unknown_field',
              ),
            ],
          ),
        ),
        actions: actions,
      );
      await tester.tap(find.byType(ToolSteps));
      await tester.pump();
      expect(
        find.text('Reading Orders — no such field “Paid on”'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    });
  });

  group('ResultTableCard', () {
    testWidgets('renders rows, chips and the totals footer', (tester) async {
      await pumpInScope(
        tester,
        ResultTableCard(item: _item<TableItem>(AssistantSeeds.main())),
        actions: actions,
      );
      expect(find.text('1042'), findsOneWidget);
      expect(find.text('Iryna Melnyk'), findsOneWidget);
      expect(find.text('Total'), findsOneWidget);
      expect(find.text('₴ 9 840'), findsOneWidget);

      await tester.tap(find.text('1041'));
      expect(actions.calls, ['open(c_orders, o_1041, null)']);
    });

    testWidgets('"Open as filtered view" hands the item to the host', (
      tester,
    ) async {
      final item = _item<TableItem>(AssistantSeeds.main());
      await pumpInScope(tester, ResultTableCard(item: item), actions: actions);
      await tester.tap(find.text('Open as filtered view'));
      expect(actions.openedTables.single, item);
    });

    testWidgets('an aggregate table has no "Open as filtered view"', (
      tester,
    ) async {
      final main = _item<TableItem>(AssistantSeeds.main());
      await pumpInScope(
        tester,
        ResultTableCard(
          item: TableItem(
            id: 'x',
            title: 'Revenue by stage',
            spec: const {'kind': 'aggregate', 'collectionId': 'c_orders'},
            table: main.table,
          ),
        ),
        actions: actions,
      );
      expect(find.text('Open as filtered view'), findsNothing);
      expect(find.text('Copy table'), findsOneWidget);
    });

    testWidgets('the # tile marks numbers only, not names', (tester) async {
      await pumpInScope(
        tester,
        const ResultTableCard(
          item: TableItem(
            id: 'x',
            title: 'People',
            table: ResultTable(
              collectionId: 'c_people',
              columns: [ResultColumn('Name')],
              rows: [
                ResultRow(cardId: 'p1', cells: ['Iryna Melnyk']),
                ResultRow(cardId: 'p2', cells: ['ORD-0002']),
              ],
            ),
          ),
        ),
        actions: actions,
      );
      expect(find.byType(HashGlyph), findsOneWidget);
      expect(
        find.descendant(
          of: find.widgetWithText(ObjectChip, 'ORD-0002'),
          matching: find.byType(HashGlyph),
        ),
        findsOneWidget,
      );
    });

    testWidgets('"Copy table" puts tab-separated text on the clipboard', (
      tester,
    ) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await pumpInScope(
        tester,
        ResultTableCard(item: _item<TableItem>(AssistantSeeds.main())),
        actions: actions,
      );
      await tester.tap(find.text('Copy table'));
      await tester.pump();

      final lines = copied!.split('\n');
      expect(lines.first, '#\tClient\tDelivery\tTotal');
      expect(lines[1], '1042\tIryna Melnyk\tNova Poshta\t₴ 2 150');
      expect(lines.last, 'Total\t\t\t₴ 9 840');
      expect(find.text('Table copied'), findsOneWidget);
    });

    testWidgets('more rows than shown: "Showing 5 of 23"', (tester) async {
      final main = _item<TableItem>(AssistantSeeds.main());
      final t = main.table!;
      await pumpInScope(
        tester,
        ResultTableCard(
          item: TableItem(
            id: 'x',
            title: main.title,
            table: ResultTable(
              columns: t.columns,
              rows: t.rows,
              totalCount: 23,
              collectionId: t.collectionId,
            ),
          ),
        ),
        actions: actions,
      );
      expect(find.text('Showing 5 of 23'), findsOneWidget);
    });

    testWidgets('six columns scroll sideways inside the card', (tester) async {
      const columns = [
        ResultColumn('#'),
        ResultColumn('Client'),
        ResultColumn('City'),
        ResultColumn('Delivery'),
        ResultColumn('Status'),
        ResultColumn('Total', numeric: true),
      ];
      await pumpInScope(
        tester,
        const ResultTableCard(
          item: TableItem(
            id: 'x',
            title: 'Wide',
            table: ResultTable(
              collectionId: 'c',
              columns: columns,
              rows: [
                ResultRow(
                  cardId: 'o1',
                  cells: [
                    '1',
                    'A very long client name that is long',
                    'Kyiv',
                    'Nova Poshta',
                    'Packing',
                    '₴ 100',
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: actions,
      );
      expect(
        find.descendant(
          of: find.byType(ResultTableCard),
          matching: find.byWidgetPredicate(
            (w) =>
                w is SingleChildScrollView &&
                w.scrollDirection == Axis.horizontal,
          ),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a table not read yet shows a skeleton', (tester) async {
      await pumpInScope(
        tester,
        const ResultTableCard(
          item: TableItem(id: 'x', title: 'Unpaid'),
        ),
        actions: actions,
      );
      expect(find.text('Copy table'), findsNothing);
    });

    test('tableAsText flattens tabs and newlines in cells', () {
      const table = ResultTable(
        columns: [ResultColumn('A'), ResultColumn('B')],
        rows: [
          ResultRow(cells: ['x\ty', 'line\nbreak']),
        ],
      );
      expect(tableAsText(table), 'A\tB\nx y\tline break');
    });
  });

  group('ResultChartCard', () {
    testWidgets('labels the peak and the partial period', (tester) async {
      await pumpInScope(
        tester,
        ResultChartCard(
          item: _item<ChartItem>(AssistantSeeds.analyze(now: testNow)),
          collectionName: 'Orders',
        ),
        actions: actions,
      );
      expect(find.text('Revenue by month, 2026'), findsOneWidget);
      expect(find.text('Sum of Total, ₴'), findsOneWidget);
      expect(find.text('48.2k'), findsOneWidget);
      expect(find.text('so far'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('Bar chart: .*peak O at 48 200')),
        findsOneWidget,
      );
    });

    testWidgets('long axis labels wrap to 2 lines and keep their full text', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpInScope(
        tester,
        ResultChartCard(
          item: ChartItem(
            id: 'c',
            title: 'Orders by Status',
            chart: ResultChart(
              metricLabel: 'count',
              points: [
                for (final s in [
                  'Ordered',
                  'To clarify',
                  'Packing',
                  'Shipped',
                  'Waiting for payment',
                  'Done',
                ])
                  ChartPoint(s, 3),
              ],
            ),
          ),
        ),
        actions: actions,
      );
      final label = find.text('To clarify');
      expect(tester.widget<Text>(label).overflow, TextOverflow.ellipsis);
      expect(tester.widget<Text>(label).maxLines, 2);
      // Two words fit on two lines instead of "To cl…".
      expect(
        tester.renderObject<RenderParagraph>(label).didExceedMaxLines,
        isFalse,
      );
      // One word never breaks mid-word ("Ordere / d"): it ellipsizes on a
      // single line (seen in the live web chat, 2026-11-12).
      expect(tester.widget<Text>(find.text('Ordered')).maxLines, 1);
      expect(tester.widget<Text>(find.text('Shipped')).maxLines, 1);
      // A tie singles out no bar, but every bar keeps its height.
      expect(find.text('3'), findsNothing);
      expect(find.bySemanticsLabel(RegExp('peak')), findsNothing);
      expect(tester.takeException(), isNull);
      expect(
        find.ancestor(of: label, matching: find.byType(Tooltip)),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Tooltip>(
              find.ancestor(of: label, matching: find.byType(Tooltip)),
            )
            .message,
        'To clarify',
      );
      expect(
        find.bySemanticsLabel(RegExp('To clarify, Packing')),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('"Show as table" is the accessible fallback', (tester) async {
      await pumpInScope(
        tester,
        ResultChartCard(
          item: _item<ChartItem>(AssistantSeeds.analyze(now: testNow)),
        ),
        actions: actions,
      );
      await tester.tap(find.text('Show as table'));
      await tester.pump();
      expect(find.text('48 200'), findsOneWidget);
      expect(find.text('N (so far)'), findsOneWidget);
      expect(find.text('Show as chart'), findsOneWidget);
    });

    testWidgets('"Save as a view" asks the assistant', (tester) async {
      await pumpInScope(
        tester,
        ResultChartCard(
          item: _item<ChartItem>(AssistantSeeds.analyze(now: testNow)),
          collectionName: 'Orders',
        ),
        actions: actions,
      );
      await tester.tap(find.text('Save as a view on Orders'));
      expect(actions.calls, [
        'suggest(Save “Revenue by month, 2026” as a view on Orders)',
      ]);
    });

    testWidgets('a line chart paints without errors', (tester) async {
      final bar = _item<ChartItem>(AssistantSeeds.analyze(now: testNow));
      await pumpInScope(
        tester,
        ResultChartCard(
          item: ChartItem(
            id: 'l',
            title: bar.title,
            kind: PresentKind.line,
            chart: bar.chart,
          ),
        ),
        actions: actions,
      );
      expect(find.bySemanticsLabel(RegExp('^Line chart')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test('number formatting', () {
      expect(compactNumber(48200), '48.2k');
      expect(compactNumber(14000), '14k');
      expect(compactNumber(2500000), '2.5M');
      expect(compactNumber(512), '512');
      expect(groupedNumber(48200), '48 200');
      expect(groupedNumber(-1234567), '-1 234 567');
      expect(groupedNumber(12.5), '12.50');
    });
  });

  group('AppliedCard', () {
    testWidgets('counts down the undo window, then expires', (tester) async {
      var now = testNow;
      final applied = _item<AppliedItem>(AssistantSeeds.analyze(now: testNow));
      await pumpInScope(
        tester,
        AppliedCard(item: applied),
        actions: actions,
        now: () => now,
      );
      expect(
        find.text('You approved 12 of 14 · undo available for 9 min'),
        findsOneWidget,
      );

      now = testNow.add(const Duration(minutes: 5));
      await tester.pump(const Duration(seconds: 15));
      expect(
        find.text('You approved 12 of 14 · undo available for 4 min'),
        findsOneWidget,
      );

      await tester.tap(find.text('Undo'));
      expect(actions.calls, ['undo(j_done)']);

      now = testNow.add(const Duration(minutes: 10));
      await tester.pump(const Duration(seconds: 15));
      expect(find.text('You approved 12 of 14 · Undo expired'), findsOneWidget);
      expect(find.text('Undo'), findsNothing);
    });

    testWidgets('a schema change lists its fields with types', (tester) async {
      final applied = _item<AppliedItem>(AssistantSeeds.schema(now: testNow));
      await pumpInScope(tester, AppliedCard(item: applied), actions: actions);
      expect(find.text('Create “Suppliers” · 4 fields'), findsOneWidget);
      expect(
        find.text('Applied · Fabrics now shows Suppliers'),
        findsOneWidget,
      );
      expect(find.text('Select · Kyiv, Lviv, Odesa'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);
    });

    testWidgets('a reverted card trades the check for an undo tile', (
      tester,
    ) async {
      final applied = _item<AppliedItem>(AssistantSeeds.analyze(now: testNow));
      await pumpInScope(
        tester,
        AppliedCard(item: applied.copyWith(undoState: UndoState.undone)),
        actions: actions,
      );
      expect(find.byIcon(Icons.undo_rounded), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsNothing);
    });

    testWidgets('undone and partial failure states', (tester) async {
      final applied = _item<AppliedItem>(AssistantSeeds.analyze(now: testNow));
      await pumpInScope(
        tester,
        Column(
          children: [
            AppliedCard(
              item: applied.copyWith(
                undoState: UndoState.undone,
                undoNote: 'Reverted 12 orders',
              ),
            ),
            AppliedCard(
              item: AppliedItem(
                id: 'f',
                plan: const PlanView(planId: 'p_f', title: 'Set Status · 200'),
                receipt: const Receipt(
                  planId: 'p_f',
                  applied: ['a'],
                  failed: [FailedItem('b', 'offline', 'Needs a connection')],
                  summary: 'Updated 1',
                ),
              ),
            ),
          ],
        ),
        actions: actions,
      );
      expect(find.text('Reverted 12 orders'), findsOneWidget);
      expect(find.text('Updated 1, 1 failed'), findsOneWidget);
      await tester.tap(find.text('Retry failed'));
      expect(actions.calls, ['retryFailed(p_f)']);
    });

    testWidgets('a partly failed apply offers Undo and Retry failed at once', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      var now = testNow;
      final until = testNow.add(const Duration(minutes: 10));
      await pumpInScope(
        tester,
        AppliedCard(
          item: AppliedItem(
            id: 'f',
            plan: const PlanView(planId: 'p_f', title: 'Set Status · 200'),
            receipt: Receipt(
              planId: 'p_f',
              applied: [for (var i = 0; i < 190; i++) 'a$i'],
              failed: [
                for (var i = 0; i < 10; i++)
                  FailedItem('b$i', 'offline', 'Needs a connection'),
              ],
              journalId: 'j_f',
              undoUntil: until,
              summary: 'Updated 190 orders',
            ),
            undoUntil: until,
          ),
        ),
        actions: actions,
        now: () => now,
      );
      expect(
        find.text('Updated 190, 10 failed · undo available for 10 min'),
        findsOneWidget,
      );
      // The live region leaves the minute countdown out.
      expect(find.bySemanticsLabel('Updated 190, 10 failed'), findsOneWidget);

      now = testNow.add(const Duration(minutes: 2));
      await tester.pump(const Duration(seconds: 15));
      expect(
        find.text('Updated 190, 10 failed · undo available for 8 min'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Updated 190, 10 failed'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.tap(find.text('Retry failed'));
      expect(actions.calls, ['undo(j_f)', 'retryFailed(p_f)']);
      semantics.dispose();
    });

    testWidgets('Undo refused offline says so and keeps Undo', (tester) async {
      final semantics = tester.ensureSemantics();
      final applied = _item<AppliedItem>(AssistantSeeds.analyze(now: testNow));
      Future<void> show(AppliedItem item) =>
          pumpInScope(tester, AppliedCard(item: item), actions: actions);

      // As the bloc leaves it after an offline Undo.
      await show(applied.copyWith(undoNote: 'Needs a connection to undo'));
      expect(find.text('Needs a connection to undo'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Needs a connection to undo'),
        findsOneWidget,
      );
      expect(find.text('Undo'), findsOneWidget);

      // Undoing again (online): the note gives way to the spinner state.
      await show(
        applied.copyWith(
          undoState: UndoState.undoing,
          undoNote: 'Needs a connection to undo',
        ),
      );
      expect(find.text('Needs a connection to undo'), findsNothing);
      semantics.dispose();
    });

    testWidgets('a note from before a later receipt is dropped', (
      tester,
    ) async {
      final applied = _item<AppliedItem>(
        AssistantSeeds.analyze(now: testNow),
      ).copyWith(undoNote: 'Needs a connection');
      Future<void> show(AppliedItem item) =>
          pumpInScope(tester, AppliedCard(item: item), actions: actions);

      await show(applied);
      expect(find.text('Needs a connection'), findsOneWidget);

      // "Retry failed" then worked: a new receipt, the stale note kept.
      await show(
        applied.copyWith(
          receipt: Receipt(
            planId: applied.receipt.planId,
            applied: [...applied.receipt.applied, 'retried'],
            journalId: applied.receipt.journalId,
            undoUntil: applied.receipt.undoUntil,
            summary: 'Updated 13',
          ),
        ),
      );
      expect(find.text('Needs a connection'), findsNothing);
    });
  });

  group('ErrorRow', () {
    testWidgets('says nothing changed and retries', (tester) async {
      await pumpInScope(
        tester,
        ErrorRow(item: _item<ErrorItem>(AssistantSeeds.schema(now: testNow))),
        actions: actions,
      );
      expect(
        find.text(
          'The connection dropped before I finished. Nothing was changed.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Try again'));
      expect(actions.calls, ['retry()']);
    });

    testWidgets('a non-retryable error has no button', (tester) async {
      await pumpInScope(
        tester,
        const ErrorRow(
          item: ErrorItem(
            id: 'e',
            kind: ChatErrorKind.blocked,
            message: 'I can’t help with that request.',
            retryable: false,
          ),
        ),
        actions: actions,
      );
      expect(find.text('Try again'), findsNothing);
    });
  });

  group('LimitBannerView', () {
    testWidgets('counts down and offers Retry now', (tester) async {
      var now = testNow;
      await pumpInScope(
        tester,
        LimitBannerView(
          banner: RetryBanner(
            testNow.add(const Duration(seconds: 20)),
            RetryReason.rpm,
          ),
        ),
        actions: actions,
        now: () => now,
      );
      expect(find.text('Gemini is busy. Retrying in 20 s.'), findsOneWidget);

      now = testNow.add(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Gemini is busy. Retrying in 15 s.'), findsOneWidget);

      await tester.tap(find.text('Retry now'));
      expect(actions.calls, ['retryNow()']);
    });

    testWidgets('announces once, not on every tick', (tester) async {
      final semantics = tester.ensureSemantics();
      var now = testNow;
      await pumpInScope(
        tester,
        LimitBannerView(
          banner: RetryBanner(
            testNow.add(const Duration(seconds: 20)),
            RetryReason.rpm,
          ),
        ),
        actions: actions,
        now: () => now,
      );
      final live = find.bySemanticsLabel('Gemini is busy. Retrying shortly.');
      expect(live, findsOneWidget);
      expect(tester.getSemantics(live).flagsCollection.isLiveRegion, isTrue);

      now = testNow.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Gemini is busy. Retrying in 19 s.'), findsOneWidget);
      expect(live, findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Retrying in')), findsNothing);
      expect(find.bySemanticsLabel(RegExp('Retry now')), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('TPM waits read differently', (tester) async {
      await pumpInScope(
        tester,
        LimitBannerView(
          banner: RetryBanner(
            testNow.add(const Duration(seconds: 30)),
            RetryReason.tpm,
          ),
        ),
        actions: actions,
      );
      expect(
        find.text('This conversation is large; waiting 30 s.'),
        findsOneWidget,
      );
    });
  });

  group('under PlanCardScope only (no AssistantScope)', () {
    testWidgets('AppliedCard counts down and undoes', (tester) async {
      final applied = _item<AppliedItem>(AssistantSeeds.analyze(now: testNow));
      await pumpInPlanScope(
        tester,
        AppliedCard(item: applied),
        actions: actions,
      );
      expect(
        find.text('You approved 12 of 14 · undo available for 9 min'),
        findsOneWidget,
      );
      await tester.tap(find.text('Undo'));
      expect(actions.calls, ['undo(j_done)']);
    });

    testWidgets('ObjectChipMessage opens the card', (tester) async {
      await pumpInPlanScope(
        tester,
        const ObjectChipMessage(
          item: ObjectChipItem(
            id: 'c',
            collectionId: 'c_orders',
            cardId: 'o_1042',
            label: '#1042',
          ),
        ),
        actions: actions,
      );
      await tester.tap(find.text('#1042'));
      expect(actions.calls, ['open(c_orders, o_1042, null)']);
    });
  });

  testWidgets('ObjectChipMessage opens the card', (tester) async {
    await pumpInScope(
      tester,
      const ObjectChipMessage(
        item: ObjectChipItem(
          id: 'c',
          collectionId: 'c_orders',
          cardId: 'o_1042',
          label: '#1042',
        ),
      ),
      actions: actions,
    );
    expect(
      tester.getSize(find.byType(ObjectChip)).height,
      greaterThanOrEqualTo(44),
    );
    await tester.tap(find.text('#1042'));
    expect(actions.calls, ['open(c_orders, o_1042, null)']);
  });
}
