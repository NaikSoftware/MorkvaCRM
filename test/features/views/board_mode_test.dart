import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
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
            matching: find.byTooltip('Collapse Won'),
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
  });

  group('collapse', () {
    Finder strip(String label) => find.ancestor(
      of: find.byKey(const ValueKey('column-expand')),
      matching: _column(label),
    );
    Finder expandButton(String label) => find.descendant(
      of: strip(label),
      matching: find.byKey(const ValueKey('column-expand')),
    );

    testWidgets('header icon collapses to a vertical strip; tap expands', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final cubit = await _pumpBoard(tester);
      await tester.tap(find.byTooltip('Collapse Lead'));
      await tester.pumpAndSettle();

      expect(_ready(cubit).activeView.collapsedGroups, ['lead']);
      expect(tester.getSize(_column('Lead')).width, BoardColumn.collapsedWidth);
      expect(_titlesIn('Lead'), isEmpty);
      // Name written top to bottom, count badge; no "+" on the strip.
      expect(
        find.ancestor(of: find.text('Lead'), matching: find.byType(RotatedBox)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: _column('Lead'), matching: find.text('2')),
        findsOneWidget,
      );
      expect(find.byTooltip('New deal in Lead'), findsNothing);
      expect(find.bySemanticsLabel('Expand Lead, 2 deals'), findsOneWidget);
      // The next column moved in.
      expect(
        tester.getTopLeft(_column('Won')).dx -
            tester.getTopLeft(_column('Lead')).dx,
        BoardColumn.collapsedWidth + 16,
      );

      await tester.tap(expandButton('Lead'));
      await tester.pumpAndSettle();
      expect(_ready(cubit).activeView.collapsedGroups, isEmpty);
      expect(tester.getSize(_column('Lead')).width, BoardColumn.defaultWidth);
      expect(_titlesIn('Lead'), ['d1', 'd3']);
      semantics.dispose();
    });

    testWidgets('a mouse click on the strip expands it (web)', (tester) async {
      final cubit = await _pumpBoard(tester);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      Future<void> click(Offset at) async {
        await mouse.moveTo(at);
        await tester.pump();
        await mouse.down(at);
        await tester.pump();
        await mouse.up();
        await tester.pumpAndSettle();
      }

      await click(tester.getCenter(find.byTooltip('Collapse Lead')));
      expect(_ready(cubit).activeView.collapsedGroups, ['lead']);
      // The strip hugs its content, top-aligned with the columns.
      final stripBox = tester.getRect(expandButton('Lead'));
      expect(stripBox.top, tester.getRect(_column('Won')).top);
      expect(stripBox.height, lessThan(tester.getSize(_board()).height / 2));

      // On the vertical name, then (collapsed again) on the expand icon.
      await click(tester.getCenter(find.text('Lead')));
      expect(_ready(cubit).activeView.collapsedGroups, isEmpty);
      expect(tester.getSize(_column('Lead')).width, BoardColumn.defaultWidth);

      await click(tester.getCenter(find.byTooltip('Collapse Lead')));
      await click(
        tester.getCenter(
          find.descendant(
            of: strip('Lead'),
            matching: find.byIcon(Icons.unfold_more),
          ),
        ),
      );
      expect(_ready(cubit).activeView.collapsedGroups, isEmpty);
    });

    testWidgets('empty and "No" groups say so in the strip label', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final repo = workRepository(
        objects: [deal('d1', 0, name: 'Acme', stage: 'lead')],
      );
      final cubit = await _pumpBoard(tester, repository: repo);
      await cubit.toggleGroupCollapsed('won');
      await cubit.toggleGroupCollapsed(null);
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Expand Won, No deals'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Expand No Stage, No deals'),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('collapsed state comes back from the repository', (
      tester,
    ) async {
      final repo = FakeDataRepository([
        deals.copyWith(
          views: [
            tableView,
            boardView.copyWith(
              collapsedGroups: ['won', ViewDefinition.noGroupToken, 'gone'],
            ),
          ],
        ),
        companies,
      ]);
      repo.seedObjects('deals', sampleDeals());
      await _pumpBoard(tester, repository: repo);
      expect(find.byKey(const ValueKey('column-expand')), findsNWidgets(2));
      expect(strip('Won'), findsOneWidget);
      expect(strip('No Stage'), findsOneWidget);
      // A stale key (deleted option) changes nothing.
      expect(find.byType(BoardColumn), findsNWidgets(4));
      expect(tester.getSize(_column('Lead')).width, BoardColumn.defaultWidth);
    });

    testWidgets('a card dropped on a strip moves to the end of that group', (
      tester,
    ) async {
      final cubit = await _pumpBoard(tester);
      await cubit.toggleGroupCollapsed('won');
      await tester.pumpAndSettle();

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Initech')),
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveBy(const Offset(0, 6));
      await tester.pump();
      final target = tester.getCenter(strip('Won'));
      await gesture.moveTo(target);
      await tester.pump();
      await gesture.moveTo(target + const Offset(0, 1));
      await tester.pump();
      // Hovered: the strip tints like a column.
      final material = tester.widget<Material>(
        find
            .descendant(of: strip('Won'), matching: find.byType(Material))
            .first,
      );
      final scheme = Theme.of(tester.element(strip('Won'))).colorScheme;
      // The hover step composes under the option tint.
      expect(
        material.color,
        Color.alphaBlend(
          const Color(0xFF2E8B57).withValues(alpha: BoardColumn.tintAlphaLight),
          scheme.surfaceContainerHigh,
        ),
      );
      await gesture.up();
      await tester.pumpAndSettle();

      expect(_stageOf(cubit, 'd3'), 'won');
      expect(find.text('Moved to Won'), findsOneWidget);
      expect(
        find.descendant(of: strip('Won'), matching: find.text('2')),
        findsOneWidget,
      );
      await cubit.toggleGroupCollapsed('won');
      await tester.pumpAndSettle();
      expect(_titlesIn('Won'), ['d2', 'd3']);
    });
  });

  group('tint', () {
    Color columnColor(WidgetTester tester, String label) =>
        (tester
                    .widget<Container>(
                      find
                          .descendant(
                            of: _column(label),
                            matching: find.byType(Container),
                          )
                          .first,
                    )
                    .decoration!
                as BoxDecoration)
            .color!;

    testWidgets('option columns are tinted; "No" column is not', (
      tester,
    ) async {
      await _pumpBoard(tester);
      final scheme = Theme.of(tester.element(_column('Won'))).colorScheme;
      expect(
        columnColor(tester, 'Won'),
        Color.alphaBlend(
          const Color(0xFF2E8B57).withValues(alpha: BoardColumn.tintAlphaLight),
          scheme.surfaceContainerLow,
        ),
      );
      expect(columnColor(tester, 'No Stage'), scheme.surfaceContainerLow);
    });

    testWidgets('options without a colour and dark theme', (tester) async {
      late BuildContext light;
      late BuildContext dark;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (c) {
              light = c;
              return Theme(
                data: AppTheme.dark,
                child: Builder(
                  builder: (c) {
                    dark = c;
                    return const SizedBox();
                  },
                ),
              );
            },
          ),
        ),
      );
      const plain = ViewGroup(key: 'plain', label: 'Plain', objects: []);
      const field = SingleSelectFieldDefinition(
        id: 'f',
        name: 'F',
        options: [SelectOption(id: 'plain', label: 'Plain')],
      );
      const surface = Color(0xFF101010);
      expect(BoardColumn.tinted(light, field, plain, surface), surface);
      const won = ViewGroup(key: 'won', label: 'Won', objects: []);
      expect(
        BoardColumn.tinted(dark, stageField, won, surface),
        Color.alphaBlend(
          const Color(0xFF2E8B57).withValues(alpha: BoardColumn.tintAlphaDark),
          surface,
        ),
      );
      // A reference grouping has no colours.
      expect(BoardColumn.tinted(light, companyField, won, surface), surface);
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

    testWidgets('Esc cancels the drag: nothing moves or is written', (
      tester,
    ) async {
      final repo = workRepository();
      final cubit = await _pumpBoard(tester, repository: repo);
      final before = repo.objectsOf('deals');
      final views = repo.saveViewsCount;
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Initech')),
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveBy(const Offset(0, 6));
      await tester.pump();
      final to = _bottomOf(tester, 'Won');
      await gesture.moveTo(to);
      await tester.pump();
      await gesture.moveTo(to + const Offset(0, 1));
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      // Still held: moves and the release are ignored.
      await gesture.moveTo(to + const Offset(0, 4));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(_stageOf(cubit, 'd3'), 'lead');
      expect(_titlesIn('Lead'), ['d1', 'd3']);
      expect(repo.objectsOf('deals'), before);
      expect(repo.saveViewsCount, views);
      expect(find.text('Moved to Won'), findsNothing);
      expect(tester.takeException(), isNull);
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
        Color.alphaBlend(
          const Color(0xFF2E8B57).withValues(alpha: BoardColumn.tintAlphaLight),
          AppTheme.light.colorScheme.surfaceContainerHigh,
        ),
      );
      // The source slot has collapsed.
      final slot = find
          .descendant(
            of: _column('Lead'),
            // The innermost: the column's own width animation wraps the slots.
            matching: find.byType(TweenAnimationBuilder<double>),
          )
          .last;
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

    testWidgets('a slow mouse drag on a card lifts it, not scrolls the board', (
      tester,
    ) async {
      final cubit = await _pumpBoard(tester);
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Initech')),
        kind: PointerDeviceKind.mouse,
      );
      // A real mouse reports 1 px steps.
      for (var i = 0; i < 8; i++) {
        await gesture.moveBy(const Offset(1, 0));
        await tester.pump();
      }
      expect(tester.state<ScrollableState>(_board()).position.pixels, 0);
      await gesture.moveTo(tester.getCenter(_column('Won')));
      await tester.pump();
      await gesture.moveBy(const Offset(0, 1));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(_stageOf(cubit, 'd3'), 'won');
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

    group('mouse wheel', () {
      /// 20 company columns; "Company 000" holds 30 cards and scrolls.
      Future<void> pump(WidgetTester tester) async {
        final cubit = await pumpWorkPage(
          tester,
          size: const Size(1280, 600),
          repository: manyCompanies(20, [
            for (var i = 0; i < 30; i++)
              deal('c$i', i, name: 'Card $i', company: 'k0'),
          ]),
        );
        cubit.selectView('board');
        await tester.pumpAndSettle();
      }

      Future<void> wheel(WidgetTester tester, Offset at, double dy) async {
        final mouse = TestPointer(1, PointerDeviceKind.mouse);
        await tester.sendEventToBinding(mouse.hover(at));
        await tester.sendEventToBinding(mouse.scroll(Offset(0, dy)));
        await tester.pumpAndSettle();
      }

      double board(WidgetTester tester) =>
          tester.state<ScrollableState>(_board()).position.pixels;

      ScrollPosition list(WidgetTester tester, String label) => tester
          .state<ScrollableState>(
            find.descendant(
              of: _column(label),
              matching: find.byType(Scrollable),
            ),
          )
          .position;

      testWidgets('over the background scrolls the board sideways', (
        tester,
      ) async {
        await pump(tester);
        // The gap between two columns.
        final gap =
            tester.getTopRight(_column('Company 001')) + const Offset(6, 100);
        await wheel(tester, gap, 120);
        expect(board(tester), 120);
        await wheel(tester, gap - const Offset(120, 0), -50);
        expect(board(tester), 70);
      });

      testWidgets('over a column that cannot scroll scrolls the board', (
        tester,
      ) async {
        await pump(tester);
        await wheel(tester, tester.getCenter(_column('Company 001')), 120);
        expect(board(tester), 120);
      });

      testWidgets('over a scrollable column scrolls only that column, even '
          'at its end', (tester) async {
        await pump(tester);
        final at = tester.getCenter(find.text('Card 1'));
        await wheel(tester, at, 100);
        expect(list(tester, 'Company 000').pixels, 100);
        expect(board(tester), 0);
        // Back at the top: a further wheel up doesn't spill to the board.
        await wheel(tester, at, -300);
        await wheel(tester, at, -100);
        expect(list(tester, 'Company 000').pixels, 0);
        expect(board(tester), 0);
      });
    });

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
