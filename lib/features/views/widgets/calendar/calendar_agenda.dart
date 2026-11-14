import 'package:flutter/material.dart';

import '../../../../core/domain/domain.dart';
import '../../../../design/design.dart';
import '../../../../l10n/l10n.dart';
import '../../modes/view_mode.dart';
import '../list_parts.dart';
import '../object_card.dart';
import 'calendar_common.dart';

/// The phone calendar: a snapping week strip over an agenda of the days that
/// have items, with "No date" last. No drag; long-press moves an item.
class CalendarAgenda extends StatefulWidget {
  const CalendarAgenda({super.key, required this.data, required this.today});

  final ViewModeData data;

  /// Local midnight of today.
  final DateTime today;

  static const double stripHeight = 56;
  static const double dayHeaderHeight = ListSectionHeader.height;

  @override
  State<CalendarAgenda> createState() => _CalendarAgendaState();
}

class _CalendarAgendaState extends State<CalendarAgenda> {
  // Week pages are counted from this far back so the strip scrolls both ways.
  static const _basePage = 520;

  late final DateTime _baseWeek = weekStartOf(widget.today);
  late final _pages = PageController(initialPage: _basePage);
  final _keys = <DateTime, GlobalKey>{};
  late DateTime _selected = widget.today;
  bool _undatedOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _reveal(widget.today, animate: false);
    });
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  DateTime _weekOf(int page) => DateTime(
    _baseWeek.year,
    _baseWeek.month,
    _baseWeek.day + (page - _basePage) * 7,
  );

  /// Scrolls the agenda to the first day on or after [day] that has items.
  void _reveal(DateTime day, {bool animate = true}) {
    final days = widget.data.state.days?.days.keys ?? const <DateTime>[];
    final target = days.where((d) => !d.isBefore(day)).firstOrNull;
    final context = target == null ? null : _keys[target]?.currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      duration: animate && !MediaQuery.disableAnimationsOf(this.context)
          ? MotionDurations.slow
          : Duration.zero,
      curve: MotionCurves.emphasized,
    );
  }

  void _select(DateTime day) {
    setState(() => _selected = day);
    _reveal(day);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final data = widget.data;
    final buckets = data.state.days;
    final days = buckets?.days ?? const <DateTime, List<MorkvaObject>>{};
    final undated = buckets?.undated ?? const <MorkvaObject>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: CalendarAgenda.stripHeight,
          child: PageView.builder(
            controller: _pages,
            itemBuilder: (context, page) {
              final start = _weekOf(page);
              return Row(
                children: [
                  for (var i = 0; i < 7; i++)
                    Expanded(
                      child: _StripDay(
                        day: DateTime(start.year, start.month, start.day + i),
                        today: widget.today,
                        selected: _selected,
                        hasItems: days.containsKey(
                          DateTime(start.year, start.month, start.day + i),
                        ),
                        onTap: _select,
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        Divider(height: 1, color: scheme.outlineVariant),
        const SizedBox(height: Spacing.sm),
        Expanded(
          child: Align(
            alignment: Alignment.topCenter,
            // The same card, section headers and rows as List mode.
            child: ListCard(
              child: CustomScrollView(
                shrinkWrap: true,
                slivers: [
                  if (days.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(Spacing.lg),
                        child: Text(
                          context.l10n.viewWidgetsNothingScheduled,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  for (final MapEntry(key: day, value: objects) in days.entries)
                    SliverMainAxisGroup(
                      key: _keys.putIfAbsent(day, GlobalKey.new),
                      slivers: [
                        SliverPersistentHeader(
                          pinned: true,
                          delegate: _DayHeader(
                            label: dayLabel(day),
                            today: isSameDay(day, widget.today),
                            count: objects.length,
                          ),
                        ),
                        _rows(objects, day),
                      ],
                    ),
                  if (undated.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Material(
                        type: MaterialType.transparency,
                        child: InkWell(
                          onTap: () =>
                              setState(() => _undatedOpen = !_undatedOpen),
                          child: ListSectionHeader(
                            label: context.l10n.viewWidgetsNoDate,
                            count: undated.length,
                            trailing: Icon(
                              _undatedOpen
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              size: 20,
                              semanticLabel: _undatedOpen
                                  ? context.l10n.viewWidgetsCollapse
                                  : context.l10n.viewWidgetsExpand,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (_undatedOpen) _rows(undated, null),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _rows(List<MorkvaObject> objects, DateTime? day) => SliverList.builder(
    itemCount: objects.length,
    itemBuilder: (_, i) => ListRowFrame(
      divider: i < objects.length - 1,
      child: _AgendaRow(
        object: objects[i],
        day: day,
        today: widget.today,
        data: widget.data,
      ),
    ),
  );
}

class _StripDay extends StatelessWidget {
  const _StripDay({
    required this.day,
    required this.today,
    required this.selected,
    required this.hasItems,
    required this.onTap,
  });

  final DateTime day;
  final DateTime today;
  final DateTime selected;
  final bool hasItems;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isToday = isSameDay(day, today);
    final isSelected = isSameDay(day, selected);
    final color = isSelected
        ? scheme.onPrimaryContainer
        : isToday
        ? primaryTextColor(context)
        : scheme.onSurface;
    return Semantics(
      button: true,
      selected: isSelected,
      label: dayLabel(day),
      excludeSemantics: true,
      child: InkWell(
        onTap: () => onTap(day),
        borderRadius: Radii.mdAll,
        child: Center(
          child: Container(
            width: 44,
            height: 52,
            decoration: BoxDecoration(
              color: isSelected ? scheme.primaryContainer : null,
              borderRadius: Radii.mdAll,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  localDateFormat('EEEEE').format(day),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: isSelected ? color : scheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  '${day.day}',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: color,
                    fontWeight: isToday || isSelected ? FontWeight.w700 : null,
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: hasItems ? scheme.primary : null,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DayHeader extends SliverPersistentHeaderDelegate {
  const _DayHeader({
    required this.label,
    required this.today,
    required this.count,
  });

  final String label;
  final bool today;
  final int count;

  @override
  double get minExtent => CalendarAgenda.dayHeaderHeight;

  @override
  double get maxExtent => CalendarAgenda.dayHeaderHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) =>
      ListSectionHeader(
        label: today ? context.l10n.viewWidgetsDayToday(label) : label,
        count: count,
        color: today ? primaryTextColor(context) : null,
      );

  @override
  bool shouldRebuild(_DayHeader old) =>
      old.label != label || old.today != today || old.count != count;
}

class _AgendaRow extends StatelessWidget {
  const _AgendaRow({
    required this.object,
    required this.day,
    required this.today,
    required this.data,
  });

  final MorkvaObject object;
  final DateTime today;

  /// The object's day, or null when undated.
  final DateTime? day;
  final ViewModeData data;

  @override
  Widget build(BuildContext context) {
    final state = data.state;
    return Semantics(
      onLongPressHint: context.l10n.viewWidgetsMoveToDate,
      child: GestureDetector(
        onLongPress: () => _moveToDate(context),
        child: ObjectCard(
          object: object,
          collection: state.collection,
          view: state.activeView,
          density: ObjectCardDensity.list,
          referenceLabels: state.referenceLabels,
          onTap: () => data.openObject(object),
        ),
      ),
    );
  }

  static final _first = DateTime(1900);
  static final _last = DateTime(2200);

  static DateTime _clamp(DateTime d) =>
      d.isBefore(_first) ? _first : (d.isAfter(_last) ? _last : d);

  Future<void> _moveToDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      helpText: context.l10n.viewWidgetsMoveToDate,
      initialDate: _clamp(day ?? today),
      firstDate: _first,
      lastDate: _last,
      builder: (_, child) => MondayFirst(child: child!),
    );
    if (picked == null || !context.mounted) return;
    moveObjectToDay(context, data, object.id, dayOf(picked));
  }
}
