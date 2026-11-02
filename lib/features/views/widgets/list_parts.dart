import 'package:flutter/material.dart';

import '../../../design/design.dart';

/// Pieces shared by the List mode and the phone calendar agenda, so both
/// read as the same list: one bordered card, 36 px section headers and
/// rows with an inset divider.

/// The rounded `surfaceContainerLowest` card a list sits in. Its border
/// paints over the rows so opaque rows never hide it.
class ListCard extends StatelessWidget {
  const ListCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        borderRadius: Radii.lgAll,
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: ClipRRect(
        borderRadius: Radii.lgAll,
        child: ColoredBox(color: scheme.surfaceContainerLowest, child: child),
      ),
    );
  }
}

/// A 36 px section header: uppercase [label] and a [count], optionally in
/// [color] (today in the agenda) and with a [trailing] widget.
class ListSectionHeader extends StatelessWidget {
  const ListSectionHeader({
    super.key,
    required this.label,
    required this.count,
    this.color,
    this.trailing,
  });

  static const double height = 36;

  final String label;
  final int count;
  final Color? color;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final style = theme.textTheme.labelMedium?.copyWith(
      color: color ?? scheme.onSurfaceVariant,
      letterSpacing: 0.6,
    );
    return Semantics(
      header: true,
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
        color: scheme.surfaceContainerLow,
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Flexible(
              child: Text(
                label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: Spacing.xs),
            Text(
              '$count',
              style: style?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            if (trailing case final widget?) ...[const Spacer(), widget],
          ],
        ),
      ),
    );
  }
}

/// A list row with the 1 px `outlineVariant` divider inset 16 under it.
class ListRowFrame extends StatelessWidget {
  const ListRowFrame({super.key, required this.child, required this.divider});

  final Widget child;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (divider)
          Positioned(
            left: Spacing.md,
            right: 0,
            bottom: 0,
            height: 1,
            child: ColoredBox(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
      ],
    );
  }
}
