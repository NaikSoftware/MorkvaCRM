import 'package:flutter/material.dart';

import '../../../core/domain/domain.dart';
import '../../../design/design.dart';
import '../../../l10n/l10n.dart';

/// What an overflow-menu selection on a [CollectionCard] resolves to.
enum CollectionCardAction { customize, rename, delete }

/// One collection on the All collections page.
///
/// Its tinted glyph, a pin toggle (pinned collections show in the sidebar),
/// the overflow menu, the name, an optional description and the field count.
/// The whole card is pressable (opens the collection).
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
    this.pinned = false,
    this.onTogglePin,
  });

  final Collection collection;

  /// Invoked when the card body is tapped (open the collection).
  final VoidCallback onOpen;

  /// Invoked with the chosen overflow-menu action.
  final ValueChanged<CollectionCardAction> onAction;

  /// Whether the collection is pinned to the sidebar.
  final bool pinned;

  /// Pins or unpins; null hides the pin button.
  final VoidCallback? onTogglePin;

  /// The card's fixed height in a grid.
  static const double height = 176;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fieldCount = collection.fields.length;
    final description = collection.description?.trim() ?? '';
    final l10n = context.l10n;

    return SurfaceCard(
      onTap: onOpen,
      semanticLabel: l10n.collectionsOpenCollection(collection.name),
      padding: const EdgeInsets.fromLTRB(
        Spacing.md,
        Spacing.md,
        Spacing.xs,
        Spacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CollectionGlyph(
                iconKey: collection.icon,
                tintSeed: collection.id,
                size: 44,
                iconSize: 22,
              ),
              const Spacer(),
              if (onTogglePin != null)
                IconButton(
                  tooltip: pinned
                      ? l10n.collectionsUnpinFromSidebar
                      : l10n.collectionsPinToSidebar,
                  isSelected: pinned,
                  visualDensity: VisualDensity.compact,
                  onPressed: onTogglePin,
                  style: IconButton.styleFrom(
                    foregroundColor: pinned
                        ? scheme.primary
                        : scheme.onSurfaceVariant,
                    backgroundColor: pinned
                        ? scheme.primary.withValues(alpha: 0.12)
                        : null,
                  ),
                  icon: Icon(
                    pinned ? Icons.push_pin : Icons.push_pin_outlined,
                    size: 18,
                  ),
                ),
              _OverflowMenu(onAction: onAction),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          Padding(
            padding: const EdgeInsets.only(right: Spacing.xs),
            child: Text(
              collection.name,
              // The brand face, as in the mockup.
              style: theme.textTheme.titleLarge?.copyWith(fontSize: 18),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: Spacing.xxs),
            Padding(
              padding: const EdgeInsets.only(right: Spacing.xs),
              child: Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          const Spacer(),
          Text(
            fieldCount == 0
                ? l10n.collectionsNoFieldsYet
                : l10n.commonFieldCount(fieldCount),
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
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
    final l10n = context.l10n;
    return PopupMenuButton<CollectionCardAction>(
      tooltip: l10n.collectionsMoreActions,
      icon: Icon(Icons.more_vert, size: 20, color: scheme.onSurfaceVariant),
      style: IconButton.styleFrom(visualDensity: VisualDensity.compact),
      padding: EdgeInsets.zero,
      splashRadius: 20,
      onSelected: onAction,
      itemBuilder: (context) => [
        PopupMenuItem(
          value: CollectionCardAction.customize,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.tune),
            title: Text(l10n.collectionsCustomize),
          ),
        ),
        PopupMenuItem(
          value: CollectionCardAction.rename,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.edit_outlined),
            title: Text(l10n.commonRename),
          ),
        ),
        PopupMenuItem(
          value: CollectionCardAction.delete,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.delete_outline, color: scheme.error),
            title: Text(
              l10n.commonDelete,
              style: TextStyle(color: scheme.error),
            ),
          ),
        ),
      ],
    );
  }
}
