import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/agent/agent_event.dart';
import 'package:morkva_crm/core/domain/automation/automation.dart';
import 'package:morkva_crm/features/assistant/bloc/assistant_state.dart';
import 'package:morkva_crm/features/assistant/bloc/chat_item.dart';
import 'package:morkva_crm/features/assistant/bloc/chat_item_codec.dart';
import 'package:morkva_crm/features/assistant/view/widgets/applied_card.dart';
import 'package:morkva_crm/features/assistant/view/widgets/chat_list.dart';
import 'package:morkva_crm/features/assistant/view/widgets/test_run_card.dart';

import 'assistant_view_harness.dart';

const _result = TestRunResult(
  status: RunStatus.succeeded,
  summary: 'Stamped',
  plan: [
    PlanLine(
      kind: 'updateCard',
      label: '#1042',
      change: 'Shipped on: — → 12 Nov',
    ),
  ],
  log: RunLog(
    calls: [
      RunCall(
        t: 0,
        op: 'cards.get',
        kind: 'read',
        args: 'ids: 1',
        ok: true,
        result: 'Read 1 card',
        ms: 12,
      ),
    ],
    console: [ConsoleLine(t: 5, level: 'info', text: 'stamping #1042')],
  ),
);

void main() {
  group('TestRunCard', () {
    testWidgets('shows the dry run read-only: status, plan rows, Calls and '
        'Console', (tester) async {
      await pumpInScope(
        tester,
        ChatItemView(
          item: const TestRunItem(
            id: 't',
            title: 'Test run · stamp-shipped-date',
            result: _result,
          ),
          state: const AssistantState(),
        ),
        actions: RecordingActions(),
      );

      expect(find.byType(TestRunCard), findsOneWidget);
      expect(find.text('Test run · stamp-shipped-date'), findsOneWidget);
      expect(find.text('Would change 1 card · 12 ms'), findsOneWidget);
      expect(find.text('#1042'), findsOneWidget);
      expect(find.text('Shipped on: — → 12 Nov'), findsOneWidget);
      expect(find.text('Calls (1)'), findsOneWidget);
      expect(find.text('Console (1)'), findsOneWidget);
      expect(find.byType(Checkbox), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a failed run says why', (tester) async {
      await pumpInScope(
        tester,
        const TestRunCard(
          item: TestRunItem(
            id: 't',
            title: 'Test run · m',
            result: TestRunResult(
              status: RunStatus.failed,
              reason: RunReason.moduleError,
              error: RunError(code: 'module_error', message: 'TypeError: x'),
            ),
          ),
        ),
        actions: RecordingActions(),
      );

      expect(find.text('Failed: TypeError: x'), findsOneWidget);
    });
  });

  group('test-run item JSON', () {
    test('parses the modules.testRun result and refuses a bad status', () {
      expect(testRunResultFromJson(_result.toJson()), _result);
      expect(
        () => testRunResultFromJson({'status': 'exploded'}),
        throwsFormatException,
      );
    });

    test('persists without the log and restores', () {
      final record = encodeChatItem(
        const TestRunItem(id: 't', title: 'Test run · m', result: _result),
      );

      expect(record['type'], 'testRun');
      expect(record['result'], isNot(contains('log')));
      final back = decodeChatItem(record)! as TestRunItem;
      expect(back.title, 'Test run · m');
      expect(back.result.plan, _result.plan);
      expect(back.result.log, RunLog.empty);
    });

    test('an applied card keeps its started-run count across a reload', () {
      final record = encodeChatItem(
        const AppliedItem(
          id: 'a',
          plan: PlanView(planId: 'p1', title: 'Set Status'),
          receipt: Receipt(planId: 'p1', applied: ['x'], summary: 'Updated 1'),
          startedRuns: 3,
        ),
      );

      expect((decodeChatItem(record)! as AppliedItem).startedRuns, 3);
    });
  });

  group('AppliedCard', () {
    Future<void> pumpApplied(WidgetTester tester, int startedRuns) =>
        pumpInScope(
          tester,
          AppliedCard(
            item: AppliedItem(
              id: 'a',
              plan: const PlanView(planId: 'p1', title: 'Set Status · 3'),
              receipt: const Receipt(
                planId: 'p1',
                applied: ['x', 'y', 'z'],
                summary: 'Updated 3',
              ),
              startedRuns: startedRuns,
            ),
          ),
          actions: RecordingActions(),
        );

    testWidgets('says how many automation runs the commit started', (
      tester,
    ) async {
      await pumpApplied(tester, 3);
      expect(find.text('Started 3 automation runs'), findsOneWidget);

      await pumpApplied(tester, 1);
      expect(find.text('Started 1 automation run'), findsOneWidget);

      await pumpApplied(tester, 0);
      expect(find.textContaining('automation run'), findsNothing);
    });
  });
}
