import 'dart:ui' show Locale;

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:morkva_crm/core/domain/view/view_definition.dart';

import '../../../l10n/l10n.dart';

/// Which kind of page the user is on. The wire names (`.name`) are the
/// `ScreenContext.page` values.
enum FocusPage { home, allCollections, collection, card, settings, other }

/// What the user is looking at right now, kept up to date by the views page
/// and the card editor (through [AssistantFocusNotifier]). The assistant bloc
/// snapshots it when a message is sent and converts it to the harness's
/// `ScreenContext` (see "Screen context" in the Epic 8 spec), so "these" and
/// "this one" mean exactly what is on screen.
///
/// Names ([collectionName], [viewName], [openCardTitle]) are display text for
/// the composer chip; the harness re-reads names from the schema itself.
final class AssistantFocus extends Equatable {
  const AssistantFocus({
    required this.page,
    this.collectionId,
    this.collectionName,
    this.collectionIcon,
    this.viewId,
    this.viewName,
    this.mode,
    this.filters = const [],
    this.search,
    this.sort,
    this.groupByFieldId,
    this.visibleFieldIds = const [],
    this.shownCount,
    this.shownIds = const [],
    this.openCardId,
    this.openCardTitle,
    this.selectedIds = const [],
  });

  /// How many [shownIds] reach the harness.
  static const int maxShownIds = 50;

  final FocusPage page;
  final String? collectionId;
  final String? collectionName;

  /// The collection's `CollectionIcons` key, for the composer chip only.
  final String? collectionIcon;
  final String? viewId;
  final String? viewName;

  /// The view mode id (`ViewModeIds`: `table`, `board`, `calendar`, …).
  final String? mode;

  /// The effective filters on screen: the view's own, plus transient ("From
  /// assistant") and quick filters, AND-ed.
  final List<ViewFilter> filters;

  /// The search text, if any.
  final String? search;
  final ViewSort? sort;
  final String? groupByFieldId;

  /// The columns / card fields shown, in order.
  final List<String> visibleFieldIds;

  /// Cards on screen after filters and search.
  final int? shownCount;

  /// Card ids in display order (row order in a table, column-then-position on
  /// a board, day order on a calendar). Only the first [maxShownIds] are sent.
  final List<String> shownIds;

  /// The card open in the editor or sheet.
  final String? openCardId;
  final String? openCardTitle;

  /// The selected cards, when a selection exists.
  final List<String> selectedIds;

  /// The composer chip's text: "Looking at: #1042" with a card open,
  /// otherwise "Looking at: Orders › Unpaid · 23 shown"; null when nothing
  /// nameable is on screen.
  String? get label => labelIn(lookupAppLocalizations(const Locale('en')));

  /// [label] in [l10n]'s language.
  String? labelIn(AppLocalizations l10n) {
    if (openCardId != null && _present(openCardTitle)) {
      return l10n.assistantLookingAt(openCardTitle ?? '');
    }
    if (!_present(collectionName)) return null;
    final view = _present(viewName) ? ' › $viewName' : '';
    final shown = switch (shownCount) {
      null => '',
      final n => ' · ${l10n.assistantShownCount(n)}',
    };
    return l10n.assistantLookingAt('$collectionName$view$shown');
  }

  /// The `ScreenContext` JSON the harness reads (`ScreenContext.fromJson`):
  /// `page`, `collectionId`, `viewId`, `viewName`, `mode`, `filters`
  /// (`ViewFilter.toJson` list), `search`, `sort` (`ViewSort.toJson`:
  /// `{fieldId, ascending}`), `groupByFieldId`, `visibleFieldIds`,
  /// `shownCount`, `shownIds` (≤ [maxShownIds]), `openCardId`, `selectedIds`.
  /// Absent values are left out; lists are always present.
  Map<String, Object?> toScreenContextJson() => {
    'page': page.name,
    'collectionId': ?collectionId,
    'viewId': ?viewId,
    'viewName': ?viewName,
    'mode': ?mode,
    'filters': [for (final f in filters) f.toJson()],
    if (_present(search)) 'search': search,
    if (sort != null) 'sort': sort!.toJson(),
    'groupByFieldId': ?groupByFieldId,
    'visibleFieldIds': [...visibleFieldIds],
    'shownCount': ?shownCount,
    'shownIds': shownIds.take(maxShownIds).toList(),
    'openCardId': ?openCardId,
    'selectedIds': [...selectedIds],
  };

  @override
  List<Object?> get props => [
    page,
    collectionId,
    collectionName,
    collectionIcon,
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
    openCardTitle,
    selectedIds,
  ];
}

bool _present(String? s) => s != null && s.trim().isNotEmpty;

/// The app-wide holder of the current [AssistantFocus], provided next to the
/// assistant bloc. The views page and the card editor publish into it; null
/// means nothing to point at (or the publisher went away).
final class AssistantFocusNotifier extends ValueNotifier<AssistantFocus?> {
  AssistantFocusNotifier([super.value]);
}
