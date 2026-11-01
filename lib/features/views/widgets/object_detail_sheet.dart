import 'package:flutter/material.dart';

import '../../../core/domain/domain.dart';
import '../../../design/design.dart';
import 'option_pill.dart';
import 'view_labels.dart';

/// Read-only view of one object: every field, formatted. Resolves to true
/// when the user asked to delete it.
class ObjectDetailSheet extends StatelessWidget {
  const ObjectDetailSheet({
    super.key,
    required this.object,
    required this.collection,
    required this.title,
    this.referenceLabels = const {},
  });

  final MorkvaObject object;
  final Collection collection;
  final String title;
  final Map<String, String> referenceLabels;

  static Future<bool?> show(
    BuildContext context, {
    required MorkvaObject object,
    required Collection collection,
    required String title,
    Map<String, String> referenceLabels = const {},
  }) => showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => ObjectDetailSheet(
      object: object,
      collection: collection,
      title: title,
      referenceLabels: referenceLabels,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.lg,
              0,
              Spacing.lg,
              Spacing.md,
            ),
            child: Row(
              children: [
                CollectionGlyph(
                  iconKey: collection.icon,
                  size: 36,
                  iconSize: 20,
                ),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.headlineSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: scheme.outlineVariant),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.lg,
                vertical: Spacing.sm,
              ),
              children: [
                for (final field in collection.fields)
                  _FieldRow(
                    field: field,
                    value: object[field.id] ?? field.emptyValue(),
                    referenceLabels: referenceLabels,
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: scheme.outlineVariant),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.md,
              vertical: Spacing.sm,
            ),
            child: Row(
              children: [
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: scheme.error,
                    minimumSize: const Size(44, 44),
                  ),
                  onPressed: () => Navigator.of(context).pop(true),
                  icon: const Icon(Icons.delete_outline, size: 20),
                  label: const Text('Delete'),
                ),
                const Spacer(),
                TextActionButton(
                  label: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({
    required this.field,
    required this.value,
    required this.referenceLabels,
  });

  final FieldDefinition field;
  final FieldValue value;
  final Map<String, String> referenceLabels;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = formatFieldValue(
      field,
      value,
      referenceLabels: referenceLabels,
    );
    final Widget display = switch ((field, value)) {
      _ when value.isEmpty => Text(
        'Empty',
        style: theme.textTheme.bodyLarge?.copyWith(color: scheme.outline),
      ),
      (
        SingleSelectFieldDefinition(),
        SingleSelectFieldValue(:final optionId),
      ) =>
        Align(
          alignment: Alignment.centerLeft,
          child: OptionPill(label: text, color: optionColor(field, optionId)),
        ),
      (MultiSelectFieldDefinition(), MultiSelectFieldValue(:final optionIds)) =>
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final id in optionIds)
              OptionPill(
                label: formatFieldValue(field, MultiSelectFieldValue([id])),
                color: optionColor(field, id),
              ),
          ],
        ),
      _ => SelectableText(text, style: theme.textTheme.bodyLarge),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                fieldTypeIcon(field),
                size: 16,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: Spacing.xs - 2),
              Text(
                field.name,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.xxs),
          display,
        ],
      ),
    );
  }
}
