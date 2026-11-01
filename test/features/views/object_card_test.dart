import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/design/design.dart';
import 'package:morkva_crm/features/views/views.dart';

import 'views_fixtures.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    ObjectCardDensity density, {
    ViewDefinition view = const ViewDefinition(
      id: 'v',
      name: 'V',
      layoutFieldId: 'stage',
      fieldIds: ['name', 'amount', 'stage', 'company', 'due'],
    ),
    MorkvaObject? object,
    VoidCallback? onTap,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 280,
            child: ObjectCard(
              object:
                  object ??
                  deal(
                    'd1',
                    0,
                    name: 'Acme renewal',
                    amount: 1200,
                    stage: 'lead',
                    company: 'k2',
                  ),
              collection: deals,
              view: view,
              density: density,
              referenceLabels: const {'k2': 'Alpha Ltd'},
              onTap: onTap,
            ),
          ),
        ),
      ),
    ),
  );

  testWidgets(
    'board: title, metric top-right, chips; layout field and empties skipped',
    (tester) async {
      var taps = 0;
      await pump(tester, ObjectCardDensity.board, onTap: () => taps++);
      expect(find.text('Acme renewal'), findsOneWidget);
      expect(find.text('1200 USD'), findsOneWidget);
      expect(find.text('Alpha Ltd'), findsOneWidget);
      // Stage is the layout field (the columns show it); Due is empty.
      expect(find.text('Lead'), findsNothing);
      expect(find.textContaining('2026'), findsNothing);
      expect(
        tester.getTopRight(find.text('1200 USD')).dx,
        greaterThan(tester.getTopRight(find.text('Acme renewal')).dx),
      );
      await tester.tap(find.text('Acme renewal'));
      expect(taps, 1);
    },
  );

  testWidgets(
    'board: select values as option pills when not the layout field',
    (tester) async {
      await pump(
        tester,
        ObjectCardDensity.board,
        view: const ViewDefinition(
          id: 'v',
          name: 'V',
          fieldIds: ['name', 'stage'],
        ),
      );
      expect(find.widgetWithText(OptionPill, 'Lead'), findsOneWidget);
    },
  );

  testWidgets(
    'list: 56 px row, dot from the select layout field, subtitle, trailing metric',
    (tester) async {
      await pump(tester, ObjectCardDensity.list);
      expect(find.text('Alpha Ltd'), findsOneWidget);
      expect(find.text('1200 USD'), findsOneWidget);
      expect(tester.getSize(find.byType(ObjectCard)).height, 64);
    },
  );

  testWidgets('list: no subtitle → 56 px', (tester) async {
    await pump(
      tester,
      ObjectCardDensity.list,
      view: const ViewDefinition(id: 'v', name: 'V', fieldIds: ['name']),
    );
    expect(tester.getSize(find.byType(ObjectCard)).height, 56);
  });

  testWidgets('pill: 24 px, title only', (tester) async {
    await pump(tester, ObjectCardDensity.pill);
    expect(tester.getSize(find.byType(ObjectCard)).height, 24);
    expect(find.text('Acme renewal'), findsOneWidget);
    expect(find.text('1200 USD'), findsNothing);
  });

  testWidgets('an empty title reads Untitled', (tester) async {
    await pump(tester, ObjectCardDensity.board, object: deal('x', 0));
    expect(find.text('Untitled'), findsOneWidget);
  });
}
