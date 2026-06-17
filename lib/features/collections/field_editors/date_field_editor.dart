import 'package:flutter/material.dart';

import '../../../core/domain/domain.dart';
import '../../../design/design.dart';
import 'field_editor.dart';
import 'widgets/config_controls.dart';

/// [FieldEditor] for the date / date-time field type.
class DateFieldEditor extends FieldEditor {
  const DateFieldEditor();

  @override
  String get typeId => kDateFieldType;

  @override
  String get displayLabel => 'Date';

  @override
  String get description => 'A calendar date, optionally with a time.';

  @override
  IconData get icon => Icons.event_outlined;

  @override
  FieldDefinition createDefault({required String id, required String name}) =>
      DateFieldDefinition(id: id, name: name);

  @override
  Widget buildConfigEditor(
    BuildContext context,
    FieldDefinition definition,
    ValueChanged<FieldDefinition> onChanged, {
    required List<Collection> collections,
    required String editingCollectionId,
  }) {
    final field = definition as DateFieldDefinition;

    DateFieldDefinition update({
      bool? includeTime,
      DateTime? Function()? min,
      DateTime? Function()? max,
    }) => DateFieldDefinition(
      id: field.id,
      name: field.name,
      description: field.description,
      isRequired: field.isRequired,
      includeTime: includeTime ?? field.includeTime,
      min: min == null ? field.min : min(),
      max: max == null ? field.max : max(),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConfigSwitch(
          label: 'Include time',
          subtitle: 'Capture a time alongside the date.',
          value: field.includeTime,
          onChanged: (value) => onChanged(update(includeTime: value)),
        ),
        _DateBoundRow(
          label: 'Earliest',
          value: field.min,
          onChanged: (date) => onChanged(update(min: () => date)),
        ),
        _DateBoundRow(
          label: 'Latest',
          value: field.max,
          onChanged: (date) => onChanged(update(max: () => date)),
        ),
      ],
    );
  }

  @override
  String summarize(FieldDefinition definition) {
    final field = definition as DateFieldDefinition;
    return field.includeTime ? 'date & time' : 'date';
  }
}

class _DateBoundRow extends StatelessWidget {
  const _DateBoundRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = value == null
        ? 'Any'
        : '${value!.year.toString().padLeft(4, '0')}-'
              '${value!.month.toString().padLeft(2, '0')}-'
              '${value!.day.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.xxs),
      child: Row(
        children: [
          SizedBox(width: 88, child: Text(label)),
          OutlinedButton(
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: value ?? DateTime.now().toUtc(),
                firstDate: DateTime.utc(1900),
                lastDate: DateTime.utc(2100),
              );
              if (picked != null) {
                onChanged(DateTime.utc(picked.year, picked.month, picked.day));
              }
            },
            child: Text(text),
          ),
          if (value != null)
            IconButton(
              tooltip: 'Clear',
              icon: Icon(Icons.clear, size: 18, color: scheme.onSurfaceVariant),
              onPressed: () => onChanged(null),
            ),
        ],
      ),
    );
  }
}
