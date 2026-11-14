import 'package:flutter/material.dart';

import '../../../design/design.dart';
import '../../../l10n/l10n.dart';
import 'inbox_format.dart';

/// The Inbox's day picker: "November 2026 ▾" (the date picker) and
/// ‹ Today › over the Mon–Sun week of [selected]. The selected day is
/// filled carrot, [today] ringed; [dots] (open items per local day) draw up
/// to 3 dots. [compact] (phone): 44 px cells and a swipe moves a week.
class WeekStrip extends StatelessWidget {
  const WeekStrip({
    super.key,
    required this.selected,
    required this.today,
    required this.dots,
    required this.onSelect,
    this.compact = false,
  });

  final DateTime selected;
  final DateTime today;
  final Map<DateTime, int> dots;
  final ValueChanged<DateTime> onSelect;
  final bool compact;

  DateTime _shift(int days) =>
      DateTime(selected.year, selected.month, selected.day + days);

  /// The days the month picker offers: ten years either side of [today].
  static ({DateTime first, DateTime last}) range(DateTime today) => (
    first: DateTime(today.year - 10),
    last: DateTime(today.year + 10, 12, 31),
  );

  Future<void> _pick(BuildContext context) async {
    final (:first, :last) = range(today);
    final picked = await showDatePicker(
      context: context,
      // The weeks' arrows can walk past the range.
      initialDate: selected.isBefore(first)
          ? first
          : selected.isAfter(last)
          ? last
          : selected,
      firstDate: first,
      lastDate: last,
      builder: (_, child) => MondayFirst(child: child!),
    );
    if (picked != null) onSelect(picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final monday = _shift(1 - selected.weekday);
    final isToday = selected == today;

    final header = Row(
      children: [
        // Expanded, not Flexible + Spacer: those split the free width in
        // half and cut "November 2026" on a phone.
        Expanded(
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: () => _pick(context),
              style: TextButton.styleFrom(
                foregroundColor: scheme.onSurface,
                minimumSize: const Size(44, 44),
                // The label's text lines up with the content edge.
                padding: const EdgeInsets.only(right: Spacing.xs),
                textStyle: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      monthLabel(selected, locale),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      semanticsLabel: l10n.inboxPickDateIn(
                        monthLabel(selected, locale),
                      ),
                    ),
                  ),
                  const SizedBox(width: Spacing.xxs),
                  const Icon(MorkvaIcons.expandMore, size: 20),
                ],
              ),
            ),
          ),
        ),
        IconButton(
          constraints: const BoxConstraints.tightFor(width: 44, height: 44),
          padding: EdgeInsets.zero,
          tooltip: l10n.inboxPreviousWeek,
          onPressed: () => onSelect(_shift(-7)),
          icon: const Icon(MorkvaIcons.chevronLeft),
        ),
        OutlinedButton(
          onPressed: isToday ? null : () => onSelect(today),
          style:
              OutlinedButton.styleFrom(
                minimumSize: const Size(44, 32),
                tapTargetSize: MaterialTapTargetSize.padded,
                padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
                shape: const RoundedRectangleBorder(borderRadius: Radii.smAll),
                foregroundColor: scheme.onSurface,
                disabledForegroundColor: scheme.onSurface.withValues(
                  alpha: 0.38,
                ),
              ).copyWith(
                // styleFrom's side would paint the disabled outline full ink;
                // disabled fades it as the mockup does (38%).
                side: WidgetStateProperty.resolveWith(
                  (states) => BorderSide(
                    color: states.contains(WidgetState.disabled)
                        ? scheme.outline.withValues(alpha: 0.38)
                        : scheme.outline,
                  ),
                ),
              ),
          child: Text(l10n.commonToday),
        ),
        IconButton(
          constraints: const BoxConstraints.tightFor(width: 44, height: 44),
          padding: EdgeInsets.zero,
          tooltip: l10n.inboxNextWeek,
          onPressed: () => onSelect(_shift(7)),
          icon: const Icon(MorkvaIcons.chevronRight),
        ),
      ],
    );

    Widget week = Row(
      children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: _DayCell(
              day: DateTime(monday.year, monday.month, monday.day + i),
              selected: selected,
              today: today,
              dots: dots,
              compact: compact,
              onTap: onSelect,
            ),
          ),
      ],
    );
    if (compact) {
      week = GestureDetector(
        onHorizontalDragEnd: (d) {
          final v = d.primaryVelocity ?? 0;
          if (v.abs() < 200) return;
          onSelect(_shift(v < 0 ? 7 : -7));
        },
        child: week,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        const SizedBox(height: Spacing.xxs),
        week,
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.selected,
    required this.today,
    required this.dots,
    required this.compact,
    required this.onTap,
  });

  final DateTime day;
  final DateTime selected;
  final DateTime today;
  final Map<DateTime, int> dots;
  final bool compact;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final isSelected = day == selected;
    final isToday = day == today;
    final count = dots[day] ?? 0;
    final ink = isSelected ? scheme.onPrimary : scheme.onSurface;
    final dotColor = isSelected ? scheme.onPrimary : scheme.primary;
    return Semantics(
      button: true,
      selected: isSelected,
      label: isToday
          ? l10n.inboxStripDayToday(dayMonthLabel(day, locale), count)
          : l10n.inboxStripDay(dayMonthLabel(day, locale), count),
      excludeSemantics: true,
      child: Center(
        child: Material(
          key: ValueKey('week-day-${day.year}-${day.month}-${day.day}'),
          color: isSelected ? scheme.primary : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: Radii.mdAll,
            side: isToday && !isSelected
                ? BorderSide(
                    color: scheme.primary,
                    width: 2,
                    strokeAlign: BorderSide.strokeAlignInside,
                  )
                : BorderSide.none,
          ),
          child: InkWell(
            borderRadius: Radii.mdAll,
            onTap: () => onTap(day),
            child: SizedBox(
              width: compact ? 44 : 48,
              height: 56,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    weekdayLabel(day, locale),
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? ink : scheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    '${day.day}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontSize: 16,
                      height: 1.25,
                      fontWeight: FontWeight.w600,
                      color: ink,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 1),
                  SizedBox(
                    height: 4,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < count.clamp(0, 3); i++) ...[
                          if (i > 0) const SizedBox(width: 3),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: dotColor,
                              shape: BoxShape.circle,
                            ),
                            child: const SizedBox.square(dimension: 4),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
