import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';
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
      expect(tester.getSize(_column('Lead')).width, BoardColumn.width);
      expect(xs[1] - xs[0], BoardColumn.width + 16);
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
      expect(wonColumn.foregroundDecoration, isNotNull);
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
