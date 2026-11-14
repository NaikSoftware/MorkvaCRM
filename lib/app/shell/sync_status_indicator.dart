import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../api/sync/sync_status.dart';
import '../../api/sync/sync_status_cubit.dart';
import '../../design/design.dart';
import '../../l10n/l10n.dart';

/// A compact pill that reports the workspace's [SyncStatus] at a glance.
///
/// Designed to live quietly in the shell (app-bar / rail header). Following the
/// "Warm Carrot" principle that *data surfaces stay calm*, the healthy
/// [SyncSynced] state is deliberately unobtrusive — a muted `onSurfaceVariant`
/// check, no fill — so it never competes with content. Only states that need
/// attention borrow a semantic color (info / warning / error).
///
/// Dumb by design: it renders state from [SyncStatusCubit] and, in the
/// [SyncConflict] state only, becomes tappable to dismiss the conflict via
/// [SyncStatusCubit.dismissConflict] (so the chip and the
/// `ConflictWarningBanner` share one acknowledgement path).
class SyncStatusIndicator extends StatelessWidget {
  const SyncStatusIndicator({super.key, this.dense = false});

  /// A bare icon + label line (no pill), for the sidebar's profile row.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SyncStatusCubit, SyncStatus>(
      builder: (context, status) {
        // No sync signal yet: render nothing so the chip never claims a status
        // (least of all a misleading "Offline") before there's evidence.
        if (status is SyncUnknown) return const SizedBox.shrink();
        final spec = _SyncChipSpec.of(context, status);
        final onTap = status is SyncConflict
            ? () => context.read<SyncStatusCubit>().dismissConflict()
            : null;
        return _SyncChip(spec: spec, onTap: onTap, dense: dense);
      },
    );
  }
}

/// Resolved presentation for the current status: label, color, and either a
/// glyph or a spinner. Centralizes the state→appearance mapping so the chip
/// widget stays purely structural.
@immutable
class _SyncChipSpec {
  const _SyncChipSpec({
    required this.label,
    required this.foreground,
    this.icon,
    this.showSpinner = false,
  });

  final String label;
  final Color foreground;
  final IconData? icon;
  final bool showSpinner;

  static _SyncChipSpec of(BuildContext context, SyncStatus status) {
    final scheme = Theme.of(context).colorScheme;
    final semantic = Theme.of(context).extension<MorkvaSemanticColors>()!;
    final l10n = context.l10n;

    return switch (status) {
      // No signal yet — the indicator hides via an early return in the builder,
      // so this branch is never actually rendered; present only to keep the
      // switch exhaustive over the sealed [SyncStatus].
      SyncUnknown() => _SyncChipSpec(
        label: '',
        foreground: scheme.onSurfaceVariant,
      ),
      // Healthy: quiet by design — muted ink, no semantic color.
      SyncSynced() => _SyncChipSpec(
        label: l10n.shellSyncSynced,
        foreground: scheme.onSurfaceVariant,
        icon: MorkvaIcons.cloudDone,
      ),
      SyncPending() => _SyncChipSpec(
        label: l10n.shellSyncSyncing,
        foreground: semantic.info,
        showSpinner: true,
      ),
      SyncOffline() => _SyncChipSpec(
        label: l10n.shellSyncOffline,
        foreground: scheme.onSurfaceVariant,
        icon: MorkvaIcons.cloudOff,
      ),
      SyncConflict() => _SyncChipSpec(
        label: l10n.shellSyncConflict,
        foreground: semantic.warning,
        icon: MorkvaIcons.warning,
      ),
      SyncError() => _SyncChipSpec(
        label: l10n.shellSyncError,
        foreground: scheme.error,
        icon: MorkvaIcons.error,
      ),
    };
  }
}

/// The pill itself: an icon (or spinner) + label on a faint tinted background,
/// fully rounded. When [onTap] is set it gains the shared [PressableScale]
/// press feel; otherwise it is a static, non-interactive label.
class _SyncChip extends StatelessWidget {
  const _SyncChip({required this.spec, this.onTap, this.dense = false});

  final _SyncChipSpec spec;
  final VoidCallback? onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final textStyle = dense
        ? Theme.of(context).textTheme.labelSmall
        : Theme.of(context).textTheme.labelMedium;

    final pill = Container(
      height: dense ? 18 : 28,
      padding: dense
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: Spacing.sm),
      decoration: dense
          ? null
          : BoxDecoration(
              // A barely-there wash of the status color keeps the chip calm
              // while still letting attention states read at a glance.
              color: spec.foreground.withValues(alpha: 0.12),
              borderRadius: Radii.fullAll,
            ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (spec.showSpinner)
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: spec.foreground,
              ),
            )
          else if (spec.icon != null)
            Icon(spec.icon, size: 14, color: spec.foreground),
          const SizedBox(width: Spacing.xxs),
          Text(spec.label, style: textStyle?.copyWith(color: spec.foreground)),
        ],
      ),
    );

    if (onTap == null) {
      return Semantics(
        label: context.l10n.shellSyncStatus(spec.label),
        container: true,
        child: pill,
      );
    }

    return Tooltip(
      message: context.l10n.syncConflictDismiss,
      child: PressableScale(
        onPressed: onTap,
        semanticLabel: context.l10n.shellSyncStatusDismiss(spec.label),
        borderRadius: Radii.fullAll,
        child: pill,
      ),
    );
  }
}
