import 'package:flutter/material.dart';

import '../../../core/domain/domain.dart';
import '../../../design/design.dart';
import '../../../l10n/l10n.dart';
import 'field_editor.dart';
import 'widgets/config_controls.dart';
import 'widgets/preview_affordances.dart';

/// [FieldEditor] for the date / date-time field type.
class DateFieldEditor extends FieldEditor {
  const DateFieldEditor();

  @override
  String get typeId => kDateFieldType;

  @override
  String label(AppLocalizations l10n) => l10n.collectionsTypeDate;

  @override
  String description(AppLocalizations l10n) =>
      l10n.collectionsTypeDateDescription;

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

    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConfigSwitch(
          label: l10n.collectionsIncludeTime,
          subtitle: l10n.collectionsIncludeTimeHint,
          value: field.includeTime,
          onChanged: (value) => onChanged(update(includeTime: value)),
        ),
        _DateBoundRow(
          label: l10n.collectionsEarliest,
          value: field.min,
          onChanged: (date) => onChanged(update(min: () => date)),
        ),
        _DateBoundRow(
          label: l10n.collectionsLatest,
          value: field.max,
          onChanged: (date) => onChanged(update(max: () => date)),
        ),
      ],
    );
  }

  @override
  String summarize(
    AppLocalizations l10n,
    FieldDefinition definition, {
    List<Collection> collections = const [],
  }) {
    final field = definition as DateFieldDefinition;
    return field.includeTime
        ? l10n.collectionsSummaryDateTime
        : l10n.collectionsSummaryDate;
  }

  @override
  Widget buildPreviewAffordance(
    BuildContext context,
    FieldDefinition definition,
  ) => const PreviewStubInput(icon: Icons.calendar_today_outlined, height: 36);
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
    final text = value == null
        ? context.l10n.collectionsAnyDate
        : '${value!.year.toString().padLeft(4, '0')}-'
              '${value!.month.toString().padLeft(2, '0')}-'
              '${value!.day.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.xxs),
      child: Row(
        children: [
          SizedBox(width: 88, child: Text(label)),
          SecondaryButton(
            label: text,
            icon: Icons.event_outlined,
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: value ?? DateTime.now().toUtc(),
                firstDate: DateTime.utc(1900),
                lastDate: DateTime.utc(2100),
                builder: (_, child) => MondayFirst(child: child!),
              );
              if (picked != null) {
                onChanged(DateTime.utc(picked.year, picked.month, picked.day));
              }
            },
          ),
          if (value != null)
            IconActionButton(
              icon: Icons.clear,
              tooltip: context.l10n.commonClear,
              onPressed: () => onChanged(null),
            ),
        ],
      ),
    );
  }
}
