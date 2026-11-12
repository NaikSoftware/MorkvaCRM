import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/automation/runner_api.dart';
import 'package:morkva_crm/core/domain/automation/automation.dart';
import 'package:morkva_crm/design/design.dart';
import 'package:morkva_crm/features/automation/view/run_detail_page.dart';

import 'automation_view_harness.dart';

void main() {
  late AutomationRig rig;
  late DateTime now;

  setUp(() async {
    rig = AutomationRig();
    now = fixtureNow;
    final module = stampModule();
    await rig.stores.modules.save(module);
    await rig.stores.grants.save(uid, consentTo(module));
    await rig.stores.automations.save(automation());
  });
  tearDown(() => rig.dispose());

  Future<void> pump(
    WidgetTester tester,
    String runId, {
    Size size = wideWindow,
    ThemeData? theme,
  }) async {
    setWindow(tester, size);
    await tester.pumpWidget(
      rig.wrap(
        RunDetailPage(runId: runId, now: () => now),
        theme: theme,
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  RunRecord applied() => storedRun('r_ok', journalId: 'j1').copyWith(
    receipt: () => const RunReceipt(applied: 1),
    endedAt: () => fixtureNow,
    durationMs: () => 412,
    log: const RunLog(
      triggerEval: 'matched: before=false after=true',
      calls: [
        RunCall(
          t: 0,
          op: 'cards.update',
          kind: 'plan',
          args: '#1042 · planned 1 change',
          ok: true,
          result: 'ok',
          ms: 6,
        ),
        RunCall(
          t: 6,
          op: 'cards.update',
          kind: 'plan',
          args: 'Clients',
          ok: false,
          result: 'not_permitted — Collection not available',
          ms: 1,
        ),
      ],
      console: [ConsoleLine(t: 1, level: 'info', text: 'Stamping #1042')],
      plan: [
        PlanLine(
          kind: 'updateCard',
          label: '#1042',
          change: 'Shipped on: — → 12 Nov',
        ),
      ],
      ui: [UiLink(kind: 'open', ref: 'b_1042', label: '#1042')],
    ),
  );

  testWidgets('applied: timeline, Undo countdown, links', (tester) async {
    rig.runner.undoable.add('r_ok');
    await rig.stores.runs.create(applied());
    now = fixtureNow.add(const Duration(seconds: 30));
    await pump(tester, 'r_ok');

    expect(find.text('Succeeded'), findsOneWidget);
    expect(find.text('Stamp when shipped'), findsOneWidget);
    expect(
      find.textContaining('Stamp shipped date v1.0.0 › Stamp'),
      findsOneWidget,
    );
    expect(find.text('Button pressed on #1042'), findsOneWidget);
    expect(find.text('matched: before=false after=true'), findsOneWidget);
    expect(
      find.textContaining('Stamping #1042', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Shipped on: — → 12 Nov'), findsOneWidget);
    expect(
      find.text('Clients · not_permitted — Collection not available'),
      findsOneWidget,
    );
    expect(find.text('Undo · 10 min left'), findsOneWidget);

    await tester.tap(find.text('Open #1042'));
    expectLastCall(rig.host.calls, 'openLink');

    await tester.tap(find.text('Undo · 10 min left'));
    await tester.pump();
    expectLastCall(rig.runner.calls, 'undo', ['r_ok']);
  });

  // On web the steps' intrinsic text height came out 1 px short of their
  // laid-out height (the Console step overflowed); the timeline may not
  // size its steps from intrinsics.
  testWidgets('timeline steps size to their content, not intrinsics', (
    tester,
  ) async {
    await rig.stores.runs.create(applied());
    await pump(tester, 'r_ok');
    expect(find.text('Console'), findsOneWidget);
    expect(find.byType(IntrinsicHeight), findsNothing);
  });

  testWidgets('the countdown ends in "Undo expired" once the deadline '
      'passes and the journal lets go', (tester) async {
    rig.runner.undoable.add('r_ok');
    await rig.stores.runs.create(applied());
    await pump(tester, 'r_ok');
    expect(find.textContaining('min left'), findsOneWidget);
    rig.runner.undoable.clear();
    now = rig.now = fixtureNow.add(const Duration(minutes: 11));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(find.text('Undo expired'), findsOneWidget);
  });

  testWidgets('a journal gone before the deadline reads "Undo isn\'t '
      'available after a reload"', (tester) async {
    rig.runner.undoable.add('r_ok');
    await rig.stores.runs.create(applied());
    await pump(tester, 'r_ok');
    rig.runner.undoable.clear();
    rig.runLog.refresh();
    await tester.pump();
    await tester.pump();
    expect(find.text("Undo isn't available after a reload"), findsOneWidget);
  });

  testWidgets('failed: message, stack, Ask Morkva to fix it, Edit', (
    tester,
  ) async {
    await rig.stores.runs.create(
      storedRun(
        'r_bad',
        status: RunStatus.failed,
        reason: RunReason.moduleError,
        error: const RunError(
          code: 'module_error',
          message: "TypeError: Cannot read properties of undefined",
          stack: 'at stamp (morkva-module/stamp-shipped-date.js:12:7)',
        ),
      ),
    );
    await pump(tester, 'r_bad');
    expect(find.text('Failed'), findsOneWidget);
    expect(
      find.text('at stamp (morkva-module/stamp-shipped-date.js:12:7)'),
      findsOneWidget,
    );
    await tester.tap(find.text('Ask Morkva to fix it'));
    expect(rig.host.calls.last.$1, 'askMorkva');
    expect(rig.host.calls.last.$2.single, contains('TypeError'));
    await tester.tap(find.text('Edit automation'));
    expectLastCall(rig.host.calls, 'editAutomation', ['a_1']);
    await tester.tap(find.text('Run again on #1042'));
    await tester.pump();
    expect(rig.runner.methods, contains('runAgain'));
  });

  testWidgets('a running run with no doc yet: its live view and Stop', (
    tester,
  ) async {
    rig.runner.activity = RunActivity(runs: [runView('r_live')]);
    await pump(tester, 'r_live');
    expect(find.text('Mark shipped'), findsOneWidget);
    await tester.tap(find.text('Stop'));
    expectLastCall(rig.runner.calls, 'stop', ['r_live']);
  });

  testWidgets('an unknown run says so', (tester) async {
    await pump(tester, 'r_missing');
    await tester.pumpAndSettle();
    expect(find.text("This run isn't in the log"), findsOneWidget);
  });

  testWidgets('back goes to the Runs tab; phone and dark lay out', (
    tester,
  ) async {
    await rig.stores.runs.create(applied());
    await pump(tester, 'r_ok', size: phoneWindow, theme: AppTheme.dark);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Runs'));
    expectLastCall(rig.host.calls, 'openAutomations');
  });

  test('Copy log is JSON with dates as ISO strings and the log decoded', () {
    final json = runLogJson(applied());
    expect(json, contains('"startedAt": "2026-11-12T10:00:00.000Z"'));
    expect(json, contains('"op": "cards.update"'));
  });

  testWidgets('an unreadable run: "Couldn\'t load this run", no spinner', (
    tester,
  ) async {
    rig.stores.runs.getError = kPermissionDenied;
    await pump(tester, 'r_old');
    await tester.pumpAndSettle();
    expect(find.text("Couldn't load this run"), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    rig.stores.runs.getError = null;
    await rig.stores.runs.create(storedRun('r_old', summary: 'Stamped #7'));
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text("Couldn't load this run"), findsNothing);
    expect(find.textContaining('Stamped #7'), findsWidgets);
  });

  testWidgets('a failed run log: "Couldn\'t load this run"', (tester) async {
    rig.stores.failAll();
    await pump(tester, 'r_old');
    await tester.pumpAndSettle();
    expect(find.text("Couldn't load this run"), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
