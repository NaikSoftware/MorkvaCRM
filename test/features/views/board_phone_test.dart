import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/design/design.dart';
import 'package:morkva_crm/features/views/views.dart';
import 'package:morkva_crm/features/views/widgets/board/board_card_draggable.dart';
import 'package:morkva_crm/features/views/widgets/board/board_column.dart';

import '../collections/fake_data_repository.dart';
import 'views_fixtures.dart';
import 'work_page_harness.dart';

const _phone = Size(390, 844);

/// Board body width at 390: the page gutter is 16 on each side.
const double _w = 390 - 2 * 16;
const double _pageWidth = _w - BoardView.peek;

Future<CollectionViewsCubit> _pumpBoard(
  WidgetTester tester, {
  FakeDataRepository? repository,
}) async {
  final cubit = await pumpWorkPage(
    tester,
    size: _phone,
    repository: repository,
  );
  cubit.selectView('board');
  await tester.pumpAndSettle();
  return cubit;
}

Finder _column(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(BoardColumn));

/// The visible column panel (the column widget fills its page).
Finder _panel(String label) =>
    find.descendant(of: _column(label), matching: find.byType(Container)).first;

double _leftOf(WidgetTester tester, String label) =>
    tester.getTopLeft(_column(label)).dx;

String? _stageOf(CollectionViewsCubit cubit, String id) =>
    switch ((cubit.state as ViewsReady).objects.firstWhere(
      (o) => o.id == id,
    )['stage']) {
      SingleSelectFieldValue(:final optionId) => optionId,
      _ => null,
    };

int _page(WidgetTester tester) =>
    tester.widget<PageView>(find.byType(PageView)).controller!.page!.round();

/// Long-presses [title] (touch) until the card lifts.
Future<TestGesture> _lift(WidgetTester tester, String title) async {
  final gesture = await tester.startGesture(tester.getCenter(find.text(title)));
  await tester.pump(BoardDragGestureRecognizer.delay);
  await tester.pump();
  return gesture;
}

/// Deals grouped by Company, with [count] companies (+ "No Company").
FakeDataRepository _companies(int count) {
  final repo = FakeDataRepository([
    deals.copyWith(views: [boardView.copyWith(layoutFieldId: 'company')]),
    companies,
  ]);
  repo.seedObjects('deals', [deal('d1', 0, name: 'Acme', company: 'k0')]);
  repo.seedObjects('companies', [
    for (var i = 0; i < count; i++) company('k$i', 'Company $i', i),
  ]);
  return repo;
}

void main() {
  testWidgets('phone ignores collapsed groups and has no collapse control', (
    tester,
  ) async {
    final repo = FakeDataRepository([
      deals.copyWith(
        views: [
          tableView,
          boardView.copyWith(collapsedGroups: ['lead', 'won']),
        ],
      ),
      companies,
    ]);
    repo.seedObjects('deals', sampleDeals());
    await _pumpBoard(tester, repository: repo);
    expect(find.byKey(const ValueKey('column-expand')), findsNothing);
    expect(find.byTooltip('Collapse Lead'), findsNothing);
    expect(tester.getSize(_column('Lead')).width, _pageWidth);
    expect(find.text('Acme renewal'), findsOneWidget);
  });

  group('phone pager', () {
    testWidgets('one column per page, the next one peeking', (tester) async {
      await _pumpBoard(tester);
      expect(find.byType(PageView), findsOneWidget);
      final pager = tester.widget<PageView>(find.byType(PageView));
      expect(pager.padEnds, isFalse);
      expect(pager.controller!.viewportFraction, (_w - 72) / _w);

      expect(_leftOf(tester, 'Lead'), 16);
      expect(tester.getSize(_panel('Lead')).width, _pageWidth - 12);
      // The whole page takes drops for its column.
      expect(tester.getSize(_column('Lead')).width, _pageWidth);
      // The next column peeks in at full opacity.
      expect(_leftOf(tester, 'Won'), 16 + _pageWidth);
      expect(_leftOf(tester, 'Won'), lessThan(390 - 16));
      expect(
        find.ancestor(of: _column('Won'), matching: find.byType(Opacity)),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('snaps to one column per swipe', (tester) async {
      await _pumpBoard(tester);
      final pager = find.byType(PageView);
      // A short drag snaps back.
      await tester.drag(pager, const Offset(-60, 0));
      await tester.pumpAndSettle();
      expect(_page(tester), 0);
      expect(_leftOf(tester, 'Lead'), 16);

      await tester.fling(pager, const Offset(-150, 0), 1000);
      await tester.pumpAndSettle();
      expect(_page(tester), 1);
      expect(_leftOf(tester, 'Won'), 16);
    });

    testWidgets('the column name opens a jump list', (tester) async {
      await _pumpBoard(tester);
      final jump = find.descendant(
        of: _column('Lead'),
        matching: find.byKey(const ValueKey('column-jump')),
      );
      expect(tester.getSize(jump).height, 44);
      expect(
        find.descendant(of: jump, matching: find.byIcon(Icons.arrow_drop_down)),
        findsOneWidget,
      );

      await tester.tap(jump);
      await tester.pumpAndSettle();
      expect(find.byType(ColumnJumpList), findsOneWidget);
      final rows = find.descendant(
        of: find.byType(ColumnJumpList),
        matching: find.byType(ListTile),
      );
      expect(rows, findsNWidgets(4));
      expect(tester.widget<ListTile>(rows.first).selected, isTrue);

      await tester.tap(
        find.descendant(of: rows.at(2), matching: find.text('Lost')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ColumnJumpList), findsNothing);
      expect(_page(tester), 2);
      expect(_leftOf(tester, 'Lost'), 16);
    });

    testWidgets('dots for up to 7 columns', (tester) async {
      await _pumpBoard(tester);
      final indicator = find.byType(BoardPageIndicator);
      final dots = find.descendant(
        of: indicator,
        matching: find.byType(AnimatedContainer),
      );
      expect(dots, findsNWidgets(4));
      expect(tester.getSize(dots.first).width, 16 + 6);
      expect(tester.getSize(dots.at(1)).width, 6 + 6);
      expect(find.text('1 / 4'), findsNothing);

      await tester.fling(find.byType(PageView), const Offset(-150, 0), 1000);
      await tester.pumpAndSettle();
      expect(tester.getSize(dots.first).width, 6 + 6);
      expect(tester.getSize(dots.at(1)).width, 16 + 6);
    });

    testWidgets('dots sit right under the shown column', (tester) async {
      await _pumpBoard(tester);
      final dots = tester.getRect(find.byType(BoardPageIndicator));
      final panel = tester.getRect(_panel('Lead'));
      expect(dots.top - panel.bottom, inInclusiveRange(0, Spacing.sm));
      expect(dots.center.dx, closeTo(panel.center.dx, 12));
    });

    testWidgets('the column button reads "Lead 5 ▾"', (tester) async {
      await _pumpBoard(tester);
      final button = find.descendant(
        of: _column('Lead'),
        matching: find.byKey(const ValueKey('column-jump')),
      );
      final count = find.descendant(of: button, matching: find.text('2'));
      final caret = find.descendant(
        of: button,
        matching: find.byIcon(Icons.arrow_drop_down),
      );
      expect(
        tester.getCenter(caret).dx,
        greaterThan(tester.getCenter(count).dx),
      );
    });

    testWidgets('"2 / 9" past 7 columns', (tester) async {
      await _pumpBoard(tester, repository: _companies(8));
      expect(find.text('1 / 9'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(BoardPageIndicator),
          matching: find.byType(AnimatedContainer),
        ),
        findsNothing,
      );
      await tester.fling(find.byType(PageView), const Offset(-150, 0), 1000);
      await tester.pumpAndSettle();
      expect(find.text('2 / 9'), findsOneWidget);
    });

    testWidgets('the FAB never covers a card', (tester) async {
      await _pumpBoard(
        tester,
        repository: workRepository(
          objects: [
            for (var i = 0; i < 30; i++)
              deal('c$i', i, name: 'Card $i', stage: 'lead'),
          ],
        ),
      );
      final fab = tester.getRect(find.byType(FloatingActionButton));
      expect(tester.getRect(_panel('Lead')).bottom, lessThanOrEqualTo(fab.top));
      expect(
        tester.getRect(find.byType(BoardPageIndicator)).bottom,
        lessThanOrEqualTo(fab.top),
      );
    });

    testWidgets('desktop keeps the side-scrolling list', (tester) async {
      final cubit = await pumpWorkPage(tester);
      cubit.selectView('board');
      await tester.pumpAndSettle();
      expect(find.byType(PageView), findsNothing);
      expect(find.byType(BoardPageIndicator), findsNothing);
      expect(find.byKey(const ValueKey('column-jump')), findsNothing);
    });
  });

  group('phone drag', () {
    testWidgets('holding a card at the edge for 500 ms turns one page', (
      tester,
    ) async {
      await _pumpBoard(tester);
      final gesture = await _lift(tester, 'Initech');
      final y = tester.getCenter(_column('Lead')).dy;
      await gesture.moveTo(Offset(390 - 16 - 20, y));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));
      expect(_page(tester), 0);
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pump(const Duration(milliseconds: 250));
      expect(_page(tester), 1);

      // Back in the middle: no further turns.
      await gesture.moveTo(Offset(150, y));
      await tester.pump(const Duration(seconds: 1));
      expect(_page(tester), 1);
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('a drop on another page writes the value', (tester) async {
      final cubit = await _pumpBoard(tester);
      final gesture = await _lift(tester, 'Initech');
      final y = tester.getCenter(_column('Lead')).dy;
      await gesture.moveTo(Offset(390 - 16 - 20, y));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 520));
      await tester.pump(const Duration(milliseconds: 250));
      expect(_page(tester), 1);
      await gesture.moveTo(Offset(120, y));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(_stageOf(cubit, 'd3'), 'won');
      expect(find.text('Moved to Won'), findsOneWidget);
    });

    testWidgets('a drop right after a turn lands in the column now under '
        'the finger', (tester) async {
      final cubit = await _pumpBoard(tester);
      final gesture = await _lift(tester, 'Initech');
      final y = tester.getCenter(_column('Lead')).dy;
      // Over the peeking "Won" column, in the edge zone.
      await gesture.moveTo(Offset(390 - 16 - 20, y));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 520));
      await tester.pump(const Duration(milliseconds: 250));
      expect(_page(tester), 1);
      // Without moving, the finger now rests on the peeking "Lost".
      await gesture.up();
      await tester.pumpAndSettle();
      expect(_stageOf(cubit, 'd3'), 'lost');
    });

    testWidgets('edge hold still works after the columns rebuild', (
      tester,
    ) async {
      final cubit = await _pumpBoard(tester);
      // Any state change rebuilds the columns (and their cards).
      await cubit.renameView('board', 'Deals board');
      await tester.pumpAndSettle();
      final gesture = await _lift(tester, 'Initech');
      final y = tester.getCenter(_column('Lead')).dy;
      await gesture.moveTo(Offset(390 - 16 - 20, y));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 520));
      await tester.pump(const Duration(milliseconds: 250));
      expect(_page(tester), 1);
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('a drop below a short column lands in it', (tester) async {
      final cubit = await _pumpBoard(tester);
      final gesture = await _lift(tester, 'Initech');
      // Over the peeking "Won", well below its last card, out of the edge zone.
      final below = Offset(
        16 + _pageWidth + 4,
        tester.getBottomLeft(_panel('Won')).dy + 150,
      );
      await gesture.moveTo(below);
      await tester.pump();
      await gesture.moveBy(const Offset(0, 1));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(_stageOf(cubit, 'd3'), 'won');
    });

    testWidgets('phone → desktop → phone keeps the page', (tester) async {
      await _pumpBoard(tester);
      await tester.tap(
        find.descendant(
          of: _column('Lead'),
          matching: find.byKey(const ValueKey('column-jump')),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(ColumnJumpList),
          matching: find.text('Lost'),
        ),
      );
      await tester.pumpAndSettle();
      expect(_page(tester), 2);

      tester.view.physicalSize = const Size(1280, 800);
      await tester.pumpAndSettle();
      expect(find.byType(PageView), findsNothing);
      tester.view.physicalSize = _phone;
      await tester.pumpAndSettle();
      // The pager and its indicator agree.
      final page = _page(tester);
      expect(find.bySemanticsLabel('Column ${page + 1} of 4'), findsOneWidget);
      expect(_leftOf(tester, ['Lead', 'Won', 'Lost', 'No Stage'][page]), 16);
    });
  });
}
