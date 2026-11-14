import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/shell/app_shell.dart';
import '../../../core/domain/domain.dart';
import '../../../design/design.dart';
import '../../../l10n/l10n.dart';
import '../collection_views_cubit.dart';
import '../widgets/calendar/calendar_agenda.dart';
import '../widgets/calendar/calendar_common.dart';
import '../widgets/calendar/month_calendar.dart';
import '../widgets/view_toolbar.dart';
import 'view_mode.dart';

/// Objects on the days of a date field: a month grid on wide screens, an
/// agenda on phones. Empty dates sit in a "No date" tray.
class CalendarMode extends ViewMode {
  const CalendarMode({this.clock});

  /// Where "today" comes from; [DateTime.now] when null.
  final DateTime Function()? clock;

  @override
  String get id => ViewModeIds.calendar;

  @override
  String get label => l10n.viewsModeCalendar;

  @override
  IconData get icon => Icons.calendar_month_outlined;

  @override
  String get description => l10n.viewsModeCalendarDescription;

  @override
  bool get needsLayoutField => true;

  @override
  bool acceptsLayoutField(FieldDefinition field) =>
      field is DateFieldDefinition;

  @override
  String get layoutFieldLabel => l10n.viewsDateField;

  @override
  String get addFieldLabel => l10n.viewsAddDateField;

  @override
  String? unavailableReason(Collection collection) =>
      collection.fields.any(acceptsLayoutField)
      ? null
      : l10n.viewsNeedsDateField;

  @override
  Widget buildBody(BuildContext context, ViewModeData data) =>
      CalendarBody(data: data, clock: clock ?? DateTime.now);

  @override
  Widget? buildSettingsChip(BuildContext context, ViewModeData data) {
    final fields = data.state.collection.fields
        .whereType<DateFieldDefinition>()
        .toList();
    if (fields.isEmpty) return null;
    final current = data.state.layoutField;
    return MenuAnchor(
      menuChildren: [
        for (final f in fields)
          MenuItemButton(
            leadingIcon: Icon(
              f.id == current?.id ? Icons.check : Icons.event_outlined,
              size: 18,
            ),
            onPressed: () =>
                context.read<CollectionViewsCubit>().setLayoutField(f.id),
            child: Text(f.name),
          ),
      ],
      builder: (context, controller, _) => ToolbarButton(
        icon: Icons.event_outlined,
        label: current is DateFieldDefinition
            ? context.l10n.viewsDateChip(current.name)
            : context.l10n.viewsDateChipEmpty,
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}

/// The Calendar mode body: month grid ≥ 840 dp, agenda below.
class CalendarBody extends StatelessWidget {
  const CalendarBody({super.key, required this.data, required this.clock});

  final ViewModeData data;
  final DateTime Function() clock;

  @override
  Widget build(BuildContext context) {
    final state = data.state;
    final collection = state.collection;
    if (state.days == null) {
      final dateFields = collection.fields
          .whereType<DateFieldDefinition>()
          .toList();
      if (dateFields.isEmpty) {
        return EmptyState(
          icon: Icons.calendar_month_outlined,
          title: context.l10n.viewsCalendarNeedsDate,
          message: context.l10n.viewsCalendarNeedsDateMessage(data.itemLabel),
          action: PrimaryButton(
            label: context.l10n.viewsAddDateField,
            icon: Icons.add,
            onPressed: () => context.go('/collections/${collection.id}/edit'),
          ),
        );
      }
      return EmptyState(
        icon: Icons.calendar_month_outlined,
        title: context.l10n.viewsCalendarChooseDate,
        message: context.l10n.viewsCalendarChooseDateMessage(
          data.itemLabel,
        ),
        action: Wrap(
          spacing: Spacing.xs,
          runSpacing: Spacing.xs,
          alignment: WrapAlignment.center,
          children: [
            for (final f in dateFields)
              SecondaryButton(
                label: f.name,
                icon: Icons.event_outlined,
                onPressed: () =>
                    context.read<CollectionViewsCubit>().setLayoutField(f.id),
              ),
          ],
        ),
      );
    }
    final today = dayOf(clock());
    final compact =
        MediaQuery.sizeOf(context).width < AppShell.expandedBreakpoint;
    return compact
        ? CalendarAgenda(data: data, today: today)
        : MonthCalendar(data: data, today: today);
  }
}
