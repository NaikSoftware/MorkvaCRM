import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import 'assistant_scope.dart';

/// A quiet action under a result card ("Open as filtered view", "Copy
/// table", "Show as table"): a 36 px neutral pill inside a 44 px hit area.
class ChipButton extends StatelessWidget {
  const ChipButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AssistantColors.of(context);
    return PressableScale(
      onPressed: onPressed,
      semanticLabel: label,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
          decoration: BoxDecoration(
            color: colors.neutralChip,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Align(
            widthFactor: 1,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                letterSpacing: 0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A tinted 44 px action inside a card ("Undo", "Retry failed", "Try
/// again"): the neutral chip fill, a carrot label unless [foreground] says
/// otherwise.
class TintedButton extends StatelessWidget {
  const TintedButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.foreground,
    this.fontSize,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color? foreground;
  final double? fontSize;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AssistantColors.of(context);
    final fg = foreground ?? colors.objectChipText;
    return PressableScale(
      onPressed: loading ? null : onPressed,
      semanticLabel: label,
      borderRadius: Radii.mdAll,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
        decoration: BoxDecoration(
          color: colors.neutralChip,
          borderRadius: Radii.mdAll,
        ),
        child: Align(
          widthFactor: 1,
          child: loading
              ? SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                )
              : Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: fg,
                    fontSize: fontSize,
                  ),
                ),
        ),
      ),
    );
  }
}
