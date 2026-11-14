import 'package:flutter/material.dart';

import '../../../core/domain/domain.dart';
import '../../../design/design.dart';
import '../../../l10n/l10n.dart';
import 'field_value_editor.dart';

/// date: a read-only box that opens the (Monday-first) date picker, then the
/// time picker when `includeTime`; ✕ clears. The picker is bounded by the
/// field's min/max. Date-only values are stored as UTC midnight of the picked
/// calendar day, date-times as the picked local instant in UTC.
class DateValueEditor extends FieldValueEditor {
  const DateValueEditor();

  @override
  String get typeId => kDateFieldType;

  @override
  Widget build(BuildContext context, ValueEditorContext ctx) =>
      _DateBox(ctx: ctx);
}

class _DateBox extends StatelessWidget {
  const _DateBox({required this.ctx});

  final ValueEditorContext ctx;

  DateFieldDefinition get _field => ctx.field as DateFieldDefinition;

  Future<void> _pick(BuildContext context) async {
    final field = _field;
    final current = (ctx.value as DateFieldValue).value;
    final first = field.min == null
        ? DateTime(1900)
        : calendarDayOf(field, field.min!);
    var last = field.max == null
        ? DateTime(2100)
        : calendarDayOf(field, field.max!);
    if (last.isBefore(first)) last = first;
    final now = DateTime.now();
    var initial = current == null
        ? DateTime(now.year, now.month, now.day)
        : calendarDayOf(field, current);
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(last)) initial = last;

    final day = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      builder: (_, child) => MondayFirst(child: child ?? const SizedBox()),
    );
    if (day == null || !context.mounted) return;
    if (!field.includeTime) {
      ctx.onChanged(DateFieldValue(DateTime.utc(day.year, day.month, day.day)));
      return;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current?.toLocal() ?? now),
    );
    if (time == null || !context.mounted) return;
    ctx.onChanged(
      DateFieldValue(
        DateTime(day.year, day.month, day.day, time.hour, time.minute).toUtc(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = formatFieldValue(ctx.field, ctx.value);
    final enabled = ctx.enabled;
    return Semantics(
      button: true,
      label: ctx.field.name,
      child: InkWell(
        borderRadius: Radii.mdAll,
        onTap: enabled ? () => _pick(context) : null,
        child: InputDecorator(
          isEmpty: text.isEmpty,
          decoration: InputDecoration(
            enabled: enabled,
            hintText: _field.includeTime
                ? context.l10n.objectsPickDateTime
                : context.l10n.objectsPickDate,
            error: ctx.error == null ? null : const SizedBox.shrink(),
            prefixIcon: Icon(
              MorkvaIcons.calendarDay,
              size: 18,
              color: scheme.onSurfaceVariant,
            ),
            suffixIcon: text.isEmpty
                ? null
                : IconActionButton(
                    icon: MorkvaIcons.close,
                    tooltip: context.l10n.objectsClearNamed(ctx.field.name),
                    onPressed: enabled
                        ? () => ctx.onChanged(const DateFieldValue(null))
                        : null,
                  ),
          ),
          child: Text(
            text,
            style: theme.textTheme.bodyLarge,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
