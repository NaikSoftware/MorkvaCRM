import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// A [ScrollController] whose mouse-wheel and trackpad-wheel steps glide.
///
/// Flutter applies every wheel event as an instant jump, so on web and
/// desktop a wheel notch reads as a hard cut and a burst of notches stutters.
/// Here each step adds to a running target and the position animates there;
/// steps that arrive mid-glide extend it instead of restarting from the
/// current offset, so fast scrolling stays continuous. Drags, flings,
/// [jumpTo] and [animateTo] behave as usual.
class SmoothWheelScrollController extends ScrollController {
  SmoothWheelScrollController({
    super.initialScrollOffset,
    super.keepScrollOffset,
    super.debugLabel,
    this.duration = const Duration(milliseconds: 160),
    this.curve = Curves.easeOutCubic,
  });

  /// How long one wheel step takes to settle.
  final Duration duration;

  /// The easing of a wheel step.
  final Curve curve;

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) => _SmoothWheelPosition(
    physics: physics,
    context: context,
    initialPixels: initialScrollOffset,
    keepScrollOffset: keepScrollOffset,
    oldPosition: oldPosition,
    debugLabel: debugLabel,
    duration: duration,
    curve: curve,
  );
}

class _SmoothWheelPosition extends ScrollPositionWithSingleContext {
  _SmoothWheelPosition({
    required super.physics,
    required super.context,
    super.initialPixels,
    super.keepScrollOffset,
    super.oldPosition,
    super.debugLabel,
    required this.duration,
    required this.curve,
  });

  final Duration duration;
  final Curve curve;

  /// Where the current glide is heading; null when none is running.
  double? _target;

  @override
  void pointerScroll(double delta) {
    final context = this.context.notificationContext;
    final reduceMotion =
        context != null && MediaQuery.maybeDisableAnimationsOf(context) == true;
    if (delta == 0.0 || reduceMotion) {
      _target = null;
      super.pointerScroll(delta);
      return;
    }
    final from = _target ?? pixels;
    final target = math.min(
      math.max(from + delta, minScrollExtent),
      maxScrollExtent,
    );
    if (target == pixels && _target == null) return;
    _target = target;
    // Tell listeners (e.g. "stop following the bottom") which way the reader
    // is scrolling, as an instant wheel jump would.
    updateUserScrollDirection(
      delta < 0 ? ScrollDirection.forward : ScrollDirection.reverse,
    );
    animateTo(target, duration: duration, curve: curve).whenComplete(() {
      if (_target == target) _target = null;
    });
  }

  @override
  void jumpTo(double value) {
    _target = null;
    super.jumpTo(value);
  }

  @override
  void beginActivity(ScrollActivity? newActivity) {
    // A drag or fling takes over: the next wheel step starts from where the
    // list actually is.
    if (newActivity is! DrivenScrollActivity) _target = null;
    super.beginActivity(newActivity);
  }
}
