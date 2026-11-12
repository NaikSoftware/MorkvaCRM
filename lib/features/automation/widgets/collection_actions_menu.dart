import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/automation/runner_api.dart';
import '../../../core/domain/automation/automation.dart';
import '../../../core/domain/collection.dart';
import '../../../design/design.dart';
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
  String get runsOn {
    final n = shownCardIds.length;
    final cards = n == 1 ? 'card' : 'cards';
    return filtered ? 'Runs on $n shown $cards' : 'Runs on all $n $cards';
  }
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
              return MenuAnchor(
                alignmentOffset: const Offset(0, Spacing.xxs),
                menuChildren: [
                  for (final v in views)
                    _MenuRow(
                      view: v,
                      tintSeed: collection.id,
                      subtitle: v.busy ? liveRunLabel(v.run!) : scope.runsOn,
                      onPressed: () =>
                          pressCollectionButton(context, v, scope, runs: runs),
                    ),
                  if (views.isNotEmpty) const Divider(height: Spacing.xs),
                  MenuItemButton(
                    leadingIcon: const Icon(Icons.bolt_rounded, size: 20),
                    onPressed: () => GoRouter.maybeOf(
                      context,
                    )?.go(AutomationPaths.automationsOf(collection.id)),
                    child: Text('Automations for ${collection.name}…'),
                  ),
                  MenuItemButton(
                    leadingIcon: const Icon(Icons.add, size: 20),
                    onPressed: () => showAutomationEditor(
                      context,
                      collectionId: collection.id,
                      kind: EditorKind.collectionButton,
                    ),
                    child: const Text('New automation…'),
                  ),
                ],
                builder: (context, controller, _) {
                  void toggle() => controller.isOpen
                      ? controller.close()
                      : controller.open();
                  if (narrow) {
                    return IconButton.outlined(
                      tooltip: 'Actions',
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
                        const Text('Actions'),
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
                  ? 'Needs consent'
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
    return Semantics(
      liveRegion: true,
      child: Tooltip(
        message: 'Long-press to stop',
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
                  'Running ${live.label}…'
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
          subtitle: scope.runsOn,
          build: (r, m) => _collectionViews(m, r, id),
          onSelect: (v) => pressCollectionButton(context, v, scope, runs: runs),
        ),
        child: row(Icons.bolt_rounded, 'Run action…'),
      ),
    PopupMenuItem(
      onTap: () =>
          GoRouter.maybeOf(context)?.go(AutomationPaths.automationsOf(id)),
      child: row(Icons.auto_mode_rounded, 'Automations…'),
    ),
  ];
}

/// Opens the review sheet for a collection-button run of [collectionId]
/// that waits for review, while this page is the top route (UX §4: else
/// the indicator and the snackbar take over).
class CollectionReviewListener extends StatelessWidget {
  const CollectionReviewListener({
    super.key,
    required this.collectionId,
    required this.child,
  });

  final String collectionId;
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
        final run = notice.run;
        if (notice.surface != NoticeSurface.reviewSheet ||
            run.trigger.collectionId != collectionId ||
            run.trigger.cardId != null ||
            !(ModalRoute.of(context)?.isCurrent ?? true)) {
          return;
        }
        runs.noticeShown();
        showReviewSheet(context, runId: run.runId);
      },
      child: child,
    );
  }
}
