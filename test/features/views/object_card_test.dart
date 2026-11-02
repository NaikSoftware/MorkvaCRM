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
      expect(find.text('1,200 USD'), findsOneWidget);
      expect(find.text('Alpha Ltd'), findsOneWidget);
      // Stage is the layout field (the columns show it); Due is empty.
      expect(find.text('Lead'), findsNothing);
      expect(find.textContaining('2026'), findsNothing);
      expect(
        tester.getTopRight(find.text('1,200 USD')).dx,
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
      expect(find.text('1,200 USD'), findsOneWidget);
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
    expect(find.text('1,200 USD'), findsNothing);
  });

  testWidgets('an empty title reads Untitled', (tester) async {
    await pump(tester, ObjectCardDensity.board, object: deal('x', 0));
    expect(find.text('Untitled'), findsOneWidget);
  });

  testWidgets('list: a row without a stage keeps the dot slot, hollow', (
    tester,
  ) async {
    double titleX() => tester.getTopLeft(find.textContaining('Acme')).dx;
    BoxDecoration dot() => tester
        .widgetList<Container>(find.byType(Container))
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .firstWhere((d) => d.shape == BoxShape.circle);

    await pump(tester, ObjectCardDensity.list);
    final withStage = titleX();
    expect(dot().color, isNotNull);

    await pump(
      tester,
      ObjectCardDensity.list,
      object: deal('d2', 0, name: 'Acme pilot'),
    );
    expect(titleX(), withStage);
    expect(dot().color, isNull);
    expect(dot().border, isNotNull);
  });

  testWidgets('list on a date layout: the dot shows the first select', (
    tester,
  ) async {
    await pump(
      tester,
      ObjectCardDensity.list,
      view: const ViewDefinition(
        id: 'v',
        name: 'V',
        mode: ViewModeIds.calendar,
        layoutFieldId: 'due',
        fieldIds: ['name', 'stage'],
      ),
    );
    final dots = tester
        .widgetList<Container>(find.byType(Container))
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .where((d) => d.shape == BoxShape.circle);
    expect(dots.single.color, isNotNull);
  });
}
