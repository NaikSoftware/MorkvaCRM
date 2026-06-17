import 'package:flutter/material.dart';

import '../collection_icons.dart';
import '../tokens/radii.dart';
import '../tokens/spacing.dart';
import 'pressable_scale.dart';

/// The outcome of [CollectionIconPicker]: the chosen [key] (null means "no
/// icon" — clear back to the default glyph). The picker future resolves to null
/// when dismissed without a choice, so callers can tell "cleared" from
/// "cancelled".
typedef CollectionIconSelection = ({String? key});

/// A modal grid for choosing a collection's icon. Finger-friendly on mobile and
/// fine on web; highlights the [current] selection and offers a "None" tile to
/// clear back to the default glyph.
class CollectionIconPicker extends StatelessWidget {
  const CollectionIconPicker({super.key, required this.current});

  /// The currently selected icon key (highlighted), or null.
  final String? current;

  /// Presents the picker as a modal bottom sheet. Resolves to the selection, or
  /// null if dismissed without choosing.
  static Future<CollectionIconSelection?> show(
    BuildContext context, {
    required String? current,
  }) {
    return showModalBottomSheet<CollectionIconSelection>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.lg)),
      ),
      builder: (_) => CollectionIconPicker(current: current),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          Spacing.lg,
          0,
          Spacing.lg,
          Spacing.lg + bottomInset,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Choose an icon', style: theme.textTheme.titleMedium),
            const SizedBox(height: Spacing.md),
            Flexible(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: Spacing.sm,
                  runSpacing: Spacing.sm,
                  children: [
                    _PickerTile(
                      icon: CollectionIcons.fallback,
                      label: 'None',
                      selected: current == null,
                      muted: true,
                      onTap: () =>
                          Navigator.of(context).pop((key: null)),
                    ),
                    for (final option in CollectionIcons.all)
                      _PickerTile(
                        icon: option.icon,
                        label: option.label,
                        selected: option.key == current,
                        onTap: () => Navigator.of(
                          context,
                        ).pop((key: option.key)),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One selectable icon in the picker grid: a tinted tile that warms to a carrot
/// outline + fill when [selected].
class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.muted = false,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// The "None" tile reads in a quieter neutral tint so it doesn't masquerade
  /// as a real icon choice.
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = muted ? scheme.onSurfaceVariant : scheme.primary;

    return PressableScale(
      onPressed: onTap,
      semanticLabel: label,
      borderRadius: Radii.mdAll,
      child: Tooltip(
        message: label,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: selected
                ? scheme.primary.withValues(alpha: 0.18)
                : accent.withValues(alpha: 0.10),
            borderRadius: Radii.mdAll,
            border: Border.all(
              color: selected ? scheme.primary : Colors.transparent,
              width: 2,
            ),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 26, color: accent),
        ),
      ),
    );
  }
}
