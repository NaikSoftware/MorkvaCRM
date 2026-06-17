import 'package:flutter/material.dart';

import '../../tokens/radii.dart';
import '../../tokens/spacing.dart';
import '../pressable_scale.dart';

/// A low-emphasis, text-only action — the quietest button in the family.
///
/// Used for tertiary actions (inline "Cancel", "Learn more", row affordances).
/// Carries no fill or border: the carrot [ColorScheme.primary] label is the
/// only emphasis. Follows the exemplar pattern — shared [PressableScale] press
/// feel, a 44px-tall hit target, an optional leading [icon], and a disabled
/// state when [onPressed] is null. Reads all color/text from the theme and
/// spacing/radius from tokens.
class TextActionButton extends StatelessWidget {
  const TextActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textStyle = Theme.of(context).textTheme.labelLarge;
    final enabled = onPressed != null;

    final fg = enabled
        ? scheme.primary
        : scheme.primary.withValues(alpha: 0.38);

    return PressableScale(
      onPressed: enabled ? onPressed : null,
      semanticLabel: label,
      borderRadius: Radii.mdAll,
      // ConstrainedBox + a content-sized Row (not Container.alignment, which
      // grows to fill any bounded width it's given): the button hugs its label
      // under loose constraints (dialog action bars, Wrap) yet still fills and
      // centers when a parent stretches it tight (e.g. a stretch Column).
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: fg),
                const SizedBox(width: Spacing.xs),
              ],
              Flexible(
                child: Text(
                  label,
                  style: textStyle?.copyWith(color: fg),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
