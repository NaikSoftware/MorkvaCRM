import 'package:flutter/animation.dart';

/// Motion tokens. Calm, decelerating motion only — no bounce or elastic easing.
/// Animate transform/opacity. Widgets should respect reduced-motion by checking
/// `MediaQuery.disableAnimationsOf(context)` and using [Durations.none] when set.
abstract final class MotionDurations {
  static const none = Duration.zero;

  /// 120ms — press feedback, icon swaps, hover.
  static const fast = Duration(milliseconds: 120);

  /// 200ms — default for state changes, nav selection.
  static const base = Duration(milliseconds: 200);

  /// 320ms — page/section reveals.
  static const slow = Duration(milliseconds: 320);
}

abstract final class MotionCurves {
  /// Exponential ease-out — natural, high-quality deceleration.
  /// `cubic-bezier(0.16, 1, 0.3, 1)`.
  static const emphasized = Cubic(0.16, 1, 0.3, 1);

  /// Standard ease-out for small state changes.
  static const standard = Curves.easeOutCubic;
}

/// Press-scale factor applied to interactive elements (the signature
/// micro-interaction). 1.0 → [pressedScale] on tap-down.
const double kPressedScale = 0.96;
