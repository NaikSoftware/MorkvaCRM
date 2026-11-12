import 'package:flutter/material.dart';

import '../../../design/design.dart';
import 'reason_copy.dart';

/// A 24 px status pill (module, automation, apply mode, run): text always,
/// so status is never colour-only. Tappable chips (Needs consent → consent,
/// Broken → editor) get the house press feel and a 44 px hit area.
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    required this.tone,
    this.onTap,
  });

  StatusChip.of(ChipCopy copy, {Key? key, VoidCallback? onTap})
    : this(key: key, label: copy.label, tone: copy.tone, onTap: onTap);

  final String label;
  final CopyTone tone;
  final VoidCallback? onTap;

  /// The chip's fill and ink for [tone].
  static ({Color background, Color foreground}) colorsOf(
    ThemeData theme,
    CopyTone tone,
  ) {
    final scheme = theme.colorScheme;
    final semantic = theme.extension<MorkvaSemanticColors>()!;
    final leaf = (theme.brightness == Brightness.light
        ? CollectionTints.light
        : CollectionTints.dark)[1];
    return switch (tone) {
      CopyTone.neutral => (
        background: scheme.surfaceContainerHigh,
        foreground: scheme.onSurface,
      ),
      CopyTone.success => leaf,
      CopyTone.warning => (
        background: semantic.warningContainer,
        foreground: semantic.onWarningContainer,
      ),
      CopyTone.error => (
        background: scheme.errorContainer,
        foreground: scheme.onErrorContainer,
      ),
      CopyTone.muted => (
        background: scheme.surfaceContainer,
        foreground: scheme.onSurfaceVariant,
      ),
      CopyTone.info => (
        background: semantic.info.withValues(alpha: 0.12),
        foreground: semantic.info,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = colorsOf(theme, tone);
    final pill = Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: Spacing.xs),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: Radii.fullAll,
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelMedium?.copyWith(color: colors.foreground),
      ),
    );
    final tap = onTap;
    if (tap == null) return pill;
    return PressableScale(
      onPressed: tap,
      semanticLabel: label,
      borderRadius: Radii.fullAll,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Center(widthFactor: 1, heightFactor: 1, child: pill),
      ),
    );
  }
}
