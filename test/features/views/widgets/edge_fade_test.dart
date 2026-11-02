import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/features/views/views.dart';
import 'package:morkva_crm/features/views/widgets/edge_fade.dart';

import '../views_fixtures.dart';
import '../work_page_harness.dart';

void main() {
  testWidgets('fades the side with more content, following the scroll', (
    t,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await t.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 300,
            height: 40,
            child: EdgeFade(
              child: ListView(
                controller: controller,
                scrollDirection: Axis.horizontal,
                children: [
                  for (var i = 0; i < 10; i++)
                    const SizedBox(width: 100, child: Text('x')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await t.pump();
    EdgeFadeState fade() => t.state<EdgeFadeState>(find.byType(EdgeFade));
    expect((fade().fadesStart, fade().fadesEnd), (false, true));
    controller.jumpTo(200);
    await t.pump();
    expect((fade().fadesStart, fade().fadesEnd), (true, true));
    controller.jumpTo(controller.position.maxScrollExtent);
    await t.pump();
    expect((fade().fadesStart, fade().fadesEnd), (true, false));
  });

  testWidgets('a board wider than the window fades its right edge', (t) async {
    await pumpWorkPage(
      t,
      size: const Size(1000, 800),
      repository: workRepository(
        collection: deals.copyWith(views: [boardView]),
      ),
    );
    await t.pump();
    final fade = t.state<EdgeFadeState>(
      find.descendant(
        of: find.byType(BoardView),
        matching: find.byType(EdgeFade),
      ),
    );
    expect(fade.fadesEnd, isTrue);
    expect(fade.fadesStart, isFalse);
  });

  testWidgets('a phone table wider than the window fades its right edge', (
    t,
  ) async {
    await pumpWorkPage(t, size: const Size(390, 844));
    await t.pump();
    final fade = t.state<EdgeFadeState>(
      find.descendant(
        of: find.byType(ViewTable),
        matching: find.byType(EdgeFade),
      ),
    );
    expect(fade.fadesEnd, isTrue);
  });
}
