import 'package:flutter/material.dart';

import '../tokens/motion.dart';

/// The signature micro-interaction: scales its child to [kPressedScale] on
/// press and springs back on release. Handles pointer, keyboard (Enter/Space),
/// hover cursor, focus, and reduced-motion. Use this to build any custom
/// pressable surface so the whole app shares one press feel.
///
/// This is the component pattern teammates should follow: read tokens, honor
/// reduced motion, expose semantics, disable when [onPressed] is null.
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    required this.onPressed,
    this.pressedScale = kPressedScale,
    this.semanticLabel,
    this.borderRadius,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final double pressedScale;
  final String? semanticLabel;
  final BorderRadius? borderRadius;

  bool get _enabled => onPressed != null;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (!widget._enabled || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final scale = _pressed && widget._enabled ? widget.pressedScale : 1.0;

    return Semantics(
      button: true,
      enabled: widget._enabled,
      label: widget.semanticLabel,
      child: FocusableActionDetector(
        enabled: widget._enabled,
        mouseCursor: widget._enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onPressed?.call();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _setPressed(true),
          onTapUp: (_) => _setPressed(false),
          onTapCancel: () => _setPressed(false),
          onTap: widget.onPressed,
          child: AnimatedScale(
            scale: scale,
            duration: reduceMotion ? MotionDurations.none : MotionDurations.fast,
            curve: MotionCurves.standard,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
