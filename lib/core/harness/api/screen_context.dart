import 'package:equatable/equatable.dart';

import '../../domain/view/view_definition.dart';

/// The kind of page the user is on.
enum ScreenPage { home, allCollections, collection, card, settings, other }

/// What the user sees, snapshotted when they send a message and carried as
/// `HarnessContext.focus` for that turn.
///
/// It holds the *effective query* of the screen (the view's filters plus any
/// transient and quick filters, the search text and the sort, all in domain
/// JSON), never row values. The harness resolves `@screen`, `@card` and
/// `@selected` from it, and grounding builds the `[Screen: …]` line from it.
/// A stale snapshot is fine: a turn uses the one it was sent with.
final class ScreenContext extends Equatable {
  /// [shownIds] is cut to its first [maxShownIds].
  ScreenContext({
    required this.page,
    this.collectionId,
    this.viewId,
    this.viewName,
    this.mode,
    List<ViewFilter> filters = const [],
    this.search,
    this.sort,
    this.groupByFieldId,
    List<String> visibleFieldIds = const [],
    this.shownCount,
    List<String> shownIds = const [],
    this.openCardId,
    List<String> selectedIds = const [],
  }) : filters = List.unmodifiable(filters),
       visibleFieldIds = List.unmodifiable(visibleFieldIds),
       shownIds = List.unmodifiable(shownIds.take(maxShownIds)),
       selectedIds = List.unmodifiable(selectedIds);

  /// Throws [FormatException] on a wrong-typed key; missing lists read as
  /// empty and an unknown [page] as [ScreenPage.other].
  factory ScreenContext.fromJson(Map<String, Object?> json) {
    final rawSort = json['sort'];
    return ScreenContext(
      page:
          ScreenPage.values.asNameMap()[_opt<String>(json, 'page')] ??
          ScreenPage.other,
      collectionId: _opt(json, 'collectionId'),
      viewId: _opt(json, 'viewId'),
      viewName: _opt(json, 'viewName'),
      mode: _opt(json, 'mode'),
      filters: [for (final f in _list(json, 'filters')) _filter(f)],
      search: _opt(json, 'search'),
      sort: rawSort is Map
          ? ViewSort.fromJson(rawSort.cast<String, dynamic>())
          : null,
      groupByFieldId: _opt(json, 'groupByFieldId'),
      visibleFieldIds: _list(json, 'visibleFieldIds').cast<String>(),
      shownCount: _opt(json, 'shownCount'),
      shownIds: _list(json, 'shownIds').cast<String>(),
      openCardId: _opt(json, 'openCardId'),
      selectedIds: _list(json, 'selectedIds').cast<String>(),
    );
  }

  /// How many [shownIds] a snapshot keeps.
  static const int maxShownIds = 50;

  final ScreenPage page;

  /// The collection on screen (also the open card's collection).
  final String? collectionId;
  final String? viewId;
  final String? viewName;

  /// The view mode id (`table`, `board`, `calendar`, …).
  final String? mode;

  /// Every filter in effect: the view's plus transient and quick filters.
  final List<ViewFilter> filters;

  /// The search text typed on the page.
  final String? search;

  /// The sort in effect; null means the view's manual order.
  final ViewSort? sort;

  /// The field the cards are grouped by (a board's columns, list groups).
  final String? groupByFieldId;

  /// The columns / card fields shown, in order.
  final List<String> visibleFieldIds;

  /// How many cards are shown after filtering and search.
  final int? shownCount;

  /// The first [maxShownIds] shown card ids, in display order.
  final List<String> shownIds;

  /// The card open in the editor or sheet.
  final String? openCardId;

  /// The selected cards, when a selection exists.
  final List<String> selectedIds;

  Map<String, Object?> toJson() => {
    'page': page.name,
    if (collectionId != null) 'collectionId': collectionId,
    if (viewId != null) 'viewId': viewId,
    if (viewName != null) 'viewName': viewName,
    if (mode != null) 'mode': mode,
    if (filters.isNotEmpty) 'filters': [for (final f in filters) f.toJson()],
    if (search != null) 'search': search,
    if (sort != null) 'sort': sort!.toJson(),
    if (groupByFieldId != null) 'groupByFieldId': groupByFieldId,
    if (visibleFieldIds.isNotEmpty) 'visibleFieldIds': visibleFieldIds,
    if (shownCount != null) 'shownCount': shownCount,
    if (shownIds.isNotEmpty) 'shownIds': shownIds,
    if (openCardId != null) 'openCardId': openCardId,
    if (selectedIds.isNotEmpty) 'selectedIds': selectedIds,
  };

  @override
  List<Object?> get props => [
    page,
    collectionId,
    viewId,
    viewName,
    mode,
    filters,
    search,
    sort,
    groupByFieldId,
    visibleFieldIds,
    shownCount,
    shownIds,
    openCardId,
    selectedIds,
  ];

  static T? _opt<T>(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value == null || value is T) return value as T?;
    throw FormatException('"$key" must be a $T');
  }

  static List<Object?> _list(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value == null) return const [];
    if (value is! List) throw FormatException('"$key" must be a list');
    for (final item in value) {
      if (key != 'filters' && item is! String) {
        throw FormatException('"$key" must hold strings');
      }
    }
    return value;
  }

  static ViewFilter _filter(Object? json) {
    final op = json is Map ? FilterOp.values.asNameMap()[json['op']] : null;
    if (json is! Map || op == null || json['fieldId'] is! String) {
      throw FormatException('Bad filter in "filters": $json');
    }
    return ViewFilter(
      fieldId: json['fieldId'] as String,
      op: op,
      operand: json['operand'],
    );
  }
}
