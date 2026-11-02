import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/design/design.dart';
import 'package:morkva_crm/features/views/views.dart';
import 'package:morkva_crm/features/views/widgets/board/board_card_draggable.dart';
import 'package:morkva_crm/features/views/widgets/board/board_column.dart';

import '../collections/fake_data_repository.dart';
import 'views_fixtures.dart';
import 'work_page_harness.dart';

/// The Work page on the "Pipeline" board view (grouped by Stage).
Future<CollectionViewsCubit> _pumpBoard(
  WidgetTester tester, {
  FakeDataRepository? repository,
}) async {
  final cubit = await pumpWorkPage(tester, repository: repository);
  cubit.selectView('board');
  await tester.pumpAndSettle();
  return cubit;
}

Finder _column(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(BoardColumn));

Finder _card(String title) =>
    find.ancestor(of: find.text(title), matching: find.byType(ObjectCard));

ViewsReady _ready(CollectionViewsCubit cubit) => cubit.state as ViewsReady;

/// The board's horizontal Scrollable.
Finder _board() => find
    .ancestor(
      of: find.byType(BoardColumn).first,
      matching: find.byType(Scrollable),
    )
    .first;

/// Group key of the column under [point], if any.
String? _columnAt(WidgetTester tester, Offset point) {
  for (final e in find.byType(BoardColumn).evaluate()) {
    final box = e.renderObject! as RenderBox;
    if ((box.localToGlobal(Offset.zero) & box.size).contains(point)) {
      return (e.widget as BoardColumn).group.key;
    }
  }
  return null;
}

String? _stageOf(CollectionViewsCubit cubit, String id) =>
    switch (_ready(cubit).objects.firstWhere((o) => o.id == id)['stage']) {
      SingleSelectFieldValue(:final optionId) => optionId,
      _ => null,
    };

List<String> _titlesIn(String column) => [
  for (final e
      in find
          .descendant(of: _column(column), matching: find.byType(ObjectCard))
          .evaluate())
    e,
].map((e) => (e.widget as ObjectCard).object.id).toList();

/// Just inside the bottom edge of a column: drops land at its end.
Offset _bottomOf(WidgetTester tester, String column) =>
    tester.getBottomLeft(_column(column)) + const Offset(80, -6);

/// Drags [title] with a mouse to [to] (global), pumping between moves.
Future<void> _mouseDrag(WidgetTester tester, String title, Offset to) async {
  final gesture = await tester.startGesture(
    tester.getCenter(find.text(title)),
    kind: PointerDeviceKind.mouse,
  );
  await gesture.moveBy(const Offset(0, 6));
  await tester.pump();
  await gesture.moveTo(to);
  await tester.pump();
  await gesture.moveTo(to + const Offset(0, 1));
  await tester.pump();
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  group('BoardMode', () {
    test('is registered and needs a groupable layout field', () {
      final registry = defaultViewModeRegistry();
      expect(registry.byId(ViewModeIds.board), isA<BoardMode>());
      const board = BoardMode();
      expect(board.needsLayoutField, isTrue);
      expect(board.drawsNoMatches, isTrue);
      expect(board.acceptsLayoutField(stageField), isTrue);
      expect(board.acceptsLayoutField(companyField), isTrue);
      expect(
        board.acceptsLayoutField(
          const ReferenceFieldDefinition(
            id: 'm',
            name: 'Many',
            targetCollectionId: 'companies',
            multiple: true,
          ),
        ),
        isFalse,
      );
      expect(board.acceptsLayoutField(dueField), isFalse);
      expect(board.unavailableReason(deals), isNull);
      expect(
        board.unavailableReason(
          const Collection(
            id: 'c',
            name: 'C',
            fields: [TextFieldDefinition(id: 'n', name: 'N')],
          ),
        ),
        'Needs a choice or reference field',
      );
    });
  });

  group('columns', () {
    testWidgets('one per option, then "No Stage", with counts', (tester) async {
      await _pumpBoard(tester);
      expect(find.byType(BoardColumn), findsNWidgets(4));
      final xs = [
        for (final l in ['Lead', 'Won', 'Lost', 'No Stage'])
          tester.getTopLeft(_column(l)).dx,
      ];
      expect(xs, orderedEquals([...xs]..sort()));
      expect(tester.getSize(_column('Lead')).width, BoardColumn.defaultWidth);
      expect(xs[1] - xs[0], BoardColumn.defaultWidth + 16);
      expect(
        find.descendant(of: _column('Lead'), matching: find.text('2')),
        findsOneWidget,
      );
      expect(_titlesIn('Lead'), ['d1', 'd3']);
      expect(_titlesIn('No Stage'), ['d5']);
      expect(find.text('Group: Stage'), findsOneWidget);
      expect(find.text('Setup card'), findsOneWidget);
    });

    testWidgets('reference columns use the target names', (tester) async {
      final cubit = await _pumpBoard(tester);
      await cubit.setLayoutField('company');
      await tester.pumpAndSettle();
      expect(_column('Alpha Ltd'), findsOneWidget);
      expect(_column('Zeta Corp'), findsOneWidget);
      expect(_column('No Company'), findsOneWidget);
      expect(_titlesIn('Alpha Ltd'), ['d1']);
      // Reference boards have no option list to edit.
      expect(find.byTooltip('Column options'), findsNothing);
    });

    testWidgets('empty columns show a short dashed drop zone', (tester) async {
      await _pumpBoard(
        tester,
        repository: workRepository(
          objects: [deal('d1', 0, name: 'Acme', stage: 'lead')],
        ),
      );
      expect(
        find.descendant(of: _column('Won'), matching: find.text('No deals')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _column('No Stage'),
          matching: find.text('Drop here to clear Stage'),
        ),
        findsOneWidget,
      );
      final zone = find.descendant(
        of: _column('Won'),
        matching: find.byType(DashedRRect),
      );
      expect(tester.getSize(zone).height, BoardColumn.emptyHeight);
    });

    testWidgets('header buttons are exactly 44 px', (tester) async {
      await _pumpBoard(tester);
      expect(
        tester.getSize(find.byTooltip('New deal in Won')),
        const Size.square(44),
      );
      expect(
        tester.getSize(
          find.descendant(
            of: _column('Won'),
            matching: find.byTooltip('Column options'),
          ),
        ),
        const Size.square(44),
      );
    });

    testWidgets('"+" opens quick add pre-filled with the column', (
      tester,
    ) async {
      await _pumpBoard(tester);
      await tester.tap(find.byTooltip('New deal in Won'));
      await tester.pumpAndSettle();
      expect(find.byType(QuickAddDialog), findsOneWidget);
      expect(find.textContaining('Stage · Won'), findsOneWidget);
    });

    testWidgets('⋯ → Edit options opens Build', (tester) async {
      await _pumpBoard(tester);
      await tester.tap(
        find.descendant(
          of: _column('Lead'),
          matching: find.byTooltip('Column options'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit options'));
      await tester.pumpAndSettle();
      expect(find.text('editor:deals'), findsOneWidget);
      expect(
        GoRouterState.of(
          tester.element(find.text('editor:deals')),
        ).uri.queryParameters['field'],
        'stage',
      );
    });
  });

  group('drag', () {
    testWidgets('column → column writes the field, with Undo', (tester) async {
      final cubit = await _pumpBoard(tester);
      await _mouseDrag(tester, 'Initech', _bottomOf(tester, 'Won'));
      expect(_stageOf(cubit, 'd3'), 'won');
      expect(_titlesIn('Won'), ['d2', 'd3']);
      expect(find.text('Moved to Won'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(_stageOf(cubit, 'd3'), 'lead');
    });

    testWidgets('within a column saves the manual order', (tester) async {
      final cubit = await _pumpBoard(tester);
      await _mouseDrag(
        tester,
        'Initech',
        tester.getTopLeft(_card('Acme renewal')) + const Offset(40, 2),
      );
      expect(_titlesIn('Lead'), ['d3', 'd1']);
      expect(
        _ready(cubit).activeView.manualOrder.indexOf('d3'),
        lessThan(_ready(cubit).activeView.manualOrder.indexOf('d1')),
      );
      expect(find.text('Reordered in Lead'), findsOneWidget);
    });

    testWidgets('dropping back in place does nothing', (tester) async {
      final cubit = await _pumpBoard(tester);
      final before = _ready(cubit).activeView;
      await _mouseDrag(tester, 'Initech', tester.getCenter(_card('Initech')));
      expect(_ready(cubit).activeView, before);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('into the No column clears the field', (tester) async {
      final cubit = await _pumpBoard(tester);
      // The last column is only partly in view at 1280.
      await _mouseDrag(
        tester,
        'Umbrella',
        tester.getTopLeft(_column('No Stage')) + const Offset(40, 80),
      );
      expect(_stageOf(cubit, 'd4'), isNull);
      expect(find.text('Moved to No Stage'), findsOneWidget);
    });

    testWidgets('into a value hidden by a filter says so', (tester) async {
      final cubit = await _pumpBoard(tester);
      await cubit.setFilters(const [
        ViewFilter(fieldId: 'stage', op: FilterOp.anyOf, operand: ['lead']),
      ]);
      await tester.pumpAndSettle();
      await _mouseDrag(tester, 'Initech', tester.getCenter(_column('Won')));
      expect(find.text('Moved to Won — hidden by filter'), findsOneWidget);
      expect(find.text('Initech'), findsNothing);
    });

    testWidgets('lift, ghost and target while dragging; 4 px slop', (
      tester,
    ) async {
      await _pumpBoard(tester);
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Initech')),
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveBy(const Offset(0, 3));
      await tester.pump();
      // Not lifted yet: no ghost anywhere.
      expect(
        find.byWidgetPredicate((w) => w is DashedRRect && w.strokeWidth == 2),
        findsNothing,
      );

      await gesture.moveBy(const Offset(0, 3));
      await tester.pump();
      await gesture.moveTo(tester.getCenter(_column('Won')));
      await tester.pump();
      await gesture.moveBy(const Offset(0, 1));
      await tester.pump(const Duration(milliseconds: 300));

      final ghost = find.byWidgetPredicate(
        (w) => w is DashedRRect && w.strokeWidth == 2,
      );
      expect(
        find.descendant(of: _column('Won'), matching: ghost),
        findsOneWidget,
      );
      final wonColumn = tester.widget<Container>(
        find
            .descendant(of: _column('Won'), matching: find.byType(Container))
            .first,
      );
      expect(
        (wonColumn.foregroundDecoration! as BoxDecoration).border,
        isA<Border>().having((b) => b.top.width, 'width', 2),
      );
      expect(
        (wonColumn.decoration! as BoxDecoration).color,
        AppTheme.light.colorScheme.surfaceContainerHigh,
      );
      // The source slot has collapsed.
      final slot = find.descendant(
        of: _column('Lead'),
        matching: find.byType(TweenAnimationBuilder<double>),
      );
      expect(tester.getSize(slot).height, 0);
      // Counts change on drop only.
      expect(
        find.descendant(of: _column('Lead'), matching: find.text('2')),
        findsOneWidget,
      );

      await gesture.up();
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: _column('Lead'), matching: find.text('1')),
        findsOneWidget,
      );
    });

    testWidgets('touch lifts after a 300 ms long press', (tester) async {
      final cubit = await _pumpBoard(tester);
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Initech')),
      );
      await tester.pump(BoardDragGestureRecognizer.delay);
      await gesture.moveTo(tester.getCenter(_column('Won')));
      await tester.pump();
      await gesture.moveBy(const Offset(0, 1));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(_stageOf(cubit, 'd3'), 'won');
    });
  });

  group('scale', () {
    /// Deals grouped by Company, with [count] companies.
    FakeDataRepository manyCompanies(int count, List<MorkvaObject> objects) {
      final repo = FakeDataRepository([
        deals.copyWith(views: [boardView.copyWith(layoutFieldId: 'company')]),
        companies,
      ]);
      repo.seedObjects('deals', objects);
      repo.seedObjects('companies', [
        for (var i = 0; i < count; i++)
          company('k$i', 'Company ${i.toString().padLeft(3, '0')}', i),
      ]);
      return repo;
    }

    testWidgets('columns are built lazily', (tester) async {
      await _pumpBoard(tester, repository: manyCompanies(200, const []));
      final built = find.byType(BoardColumn).evaluate().length;
      expect(built, greaterThan(0));
      expect(built, lessThan(10));
    });

    testWidgets('holding a card near a column bottom scrolls that column', (
      tester,
    ) async {
      final cubit = await pumpWorkPage(
        tester,
        size: const Size(1280, 600),
        repository: workRepository(
          objects: [
            for (var i = 0; i < 30; i++)
              deal('c$i', i, name: 'Card $i', stage: 'lead'),
          ],
        ),
      );
      cubit.selectView('board');
      await tester.pumpAndSettle();
      final list = find.descendant(
        of: _column('Lead'),
        matching: find.byType(Scrollable),
      );
      final position = tester.state<ScrollableState>(list).position;
      expect(position.pixels, 0);

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Card 1')),
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveBy(const Offset(0, 6));
      await tester.pump();
      await gesture.moveTo(tester.getBottomLeft(list) + const Offset(60, -12));
      await tester.pump();
      await gesture.moveBy(const Offset(0, 1));
      await tester.pump();
      // Cards above the pointer before any scrolling.
      final pointerY = tester.getBottomLeft(list).dy - 11;
      final stale = [
        for (final e
            in find
                .descendant(
                  of: _column('Lead'),
                  matching: find.byType(ObjectCard),
                )
                .evaluate())
          if ((e.widget as ObjectCard).object.id != 'c1')
            if (e.renderObject case final RenderBox box
                when box.localToGlobal(box.size.center(Offset.zero)).dy <
                    pointerY)
              e,
      ].length;
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(position.pixels, greaterThan(0));
      // The board itself did not scroll sideways.
      expect(tester.state<ScrollableState>(_board()).position.pixels, 0);

      // Dropped without moving: it lands where the pointer is now, deep in
      // the scrolled column, not where it was when scrolling began.
      await gesture.up();
      await tester.pumpAndSettle();
      final order = [for (final o in _ready(cubit).objects) o.id];
      expect(order.indexOf('c1'), greaterThan(stale + 2));
    });

    testWidgets('a drop while the board scrolls under a still pointer lands '
        'in the column now under it', (tester) async {
      final cubit = await _pumpBoard(
        tester,
        repository: manyCompanies(60, [
          deal('d1', 0, name: 'Acme renewal', company: 'k0'),
        ]),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Acme renewal')),
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveBy(const Offset(0, 6));
      await tester.pump();
      final edge = tester.getTopRight(_board()) + const Offset(-10, 40);
      await gesture.moveTo(edge);
      await tester.pump();
      final start = _columnAt(tester, edge);
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      final now = _columnAt(tester, edge);
      expect(now, isNot(start));
      await gesture.up();
      await tester.pumpAndSettle();
      final company = switch (_ready(cubit).objects.single['company']) {
        ReferenceFieldValue(:final objectIds) => objectIds.single,
        _ => null,
      };
      expect(company, now);
    });

    testWidgets('board and column auto-scroll after the columns rebuild', (
      tester,
    ) async {
      final cubit = await _pumpBoard(
        tester,
        repository: manyCompanies(60, [
          for (var i = 0; i < 30; i++)
            deal('c$i', i, name: 'Card $i', company: 'k0'),
        ]),
      );
      // Any state change rebuilds the columns (and their cards).
      await cubit.renameView('board', 'Renamed');
      await tester.pumpAndSettle();

      // Column: hold near its bottom.
      final list = find.descendant(
        of: _column('Company 000'),
        matching: find.byType(Scrollable),
      );
      final column = tester.state<ScrollableState>(list).position;
      var gesture = await tester.startGesture(
        tester.getCenter(find.text('Card 1')),
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveBy(const Offset(0, 6));
      await tester.pump();
      await gesture.moveTo(tester.getBottomLeft(list) + const Offset(60, -12));
      await tester.pump();
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      // More than one step.
      expect(column.pixels, greaterThan(40));
      await gesture.moveTo(tester.getCenter(_column('Company 000')));
      await tester.pump(const Duration(milliseconds: 300));
      await gesture.up();
      await tester.pumpAndSettle();

      // Board: hold at the right edge.
      gesture = await tester.startGesture(
        tester.getCenter(
          find
              .descendant(
                of: _column('Company 000'),
                matching: find.byType(ObjectCard),
              )
              .hitTestable()
              .first,
        ),
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveBy(const Offset(0, 6));
      await tester.pump();
      await gesture.moveTo(
        tester.getTopRight(_board()) + const Offset(-10, 40),
      );
      await tester.pump();
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(
        tester.state<ScrollableState>(_board()).position.pixels,
        greaterThan(40),
      );
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('a ghost alone in a column keeps the empty height', (
      tester,
    ) async {
      await _pumpBoard(
        tester,
        repository: workRepository(
          objects: [deal('d1', 0, name: 'Acme', stage: 'lead')],
        ),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Acme')),
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveBy(const Offset(0, 6));
      await tester.pump();
      await gesture.moveTo(tester.getCenter(_column('Won')));
      await tester.pump();
      await gesture.moveBy(const Offset(0, 1));
      await tester.pump();
      final ghost = find.descendant(
        of: _column('Won'),
        matching: find.byWidgetPredicate(
          (w) => w is DashedRRect && w.strokeWidth == 2,
        ),
      );
      expect(tester.getSize(ghost).height, BoardColumn.emptyHeight);
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('another finger does not stop the drag auto-scroll', (
      tester,
    ) async {
      await _pumpBoard(
        tester,
        repository: manyCompanies(60, [
          deal('d1', 0, name: 'Acme renewal', company: 'k0'),
        ]),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Acme renewal')),
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveBy(const Offset(0, 6));
      await tester.pump();
      await gesture.moveTo(
        tester.getTopRight(_board()) + const Offset(-10, 120),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final position = tester.state<ScrollableState>(_board()).position;

      // A second finger lands, moves away from the edge and lifts.
      final other = await tester.startGesture(
        const Offset(400, 500),
        pointer: 7,
      );
      await other.moveBy(const Offset(-80, 0));
      await tester.pump();
      await other.up();
      await tester.pump(const Duration(milliseconds: 300));
      final before = position.pixels;
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(position.pixels, greaterThan(before));

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('board auto-scroll stops on release even after the source '
        'column is gone', (tester) async {
      await _pumpBoard(
        tester,
        repository: manyCompanies(60, [
          deal('d1', 0, name: 'Acme renewal', company: 'k0'),
        ]),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Acme renewal')),
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveBy(const Offset(0, 6));
      await tester.pump();
      final board = find
          .ancestor(
            of: find.byType(BoardColumn).first,
            matching: find.byType(Scrollable),
          )
          .first;
      final edge = tester.getTopRight(board) + const Offset(-10, 120);
      await gesture.moveTo(edge);
      await tester.pump();
      for (var i = 0; i < 120; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      final position = tester.state<ScrollableState>(board).position;
      expect(position.pixels, greaterThan(BoardColumn.defaultWidth * 2));
      // The source column scrolled out and was disposed.
      expect(_column('Company 000'), findsNothing);

      await gesture.up();
      await tester.pump();
      // Let the step already in flight finish.
      await tester.pump(const Duration(milliseconds: 300));
      final stopped = position.pixels;
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(position.pixels, stopped);
      await tester.pumpAndSettle();
    });
  });

  group('settings and states', () {
    testWidgets('"Group: Stage" picks another groupable field', (tester) async {
      final cubit = await _pumpBoard(tester);
      await tester.tap(find.text('Group: Stage'));
      await tester.pumpAndSettle();
      // Only groupable fields are offered.
      expect(find.widgetWithText(MenuItemButton, 'Stage'), findsOneWidget);
      expect(find.widgetWithText(MenuItemButton, 'Due'), findsNothing);
      await tester.tap(find.widgetWithText(MenuItemButton, 'Company'));
      await tester.pumpAndSettle();
      expect(_ready(cubit).activeView.layoutFieldId, 'company');
      expect(find.text('Group: Company'), findsOneWidget);
    });

    testWidgets('filters hiding everything keep the columns', (tester) async {
      final cubit = await _pumpBoard(tester);
      await cubit.setFilters(const [
        ViewFilter(fieldId: 'name', op: FilterOp.contains, operand: 'zzz'),
      ]);
      await tester.pumpAndSettle();
      expect(find.byType(BoardColumn), findsNWidgets(4));
      expect(find.text('Nothing matches these filters'), findsOneWidget);
      await tester.tap(find.text('Clear filters'));
      await tester.pumpAndSettle();
      expect(_ready(cubit).activeView.filters, isEmpty);
      expect(find.text('Nothing matches these filters'), findsNothing);
    });

    testWidgets('no groupable field → "Add field" opens Build', (tester) async {
      const plain = Collection(
        id: 'deals',
        name: 'Deals',
        fields: [TextFieldDefinition(id: 'name', name: 'Name')],
        views: [
          ViewDefinition(
            id: 'all',
            name: 'Board',
            mode: ViewModeIds.board,
            fieldIds: ['name'],
          ),
        ],
      );
      await pumpWorkPage(
        tester,
        repository: workRepository(collection: plain, objects: const []),
      );
      expect(
        find.text('Board needs a choice or reference field'),
        findsOneWidget,
      );
      expect(find.textContaining('Group:'), findsNothing);
      // Nothing to sort or set up until the board can draw.
      expect(find.text('Sort'), findsNothing);
      expect(find.text('Setup card'), findsNothing);
      await tester.tap(find.text('Add field'));
      await tester.pumpAndSettle();
      expect(find.text('editor:deals'), findsOneWidget);
    });

    testWidgets('no layout field yet → pick one', (tester) async {
      final cubit = await _pumpBoard(tester);
      await cubit.setLayoutField(null);
      await tester.pumpAndSettle();
      expect(find.text('Choose how to group this board'), findsOneWidget);
      await tester.tap(find.text('Group by…'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(MenuItemButton, 'Stage').last);
      await tester.pumpAndSettle();
      expect(_ready(cubit).activeView.layoutFieldId, 'stage');
      expect(find.byType(BoardColumn), findsNWidgets(4));
    });
  });
}
