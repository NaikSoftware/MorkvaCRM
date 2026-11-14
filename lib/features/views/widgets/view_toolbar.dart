import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import '../../../core/domain/domain.dart';
import '../../../design/design.dart';
import '../../../l10n/l10n.dart';
import 'view_labels.dart';

/// One toolbar row: filter chips and a dashed "+ Filter" on the left; on wide
/// screens a neutral-outline cluster on the right with the mode's setting
/// chip, Sort, and Columns / Setup card. On phones only the chip row shows
/// (the rest lives in the view settings sheet).
class ViewToolbar extends StatelessWidget {
  const ViewToolbar({
    super.key,
    required this.collection,
    required this.view,
    required this.compact,
    required this.fieldsLabel,
    required this.onAddFilter,
    required this.onEditFilter,
    required this.onRemoveFilter,
    this.onSort,
    this.onEditFields,
    this.settingsChip,
    this.horizontalPadding = Spacing.lg,
    this.referenceLabels = const {},
    this.leading = const [],
  });

  final Collection collection;
  final ViewDefinition view;
  final bool compact;
  final String fieldsLabel;
  final VoidCallback onAddFilter;
  final ValueChanged<int> onEditFilter;
  final ValueChanged<int> onRemoveFilter;

  /// Null hides Sort (the mode can't draw this collection yet).
  final VoidCallback? onSort;

  /// Null hides Columns / Setup card.
  final VoidCallback? onEditFields;
  final Widget? settingsChip;
  final double horizontalPadding;
  final Map<String, String> referenceLabels;

  /// Shown before the filter chips (the "From assistant" chip).
  final List<Widget> leading;

  @override
  Widget build(BuildContext context) {
    final chips = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Row(
        children: [
          for (final widget in leading) ...[
            widget,
            const SizedBox(width: Spacing.xs),
          ],
          for (var i = 0; i < view.filters.length; i++) ...[
            _FilterChip(
              label: filterLabel(
                view.filters[i],
                collection,
                referenceLabels: referenceLabels,
                l10n: context.l10n,
              ),
              onPressed: () => onEditFilter(i),
              onRemove: () => onRemoveFilter(i),
            ),
            const SizedBox(width: Spacing.xs),
          ],
          _AddFilterButton(onPressed: onAddFilter),
        ],
      ),
    );
    final onSort = this.onSort;
    final onEditFields = this.onEditFields;
    if (compact ||
        (settingsChip == null && onSort == null && onEditFields == null)) {
      return SizedBox(
        height: 52,
        child: Align(alignment: Alignment.centerLeft, child: chips),
      );
    }

    final sort = view.sort;
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          Expanded(
            child: Align(alignment: Alignment.centerLeft, child: chips),
          ),
          Padding(
            padding: EdgeInsets.only(right: horizontalPadding),
            child: _Cluster(
              children: [
                ?settingsChip,
                if (onSort != null)
                  ToolbarButton(
                    icon: switch (sort) {
                      null => MorkvaIcons.swapVert,
                      ViewSort(ascending: true) => MorkvaIcons.arrowUp,
                      _ => MorkvaIcons.arrowDown,
                    },
                    label:
                        sortLabel(sort, collection, l10n: context.l10n) ??
                        context.l10n.viewWidgetsSort,
                    onPressed: onSort,
                  ),
                if (onEditFields != null)
                  ToolbarButton(
                    icon: MorkvaIcons.viewColumns,
                    label: fieldsLabel,
                    onPressed: onEditFields,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A 36 px toolbar button with a 44 px hit area, for the toolbar cluster.
/// Modes use it for their setting chip ("Group: Stage").
class ToolbarButton extends StatelessWidget {
  const ToolbarButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: SizedBox(
          height: 44,
          child: Center(
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: onPressed,
                borderRadius: Radii.smAll,
                hoverColor: scheme.surfaceContainerHigh,
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 18, color: scheme.onSurfaceVariant),
                      const SizedBox(width: Spacing.xxs),
                      Text(
                        label,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: scheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The outlined group the toolbar buttons sit in, with hairline separators.
class _Cluster extends StatelessWidget {
  const _Cluster({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          top: 4,
          bottom: 4,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: scheme.outline.withValues(alpha: 0.6)),
              borderRadius: Radii.mdAll,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0)
                  Container(width: 1, height: 20, color: scheme.outlineVariant),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.onPressed,
    required this.onRemove,
  });

  final String label;
  final VoidCallback onPressed;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InputChip(
      label: Text(label),
      onPressed: onPressed,
      onDeleted: onRemove,
      deleteIcon: const Icon(MorkvaIcons.close, size: 16),
      deleteButtonTooltipMessage: context.l10n.viewWidgetsRemoveFilter,
      backgroundColor: scheme.primaryContainer,
      side: BorderSide.none,
      shape: const RoundedRectangleBorder(borderRadius: Radii.smAll),
      labelStyle: theme.textTheme.labelLarge?.copyWith(
        color: scheme.onPrimaryContainer,
      ),
      deleteIconColor: scheme.onPrimaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );
  }
}

class _AddFilterButton extends StatelessWidget {
  const _AddFilterButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      button: true,
      label: context.l10n.viewWidgetsAddFilter,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: SizedBox(
          height: 44,
          child: Center(
            child: CustomPaint(
              painter: _DashedBorderPainter(color: scheme.outline),
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: onPressed,
                  borderRadius: Radii.smAll,
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          MorkvaIcons.add,
                          size: 18,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: Spacing.xxs),
                        Text(
                          context.l10n.viewWidgetsFilter,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(0.5),
          const Radius.circular(Radii.sm),
        ),
      );
    for (final PathMetric metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 7) {
        canvas.drawPath(metric.extractPath(d, d + 4), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) => old.color != color;
}
