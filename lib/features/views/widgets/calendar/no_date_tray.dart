import 'package:flutter/material.dart';

import '../../../../core/domain/domain.dart';
import '../../../../design/design.dart';
import '../../modes/view_mode.dart';
import 'calendar_common.dart';

/// The collapsible "No date" panel beside the month grid. Dropping a pill on
/// it clears that object's date.
class NoDateTray extends StatefulWidget {
  const NoDateTray({super.key, required this.data});

  final ViewModeData data;

  static const double width = 280;
  static const double collapsedWidth = 52;

  @override
  State<NoDateTray> createState() => _NoDateTrayState();
}

class _NoDateTrayState extends State<NoDateTray> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final data = widget.data;
    final undated = data.state.days?.undated ?? const <MorkvaObject>[];
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return DragTarget<String>(
      onWillAcceptWithDetails: (d) => !undated.any((o) => o.id == d.data),
      onAcceptWithDetails: (d) => moveObjectToDay(context, data, d.data, null),
      builder: (context, candidates, _) {
        final hovering = candidates.isNotEmpty;
        return AnimatedContainer(
          duration: reduceMotion ? MotionDurations.none : MotionDurations.base,
          curve: MotionCurves.standard,
          width: _expanded ? NoDateTray.width : NoDateTray.collapsedWidth,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: hovering
                ? scheme.primaryContainer
                : scheme.surfaceContainerLowest,
            borderRadius: Radii.lgAll,
            border: Border.all(
              color: hovering ? scheme.primary : scheme.outlineVariant,
            ),
          ),
          child: _expanded
              ? _expandedBody(context, undated, hovering)
              : _collapsedBody(context, undated.length),
        );
      },
    );
  }

  Widget _collapsedBody(BuildContext context, int count) {
    final theme = Theme.of(context);
    return Column(
      children: [
        const SizedBox(height: Spacing.xxs),
        IconActionButton(
          icon: Icons.chevron_left,
          tooltip: 'Show No date ($count)',
          onPressed: () => setState(() => _expanded = true),
        ),
        const SizedBox(height: Spacing.xs),
        Icon(
          Icons.event_busy_outlined,
          size: 20,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: Spacing.xxs),
        Text('$count', style: theme.textTheme.labelLarge),
      ],
    );
  }

  Widget _expandedBody(
    BuildContext context,
    List<MorkvaObject> undated,
    bool hovering,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return OverflowBox(
      // Keeps the content laid out at full width while the panel animates.
      alignment: Alignment.topLeft,
      minWidth: NoDateTray.width - 2,
      maxWidth: NoDateTray.width - 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.md,
              Spacing.xxs,
              Spacing.xxs,
              0,
            ),
            child: Row(
              children: [
                Text('No date', style: theme.textTheme.titleSmall),
                const SizedBox(width: Spacing.xs),
                _CountBadge(count: undated.length),
                const Spacer(),
                IconActionButton(
                  icon: Icons.chevron_right,
                  tooltip: 'Hide No date',
                  onPressed: () => setState(() => _expanded = false),
                ),
              ],
            ),
          ),
          Expanded(
            child: undated.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(Spacing.md),
                    child: Text(
                      hovering
                          ? 'Drop to clear the date'
                          : 'Every ${widget.data.itemLabel} has a date. '
                                'Drop one here to clear it.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      Spacing.sm,
                      Spacing.xxs,
                      Spacing.sm,
                      Spacing.sm,
                    ),
                    itemCount: undated.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: Spacing.xxs),
                    itemBuilder: (_, i) =>
                        CalendarPill(object: undated[i], data: widget.data),
                  ),
          ),
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.xs, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: Radii.fullAll,
      ),
      child: Text(
        '$count',
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
