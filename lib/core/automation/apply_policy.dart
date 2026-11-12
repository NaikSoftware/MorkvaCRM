import '../domain/automation/automation.dart';
import '../harness/automation_validation.dart' show moduleGrants;
import '../harness/plan/plan.dart';

/// What [ApplyPolicy.decide] chose for a sealed plan.
sealed class ApplyDecision {
  const ApplyDecision();
}

/// Commit now as the user, no review.
final class ApplyAuto extends ApplyDecision {
  const ApplyAuto();
}

/// The user reviews the plan; [why] is the run log's `policy` line
/// ("review: 23 items > 20").
final class ApplyReview extends ApplyDecision {
  const ApplyReview(this.why);

  final String why;
}

/// Auto or review for one sealed plan (design spec, Apply policy). Every
/// check reads the **live** module and consent, not the snapshot the run
/// started with; any failure falls back to review and says which check.
final class ApplyPolicy {
  const ApplyPolicy();

  static const int kMaxAutoItems = 20;

  /// Auto only when [automation] asks for it on behalf of [uid], [consent]
  /// (re-read now) allows auto-apply for exactly the bundle the run loaded
  /// ([codeHash], which must also be [module]'s live hash), the module is
  /// `ok`, and [plan] is ≤ [kMaxAutoItems] low-risk card creates/updates
  /// that blank nothing and stay inside the live grants. [takeBudget] is
  /// asked last, since spending the workspace auto budget has no refund.
  ApplyDecision decide({
    required AutomationRecord automation,
    required String uid,
    required ModuleRecord? module,
    required GrantRecord? consent,
    required String codeHash,
    required Plan plan,
    required bool Function(int items) takeBudget,
  }) {
    if (automation.apply != ApplyMode.auto) {
      return const ApplyReview('review: the automation asks first');
    }
    if (automation.autoBy != uid) {
      return const ApplyReview('review: auto-apply was set by another member');
    }
    if (module == null ||
        module.manifest == null ||
        consent == null ||
        moduleStatusOf(module, consent) != ModuleStatus.ok ||
        module.bundleHash != codeHash) {
      return const ApplyReview("review: the module's permissions changed");
    }
    if (!consent.autoApply) {
      return const ApplyReview('review: auto-apply is off for this module');
    }
    for (final item in plan.items) {
      if (item.kind != PlanItemKind.createCard &&
          item.kind != PlanItemKind.updateCard) {
        return ApplyReview('review: ${item.kind.name} always needs review');
      }
    }
    if (plan.items.any((i) => i.risk != Risk.low)) {
      return const ApplyReview('review: a change is not low risk');
    }
    if (plan.itemCount > kMaxAutoItems) {
      return ApplyReview('review: ${plan.itemCount} items > $kMaxAutoItems');
    }
    for (final item in plan.items) {
      for (final c in item.changes) {
        if (c.before != null && c.after == null) {
          return ApplyReview('review: it would clear ${c.field}');
        }
      }
    }
    final grants = moduleGrants(
      module.manifest!,
      consent,
      collections: automation.collections,
    );
    for (final item in plan.items) {
      if (!grants.allows(item.capability) ||
          !grants.allowsCollection(item.collectionId)) {
        return const ApplyReview('review: a change is outside its permissions');
      }
    }
    if (!takeBudget(plan.itemCount)) {
      return const ApplyReview(
        'review: auto-apply paused for 10 min — too many changes',
      );
    }
    return const ApplyAuto();
  }
}
