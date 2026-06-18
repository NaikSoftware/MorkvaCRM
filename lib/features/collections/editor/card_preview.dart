import 'package:flutter/material.dart';

import '../../../core/domain/domain.dart';
import '../../../design/design.dart';
import '../field_editors/field_editor.dart';
import '../field_editors/widgets/preview_affordances.dart';

/// Width at/below which cells render full-width (one per line).
const double _narrowBreakpoint = 600;

/// A compact, read-only preview of an empty card rendered from [Collection.layout].
///
/// Sections are shown with a header (title + collapse chevron) and their rows.
/// Each row distributes cells using span-based flex (12-column grid). Below
/// [_narrowBreakpoint] every cell expands to full width (stacked layout).
///
/// This is the canvas skeleton that Tasks 8–10 attach drag/resize gestures to —
/// keep it cleanly factored and interaction-free.
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
    final isEmpty = collection.layout.fieldIds.isEmpty;

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
          // ── Header bar ──────────────────────────────────────────────────────
          Row(
            children: [
              Icon(Icons.preview_outlined, size: 16, color: scheme.onSurfaceVariant),
              const SizedBox(width: Spacing.xs),
              Text(
                'Card preview',
                style: theme.textTheme.labelMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: Spacing.md),
          // ── Collection name ──────────────────────────────────────────────────
          Text(
            collection.name.trim().isEmpty ? 'Untitled collection' : collection.name,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: Spacing.md),
          // ── Body ─────────────────────────────────────────────────────────────
          if (isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
              child: Text(
                'Add fields to see the card take shape.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth <= _narrowBreakpoint;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < collection.layout.sections.length; i++)
                      _SectionView(
                        section: collection.layout.sections[i],
                        registry: registry,
                        collection: collection,
                        narrow: narrow,
                        isFirst: i == 0,
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

// ─── Section ────────────────────────────────────────────────────────────────

class _SectionView extends StatelessWidget {
  const _SectionView({
    required this.section,
    required this.registry,
    required this.collection,
    required this.narrow,
    required this.isFirst,
  });

  final LayoutSection section;
  final FieldEditorRegistry registry;
  final Collection collection;
  final bool narrow;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Hairline divider between sections (not above the first) ──────
        if (!isFirst) ...[
          Divider(height: 1, thickness: 1, color: scheme.outlineVariant),
          const SizedBox(height: Spacing.md),
        ],
        // ── Section header ────────────────────────────────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              section.collapsed ? Icons.chevron_right : Icons.expand_more,
              size: 16,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(width: Spacing.xxs),
            Builder(
              builder: (context) {
                final isPlaceholder =
                    !(section.title?.trim().isNotEmpty ?? false);
                return Text(
                  isPlaceholder ? 'Untitled section' : section.title!,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: isPlaceholder
                        ? scheme.onSurfaceVariant
                        : scheme.onSurface,
                    fontStyle: isPlaceholder
                        ? FontStyle.italic
                        : FontStyle.normal,
                  ),
                );
              },
            ),
          ],
        ),
        // ── Rows (hidden when collapsed) ──────────────────────────────────
        if (!section.collapsed) ...[
          const SizedBox(height: Spacing.md),
          for (final row in section.rows)
            Padding(
              padding: const EdgeInsets.only(bottom: Spacing.md),
              child: _RowView(
                row: row,
                registry: registry,
                collection: collection,
                narrow: narrow,
              ),
            ),
        ] else
          const SizedBox(height: Spacing.md),
      ],
    );
  }
}

// ─── Row ─────────────────────────────────────────────────────────────────────

class _RowView extends StatelessWidget {
  const _RowView({
    required this.row,
    required this.registry,
    required this.collection,
    required this.narrow,
  });

  final LayoutRow row;
  final FieldEditorRegistry registry;
  final Collection collection;
  final bool narrow;

  @override
  Widget build(BuildContext context) {
    if (narrow) {
      // Narrow: every cell is its own full-width line.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < row.cells.length; i++) ...[
            if (i > 0) const SizedBox(height: Spacing.xs),
            _LayoutCellTile(
              field: collection.fieldById(row.cells[i].fieldId),
              registry: registry,
            ),
          ],
        ],
      );
    }

    // Wide: cells share the row, sized by span (flex).
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < row.cells.length; i++) ...[
          if (i > 0) const SizedBox(width: Spacing.sm),
          Expanded(
            flex: row.cells[i].span,
            child: _LayoutCellTile(
              field: collection.fieldById(row.cells[i].fieldId),
              registry: registry,
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Cell tile ───────────────────────────────────────────────────────────────

/// One field's label + inert affordance. Shared by the canvas tasks (8–10).
///
/// Intentionally free of interaction logic so later tasks can wrap or extend it
/// cleanly with gesture detectors and resize handles.
class _LayoutCellTile extends StatelessWidget {
  const _LayoutCellTile({required this.field, required this.registry});

  final FieldDefinition? field;
  final FieldEditorRegistry registry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final f = field;
    if (f == null) return const SizedBox.shrink();

    final editor = registry.forType(f.type);

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: Radii.smAll,
        border: Border.all(color: scheme.outlineVariant),
      ),
      padding: const EdgeInsets.all(Spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Label row ──────────────────────────────────────────────────────
          Row(
            children: [
              Icon(
                editor?.icon ?? Icons.help_outline,
                size: 13,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: Spacing.xxs),
              Flexible(
                child: Text.rich(
                  TextSpan(
                    text: f.name.trim().isEmpty ? 'Untitled field' : f.name,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    children: f.isRequired
                        ? [
                            TextSpan(
                              text: ' *',
                              style: theme.textTheme.labelMedium
                                  ?.copyWith(color: scheme.error),
                            ),
                          ]
                        : null,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.xs),
          // ── Inert affordance ───────────────────────────────────────────────
          editor?.buildPreviewAffordance(context, f) ??
              const PreviewStubInput(height: 36),
        ],
      ),
    );
  }
}
