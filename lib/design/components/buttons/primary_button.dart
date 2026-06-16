import 'package:flutter/material.dart';

import '../../tokens/motion.dart';
import '../../tokens/radii.dart';
import '../../tokens/spacing.dart';
import '../pressable_scale.dart';

/// The primary call-to-action: a solid carrot fill with the shared press-scale.
///
/// **Exemplar component** — the reference for every other button/component:
/// - reads color/text from the theme ([ColorScheme] / [TextTheme]), never hex;
/// - reads spacing/radius from tokens;
/// - uses [PressableScale] for the signature press feel;
/// - supports leading icon, full-width, disabled, and loading states.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
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

    final fg = scheme.onPrimary;
    final bg = enabled
        ? scheme.primary
        : scheme.primary.withValues(alpha: 0.38);

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
        decoration: BoxDecoration(color: bg, borderRadius: Radii.mdAll),
        alignment: Alignment.center,
        child: content,
      ),
    );
  }
}
