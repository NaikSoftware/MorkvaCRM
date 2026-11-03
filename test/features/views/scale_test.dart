import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/features/views/views.dart';

import 'views_fixtures.dart';
import 'work_page_harness.dart';

/// Every mode builds widgets only for what is on screen, so a collection of
/// thousands stays smooth: the built titles stay bounded at 3000 deals.
void main() {
  final now = DateTime.now();
  // Spread over the stages (and none) and the days of the current month.
  final many = [
    for (var i = 0; i < 3000; i++)
      deal(
        'd$i',
        i,
        name: 'Deal $i',
        amount: i,
        stage: const ['lead', 'won', 'lost', null][i % 4],
        due: DateTime.utc(now.year, now.month, 1 + i % 28),
      ),
  ];

  int builtTitles() => find.textContaining('Deal ').evaluate().length;

  testWidgets('3000 objects: every mode builds only what is in view', (
    tester,
  ) async {
    final cubit = await pumpWorkPage(
      tester,
      repository: workRepository(objects: many),
    );
    await tester.pumpAndSettle();
    expect((cubit.state as ViewsReady).objects, hasLength(3000));
    expect(builtTitles(), inInclusiveRange(1, 60), reason: 'table');

    cubit.selectView('board');
    await tester.pumpAndSettle();
    expect(
      find.byType(ObjectCard).evaluate().length,
      inInclusiveRange(4, 100),
      reason: 'board',
    );

    await cubit.createView('List', mode: ViewModeIds.list);
    await tester.pumpAndSettle();
    expect(builtTitles(), inInclusiveRange(1, 60), reason: 'list');

    await cubit.setLayoutField('stage');
    await tester.pumpAndSettle();
    expect(builtTitles(), inInclusiveRange(1, 60), reason: 'grouped list');

    await cubit.setMode(ViewModeIds.calendar, layoutFieldId: 'due');
    await tester.pumpAndSettle();
    // A month grid caps each day's pills ("+N more").
    expect(builtTitles(), inInclusiveRange(1, 200), reason: 'calendar');
  });
}
