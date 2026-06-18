import 'package:flutter/material.dart';

import '../collection_icons.dart';
import '../tokens/radii.dart';
import 'pressable_scale.dart';

/// The carrot-tinted tile that fronts a collection everywhere it appears — the
/// Home list card and the schema-editor header — so a collection reads with one
/// consistent mark. Resolves [iconKey] through [CollectionIcons] (falling back
/// to the default glyph when null/unknown).
///
/// When [onTap] is supplied the tile becomes a button with the shared press
/// feel and a small edit badge, signalling that the icon can be changed (used in
/// the editor header). Without it the tile is purely decorative.
class CollectionGlyph extends StatelessWidget {
  const CollectionGlyph({
    super.key,
    required this.iconKey,
    this.size = 40,
    this.iconSize = 22,
    this.onTap,
    this.tooltip,
  });

  /// The collection's persisted icon key (`Collection.icon`), or null.
  final String? iconKey;

  /// Edge length of the square tile.
  final double size;

  /// Size of the centered glyph.
  final double iconSize;

  /// When non-null, the tile is tappable (opens the icon picker) and shows an
  /// edit badge.
  final VoidCallback? onTap;

  /// Accessibility / hover label when [onTap] is set.
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final tile = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.12),
        borderRadius: Radii.mdAll,
      ),
      alignment: Alignment.center,
      child: Icon(
        CollectionIcons.byKey(iconKey),
        size: iconSize,
        color: scheme.primary,
      ),
    );

    if (onTap == null) return tile;

    return PressableScale(
      onPressed: onTap,
      semanticLabel: tooltip ?? 'Change icon',
      borderRadius: Radii.mdAll,
      child: Tooltip(
        message: tooltip ?? 'Change icon',
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            tile,
            Positioned(
              right: -3,
              bottom: -3,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  // A contrast ring + raised fill keep the badge legible on
                  // both the editor header (surface) and the dialog's lowest
                  // surface, where a plain `surface` fill vanished.
                  color: scheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Icon(
                  Icons.edit_outlined,
                  size: 12,
                  color: scheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
