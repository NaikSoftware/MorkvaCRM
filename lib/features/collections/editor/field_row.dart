import 'package:flutter/material.dart';

import '../../../core/domain/domain.dart';
import '../../../design/design.dart';
import '../field_editors/field_editor.dart';

/// One field in the schema editor's reorderable list.
///
/// Reads like a scannable record: a tinted type glyph, the field name, a quiet
/// type badge, and the [FieldEditor.summarize] line beneath. Trailing controls
/// hold the required indicator, a type-lock hint (for persisted fields whose
/// type can no longer change), a remove affordance, and the drag handle.
///
/// Purely presentational: every interaction is reported through a callback. The
/// whole row is selectable (tap) so picking a field opens its config; the row
/// reflects [selected] with a carrot-tinted surface and outline.
class FieldRow extends StatelessWidget {
  const FieldRow({
    super.key,
    required this.field,
    required this.editor,
    required this.index,
    required this.selected,
    required this.typeLocked,
    required this.onTap,
    required this.onRemove,
    this.collections = const [],
  });

  final FieldDefinition field;

  /// The registry editor for this field's type (icon, label, summary).
  final FieldEditor? editor;

  /// The workspace collections, so reference summaries resolve a target name
  /// rather than printing a raw id.
  final List<Collection> collections;

  /// Position in the list — drives the [ReorderableDragStartListener].
  final int index;

  /// Whether this row's config panel is currently open.
  final bool selected;

  /// Whether the field's type is locked (it has been persisted).
  final bool typeLocked;

  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final summary = editor?.summarize(field, collections: collections) ?? '';
    final typeLabel = editor?.displayLabel ?? field.type;

    final borderColor = selected ? scheme.primary : scheme.outlineVariant;
    final background = selected
        ? scheme.primaryContainer.withValues(alpha: 0.35)
        : scheme.surfaceContainerLowest;

    return Padding(
      // Spacing between reorderable rows (ReorderableListView ignores
      // separators, so the gap lives on the row itself).
      padding: const EdgeInsets.only(bottom: Spacing.xs),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: Radii.mdAll,
          child: AnimatedContainer(
            duration: MotionDurations.fast,
            curve: MotionCurves.standard,
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.sm,
              vertical: Spacing.sm,
            ),
            decoration: BoxDecoration(
              color: background,
              borderRadius: Radii.mdAll,
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                _TypeGlyph(icon: editor?.icon ?? Icons.help_outline),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              field.name.trim().isEmpty
                                  ? 'Untitled field'
                                  : field.name,
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: field.name.trim().isEmpty
                                    ? scheme.onSurfaceVariant
                                    : scheme.onSurface,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (field.isRequired) ...[
                            const SizedBox(width: Spacing.xxs),
                            Text(
                              '*',
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: scheme.error,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: Spacing.xxs),
                      Row(
                        children: [
                          _TypeBadge(label: typeLabel, locked: typeLocked),
                          if (summary.isNotEmpty) ...[
                            const SizedBox(width: Spacing.xs),
                            Flexible(
                              child: Text(
                                summary,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Spacing.xxs),
                IconActionButton(
                  icon: Icons.close,
                  tooltip: 'Remove field',
                  onPressed: onRemove,
                ),
                ReorderableDragStartListener(
                  index: index,
                  child: const IconActionButton(
                    icon: Icons.drag_indicator,
                    tooltip: 'Drag to reorder',
                    // Reordering is driven by the wrapping listener, not a tap.
                    onPressed: _noop,
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

/// A no-op tap for the drag-handle button — the wrapping
/// [ReorderableDragStartListener] handles the actual interaction; the button is
/// here only for the 44dp hit target and tooltip.
void _noop() {}

/// The tinted square that fronts each row with its type icon. Carrot-tinted to
/// match the type cards in the add-field sheet (every glyph in the feature
/// reads in brand color, never a flat grey).
class _TypeGlyph extends StatelessWidget {
  const _TypeGlyph({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.12),
        borderRadius: Radii.smAll,
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 18, color: scheme.primary),
    );
  }
}

/// A quiet pill naming the field's type, with a lock glyph when the type is
/// frozen (the field has been persisted).
class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.label, required this.locked});

  final String label;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.xs, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: Radii.smAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (locked) ...[
            Icon(Icons.lock_outline, size: 12, color: scheme.onSurfaceVariant),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
