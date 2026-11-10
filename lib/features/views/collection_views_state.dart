import 'package:equatable/equatable.dart';

import '../../core/domain/domain.dart';

/// State of a collection's Work surface (its saved views).
sealed class CollectionViewsState extends Equatable {
  const CollectionViewsState();

  @override
  List<Object?> get props => const [];
}

/// Before the collection and its objects have both arrived.
final class ViewsLoading extends CollectionViewsState {
  const ViewsLoading();
}

/// The collection does not exist (deleted, or a bad link).
final class ViewsNotFound extends CollectionViewsState {
  const ViewsNotFound();
}

/// A stream failed; [message] is the cause, for logs and the error card.
final class ViewsError extends CollectionViewsState {
  const ViewsError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

/// The collection with its active view applied. Modes only read this; they
/// never query on their own.
final class ViewsReady extends CollectionViewsState {
  const ViewsReady({
    required this.collection,
    required this.activeViewId,
    required this.objects,
    required this.totalCount,
    this.groups,
    this.days,
    this.referenceLabels = const {},
    this.referenceChoices = const {},
    this.calculationNotes = const {},
    this.transientFilters = const [],
    this.writeError,
    this.writeErrorSeq = 0,
  });

  /// The collection; [Collection.views] is never empty here.
  final Collection collection;

  /// Id of the view shown; always one of [Collection.views].
  final String activeViewId;

  /// The objects passing the active view's filters, in its order.
  final List<MorkvaObject> objects;

  /// How many objects the collection has before filtering.
  final int totalCount;

  /// Board columns when the active view's layout field is a single select or
  /// a single reference, else null.
  final List<ViewGroup>? groups;

  /// Day buckets when the active view's layout field is a date, else null.
  final DayBuckets? days;

  /// Referenced object id → label, for the reference fields the active view
  /// shows, lays out by or filters on. Pass to `formatFieldValue`.
  final Map<String, String> referenceLabels;

  /// Reference field id → (object id → label) of what it can point at, for
  /// fields passed to `loadReferenceChoices` whose targets have loaded.
  final Map<String, Map<String, String>> referenceChoices;

  /// What each calculated field computes, in one line, by field id.
  final Map<String, String> calculationNotes;

  /// Filters a deep link put over the active view ("From assistant"): not
  /// saved, AND-ed with the view's own and already applied to [objects].
  final List<ViewFilter> transientFilters;

  /// The last failed write, for a snackbar. A new failure bumps
  /// [writeErrorSeq], so listeners can tell repeats apart.
  final String? writeError;
  final int writeErrorSeq;

  ViewDefinition get activeView =>
      collection.views.firstWhere((v) => v.id == activeViewId);

  /// The field the active view lays out by, if it still exists.
  FieldDefinition? get layoutField => switch (activeView.layoutFieldId) {
    final id? => collection.fieldById(id),
    null => null,
  };

  /// Every filter in effect: the view's own, then [transientFilters].
  List<ViewFilter> get effectiveFilters => transientFilters.isEmpty
      ? activeView.filters
      : [...activeView.filters, ...transientFilters];

  /// Whether filters hide some objects.
  bool get isFiltered => objects.length < totalCount;

  MorkvaObject? objectById(String id) =>
      objects.where((o) => o.id == id).firstOrNull;

  @override
  List<Object?> get props => [
    collection,
    activeViewId,
    objects,
    totalCount,
    groups,
    days,
    referenceLabels,
    referenceChoices,
    calculationNotes,
    transientFilters,
    writeError,
    writeErrorSeq,
  ];
}
