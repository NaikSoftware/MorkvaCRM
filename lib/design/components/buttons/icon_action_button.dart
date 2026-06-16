import 'package:flutter/material.dart';

import '../../tokens/radii.dart';
import '../pressable_scale.dart';

/// An icon-only, circular action with a guaranteed 44x44 hit target.
///
/// Two emphases: the default is borderless (a quiet icon on the canvas); the
/// [filled] variant sits on a `surfaceContainerHighest` disc for standalone
/// affordances (e.g. an app-bar action). A [tooltip] is required and doubles as
/// the semantic label so the control is always self-describing. Follows the
/// exemplar pattern — shared [PressableScale] press feel, disabled state when
/// [onPressed] is null — and reads all color/radius from the theme and tokens.
class IconActionButton extends StatelessWidget {
  const IconActionButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.filled = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;

  /// Required accessible description. Shown as a [Tooltip] and used as the
  /// semantic label.
  final String tooltip;

  /// When true, paints a `surfaceContainerHighest` disc behind the icon for a
  /// little more emphasis.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onPressed != null;

    final baseFg = filled ? scheme.onSurface : scheme.onSurfaceVariant;
    final fg = enabled ? baseFg : baseFg.withValues(alpha: 0.38);
    final bg = filled
        ? (enabled
            ? scheme.surfaceContainerHighest
            : scheme.surfaceContainerHighest.withValues(alpha: 0.38))
        : null;

    return Tooltip(
      message: tooltip,
      child: PressableScale(
        onPressed: enabled ? onPressed : null,
        semanticLabel: tooltip,
        borderRadius: Radii.fullAll,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Icon(icon, size: 20, color: fg),
        ),
      ),
    );
  }
}
