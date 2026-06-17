import 'package:flutter/material.dart';

import '../../../core/domain/domain.dart';
import '../../../design/design.dart';
import '../field_editors/field_editor.dart';
import '../field_editors/widgets/preview_affordances.dart';

/// A compact, read-only preview of an empty card for the current draft schema.
///
/// This is the editor's "what am I building" mirror: each field renders as a
/// label plus a type-appropriate, inert affordance placeholder (a stubbed
/// input, a switch shape, a chip row), so the author sees the *shape* of a card
/// without entering any data — data entry is Epic 5. Nothing here is
/// interactive; every control is a static silhouette.
///
/// Secondary by design: it lives in a quiet collapsible card so it informs
/// without competing with the field editor.
class CardPreview extends StatelessWidget {
  const CardPreview({
    super.key,
    required this.collection,
    required this.registry,
  });

  final Collection collection;
  final FieldEditorRegistry registry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fields = collection.fields;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: Radii.lgAll,
        border: Border.all(color: scheme.outlineVariant),
      ),
      padding: const EdgeInsets.all(Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.preview_outlined,
                size: 16,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: Spacing.xs),
              Text(
                'Card preview',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.md),
          Text(
            collection.name.trim().isEmpty
                ? 'Untitled collection'
                : collection.name,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: Spacing.md),
          if (fields.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
              child: Text(
                'Add fields to see the card take shape.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            )
          else
            for (final field in fields) ...[
              _PreviewField(field: field, registry: registry),
              if (field != fields.last) const SizedBox(height: Spacing.md),
            ],
        ],
      ),
    );
  }
}

/// One field in the preview: its label (with a required marker) over a
/// type-appropriate inert affordance.
class _PreviewField extends StatelessWidget {
  const _PreviewField({required this.field, required this.registry});

  final FieldDefinition field;
  final FieldEditorRegistry registry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final editor = registry.forType(field.type);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              editor?.icon ?? Icons.help_outline,
              size: 14,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(width: Spacing.xxs),
            Flexible(
              child: Text(
                field.name.trim().isEmpty ? 'Untitled field' : field.name,
                style: theme.textTheme.labelMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (field.isRequired)
              Text(
                ' *',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.error,
                ),
              ),
          ],
        ),
        const SizedBox(height: Spacing.xs),
        // Dispatch the inert affordance through the registry seam — no widget
        // names a concrete field type. A generic input silhouette stands in for
        // any type without a registered editor (e.g. a future JS-module type).
        editor?.buildPreviewAffordance(context, field) ??
            const PreviewStubInput(height: 36),
      ],
    );
  }
}
