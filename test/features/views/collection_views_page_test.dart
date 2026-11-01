import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/design/design.dart';
import 'package:morkva_crm/features/views/views.dart';

import 'views_fixtures.dart';
import 'work_page_harness.dart';

const _phone = Size(390, 844);

List<String> _rowTitles(WidgetTester tester) =>
    [
      for (final name in [
        'Acme renewal',
        'Globex pilot',
        'Initech',
        'Umbrella',
        'Hooli',
      ])
        if (find.text(name).evaluate().isNotEmpty) name,
    ]..sort(
      (a, b) => tester
          .getTopLeft(find.text(a))
          .dy
          .compareTo(tester.getTopLeft(find.text(b)).dy),
    );

void main() {
  group('loading', () {
    testWidgets('the skeleton shows only after 150 ms', (tester) async {
      await pumpWorkPage(tester, initialize: false);
      expect(find.bySemanticsLabel('Loading'), findsNothing);
      await tester.pump(const Duration(milliseconds: 160));
      expect(find.bySemanticsLabel('Loading'), findsOneWidget);
    });
  });

  group('wide', () {
    testWidgets('header, rail, tabs, toolbar and the table', (tester) async {
      await pumpWorkPage(tester);
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.text('Deals'), findsOneWidget);
      expect(find.text('Customize'), findsOneWidget);
      expect(find.text('New deal'), findsWidgets);
      expect(find.text('All deals'), findsOneWidget);
      expect(find.text('Pipeline'), findsOneWidget);
      expect(find.text('Filter'), findsOneWidget);
      expect(find.text('Sort'), findsOneWidget);
      expect(find.text('Columns'), findsOneWidget);
      expect(_rowTitles(tester), [
        'Acme renewal',
        'Globex pilot',
        'Initech',
        'Umbrella',
        'Hooli',
      ]);
      // Select cells as pills, references by label.
      expect(find.widgetWithText(OptionPill, 'Lead'), findsNWidgets(2));
      expect(find.text('Alpha Ltd'), findsOneWidget);
      expect(find.text('1200 USD'), findsOneWidget);
      expect(find.text('5 deals'), findsOneWidget);
    });

    testWidgets('header taps cycle the sort asc → desc → none', (tester) async {
      final cubit = await pumpWorkPage(tester);
      await tester.tap(find.bySemanticsLabel('Sort by Amount'));
      await tester.pumpAndSettle();
      expect(
        (cubit.state as ViewsReady).activeView.sort,
        const ViewSort(fieldId: 'amount'),
      );
      expect(_rowTitles(tester).take(3), [
        'Initech',
        'Globex pilot',
        'Acme renewal',
      ]);
      expect(find.byIcon(Icons.arrow_upward), findsWidgets);

      await tester.tap(find.bySemanticsLabel('Sort by Amount'));
      await tester.pumpAndSettle();
      expect(_rowTitles(tester).take(3), [
        'Acme renewal',
        'Globex pilot',
        'Initech',
      ]);

      await tester.tap(find.bySemanticsLabel('Sort by Amount'));
      await tester.pumpAndSettle();
      expect((cubit.state as ViewsReady).activeView.sort, isNull);
    });

    testWidgets('Customize opens the editor', (tester) async {
      await pumpWorkPage(tester);
      await tester.tap(find.text('Customize'));
      await tester.pumpAndSettle();
      expect(find.text('editor:deals'), findsOneWidget);
    });

    testWidgets('Columns is a stub for now', (tester) async {
      await pumpWorkPage(tester);
      await tester.tap(find.text('Columns'));
      await tester.pump();
      expect(find.text('Columns is coming soon'), findsOneWidget);
    });

    testWidgets('switching tabs shows the other view', (tester) async {
      final cubit = await pumpWorkPage(tester);
      await tester.tap(find.text('Pipeline'));
      await tester.pumpAndSettle();
      expect((cubit.state as ViewsReady).activeViewId, 'board');
    });
  });

  group('phone', () {
    testWidgets('pushed-route header, FAB, chips row only', (tester) async {
      await pumpWorkPage(tester, size: _phone);
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byTooltip('Back'), findsOneWidget);
      expect(find.byTooltip('View settings'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.text('Sort'), findsNothing);
      expect(find.text('Filter'), findsOneWidget);
      expect(find.text('Acme renewal'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('overflow → Customize collection', (tester) async {
      await pumpWorkPage(tester, size: _phone);
      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Customize collection'));
      await tester.pumpAndSettle();
      expect(find.text('editor:deals'), findsOneWidget);
    });

    testWidgets('back returns home', (tester) async {
      await pumpWorkPage(tester, size: _phone);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
    });
  });

  group('states', () {
    testWidgets('no objects: header plus a ghost row and Change fields', (
      tester,
    ) async {
      await pumpWorkPage(tester, repository: workRepository(objects: []));
      expect(find.bySemanticsLabel('Sort by Amount'), findsOneWidget);
      expect(find.text('New deal'), findsNWidgets(2));
      expect(find.text('Change fields'), findsOneWidget);
    });

    testWidgets('no fields: set up fields', (tester) async {
      await pumpWorkPage(
        tester,
        repository: workRepository(
          collection: const Collection(id: 'deals', name: 'Deals'),
          objects: [],
        ),
      );
      expect(find.text('This collection has no fields yet'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('filters hiding everything: no matches + clear', (
      tester,
    ) async {
      final cubit = await pumpWorkPage(tester);
      await cubit.setFilters(const [
        ViewFilter(fieldId: 'name', op: FilterOp.contains, operand: 'zzz'),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('Nothing matches these filters'), findsOneWidget);
      expect(find.text('Name contains zzz'), findsOneWidget);
      await tester.tap(find.text('Clear filters'));
      await tester.pumpAndSettle();
      expect(find.text('Acme renewal'), findsOneWidget);
    });

    testWidgets('filtered footer counts "N of M"; chip ✕ removes', (
      tester,
    ) async {
      final cubit = await pumpWorkPage(tester);
      await cubit.setFilters(const [
        ViewFilter(fieldId: 'stage', op: FilterOp.anyOf, operand: ['lead']),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('2 of 5'), findsOneWidget);
      expect(find.text('Stage is Lead'), findsOneWidget);
      await tester.tap(find.byTooltip('Remove filter'));
      await tester.pumpAndSettle();
      expect(find.text('5 deals'), findsOneWidget);
    });

    testWidgets('an unknown mode renders as a table with a notice', (
      tester,
    ) async {
      await pumpWorkPage(
        tester,
        repository: workRepository(
          collection: deals.copyWith(
            views: [tableView.copyWith(mode: 'gallery')],
          ),
        ),
      );
      expect(find.textContaining('"gallery" mode'), findsOneWidget);
      expect(find.text('Acme renewal'), findsOneWidget);
    });

    testWidgets('a stream error shows the error card; Retry reloads', (
      tester,
    ) async {
      final repo = workRepository();
      await pumpWorkPage(tester, repository: repo);
      repo.failObjects('deals', StateError('boom'));
      await tester.pump();
      await tester.pump();
      expect(find.text("Couldn't load this view"), findsOneWidget);
      repo.seedObjects('deals', sampleDeals());
      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Acme renewal'), findsOneWidget);
    });

    testWidgets('a failed write shows an error snackbar', (tester) async {
      final repo = workRepository();
      final cubit = await pumpWorkPage(tester, repository: repo);
      repo.objectWriteError = () => StateError('denied');
      cubit.deleteObject('d1');
      await tester.pump();
      await tester.pump();
      expect(find.text("Couldn't delete it"), findsOneWidget);
      expect(find.text('Acme renewal'), findsOneWidget);
    });
  });

  group('objects', () {
    testWidgets('tap → detail sheet → Delete → Undo', (tester) async {
      await pumpWorkPage(tester);
      await tester.tap(find.text('Globex pilot'));
      await tester.pumpAndSettle();
      expect(find.byType(ObjectDetailSheet), findsOneWidget);
      expect(find.text('Zeta Corp'), findsWidgets);

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Globex pilot'), findsNothing);
      expect(find.text('Deleted "Globex pilot"'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(find.text('Globex pilot'), findsOneWidget);
    });

    testWidgets('New deal → quick-add dialog → a new row', (tester) async {
      await pumpWorkPage(tester);
      await tester.tap(find.widgetWithText(PrimaryButton, 'New deal'));
      await tester.pumpAndSettle();
      expect(find.byType(QuickAddDialog), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Wayne Enterprises');
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      expect(find.text('Wayne Enterprises'), findsOneWidget);
      expect(find.text('6 deals'), findsOneWidget);
    });
  });

  group('tab menu', () {
    testWidgets('duplicate, inline rename, delete with confirm', (
      tester,
    ) async {
      final cubit = await pumpWorkPage(tester);
      await tester.tap(find.byTooltip('View options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Duplicate'));
      await tester.pumpAndSettle();
      expect(find.text('All deals copy'), findsOneWidget);

      await tester.tap(find.byTooltip('View options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Big ones');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text('Big ones'), findsOneWidget);

      await tester.tap(find.byTooltip('View options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      // The confirm dialog's Delete sits above the menu's.
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();
      final views = (cubit.state as ViewsReady).collection.views;
      expect(views.map((v) => v.name), ['All deals', 'Pipeline']);
    });

    testWidgets('the last view cannot be deleted', (tester) async {
      await pumpWorkPage(
        tester,
        repository: workRepository(
          collection: deals.copyWith(views: const [tableView]),
        ),
      );
      await tester.tap(find.byTooltip('View options'));
      await tester.pumpAndSettle();
      final item = tester.widget<PopupMenuItem<Object?>>(
        find.ancestor(
          of: find.text('Delete'),
          matching: find.byWidgetPredicate((w) => w is PopupMenuItem),
        ),
      );
      expect(item.enabled, isFalse);
    });
  });
}
