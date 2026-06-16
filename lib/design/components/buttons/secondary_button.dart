import 'package:flutter/material.dart';

import '../../tokens/motion.dart';
import '../../tokens/radii.dart';
import '../../tokens/spacing.dart';
import '../pressable_scale.dart';

/// A quiet, neutral button for secondary actions — the calm counterpart to
/// [PrimaryButton] (carrot is reserved for the primary call-to-action).
///
/// Follows the exemplar pattern: a `surfaceContainerHighest` fill with an
/// `outlineVariant` hairline, an `onSurface` label, the shared [PressableScale]
/// press feel, and a 44px hit target. Reads every color/text value from the
/// theme and every spacing/radius from tokens — never hardcoded.
///
/// Mirrors [PrimaryButton]'s API: [label], [onPressed], optional [icon],
/// [expand] (full-width), [loading] (spinner), and a disabled state when
/// [onPressed] is null.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = false,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textStyle = Theme.of(context).textTheme.labelLarge;
    final enabled = onPressed != null && !loading;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    final fg = enabled
        ? scheme.onSurface
        : scheme.onSurface.withValues(alpha: 0.38);
    final bg = enabled
        ? scheme.surfaceContainerHighest
        : scheme.surfaceContainerHighest.withValues(alpha: 0.38);
    final borderColor = enabled
        ? scheme.outlineVariant
        : scheme.outlineVariant.withValues(alpha: 0.38);

    final content = AnimatedSize(
      duration: reduceMotion ? MotionDurations.none : MotionDurations.fast,
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (loading)
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: fg),
            )
          else if (icon != null) ...[
            Icon(icon, size: 18, color: fg),
            const SizedBox(width: Spacing.xs),
          ],
          if (!loading)
            Flexible(
              child: Text(
                label,
                style: textStyle?.copyWith(color: fg),
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );

    return PressableScale(
      onPressed: enabled ? onPressed : null,
      semanticLabel: label,
      borderRadius: Radii.mdAll,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: Radii.mdAll,
          border: Border.all(color: borderColor),
        ),
        child: content,
      ),
    );
  }
}
