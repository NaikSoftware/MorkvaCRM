import 'package:flutter/material.dart';

import '../../../design/design.dart';

/// A select value as a pill: a tint of the option colour with a leading dot.
/// Without a colour it falls back to the neutral `surfaceContainerHigh`.
class OptionPill extends StatelessWidget {
  const OptionPill({super.key, required this.label, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tint = color;
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: Spacing.xs),
      decoration: BoxDecoration(
        color: tint == null
            ? scheme.surfaceContainerHigh
            : Color.alphaBlend(
                tint.withValues(alpha: 0.16),
                scheme.surfaceContainerLowest,
              ),
        borderRadius: Radii.fullAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: tint ?? scheme.outline,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
