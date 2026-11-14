import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/automation/runner_api.dart';
import '../../../core/domain/automation/automation.dart';
import '../../../core/domain/collection.dart';
import '../../../design/design.dart';
import '../../../l10n/l10n.dart';
import '../bloc/automation_editor_cubit.dart' show EditorKind;
import '../bloc/automation_runs_cubit.dart';
import '../bloc/modules_cubit.dart';
import '../view/automation_editor_sheet.dart';
import '../view/review_sheet.dart';
import 'action_buttons.dart';

/// What a collection button runs on: the current view's shown cards.
final class CollectionScope {
  const CollectionScope({
    required this.collection,
    required this.shownCardIds,
    required this.filtered,
    this.viewId,
  });

  final Collection collection;

  /// In display order.
  final List<String> shownCardIds;

  /// The view has filters: "shown" cards, else "all" of them.
  final bool filtered;
  final String? viewId;

  /// "Runs on 23 shown cards" / "Runs on all 23 cards".
  String runsOn(AppLocalizations l10n) => filtered
      ? l10n.automationWidgetsRunsOnShown(shownCardIds.length)
      : l10n.automationWidgetsRunsOnAll(shownCardIds.length);
}

/// The live (not awaiting review) collection-button run of [collectionId].
RunView? liveCollectionRun(RunActivity activity, String collectionId) =>
    activity.runs
        .where(
          (r) =>
              r.isButton &&
              r.trigger.cardId == null &&
              r.trigger.collectionId == collectionId &&
              r.status != RunStatus.awaitingReview,
        )
        .firstOrNull;

/// A collection button pressed: focus its live run, open what blocks it, or
/// run it over the shown cards (≤ 500).
Future<void> pressCollectionButton(
  BuildContext context,
  ButtonView view,
  CollectionScope scope, {
  required AutomationRunsCubit runs,
}) async {
  switch (view.phase) {
    case ButtonPhase.review:
      await showReviewSheet(context, runId: view.run!.runId);
    case ButtonPhase.needsConsent:
      GoRouter.maybeOf(
        context,
      )?.go(AutomationPaths.module(view.entry.automation.moduleId));
    case ButtonPhase.queued || ButtonPhase.running:
      break;
    case ButtonPhase.idle || ButtonPhase.failed:
      final messenger = ScaffoldMessenger.maybeOf(context);
      final id = await runs.pressCollection(
        view.entry.automation.id,
        cardIds: scope.shownCardIds.take(500).toList(),
        viewId: scope.viewId,
      );
      final error = runs.state.error;
      if (id == null && error != null) {
        messenger?.showSnackBar(
          SnackBar(
            content: Text(error),
            persist: false,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
  }
}

List<ButtonView> _collectionViews(
  ModulesState m,
  AutomationRunsState r,
  String collectionId,
) => buttonViewsOf(
  buttonsOf(m.automations, collectionId, scope: ButtonScope.collection),
  r,
  cardId: null,
  collection: true,
);

/// The wide collection header's **Actions ▾** (icon-only with a tooltip
/// when [narrow]): one item per collection button with what it runs on,
/// then "Automations for …" and "New automation…" (UX §4). Nothing without
/// the app's automation cubits.
class CollectionActionsMenu extends StatelessWidget {
  const CollectionActionsMenu({
    super.key,
    required this.scope,
    this.narrow = false,
  });

  final CollectionScope scope;
  final bool narrow;

  @override
  Widget build(BuildContext context) {
    final runs = maybeRead<AutomationRunsCubit>(context);
    final modules = maybeRead<ModulesCubit>(context);
    if (runs == null || modules == null) return const SizedBox.shrink();
    final collection = scope.collection;
    // Trails a gap, so nothing is left behind when the menu is absent.
    return Padding(
      padding: const EdgeInsets.only(right: Spacing.sm),
      child: _menu(context, runs, modules, collection),
    );
  }

  Widget _menu(
    BuildContext context,
    AutomationRunsCubit runs,
    ModulesCubit modules,
    Collection collection,
  ) {
    return BlocBuilder<ModulesCubit, ModulesState>(
      bloc: modules,
      builder: (context, m) =>
          BlocBuilder<AutomationRunsCubit, AutomationRunsState>(
            bloc: runs,
            builder: (context, r) {
              final views = _collectionViews(m, r, collection.id);
              final l10n = context.l10n;
              return MenuAnchor(
                alignmentOffset: const Offset(0, Spacing.xxs),
                menuChildren: [
                  for (final v in views)
                    _MenuRow(
                      view: v,
                      tintSeed: collection.id,
                      subtitle: v.busy
                          ? liveRunLabel(v.run!, l10n)
                          : scope.runsOn(l10n),
                      onPressed: () =>
                          pressCollectionButton(context, v, scope, runs: runs),
                    ),
                  if (views.isNotEmpty) const Divider(height: Spacing.xs),
                  MenuItemButton(
                    leadingIcon: const Icon(Icons.bolt_rounded, size: 20),
                    onPressed: () => GoRouter.maybeOf(
                      context,
                    )?.go(AutomationPaths.automationsOf(collection.id)),
                    child: Text(
                      l10n.automationWidgetsAutomationsFor(collection.name),
                    ),
                  ),
                  MenuItemButton(
                    leadingIcon: const Icon(Icons.add, size: 20),
                    onPressed: () => showAutomationEditor(
                      context,
                      collectionId: collection.id,
                      kind: EditorKind.collectionButton,
                    ),
                    child: Text(l10n.automationWidgetsNewAutomation),
                  ),
                ],
                builder: (context, controller, _) {
                  void toggle() => controller.isOpen
                      ? controller.close()
                      : controller.open();
                  if (narrow) {
                    return IconButton.outlined(
                      tooltip: l10n.automationWidgetsActions,
                      onPressed: toggle,
                      icon: const Icon(Icons.bolt_rounded, size: 18),
                    );
                  }
                  return OutlinedButton.icon(
                    onPressed: toggle,
                    icon: const Icon(Icons.bolt_rounded, size: 18),
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(l10n.automationWidgetsActions),
                        const SizedBox(width: Spacing.xxs),
                        Icon(
                          controller.isOpen
                              ? Icons.expand_less_rounded
                              : Icons.expand_more_rounded,
                          size: 18,
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.view,
    required this.tintSeed,
    required this.subtitle,
    required this.onPressed,
  });

  final ButtonView view;
  final String tintSeed;
  final String subtitle;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = buttonTintOf(
      view.entry.automation.button?.tint,
      tintSeed,
      theme.brightness,
    );
    return MenuItemButton(
      onPressed: onPressed,
      leadingIcon: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: tint.background,
          borderRadius: Radii.smAll,
        ),
        child: view.busy
            ? SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: tint.foreground,
                ),
              )
            : Icon(buttonIconOf(view.entry), size: 18, color: tint.foreground),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(view.label, style: theme.textTheme.titleSmall),
            Text(
              view.phase == ButtonPhase.needsConsent
                  ? context.l10n.automationWidgetsNeedsConsent
                  : subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Running Flag low stock…": the header pill while a collection button of
/// [collectionId] runs.
class CollectionRunPill extends StatelessWidget {
  const CollectionRunPill({super.key, required this.collectionId});

  final String collectionId;

  @override
  Widget build(BuildContext context) {
    final runs = maybeRead<AutomationRunsCubit>(context);
    if (runs == null) return const SizedBox.shrink();
    return BlocBuilder<AutomationRunsCubit, AutomationRunsState>(
      bloc: runs,
      builder: (context, r) {
        final live = liveCollectionRun(r.activity, collectionId);
        if (live == null) return const SizedBox.shrink();
        final theme = Theme.of(context);
        final info = theme.extension<MorkvaSemanticColors>()!.info;
        final p = live.progress;
        return Padding(
          padding: const EdgeInsets.only(right: Spacing.sm),
          child: _pill(context, runs, live, info, p),
        );
      },
    );
  }

  Widget _pill(
    BuildContext context,
    AutomationRunsCubit runs,
    RunView live,
    Color info,
    RunProgress? p,
  ) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Semantics(
      liveRegion: true,
      label: l10n.automationWidgetsRunningLabel(live.label),
      onLongPress: () => runs.stop(live.runId),
      excludeSemantics: true,
      child: Tooltip(
        message: l10n.automationWidgetsLongPressToStop,
        child: GestureDetector(
          onLongPress: () => runs.stop(live.runId),
          child: Container(
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
            decoration: BoxDecoration(
              color: info.withValues(alpha: 0.12),
              borderRadius: Radii.fullAll,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: info,
                  ),
                ),
                const SizedBox(width: Spacing.xs),
                Text(
                  '${l10n.automationWidgetsRunningLabelEllipsis(live.label)}'
                  '${p == null || p.total <= 0 ? '' : ' ${p.done}/${p.total}'}',
                  style: theme.textTheme.labelMedium?.copyWith(color: info),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The phone collection More menu's automation rows ("Run action…",
/// "Automations…"), above "Customize collection". Empty without the app's
/// automation cubits.
List<PopupMenuEntry<void>> collectionPhoneMenuItems(
  BuildContext context,
  CollectionScope scope,
) {
  final runs = maybeRead<AutomationRunsCubit>(context);
  final modules = maybeRead<ModulesCubit>(context);
  if (runs == null || modules == null) return const [];
  final id = scope.collection.id;
  final l10n = context.l10n;
  Widget row(IconData icon, String label) => Row(
    children: [
      Icon(icon, size: 20),
      const SizedBox(width: Spacing.sm),
      Flexible(child: Text(label)),
    ],
  );
  return [
    if (_collectionViews(modules.state, runs.state, id).isNotEmpty)
      PopupMenuItem(
        onTap: () => showActionsSheet(
          context,
          runs: runs,
          modules: modules,
          tintSeed: id,
          subtitle: scope.runsOn(l10n),
          build: (r, m) => _collectionViews(m, r, id),
          onSelect: (v) => pressCollectionButton(context, v, scope, runs: runs),
        ),
        child: row(Icons.bolt_rounded, l10n.automationWidgetsRunAction),
      ),
    PopupMenuItem(
      onTap: () =>
          GoRouter.maybeOf(context)?.go(AutomationPaths.automationsOf(id)),
      child: row(
        Icons.auto_mode_rounded,
        l10n.automationWidgetsAutomationsEllipsis,
      ),
    ),
  ];
}

/// The finish notices outside the card editor (UX §4–§5): the review sheet
/// for a collection-button run of [collectionId] while this page is on top,
/// the finish snackbar for every other notice. While a card editor is open
/// its banner owns them. Mount exactly one (the collection page now; T16
/// hoists it to the shell with [collectionId] null).
class RunNoticeHost extends StatelessWidget {
  const RunNoticeHost({super.key, this.collectionId, required this.child});

  final String? collectionId;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final runs = maybeRead<AutomationRunsCubit>(context);
    if (runs == null) return child;
    return BlocListener<AutomationRunsCubit, AutomationRunsState>(
      bloc: runs,
      listenWhen: (prev, next) =>
          next.notice != null && prev.notice != next.notice,
      listener: (context, state) {
        final notice = state.notice!;
        if (state.editorOpen) return;
        runs.noticeShown();
        final run = notice.run;
        if (notice.surface == NoticeSurface.reviewSheet &&
            collectionId != null &&
            run.trigger.collectionId == collectionId &&
            run.trigger.cardId == null &&
            (ModalRoute.of(context)?.isCurrent ?? true)) {
          showReviewSheet(context, runId: run.runId);
          return;
        }
        showRunSnackbar(context, run, runs: runs);
      },
      child: child,
    );
  }
}

/// The finish snackbar (`persist: false`, 5 s, floating, 480 wide on wide
/// screens). It queues behind a visible snackbar instead of replacing it.
// shortcut: one snackbar per run; event runs aren't coalesced within 2 s
// yet, add it here if bursts of event runs flood the queue.
void showRunSnackbar(
  BuildContext context,
  RunView run, {
  required AutomationRunsCubit runs,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  final l10n = context.l10n;
  final copy = runNoticeCopy(run, l10n: l10n);
  final router = GoRouter.maybeOf(context);
  final wide = MediaQuery.sizeOf(context).width >= 840;
  final action = copy.actions.firstOrNull;
  messenger.showSnackBar(
    SnackBar(
      content: Text(copy.text),
      duration: const Duration(seconds: 5),
      persist: false,
      behavior: SnackBarBehavior.floating,
      width: wide ? 480 : null,
      action: action == null
          ? null
          : SnackBarAction(
              label: action.labelIn(l10n),
              onPressed: () {
                switch (action) {
                  case NoticeAction.undo:
                    runs.undo(run.runId);
                  case NoticeAction.viewRun:
                    router?.go(AutomationPaths.run(run.runId));
                  case NoticeAction.review:
                    if (context.mounted) {
                      showReviewSheet(context, runId: run.runId);
                    }
                  case NoticeAction.runAgain:
                    runs.runAgain(run.runId);
                }
              },
            ),
    ),
  );
}
