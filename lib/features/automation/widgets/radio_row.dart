import 'package:flutter/material.dart';

import '../../../design/design.dart';

/// A radio with its title (and hint) in a [RadioGroup]: the whole row is the
/// 44 px target, and the 20 px circle sits flush with the section label
/// above it (a padded M3 radio indented it ~14 px).
class RadioRow<T> extends StatelessWidget {
  const RadioRow({
    super.key,
    required this.value,
    required this.title,
    this.hint,
    this.enabled = true,
    this.titleStyle,
  });

  /// The circle's width plus its gap: where the title starts.
  static const double inset = 24 + Spacing.xs;

  final T value;
  final String title;
  final String? hint;
  final bool enabled;
  final TextStyle? titleStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink = enabled
        ? theme.colorScheme.onSurface
        : theme.colorScheme.onSurface.withValues(alpha: 0.38);
    return InkWell(
      onTap: enabled
          ? () => RadioGroup.maybeOf<T>(context)?.onChanged(value)
          : null,
      borderRadius: Radii.smAll,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: Spacing.xs),
              child: Radio<T>(
                value: value,
                enabled: enabled,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: const VisualDensity(
                  horizontal: VisualDensity.minimumDensity,
                  vertical: VisualDensity.minimumDensity,
                ),
              ),
            ),
            const SizedBox(width: Spacing.xs),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: Spacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: (titleStyle ?? theme.textTheme.bodyLarge)
                          ?.copyWith(color: ink),
                    ),
                    if (hint != null)
                      Text(
                        hint!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: enabled
                              ? theme.colorScheme.onSurfaceVariant
                              : ink,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
