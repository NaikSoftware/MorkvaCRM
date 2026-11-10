// Screenshots of each Epic 8 mockup artboard's seeded state, for the design
// critic to compare with docs/superpowers/mockups/epic-08/*.dc.html.
//
// Regenerate: flutter test --update-goldens
//   test/features/assistant/view/assistant_screenshots_test.dart
//
// Fonts: Hanken Grotesk / Bricolage Grotesque are fetched at runtime by
// google_fonts and are not on disk, so the shots use the SDK's Roboto under
// those family names (see loadAppFonts). Spacing, colour and layout are
// exact; letterforms and widths differ slightly from the mockups.
import 'package:flutter/material.dart';
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
  setUpAll(loadAppFonts);

  Future<void> shoot(WidgetTester tester, String name) => expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/$name.png'),
  );

  testWidgets('Main (light): table answer + pending plan', (tester) async {
    await pumpPanel(
      tester,
      FakeAssistantBloc.main(),
      actions: RecordingActions(),
    );
    await tester.pumpAndSettle();
    await shoot(tester, 'main_light');
  });

  testWidgets('Main (dark): the Dark artboard', (tester) async {
    await pumpPanel(
      tester,
      FakeAssistantBloc.main(),
      actions: RecordingActions(),
      theme: AppTheme.dark,
    );
    await tester.pumpAndSettle();
    await shoot(tester, 'main_dark');
  });

  testWidgets('Empty: first open, composer focused', (tester) async {
    await pumpPanel(
      tester,
      FakeAssistantBloc.empty(),
      actions: RecordingActions(),
      autofocus: true,
    );
    await tester.pumpAndSettle();
    await shoot(tester, 'empty');
  });

  testWidgets('Empty: consent disclosure', (tester) async {
    await pumpPanel(
      tester,
      FakeAssistantBloc.consent(),
      actions: RecordingActions(),
    );
    await tester.pumpAndSettle();
    await shoot(tester, 'consent');
  });

  testWidgets('Analyze: chart, applied card and its undo snackbar', (
    tester,
  ) async {
    final full = AssistantSeeds.analyze(now: testNow);
    final bloc = FakeAssistantBloc(
      full.copyWith(
        items: full.items.takeWhile((i) => i is! AppliedItem).toList(),
      ),
    );
    await pumpPanel(tester, bloc, actions: RecordingActions());
    await tester.pumpAndSettle();
    // The artboard shows the steps expanded.
    await tester.tap(find.textContaining('Read the Orders schema'));
    await tester.pumpAndSettle();
    bloc.set(full);
    await tester.pumpAndSettle();
    await shoot(tester, 'analyze');
  });

  testWidgets('Schema: banner, applied schema, destructive plan, error', (
    tester,
  ) async {
    await pumpPanel(
      tester,
      FakeAssistantBloc.schema(now: testNow),
      actions: RecordingActions(),
    );
    await tester.pumpAndSettle();
    await shoot(tester, 'schema');
  });

  testWidgets('Phone: streaming answer', (tester) async {
    await setSurface(tester, const Size(390, 844));
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: AssistantPage(
          bloc: FakeAssistantBloc.phoneStreaming(),
          actions: RecordingActions(),
          onBack: () {},
          onOpenHistory: () {},
          now: () => testNow,
        ),
      ),
    );
    // A step is still running (spinner): no settle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await shoot(tester, 'phone');
  });

  testWidgets('Tablet: rail modal sheet with the history list', (tester) async {
    await setSurface(tester, const Size(1024, 768));
    final threads = [
      for (final r in AssistantSeeds.threads(now: testNow))
        ThreadSummary.fromRecord(r),
    ];
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: Builder(
          builder: (context) {
            final scheme = Theme.of(context).colorScheme;
            return Scaffold(
              body: Row(
                children: [
                  Container(width: 80, color: scheme.surfaceContainer),
                  Expanded(
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: ColoredBox(
                            color: scheme.shadow.withValues(alpha: 0.32),
                          ),
                        ),
                        Positioned(
                          top: 0,
                          right: 0,
                          bottom: 0,
                          child: AssistantPanel(
                            bloc: FakeAssistantBloc.tabletHistory(),
                            actions: RecordingActions(),
                            overlay: true,
                            onClose: () {},
                            autofocus: false,
                            initiallyShowHistory: true,
                            now: () => testNow,
                            historyBuilder: (context, back) => ThreadListView(
                              threads: threads,
                              currentId: 't_unpaid',
                              onSelect: (_) => back(),
                              onDelete: (_) {},
                              now: () => testNow,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await shoot(tester, 'tablet_history');
  });

  testWidgets('Applying: progress on the plan card', (tester) async {
    final main = AssistantSeeds.main();
    final plan = main.items.last as PlanItem;
    await pumpPanel(
      tester,
      FakeAssistantBloc(
        main.copyWith(
          phase: const ApplyingPhase(2, 3),
          items: [
            ...main.items.take(main.items.length - 1),
            plan.copyWith(status: PlanStatus.committing),
          ],
        ),
      ),
      actions: RecordingActions(),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await shoot(tester, 'applying');
  });
}
