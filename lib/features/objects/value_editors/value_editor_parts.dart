import 'package:flutter/material.dart';

import '../../../design/design.dart';

/// The quiet "+ Add" / "+ Link company" button after a row of chips: 32 px
/// tall, outlined, with a padded 48 px hit area.
class AddValueButton extends StatelessWidget {
  const AddValueButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color =
        theme.extension<MorkvaSemanticColors>()?.primaryText ?? scheme.primary;
    return TextButton.icon(
      onPressed: onPressed,
      icon: const Icon(MorkvaIcons.add, size: 18),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: color,
        minimumSize: const Size(0, 32),
        padding: const EdgeInsets.symmetric(horizontal: Spacing.xs),
        tapTargetSize: MaterialTapTargetSize.padded,
        textStyle: theme.textTheme.labelLarge,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.smAll,
          side: BorderSide(color: scheme.outline),
        ),
      ),
    );
  }
}

/// A removable chip: [label] with an optional leading widget and a ✕ whose
/// tooltip/semantics is [deleteTooltip]. Tapping the body runs [onPressed].
class RemovableChip extends StatelessWidget {
  const RemovableChip({
    super.key,
    required this.label,
    required this.deleteTooltip,
    required this.onDeleted,
    this.leading,
    this.color,
    this.onPressed,
    this.shape,
  });

  final String label;
  final String deleteTooltip;
  final VoidCallback? onDeleted;
  final VoidCallback? onPressed;
  final Widget? leading;

  /// Background; defaults to `surfaceContainer`.
  final Color? color;
  final OutlinedBorder? shape;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InputChip(
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      labelStyle: theme.textTheme.labelLarge?.copyWith(color: scheme.onSurface),
      avatar: leading,
      backgroundColor: color ?? scheme.surfaceContainer,
      side: BorderSide.none,
      shape: shape ?? const RoundedRectangleBorder(borderRadius: Radii.smAll),
      deleteIcon: const Icon(MorkvaIcons.close, size: 16),
      deleteIconColor: scheme.onSurfaceVariant,
      deleteButtonTooltipMessage: deleteTooltip,
      onDeleted: onDeleted,
      onPressed: onPressed,
      isEnabled: onDeleted != null,
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );
  }
}
