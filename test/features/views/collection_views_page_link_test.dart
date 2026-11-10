import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/features/assistant/bloc/assistant_focus.dart';
import 'package:morkva_crm/features/objects/object_editor.dart';
import 'package:morkva_crm/features/views/views.dart';

import 'work_page_harness.dart';

/// Deals at stage Won or Lead: d1, d2, d3.
final _wonOrLead = [
  {
    'field': 'Stage',
    'op': 'anyOf',
    'value': ['Won', 'Lead'],
  },
];

void _go(WidgetTester tester, String location) =>
    GoRouter.of(tester.element(find.byType(CollectionViewsPage))).go(location);

void main() {
  setUp(resetFirstItemNudges);

  group('deep links', () {
    testWidgets('same collection, new filter param: filter applied', (
      tester,
    ) async {
      final cubit = await pumpWorkPage(tester);
      expect(find.text('Umbrella'), findsOneWidget);

      _go(tester, collectionLink('deals', where: _wonOrLead));
      await tester.pumpAndSettle();

      expect(find.textContaining('From assistant'), findsOneWidget);
      expect(find.text('Umbrella'), findsNothing);
      expect(find.text('Globex pilot'), findsOneWidget);
      final state = cubit.state as ViewsReady;
      expect(state.objects.map((o) => o.id), ['d1', 'd2', 'd3']);
      expect(state.activeView.filters, isEmpty);
    });

    testWidgets('the same link again is not re-applied', (tester) async {
      final cubit = await pumpWorkPage(
        tester,
        location: collectionLink('deals', where: _wonOrLead),
      );
      expect(find.textContaining('From assistant'), findsOneWidget);
      cubit.clearTransientFilters();
      await tester.pumpAndSettle();
      // A new location with the same (view, filter, card) keeps the user's
      // choice.
      _go(tester, '${collectionLink('deals', where: _wonOrLead)}&x=1');
      await tester.pumpAndSettle();
      expect(find.textContaining('From assistant'), findsNothing);
      // A different link applies again.
      _go(tester, collectionLink('deals', view: 'all', where: _wonOrLead));
      await tester.pumpAndSettle();
      expect(find.textContaining('From assistant'), findsOneWidget);
    });

    testWidgets('a cold link selects the view and filters it', (tester) async {
      final cubit = await pumpWorkPage(
        tester,
        location: collectionLink('deals', view: 'board', where: _wonOrLead),
      );
      await tester.pumpAndSettle();
      final state = cubit.state as ViewsReady;
      expect(state.activeViewId, 'board');
      expect(state.transientFilters, hasLength(1));
      expect(find.textContaining('From assistant'), findsOneWidget);
    });

    testWidgets('an invalid filter is dropped with a snackbar', (tester) async {
      final cubit = await pumpWorkPage(tester);
      _go(tester, '/collections/deals?view=board&filter=bm9wZQ');
      await tester.pumpAndSettle();
      expect(find.text("This link's filter isn't valid"), findsOneWidget);
      final state = cubit.state as ViewsReady;
      expect(state.activeViewId, 'board');
      expect(state.transientFilters, isEmpty);
      expect(state.objects, hasLength(5));
    });

    testWidgets('a card param opens its editor, even when filtered out', (
      tester,
    ) async {
      await pumpWorkPage(tester);
      _go(tester, collectionLink('deals', card: 'd4', where: _wonOrLead));
      await tester.pumpAndSettle();
      expect(find.byType(ObjectEditor), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ObjectEditor),
          matching: find.text('Umbrella'),
        ),
        findsWidgets,
      );
    });

    testWidgets('a missing card says so', (tester) async {
      await pumpWorkPage(tester);
      _go(tester, collectionLink('deals', card: 'gone'));
      await tester.pumpAndSettle();
      expect(find.byType(ObjectEditor), findsNothing);
      expect(find.text("This link's deal is gone"), findsOneWidget);
    });

    testWidgets('the chip clears the filters, or saves them as a view', (
      tester,
    ) async {
      final cubit = await pumpWorkPage(
        tester,
        location: collectionLink('deals', where: _wonOrLead),
      );
      await tester.tap(find.byTooltip('Clear assistant filters'));
      await tester.pumpAndSettle();
      expect(find.textContaining('From assistant'), findsNothing);
      expect(find.text('Umbrella'), findsOneWidget);

      cubit.openLink(filter: encodeLinkFilter(_wonOrLead));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save as view'));
      await tester.pumpAndSettle();
      final state = cubit.state as ViewsReady;
      expect(state.activeView.name, 'All deals · filtered');
      expect(state.activeView.filters, hasLength(1));
      expect(state.transientFilters, isEmpty);
      expect(find.textContaining('From assistant'), findsNothing);
      expect(find.text('Umbrella'), findsNothing);
    });

    testWidgets('Clear filters on "Nothing matches" clears them too', (
      tester,
    ) async {
      final cubit = await pumpWorkPage(
        tester,
        location: collectionLink(
          'deals',
          where: [
            {'field': 'Amount', 'op': 'greaterThan', 'value': 99999},
          ],
        ),
      );
      expect(find.text('Nothing matches these filters'), findsOneWidget);
      await tester.tap(find.text('Clear filters'));
      await tester.pumpAndSettle();
      expect((cubit.state as ViewsReady).transientFilters, isEmpty);
      expect(find.text('Umbrella'), findsOneWidget);
    });
  });

  group('screen focus', () {
    testWidgets('publishes what is shown, debounced', (tester) async {
      final focus = AssistantFocusNotifier();
      addTearDown(focus.dispose);
      final cubit = await pumpWorkPage(tester, focus: focus);
      expect(focus.value, isNull);
      await tester.pump(const Duration(milliseconds: 160));
      expect(focus.value?.label, 'Looking at: Deals › All deals · 5 shown');
      expect(focus.value?.shownIds, ['d1', 'd2', 'd3', 'd4', 'd5']);

      var changes = 0;
      focus.addListener(() => changes++);
      cubit.selectView('board');
      cubit.openLink(filter: encodeLinkFilter(_wonOrLead));
      await tester.pump(const Duration(milliseconds: 100));
      expect(changes, 0);
      await tester.pump(const Duration(milliseconds: 60));
      expect(changes, 1);
      final value = focus.value!;
      expect(value.viewId, 'board');
      expect(value.mode, ViewModeIds.board);
      expect(value.groupByFieldId, 'stage');
      expect(value.filters, [
        const ViewFilter(
          fieldId: 'stage',
          op: FilterOp.anyOf,
          operand: ['won', 'lead'],
        ),
      ]);
      // Column order: Lead (d1, d3), then Won (d2).
      expect(value.shownIds, ['d1', 'd3', 'd2']);
      expect(value.shownCount, 3);
      await tester.pumpAndSettle();
    });

    testWidgets('the open card is published until the editor closes', (
      tester,
    ) async {
      final focus = AssistantFocusNotifier();
      addTearDown(focus.dispose);
      await pumpWorkPage(tester, focus: focus);
      await tester.tap(find.text('Globex pilot'));
      await tester.pumpAndSettle();
      expect(find.byType(ObjectEditor), findsOneWidget);
      expect(focus.value?.page, FocusPage.card);
      expect(focus.value?.openCardId, 'd2');
      expect(focus.value?.label, 'Looking at: Globex pilot');

      await tester.tapAt(const Offset(5, 5)); // the barrier
      await tester.pumpAndSettle();
      expect(find.byType(ObjectEditor), findsNothing);
      expect(focus.value?.page, FocusPage.collection);
      expect(focus.value?.openCardId, isNull);
    });

    testWidgets('leaving the page clears the focus', (tester) async {
      final focus = AssistantFocusNotifier();
      addTearDown(focus.dispose);
      await pumpWorkPage(tester, focus: focus);
      await tester.pump(const Duration(milliseconds: 160));
      expect(focus.value, isNotNull);
      _go(tester, '/');
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
      expect(focus.value, isNull);
    });

    testWidgets('works without a notifier', (tester) async {
      await pumpWorkPage(tester);
      await tester.pump(const Duration(milliseconds: 160));
      expect(tester.takeException(), isNull);
    });
  });
}
