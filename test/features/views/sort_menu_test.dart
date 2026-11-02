import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/design/design.dart';
import 'package:morkva_crm/features/views/views.dart';

import 'views_fixtures.dart';

void main() {
  late List<ViewSort?> changes;
  late int picked;

  Future<void> pump(
    WidgetTester tester, {
    ViewSort? current,
    bool allowManual = false,
  }) async {
    changes = [];
    picked = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: SortMenu(
              collection: deals,
              current: current,
              allowManual: allowManual,
              onChanged: changes.add,
              onPicked: () => picked++,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('fields plus Created / Updated; no Manual on a table', (
    tester,
  ) async {
    await pump(tester);
    for (final label in [
      ...deals.fields.map((f) => f.name),
      'Created',
      'Updated',
    ]) {
      expect(find.bySemanticsLabel(label), findsOneWidget);
    }
    expect(find.bySemanticsLabel('Manual'), findsNothing);
  });

  testWidgets('picking a field sorts by it in the chosen direction', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.bySemanticsLabel('Updated'));
    expect(changes.single, const ViewSort(fieldId: ViewSort.updatedAt));
    expect(picked, 1);
  });

  testWidgets('the direction toggle re-sorts without closing', (tester) async {
    await pump(tester, current: const ViewSort(fieldId: 'amount'));
    await tester.tap(find.text('Desc'));
    await tester.pump();
    expect(changes.single, const ViewSort(fieldId: 'amount', ascending: false));
    expect(picked, 0);
    await tester.tap(find.bySemanticsLabel('Name'));
    expect(changes.last, const ViewSort(fieldId: 'name', ascending: false));
  });

  testWidgets('Manual (board / list) clears the sort', (tester) async {
    await pump(
      tester,
      current: const ViewSort(fieldId: 'amount'),
      allowManual: true,
    );
    await tester.tap(find.bySemanticsLabel('Manual'));
    await tester.pump();
    expect(changes.single, isNull);
    final toggle = tester.widget<SegmentedButton<bool>>(
      find.byType(SegmentedButton<bool>),
    );
    expect(toggle.onSelectionChanged, isNull);
  });
}
