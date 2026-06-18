import 'package:flutter/material.dart';

import '../../../design/design.dart';
import '../field_editors/field_editor.dart';

/// A modal sheet that picks a field type to add.
///
/// Presents every registered [FieldEditor] as a tappable card — icon, label, a
/// one-line description, and a "computed in a later update" tag for the declared
/// computed types. Picking a card returns its `typeId` to the caller, which
/// appends a default field of that type through the editor cubit.
///
/// Responsive: a multi-column grid on wide sheets, a single column on narrow
/// (phone) sheets. Returns the chosen `typeId`, or null on dismiss.
class AddFieldSheet extends StatelessWidget {
  const AddFieldSheet({super.key, required this.editors});

  /// Every registered editor, in type-picker order.
  final List<FieldEditor> editors;

  /// Shows the sheet and resolves to the chosen type id (or null on dismiss).
  static Future<String?> show(
    BuildContext context, {
    required List<FieldEditor> editors,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.lg)),
      ),
      builder: (_) => AddFieldSheet(editors: editors),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    // Cap the sheet height so it never swallows the whole screen, but let it
    // grow on tall windows.
    final maxHeight = media.size.height * 0.7;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.lg,
              0,
              Spacing.lg,
              Spacing.xs,
            ),
            child: Text('Add a field', style: theme.textTheme.titleLarge),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.lg,
              0,
              Spacing.lg,
              Spacing.md,
            ),
            child: Text(
              'Pick a type — you can configure and rename it next.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Flexible(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 560 ? 2 : 1;
                return GridView.builder(
                  padding: EdgeInsets.fromLTRB(
                    Spacing.lg,
                    0,
                    Spacing.lg,
                    Spacing.lg + media.padding.bottom,
                  ),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: Spacing.sm,
                    crossAxisSpacing: Spacing.sm,
                    mainAxisExtent: 84,
                  ),
                  itemCount: editors.length,
                  itemBuilder: (context, index) {
                    final editor = editors[index];
                    return _TypeCard(
                      editor: editor,
                      onTap: () =>
                          Navigator.of(context).pop<String>(editor.typeId),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// A small "Declare only" tag for computed types: the type can be configured
/// now, but evaluation lands in a later update. Mirrors the field-row type
/// badge (surfaceContainerHighest + labelSmall) so the two read as siblings.
class _DeclareOnlyPill extends StatelessWidget {
  const _DeclareOnlyPill();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.xs, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: Radii.smAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule, size: 11, color: scheme.onSurfaceVariant),
          const SizedBox(width: 3),
          Text(
            'Declare only',
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// One selectable type in the picker grid.
class _TypeCard extends StatelessWidget {
  const _TypeCard({required this.editor, required this.onTap});

  final FieldEditor editor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return PressableScale(
      onPressed: onTap,
      semanticLabel: 'Add ${editor.displayLabel} field',
      borderRadius: Radii.mdAll,
      child: Container(
        padding: const EdgeInsets.all(Spacing.sm),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: Radii.mdAll,
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.12),
                borderRadius: Radii.smAll,
              ),
              alignment: Alignment.center,
              child: Icon(editor.icon, size: 20, color: scheme.primary),
            ),
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
                          editor.displayLabel,
                          style: theme.textTheme.titleSmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (editor.isComputed) ...[
                        const SizedBox(width: Spacing.xs),
                        const _DeclareOnlyPill(),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  // Keep the real type description; the pill above already
                  // signals it is declare-only for now.
                  Text(
                    editor.description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
