import 'package:flutter/widgets.dart';

import '../../bloc/chat_item.dart';

/// What a plan card, its applied card and its object chips can ask for. The
/// chat implements it through `AssistantActions`; the automation review
/// sheet implements it over the runner (where [retry] means "Run again").
abstract interface class PlanCardActions {
  /// A plan card's ticks changed.
  void changePlanSelection(String planId, Set<String> itemIds);

  /// "Approve N changes" / "Delete 7 orders" / "Install module".
  void approvePlan(String planId);

  /// "Reject" / "Keep them".
  void rejectPlan(String planId);

  /// An applied card's Undo.
  void undo(String journalId);

  /// "Retry failed" on a partly failed apply.
  void retryFailed(String planId);

  /// An expired plan's "Rebuild" (the chat re-runs the turn, the review
  /// sheet runs the automation again).
  void retry();

  /// An object chip: open the collection (and view / card).
  void openObject({
    required String collectionId,
    String? cardId,
    String? viewId,
  });

  /// A module row's "View code": the read-only viewer over [row]'s `code`.
  void viewCode(PlanRow row);
}

/// Hands [PlanCardActions] and the clock to plan cards, applied cards and
/// object chips, so they render in the chat and outside it (the review
/// sheet) without `AssistantScope`.
class PlanCardScope extends InheritedWidget {
  const PlanCardScope({
    super.key,
    required this.actions,
    this.now = DateTime.now,
    required super.child,
  });

  final PlanCardActions actions;

  /// The clock behind undo windows (tests pin it).
  final DateTime Function() now;

  static PlanCardScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<PlanCardScope>();
    assert(scope != null, 'No PlanCardScope above this plan widget');
    return scope!;
  }

  @override
  bool updateShouldNotify(PlanCardScope oldWidget) =>
      actions != oldWidget.actions || now != oldWidget.now;
}
