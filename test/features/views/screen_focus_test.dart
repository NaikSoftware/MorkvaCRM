import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/features/assistant/bloc/assistant_focus.dart';
import 'package:morkva_crm/features/views/collection_views_state.dart';
import 'package:morkva_crm/features/views/screen_focus.dart';

import 'views_fixtures.dart';

void main() {
  /// [deals] showing [view] over [objects], as the cubit would emit it.
  ViewsReady ready(
    ViewDefinition view, {
    List<MorkvaObject>? objects,
    List<ViewFilter> transient = const [],
  }) {
    final collection = deals.copyWith(views: [view]);
    final all = objects ?? sampleDeals();
    final effective = view.copyWith(filters: [...view.filters, ...transient]);
    final applied = applyView(collection, effective, all);
    final layout = view.layoutFieldId == null
        ? null
        : collection.fieldById(view.layoutFieldId!);
    return ViewsReady(
      collection: collection,
      activeViewId: view.id,
      objects: applied,
      totalCount: all.length,
      groups: isGroupable(layout) ? groupObjects(layout!, applied) : null,
      days: layout is DateFieldDefinition ? bucketByDay(layout, applied) : null,
      transientFilters: transient,
    );
  }

  test('a table: effective filters, sort, columns and row order', () {
    const won = ViewFilter(
      fieldId: 'stage',
      op: FilterOp.noneOf,
      operand: ['lost'],
    );
    const big = ViewFilter(
      fieldId: 'amount',
      op: FilterOp.greaterThan,
      operand: 100,
    );
    final view = tableView.copyWith(
      filters: const [won],
      sort: const ViewSort(fieldId: 'amount', ascending: false),
      fieldIds: const ['name', 'gone', 'amount'],
    );
    final focus = screenFocusOf(ready(view, transient: const [big]));
    expect(focus.page, FocusPage.collection);
    expect(focus.collectionId, 'deals');
    expect(focus.collectionName, 'Deals');
    expect(focus.viewId, 'all');
    expect(focus.viewName, 'All deals');
    expect(focus.mode, ViewModeIds.table);
    expect(focus.filters, [won, big]);
    expect(focus.sort, const ViewSort(fieldId: 'amount', ascending: false));
    expect(focus.groupByFieldId, isNull);
    // A field the collection lost is not visible.
    expect(focus.visibleFieldIds, ['name', 'amount']);
    expect(focus.shownCount, 2);
    expect(focus.shownIds, ['d1', 'd2']);
    expect(focus.label, 'Looking at: Deals › All deals · 2 shown');
  });

  test('a board lists its cards column by column', () {
    final focus = screenFocusOf(ready(boardView));
    expect(focus.groupByFieldId, 'stage');
    // Columns lead, won, lost, then "No stage".
    expect(focus.shownIds, ['d1', 'd3', 'd2', 'd4', 'd5']);
    expect(focus.shownCount, 5);
  });

  test('a table that kept its board layout field is not grouped', () {
    // Switching Board → Table keeps layoutFieldId, so the cubit still groups.
    final state = ready(tableView.copyWith(layoutFieldId: 'stage'));
    expect(state.groups, isNotNull);
    final focus = screenFocusOf(state);
    expect(focus.groupByFieldId, isNull);
    expect(focus.shownIds, [for (final o in state.objects) o.id]);
  });

  test('a calendar lists its cards day by day, undated last', () {
    const calendar = ViewDefinition(
      id: 'cal',
      name: 'Due',
      mode: ViewModeIds.calendar,
      layoutFieldId: 'due',
      fieldIds: ['name'],
    );
    final focus = screenFocusOf(
      ready(
        calendar,
        objects: [
          deal('late', 0, due: DateTime.utc(2026, 5, 9)),
          deal('none', 1),
          deal('early', 2, due: DateTime.utc(2026, 5, 2)),
        ],
      ),
    );
    expect(focus.groupByFieldId, isNull);
    expect(focus.shownIds, ['early', 'late', 'none']);
  });

  test('the open card turns it into a card focus', () {
    final focus = screenFocusOf(
      ready(tableView),
      openCardId: 'd2',
      openCardTitle: 'Globex pilot',
    );
    expect(focus.page, FocusPage.card);
    expect(focus.openCardId, 'd2');
    expect(focus.label, 'Looking at: Globex pilot');
    expect(focus.shownCount, 5);
  });

  test('shownIds keep the first 50, shownCount all', () {
    final focus = screenFocusOf(
      ready(tableView, objects: [for (var i = 0; i < 60; i++) deal('x$i', i)]),
    );
    expect(focus.shownCount, 60);
    expect(focus.shownIds, [for (var i = 0; i < 50; i++) 'x$i']);
  });
}
