import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/shell/app_shell.dart';
import '../../../core/automation/runner_api.dart';
import '../../../core/domain/automation/automation.dart';
import '../../../design/design.dart';
import '../../assistant/bloc/assistant_state.dart' show ApplyingPhase;
import '../../assistant/bloc/chat_item.dart';
import '../../assistant/view/widgets/plan_card.dart';
import '../../assistant/view/widgets/plan_card_scope.dart';
import '../../views/view_link.dart';
import '../bloc/automation_runs_cubit.dart';
import '../bloc/review_sheet_cubit.dart';
import '../widgets/action_buttons.dart';

/// Opens the review of [runId] (UX §6): a 560 dialog on wide screens, a
/// full-height bottom sheet on phones. Over the card editor ([overEditor])
/// the barrier is transparent, since the editor's scrim already darkens the
/// page. Closing without deciding keeps the run in Needs review ("Saved for
/// review").
///
/// Needs the app's `AutomationRunnerApi` and `AutomationStores` (does
/// nothing without them).
Future<void> showReviewSheet(
  BuildContext context, {
  required String runId,
  bool overEditor = false,
}) async {
  final runner = maybeRead<AutomationRunnerApi>(context);
  final stores = maybeRead<AutomationStores>(context);
  if (runner == null || stores == null) return;
  final runs = maybeRead<AutomationRunsCubit>(context);
  final messenger = ScaffoldMessenger.maybeOf(context);
  final wide = MediaQuery.sizeOf(context).width >= AppShell.expandedBreakpoint;
  ReviewSheetCubit? cubit;
  Widget sheet(BuildContext _) => BlocProvider(
    create: (_) => cubit = ReviewSheetCubit(runner, stores, runId: runId),
    child: ReviewSheet(compact: !wide, runs: runs),
  );
  final scrim = overEditor ? Colors.transparent : null;
  if (wide) {
    await showDialog<void>(
      context: context,
      barrierColor: scrim,
      barrierLabel: 'Decide later',
      builder: (context) => Dialog(
        // Over the editor there is no second scrim, so the same surface
        // colour without a shadow melted into the form behind it: step up
        // to the white card surface and lift it.
        backgroundColor: overEditor
            ? Theme.of(context).colorScheme.surfaceContainerLowest
            : Theme.of(context).colorScheme.surface,
        elevation: overEditor ? 12 : null,
        shadowColor: overEditor ? const Color(0x66000000) : null,
        insetPadding: const EdgeInsets.all(Spacing.xl),
        shape: const RoundedRectangleBorder(borderRadius: Radii.lgAll),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: sheet(context),
        ),
      ),
    );
  } else {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      barrierColor: scrim,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.lg)),
      ),
      builder: (context) =>
          FractionallySizedBox(heightFactor: 1, child: sheet(context)),
    );
  }
  // Dismissed with the plan still open: decide later. Over the editor the
  // snackbar would sit under its scrim; the Needs-review count says it.
  if (cubit?.state.phase == ReviewPhase.review && !overEditor) {
    messenger?.showSnackBar(
      SnackBar(
        content: const Text('Saved for review'),
        duration: const Duration(seconds: 5),
        persist: false,
        behavior: SnackBarBehavior.floating,
        width: wide ? 480 : null,
        action: context.mounted
            ? SnackBarAction(
                label: 'Review',
                onPressed: () {
                  if (context.mounted) {
                    showReviewSheet(context, runId: cubit!.state.runId);
                  }
                },
              )
            : null,
      ),
    );
  }
}

/// "12:04".
String _clock(DateTime t) {
  final l = t.toLocal();
  return '${l.hour.toString().padLeft(2, '0')}:'
      '${l.minute.toString().padLeft(2, '0')}';
}

/// "Button pressed on #1042 · 12:04", "Because #1042 was updated · 12:04".
String reviewContextLine(RunTrigger trigger, DateTime at) {
  final card = trigger.cardLabel ?? (trigger.cardId == null ? null : 'a card');
  final what = switch (trigger.kind) {
    TriggerKind.button =>
      card == null ? 'Button pressed' : 'Button pressed on $card',
    TriggerKind.cardCreated => 'Because ${card ?? 'a card'} was created',
    TriggerKind.cardDeleted => 'Because ${card ?? 'a card'} was deleted',
    TriggerKind.cardUpdated => 'Because ${card ?? 'a card'} was updated',
  };
  return '$what · ${_clock(at)}';
}

/// The review sheet's content over [ReviewSheetCubit]: provenance, context,
/// the assistant's PlanCard, and what follows a decision.
class ReviewSheet extends StatelessWidget {
  const ReviewSheet({super.key, required this.compact, this.runs});

  final bool compact;

  /// Told about a Run again, so the new run's review opens the sheet.
  final AutomationRunsCubit? runs;

  Future<void> _runAgain(BuildContext context) async {
    final id = await context.read<ReviewSheetCubit>().runAgain();
    if (id == null || !context.mounted) return;
    runs?.startedManually(id);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final cubit = context.read<ReviewSheetCubit>();
    return BlocConsumer<ReviewSheetCubit, ReviewSheetState>(
      listenWhen: (prev, next) => prev.phase != next.phase,
      listener: (context, state) {
        if (state.phase == ReviewPhase.done &&
            !state.partlyFailed &&
            state.next == null) {
          Navigator.of(context).pop();
        }
      },
      builder: (context, state) {
        final trigger = state.trigger;
        final at = state.record?.startedAt ?? state.run?.startedAt;
        final header = Padding(
          padding: EdgeInsets.fromLTRB(
            Spacing.lg,
            compact ? 0 : Spacing.md,
            Spacing.sm,
            Spacing.sm,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (state.provenance case final line?)
                      Text(
                        line,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    if (trigger != null && at != null) ...[
                      const SizedBox(height: Spacing.xxs),
                      Text(
                        reviewContextLine(trigger, at),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ],
                ),
              ),
              IconActionButton(
                icon: Icons.close,
                tooltip: 'Decide later',
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
        );
        final body = <Widget>[
          switch (state.phase) {
            ReviewPhase.review || ReviewPhase.applying => _Plan(
              state: state,
              actions: _ReviewActions(
                cubit,
                onRunAgain: () => _runAgain(context),
                onOpen: (path) {
                  Navigator.of(context).pop();
                  GoRouter.maybeOf(context)?.go(path);
                },
              ),
            ),
            ReviewPhase.expired => _Expired(
              onRunAgain: () => _runAgain(context),
            ),
            ReviewPhase.done => _Decided(
              state: state,
              onNext: cubit.openNext,
              onRetryFailed: cubit.retryFailed,
              onUndo: cubit.undo,
              onClose: () => Navigator.of(context).pop(),
            ),
          },
          if (state.refusal case final refusal?) ...[
            const SizedBox(height: Spacing.sm),
            _Refusal(
              message: refusal.message,
              onRunAgain: refusal.runAgain ? () => _runAgain(context) : null,
            ),
          ],
        ];
        return Column(
          mainAxisSize: compact ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            Flexible(
              fit: compact ? FlexFit.tight : FlexFit.loose,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  Spacing.lg,
                  0,
                  Spacing.lg,
                  Spacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: body,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The assistant's PlanCard over the sealed plan; the ticks shown are the
/// ones Approve sends.
class _Plan extends StatelessWidget {
  const _Plan({required this.state, required this.actions});

  final ReviewSheetState state;
  final _ReviewActions actions;

  @override
  Widget build(BuildContext context) {
    final view = _planOf(state);
    if (view == null) return _Expired(onRunAgain: actions.retry);
    final progress = state.run?.progress;
    return PlanCardScope(
      actions: actions..view = view,
      child: PlanCard(
        item: PlanItem(
          id: state.runId,
          plan: view,
          selected: state.selection ?? view.defaultSelection,
          status: state.phase == ReviewPhase.applying
              ? PlanStatus.committing
              : PlanStatus.pending,
        ),
        progress: state.phase == ReviewPhase.applying && progress != null
            ? ApplyingPhase(progress.done, progress.total)
            : null,
      ),
    );
  }
}

PlanView? _planOf(ReviewSheetState state) {
  final json = state.plan;
  if (json == null) return null;
  try {
    return PlanView.fromJson(json);
  } on FormatException {
    return null;
  }
}

/// The review sheet's side of [PlanCardActions] (`retry` = Run again).
final class _ReviewActions implements PlanCardActions {
  _ReviewActions(this._cubit, {required this.onRunAgain, required this.onOpen});

  final ReviewSheetCubit _cubit;
  final VoidCallback onRunAgain;
  final ValueChanged<String> onOpen;

  /// The plan on screen: its default ticks are what Approve sends until the
  /// user changes them.
  PlanView? view;

  @override
  void changePlanSelection(String planId, Set<String> itemIds) =>
      _cubit.select(itemIds);

  @override
  void approvePlan(String planId) {
    final shown = view;
    if (_cubit.state.selection == null && shown != null) {
      _cubit.select(shown.defaultSelection);
    }
    _cubit.approve();
  }

  @override
  void rejectPlan(String planId) => _cubit.reject();

  @override
  void undo(String journalId) => _cubit.undo();

  @override
  void retryFailed(String planId) => _cubit.retryFailed();

  @override
  void retry() => onRunAgain();

  @override
  void openObject({
    required String collectionId,
    String? cardId,
    String? viewId,
  }) => onOpen(collectionLink(collectionId, view: viewId, card: cardId));

  // A module's run can't plan a module install, so no row carries code.
  @override
  void viewCode(PlanRow row) {}
}

/// "This review expired." + Run again.
class _Expired extends StatelessWidget {
  const _Expired({required this.onRunAgain});

  final VoidCallback onRunAgain;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: Radii.lgAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(
                  text: 'This review expired. ',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(
                  text:
                      'Previews are kept only while Morkva is open. Run it '
                      'again to get a fresh preview on the current data.',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: Spacing.sm),
          PrimaryButton(label: 'Run again', onPressed: onRunAgain),
        ],
      ),
    );
  }
}

/// An approve refused: the runner's sentence, with Run again when it helps.
class _Refusal extends StatelessWidget {
  const _Refusal({required this.message, this.onRunAgain});

  final String message;
  final VoidCallback? onRunAgain;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<MorkvaSemanticColors>();
    final scheme = theme.colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.sm,
          vertical: Spacing.xxs,
        ),
        decoration: BoxDecoration(
          color: semantic?.warningContainer ?? scheme.tertiaryContainer,
          borderRadius: Radii.mdAll,
        ),
        child: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 20,
              color: semantic?.onWarningContainer ?? scheme.onSurface,
            ),
            const SizedBox(width: Spacing.xs),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
                child: Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: semantic?.onWarningContainer,
                  ),
                ),
              ),
            ),
            if (onRunAgain != null)
              TextActionButton(label: 'Run again', onPressed: onRunAgain),
          ],
        ),
      ),
    );
  }
}

/// After a decision: a partly failed apply stays ("Updated 190, 10 failed ·
/// Retry failed"); otherwise the next waiting review is offered.
class _Decided extends StatelessWidget {
  const _Decided({
    required this.state,
    required this.onNext,
    required this.onRetryFailed,
    required this.onUndo,
    required this.onClose,
  });

  final ReviewSheetState state;
  final VoidCallback onNext;
  final VoidCallback onRetryFailed;
  final VoidCallback onUndo;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final receipt = state.record?.receipt;
    final left = state.reviewsLeft.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.partlyFailed && receipt != null)
          Container(
            padding: const EdgeInsets.all(Spacing.md),
            decoration: BoxDecoration(
              color: scheme.errorContainer,
              borderRadius: Radii.lgAll,
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: scheme.onErrorContainer),
                const SizedBox(width: Spacing.xs),
                Expanded(
                  child: Text(
                    'Updated ${receipt.applied}, ${receipt.failed} failed',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: scheme.onErrorContainer,
                    ),
                  ),
                ),
                TextActionButton(label: 'Undo', onPressed: onUndo),
                TextActionButton(
                  label: 'Retry failed',
                  onPressed: onRetryFailed,
                ),
              ],
            ),
          )
        else
          Text('Done.', style: theme.textTheme.titleMedium),
        const SizedBox(height: Spacing.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextActionButton(label: 'Close', onPressed: onClose),
            if (state.next != null) ...[
              const SizedBox(width: Spacing.xs),
              PrimaryButton(
                label: 'Next review ($left left)',
                onPressed: onNext,
              ),
            ],
          ],
        ),
      ],
    );
  }
}
