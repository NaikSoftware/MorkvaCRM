import 'package:flutter/material.dart';

import '../../tokens/elevation.dart';
import '../../tokens/motion.dart';
import '../../tokens/radii.dart';
import '../../tokens/spacing.dart';
import '../pressable_scale.dart';

/// The base surface for content: a `surfaceContainerLowest` panel on radius
/// `lg` with a soft [MorkvaElevation] shadow (never stock Material elevation).
///
/// When [onTap] is set the card becomes pressable — it gains the shared
/// [PressableScale] feel and lifts to [MorkvaElevation.level2] on hover/press.
class SurfaceCard extends StatefulWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Spacing.md),
    this.onTap,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  State<SurfaceCard> createState() => _SurfaceCardState();
}

class _SurfaceCardState extends State<SurfaceCard> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final interactive = widget.onTap != null;
    final lifted = interactive && (_hovered || _pressed);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    final surface = AnimatedContainer(
      duration: reduceMotion ? MotionDurations.none : MotionDurations.fast,
      curve: MotionCurves.standard,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: Radii.lgAll,
        boxShadow: lifted ? MorkvaElevation.level2 : MorkvaElevation.level1,
      ),
      child: widget.child,
    );

    if (!interactive) return surface;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Listener(
        onPointerDown: (_) => setState(() => _pressed = true),
        onPointerUp: (_) => setState(() => _pressed = false),
        onPointerCancel: (_) => setState(() => _pressed = false),
        child: PressableScale(
          onPressed: widget.onTap,
          semanticLabel: widget.semanticLabel,
          borderRadius: Radii.lgAll,
          child: surface,
        ),
      ),
    );
  }
}
