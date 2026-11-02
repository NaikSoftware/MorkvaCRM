import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/shell/app_shell.dart';
import '../../../core/domain/domain.dart';
import '../../../design/design.dart';
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
  String get label => 'Calendar';

  @override
  IconData get icon => Icons.calendar_month_outlined;

  @override
  String get description => 'Items on the days of a date field.';

  @override
  bool get needsLayoutField => true;

  @override
  bool acceptsLayoutField(FieldDefinition field) =>
      field is DateFieldDefinition;

  @override
  String get layoutFieldLabel => 'Date field';

  @override
  String get addFieldLabel => 'Add date field';

  @override
  String? unavailableReason(Collection collection) =>
      collection.fields.any(acceptsLayoutField) ? null : 'Needs a date field';

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
            ? 'Date: ${current.name}'
            : 'Date',
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
          title: 'Calendar needs a date field',
          message: 'Add a date field to place each ${data.itemLabel} on a day.',
          action: PrimaryButton(
            label: 'Add date field',
            icon: Icons.add,
            onPressed: () => context.go('/collections/${collection.id}/edit'),
          ),
        );
      }
      return EmptyState(
        icon: Icons.calendar_month_outlined,
        title: 'Choose a date field',
        message: 'Pick the date that places each ${data.itemLabel} on a day.',
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
