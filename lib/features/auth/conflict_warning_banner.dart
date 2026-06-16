import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../api/sync/sync_status.dart';
import '../../api/sync/sync_status_cubit.dart';
import '../../design/design.dart';

/// A full-width banner that makes a last-write-wins conflict *visible* without
/// alarming the user.
///
/// Shown only while [SyncStatus] is [SyncConflict]: a calm amber strip (the
/// semantic `warning` role, never the carrot primary) that explains, in plain
/// language, that a newer version saved elsewhere was overwritten and the
/// user's own changes were kept. A single dismiss action calls
/// [SyncStatusCubit.dismissConflict].
///
/// Dumb by design: it reads state from [SyncStatusCubit] and forwards the
/// dismiss. When there is no conflict it renders nothing
/// ([SizedBox.shrink]), so it is safe to mount permanently at the top of a
/// page or shell body.
class ConflictWarningBanner extends StatelessWidget {
  const ConflictWarningBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SyncStatusCubit, SyncStatus>(
      buildWhen: (previous, current) =>
          previous is SyncConflict || current is SyncConflict,
      builder: (context, state) {
        if (state is! SyncConflict) return const SizedBox.shrink();
        return _ConflictBanner(affectedCount: state.affectedObjectIds.length);
      },
    );
  }
}

class _ConflictBanner extends StatelessWidget {
  const _ConflictBanner({required this.affectedCount});

  /// Number of affected objects, used to phrase the message naturally.
  final int affectedCount;

  String get _itemPhrase {
    if (affectedCount <= 1) return 'an item';
    return '$affectedCount items';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<MorkvaSemanticColors>()!;
    final fg = semantic.onWarning;

    return Semantics(
      liveRegion: true,
      container: true,
      label: 'Sync conflict warning',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.md,
          vertical: Spacing.sm,
        ),
        decoration: BoxDecoration(
          // Soft amber wash, not a saturated alarm bar, with a clear amber edge
          // so the strip still announces itself against the cream canvas.
          color: semantic.warning.withValues(alpha: 0.18),
          border: Border(
            bottom: BorderSide(color: semantic.warning.withValues(alpha: 0.5)),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: Spacing.xxs),
              child: Icon(Icons.history_rounded, size: 20, color: fg),
            ),
            const SizedBox(width: Spacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'A newer version of $_itemPhrase was saved elsewhere',
                    style: theme.textTheme.titleSmall?.copyWith(color: fg),
                  ),
                  const SizedBox(height: Spacing.xxs),
                  Text(
                    'We kept your latest changes and replaced the other copy. '
                    'If that other version mattered, re-enter those edits now.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: fg),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Spacing.xs),
            _DismissAction(fg: fg),
          ],
        ),
      ),
    );
  }
}

/// "Got it" text action that dismisses the conflict. Tinted to the warning
/// foreground so it belongs to the banner, with a 44px hit target and the
/// shared press feel. Kept as a text action (not a filled button) so it reads
/// as an acknowledgement, not a destructive choice.
class _DismissAction extends StatelessWidget {
  const _DismissAction({required this.fg});

  final Color fg;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.labelLarge;
    return PressableScale(
      onPressed: () => context.read<SyncStatusCubit>().dismissConflict(),
      semanticLabel: 'Dismiss conflict warning',
      borderRadius: Radii.smAll,
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
        child: Text('Got it', style: textStyle?.copyWith(color: fg)),
      ),
    );
  }
}
