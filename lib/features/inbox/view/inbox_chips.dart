import 'package:flutter/material.dart';

import '../../../design/design.dart';
import '../../../l10n/l10n.dart';

/// A 32 px value chip in a 44 px hit box: an optional [icon], a [label]
/// (none = icon-only), an optional 44 px × ([onClear]). [selected] fills it
/// primaryContainer with a check (date presets).
class InboxChip extends StatelessWidget {
  const InboxChip({
    super.key,
    this.icon,
    this.label,
    this.tooltip,
    this.onPressed,
    this.onClear,
    this.clearTooltip,
    this.selected = false,
    this.outlined = false,
  });

  final IconData? icon;
  final String? label;
  final String? tooltip;
  final VoidCallback? onPressed;
  final VoidCallback? onClear;
  final String? clearTooltip;
  final bool selected;

  /// An empty icon-only chip: a 1 px outline instead of a fill.
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final enabled = onPressed != null;
    final fg = selected
        ? scheme.onPrimaryContainer
        : enabled || onClear != null
        ? scheme.onSurface
        : scheme.onSurface.withValues(alpha: 0.38);
    final label = this.label;
    final leading = selected ? MorkvaIcons.check : icon;
    final pill = BoxDecoration(
      color: selected
          ? scheme.primaryContainer
          : outlined
          ? Colors.transparent
          : scheme.surfaceContainer,
      borderRadius: Radii.smAll,
      border: outlined
          ? Border.all(color: scheme.outline.withValues(alpha: 0.6))
          : null,
    );
    final content = Container(
      // 44 tall (the ×'s hit box) over a 32 px pill.
      height: 44,
      constraints: const BoxConstraints(minWidth: 32),
      padding: EdgeInsets.only(
        left: label == null ? 0 : Spacing.xs + 2,
        right: label == null
            ? 0
            : onClear == null
            ? Spacing.sm
            : 0,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (leading != null)
            Icon(leading, size: label == null ? 18 : 16, color: fg),
          if (label != null) ...[
            if (leading != null) const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
            ),
          ],
          if (onClear case final clear?)
            SizedBox.square(
              dimension: 44,
              child: IconButton(
                padding: EdgeInsets.zero,
                iconSize: 16,
                tooltip: clearTooltip ?? context.l10n.commonClear,
                color: scheme.onSurfaceVariant,
                onPressed: clear,
                icon: const Icon(MorkvaIcons.close),
              ),
            ),
        ],
      ),
    );
    Widget chip = Stack(
      children: [
        Positioned.fill(
          top: 6,
          bottom: 6,
          child: DecoratedBox(decoration: pill),
        ),
        content,
      ],
    );
    chip = InkWell(
      onTap: onPressed,
      borderRadius: Radii.smAll,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
        child: Center(widthFactor: 1, child: chip),
      ),
    );
    final tip = tooltip;
    if (tip != null) chip = Tooltip(message: tip, child: chip);
    return Semantics(
      button: true,
      enabled: enabled,
      selected: selected,
      child: chip,
    );
  }
}

/// A floating snackbar that times out even with an action (`persist:
/// false`: one with an action never times out on web otherwise).
void showInboxSnack(
  ScaffoldMessengerState? messenger,
  String text, {
  VoidCallback? onUndo,
}) {
  if (messenger == null) return;
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(text),
      behavior: SnackBarBehavior.floating,
      persist: false,
      duration: const Duration(seconds: 5),
      action: onUndo == null
          ? null
          : SnackBarAction(
              label: messenger.context.l10n.commonUndo,
              onPressed: onUndo,
            ),
    ),
  );
}
