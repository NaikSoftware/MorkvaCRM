import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../../../../l10n/l10n.dart';
import 'assistant_scope.dart';

/// The composer's context chip ("Looking at: Orders › Unpaid · 23 shown",
/// "Looking at: #1042") with a ✕ that drops it from the next message,
/// led by the focused collection's own icon ([iconKey]).
class FocusChip extends StatelessWidget {
  const FocusChip({
    super.key,
    required this.label,
    required this.onRemove,
    this.iconKey,
  });

  final String label;
  final VoidCallback onRemove;

  /// The collection's `CollectionIcons` key; null shows a generic glyph.
  final String? iconKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = AssistantColors.of(context);
    return Row(
      children: [
        Flexible(
          child: Container(
            height: 26,
            padding: const EdgeInsetsDirectional.fromSTEB(6, 0, 10, 0),
            decoration: BoxDecoration(
              color: colors.neutralChip,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  iconKey == null
                      ? Icons.view_in_ar_outlined
                      : CollectionIcons.byKey(iconKey),
                  size: 14,
                  color: scheme.onSurface,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      letterSpacing: 0,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // A 32 px visual inside a 44 px hit area.
        Tooltip(
          message: context.l10n.assistantRemoveContext,
          child: PressableScale(
            onPressed: onRemove,
            semanticLabel: context.l10n.assistantRemoveContext,
            borderRadius: Radii.mdAll,
            child: SizedBox.square(
              dimension: 44,
              child: Icon(
                Icons.close_rounded,
                size: 14,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
