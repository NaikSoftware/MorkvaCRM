import '../../core/domain/domain.dart';
import '../assistant/bloc/assistant_focus.dart';
import 'collection_views_state.dart';

/// What the Work surface in [state] shows, as the assistant's focus: the
/// active view, its effective filters (the view's plus the transient ones),
/// sort, grouping, visible fields and the shown cards in display order, plus
/// the card open in the editor ([openCardId], [openCardTitle]).
AssistantFocus screenFocusOf(
  ViewsReady state, {
  String? openCardId,
  String? openCardTitle,
}) {
  final collection = state.collection;
  final view = state.activeView;
  final shown = shownIdsOf(state);
  return AssistantFocus(
    page: openCardId == null ? FocusPage.collection : FocusPage.card,
    collectionId: collection.id,
    collectionName: collection.name,
    viewId: view.id,
    viewName: view.name,
    mode: view.mode,
    filters: state.effectiveFilters,
    sort: view.sort,
    groupByFieldId: state.groups == null ? null : view.layoutFieldId,
    visibleFieldIds: [
      for (final id in view.fieldIds)
        if (collection.fieldById(id) != null) id,
    ],
    shownCount: state.objects.length,
    shownIds: shown.length > AssistantFocus.maxShownIds
        ? shown.sublist(0, AssistantFocus.maxShownIds)
        : shown,
    openCardId: openCardId,
    openCardTitle: openCardTitle,
  );
}

/// The shown card ids in display order: column by column on a board (and
/// group by group in a grouped list), day by day on a calendar with the
/// undated ones last, else the view's row order.
List<String> shownIdsOf(ViewsReady state) {
  final mode = state.activeView.mode;
  final groups = state.groups;
  final days = state.days;
  final ordered = switch (mode) {
    ViewModeIds.board || ViewModeIds.list when groups != null => [
      for (final g in groups) ...g.objects,
    ],
    ViewModeIds.calendar when days != null => [
      for (final day in days.days.values) ...day,
      ...days.undated,
    ],
    _ => state.objects,
  };
  return [for (final o in ordered) o.id];
}
