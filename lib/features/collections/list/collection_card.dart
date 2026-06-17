import 'package:flutter/material.dart';

import '../../../core/domain/domain.dart';
import '../../../design/design.dart';

/// What an overflow-menu selection on a [CollectionCard] resolves to.
enum CollectionCardAction { rename, delete }

/// One collection tile on the Home surface.
///
/// Reads like a tidy index card: the collection name as the anchor, an optional
/// description line, and a quiet footer that counts the fields in its schema.
/// The whole card is pressable (opens the editor); a borderless overflow button
/// holds the rename / delete actions so destructive actions never sit under the
/// thumb by accident.
///
/// Purely presentational — it reports taps and menu picks through callbacks and
/// owns no state. Built on the shared [SurfaceCard] so it inherits the house
/// hover-lift and press-scale.
class CollectionCard extends StatelessWidget {
  const CollectionCard({
    super.key,
    required this.collection,
    required this.onOpen,
    required this.onAction,
  });

  final Collection collection;

  /// Invoked when the card body is tapped (navigate to the editor).
  final VoidCallback onOpen;

  /// Invoked with the chosen overflow-menu action.
  final ValueChanged<CollectionCardAction> onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fieldCount = collection.fields.length;

    return SurfaceCard(
      onTap: onOpen,
      semanticLabel: 'Open ${collection.name}',
      padding: const EdgeInsets.all(Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CollectionGlyph(iconKey: collection.icon),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: Padding(
                  // Optically center the title against the glyph.
                  padding: const EdgeInsets.only(top: Spacing.xxs),
                  child: Text(
                    collection.name,
                    style: theme.textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              _OverflowMenu(onAction: onAction),
            ],
          ),
          if (collection.description != null &&
              collection.description!.trim().isNotEmpty) ...[
            const SizedBox(height: Spacing.xs),
            Text(
              collection.description!,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: Spacing.sm),
          Row(
            children: [
              Icon(
                Icons.view_column_outlined,
                size: 16,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: Spacing.xxs),
              Text(
                fieldCount == 0
                    ? 'No fields yet'
                    : '$fieldCount ${fieldCount == 1 ? 'field' : 'fields'}',
                style: theme.textTheme.labelMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


/// The borderless rename / delete menu. Kept compact so it doesn't compete with
/// the card title; delete is tinted with the error role as a quiet warning.
class _OverflowMenu extends StatelessWidget {
  const _OverflowMenu({required this.onAction});

  final ValueChanged<CollectionCardAction> onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopupMenuButton<CollectionCardAction>(
      tooltip: 'More actions',
      icon: Icon(Icons.more_vert, size: 20, color: scheme.onSurfaceVariant),
      padding: EdgeInsets.zero,
      splashRadius: 20,
      onSelected: onAction,
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: CollectionCardAction.rename,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.edit_outlined),
            title: Text('Rename'),
          ),
        ),
        PopupMenuItem(
          value: CollectionCardAction.delete,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.delete_outline, color: scheme.error),
            title: Text('Delete', style: TextStyle(color: scheme.error)),
          ),
        ),
      ],
    );
  }
}
