import 'package:flutter/material.dart';

import '../../design/design.dart';

/// The Morkva CRM brand mark for the navigation rail header.
///
/// Always shows a carrot logomark; appends the "Morkva CRM" wordmark when the
/// rail is [extended]. A collapsed rail shows only the mark so it fits the
/// narrow column.
class BrandWordmark extends StatelessWidget {
  const BrandWordmark({super.key, this.extended = true});

  /// Whether to show the full wordmark beside the logomark.
  final bool extended;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final logomark = Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: Radii.smAll,
      ),
      alignment: Alignment.center,
      child: Text(
        'M',
        style: theme.textTheme.titleLarge?.copyWith(
          color: scheme.onPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    if (!extended) return logomark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        logomark,
        const SizedBox(width: Spacing.xs),
        Flexible(
          child: Text(
            'Morkva CRM',
            style: theme.textTheme.titleLarge,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
