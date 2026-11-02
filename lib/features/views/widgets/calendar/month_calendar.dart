import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/domain/domain.dart';
import '../../../../design/design.dart';
import '../../modes/view_mode.dart';
import '../object_card.dart';
import 'calendar_common.dart';
import 'no_date_tray.dart';

/// The desktop calendar: a month grid (Monday first) with a "No date" tray.
/// The shown month is local UI state, starting at [today]'s month.
class MonthCalendar extends StatefulWidget {
  const MonthCalendar({super.key, required this.data, required this.today});

  final ViewModeData data;

  /// Local midnight of today.
  final DateTime today;

  static const double minCellHeight = 112;
  static const double weekdayRowHeight = 32;

  @override
  State<MonthCalendar> createState() => _MonthCalendarState();
}

class _MonthCalendarState extends State<MonthCalendar> {
  late DateTime _month = DateTime(widget.today.year, widget.today.month);
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _shift(int months) =>
      setState(() => _month = DateTime(_month.year, _month.month + months));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final today = widget.today;
    final first = _month;
    final lead = first.weekday - DateTime.monday;
    final daysInMonth = DateTime(first.year, first.month + 1, 0).day;
    final weeks = ((lead + daysInMonth) / 7).ceil();
    final isCurrentMonth =
        first.year == today.year && first.month == today.month;

    final header = SizedBox(
      height: 56,
      child: Row(
        children: [
          Expanded(
            child: Text(
              MaterialLocalizations.of(context).formatMonthYear(first),
              style: theme.textTheme.headlineSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconActionButton(
            icon: Icons.chevron_left,
            tooltip: 'Previous month',
            onPressed: () => _shift(-1),
          ),
          IconActionButton(
            icon: Icons.chevron_right,
            tooltip: 'Next month',
            onPressed: () => _shift(1),
          ),
          const SizedBox(width: Spacing.xs),
          ActionChip(
            label: const Text('Today'),
            onPressed: isCurrentMonth
                ? null
                : () => setState(
                    () => _month = DateTime(today.year, today.month),
                  ),
          ),
        ],
      ),
    );

    final grid = DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        borderRadius: Radii.lgAll,
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: ClipRRect(
        borderRadius: Radii.lgAll,
        child: ColoredBox(
          color: scheme.surfaceContainerLowest,
          child: Column(
            children: [
              SizedBox(
                height: MonthCalendar.weekdayRowHeight,
                child: Row(
                  children: [
                    for (final name in weekdayNames)
                      Expanded(
                        child: Center(
                          child: Text(
                            name,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Divider(height: 1, color: scheme.outlineVariant),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final rowHeight = math.max(
                      MonthCalendar.minCellHeight,
                      constraints.maxHeight / weeks,
                    );
                    return SingleChildScrollView(
                      controller: _scroll,
                      child: Column(
                        children: [
                          for (var w = 0; w < weeks; w++)
                            SizedBox(
                              height: rowHeight,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  for (var d = 0; d < 7; d++)
                                    Expanded(
                                      child: Builder(
                                        builder: (context) {
                                          final day = DateTime(
                                            first.year,
                                            first.month,
                                            1 - lead + w * 7 + d,
                                          );
                                          return _DayCell(
                                            key: ValueKey(day),
                                            day: day,
                                            month: first.month,
                                            today: today,
                                            data: widget.data,
                                            lastColumn: d == 6,
                                            lastRow: w == weeks - 1,
                                          );
                                        },
                                      ),
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: grid),
              const SizedBox(width: Spacing.sm),
              NoDateTray(data: widget.data),
            ],
          ),
        ),
      ],
    );
  }
}

class _DayCell extends StatefulWidget {
  const _DayCell({
    super.key,
    required this.day,
    required this.month,
    required this.today,
    required this.data,
    required this.lastColumn,
    required this.lastRow,
  });

  final DateTime day;
  final int month;
  final DateTime today;
  final ViewModeData data;
  final bool lastColumn;
  final bool lastRow;

  static const double pillHeight = 24;
  static const double gap = 2;
  static const double moreHeight = 20;
  static const int maxPills = 3;

  @override
  State<_DayCell> createState() => _DayCellState();
}

class _DayCellState extends State<_DayCell> {
  bool _hovered = false;

  /// How many pills fit in [height] for [count] items, and whether a
  /// "+N more" row is needed.
  static (int, bool) _fit(int count, double height) {
    double extent(int k) =>
        k * _DayCell.pillHeight + math.max(0, k - 1) * _DayCell.gap;
    if (count <= _DayCell.maxPills && extent(count) <= height) {
      return (count, false);
    }
    var k = math.min(_DayCell.maxPills, count);
    while (k > 0 && extent(k) + _DayCell.gap + _DayCell.moreHeight > height) {
      k--;
    }
    return (k, true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final day = widget.day;
    final data = widget.data;
    final objects = data.state.days?.days[day] ?? const <MorkvaObject>[];
    final outside = day.month != widget.month;
    final isToday = isSameDay(day, widget.today);
    final label = dayLabel(day);

    return DragTarget<String>(
      onWillAcceptWithDetails: (d) => !objects.any((o) => o.id == d.data),
      onAcceptWithDetails: (d) => moveObjectToDay(context, data, d.data, day),
      builder: (context, candidates, _) {
        final hovering = candidates.isNotEmpty;
        return MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: Container(
            decoration: BoxDecoration(
              color: hovering
                  ? scheme.primaryContainer
                  : outside
                  ? scheme.surfaceContainerLow
                  : null,
              border: Border(
                right: widget.lastColumn
                    ? BorderSide.none
                    : BorderSide(color: scheme.outlineVariant),
                bottom: widget.lastRow
                    ? BorderSide.none
                    : BorderSide(color: scheme.outlineVariant),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(
              Spacing.xxs,
              Spacing.xxs,
              Spacing.xxs,
              2,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 28,
                  child: Row(
                    children: [
                      _DateBadge(day: day, today: isToday, outside: outside),
                      const Spacer(),
                      AnimatedOpacity(
                        opacity: _hovered ? 1 : 0,
                        duration: MotionDurations.fast,
                        child: Tooltip(
                          message: 'New ${data.itemLabel} on $label',
                          child: IconButton(
                            onPressed: () => data.quickAdd(day: day),
                            icon: const Icon(Icons.add, size: 18),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints.tightFor(
                              width: 28,
                              height: 28,
                            ),
                            style: IconButton.styleFrom(
                              foregroundColor: scheme.onSurfaceVariant,
                              shape: const RoundedRectangleBorder(
                                borderRadius: Radii.smAll,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final (shown, more) = _fit(
                        objects.length,
                        constraints.maxHeight,
                      );
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = 0; i < shown; i++) ...[
                            if (i > 0) const SizedBox(height: _DayCell.gap),
                            CalendarPill(object: objects[i], data: data),
                          ],
                          if (more) ...[
                            if (shown > 0) const SizedBox(height: _DayCell.gap),
                            _MoreButton(
                              count: objects.length - shown,
                              onPressed: () =>
                                  _showDay(context, data, day, objects),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DateBadge extends StatelessWidget {
  const _DateBadge({
    required this.day,
    required this.today,
    required this.outside,
  });

  final DateTime day;
  final bool today;
  final bool outside;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: today
          ? BoxDecoration(color: scheme.primary, shape: BoxShape.circle)
          : null,
      child: Text(
        '${day.day}',
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: today ? FontWeight.w700 : null,
          color: today
              ? scheme.onPrimary
              : outside
              ? scheme.onSurfaceVariant.withValues(alpha: 0.6)
              : scheme.onSurface,
        ),
      ),
    );
  }
}

class _MoreButton extends StatelessWidget {
  const _MoreButton({required this.count, required this.onPressed});

  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onPressed,
        borderRadius: Radii.smAll,
        child: Container(
          height: _DayCell.moreHeight,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: Spacing.xxs),
          child: Text(
            '+$count more',
            style: theme.textTheme.labelMedium?.copyWith(
              color: primaryTextColor(context),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// Every object of [day], opened from "+N more".
Future<void> _showDay(
  BuildContext context,
  ViewModeData data,
  DateTime day,
  List<MorkvaObject> objects,
) => showDialog<void>(
  context: context,
  builder: (dialogContext) {
    final theme = Theme.of(dialogContext);
    final state = data.state;
    return Dialog(
      shape: const RoundedRectangleBorder(borderRadius: Radii.lgAll),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Spacing.lg,
                Spacing.md,
                Spacing.xs,
                Spacing.xs,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      dayLabel(day),
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  IconActionButton(
                    icon: Icons.close,
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(dialogContext).pop(),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: Spacing.xs),
                children: [
                  for (final o in objects)
                    ObjectCard(
                      object: o,
                      collection: state.collection,
                      view: state.activeView,
                      density: ObjectCardDensity.list,
                      referenceLabels: state.referenceLabels,
                      onTap: () {
                        Navigator.of(dialogContext).pop();
                        data.openObject(o);
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  },
);
