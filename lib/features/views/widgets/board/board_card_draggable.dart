import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/domain/domain.dart';
import '../../../../design/design.dart';

/// What a board card carries while dragged.
class BoardDrag {
  BoardDrag({required this.object, required this.fromKey});

  final MorkvaObject object;

  /// Group key of the column the card was lifted from (null = `No <field>`).
  final String? fromKey;

  /// The card's real height, measured when the drag starts; the ghost uses it.
  double height = 0;
}

/// A board card that lifts after 4 px with a mouse / pen, or after a 300 ms
/// long press (with a haptic tick) on touch. While dragged, its slot
/// collapses and a tilted, raised copy follows the pointer.
class BoardCardDraggable extends StatelessWidget {
  const BoardCardDraggable({
    super.key,
    required this.drag,
    required this.width,
    required this.child,
    this.onDragUpdate,
    this.onDragEnd,
  });

  final BoardDrag drag;

  /// Width of the lifted copy (the overlay doesn't constrain it).
  final double width;
  final Widget child;
  final ValueChanged<Offset>? onDragUpdate;
  final VoidCallback? onDragEnd;

  static const double liftScale = 1.03;
  static const double tiltRadians = 2 * math.pi / 180;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return _CardDraggable(
      data: drag,
      onDragStarted: () => drag.height = context.size?.height ?? 0,
      onDragUpdate: (d) => onDragUpdate?.call(d.globalPosition),
      onDragEnd: (_) => onDragEnd?.call(),
      feedback: Transform.rotate(
        angle: tiltRadians,
        child: Transform.scale(
          scale: liftScale,
          child: Material(
            type: MaterialType.transparency,
            child: SizedBox(
              width: width,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  borderRadius: Radii.mdAll,
                  boxShadow: MorkvaElevation.level3,
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
      childWhenDragging: TweenAnimationBuilder<double>(
        tween: Tween(begin: 1, end: 0),
        duration: reduceMotion ? MotionDurations.none : MotionDurations.base,
        curve: MotionCurves.standard,
        builder: (context, factor, child) => ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: factor,
            child: child,
          ),
        ),
        child: Opacity(opacity: 0, child: child),
      ),
      child: child,
    );
  }
}

/// [Draggable] with the board's start gestures (see [BoardCardDraggable]).
class _CardDraggable extends Draggable<BoardDrag> {
  const _CardDraggable({
    required super.child,
    required super.feedback,
    required super.data,
    super.childWhenDragging,
    super.onDragStarted,
    super.onDragUpdate,
    super.onDragEnd,
  });

  @override
  MultiDragGestureRecognizer createRecognizer(
    GestureMultiDragStartCallback onStart,
  ) => BoardDragGestureRecognizer()..onStart = onStart;
}

/// Starts a drag after [slop] px for mouse / trackpad / pen and after a
/// [delay] long press for touch, per pointer.
class BoardDragGestureRecognizer extends MultiDragGestureRecognizer {
  BoardDragGestureRecognizer({super.debugOwner});

  static const double slop = 4;
  static const Duration delay = Duration(milliseconds: 300);

  @override
  MultiDragPointerState createNewPointerState(PointerDownEvent event) =>
      event.kind == PointerDeviceKind.touch
      ? _LongPressState(event.position, event.kind, gestureSettings)
      : _SlopState(event.position, event.kind, gestureSettings);

  @override
  String get debugDescription => 'board card drag';
}

class _SlopState extends MultiDragPointerState {
  _SlopState(super.initialPosition, super.kind, super.gestureSettings);

  @override
  void checkForResolutionAfterMove() {
    if (pendingDelta!.distance > BoardDragGestureRecognizer.slop) {
      resolve(GestureDisposition.accepted);
    }
  }

  @override
  void accepted(GestureMultiDragStartCallback starter) =>
      starter(initialPosition);
}

/// Accepts once the pointer has rested for [BoardDragGestureRecognizer.delay];
/// moving past the touch slop first gives the gesture to scrolling.
class _LongPressState extends MultiDragPointerState {
  _LongPressState(super.initialPosition, super.kind, super.gestureSettings) {
    _timer = Timer(BoardDragGestureRecognizer.delay, _delayPassed);
  }

  Timer? _timer;
  GestureMultiDragStartCallback? _starter;

  void _delayPassed() {
    _timer = null;
    HapticFeedback.selectionClick();
    if (_starter case final starter?) {
      _starter = null;
      starter(initialPosition);
    } else {
      resolve(GestureDisposition.accepted);
    }
  }

  @override
  void accepted(GestureMultiDragStartCallback starter) {
    if (_timer == null) {
      starter(initialPosition);
    } else {
      _starter = starter;
    }
  }

  @override
  void checkForResolutionAfterMove() {
    if (_timer == null) return;
    if (pendingDelta!.distance > computeHitSlop(kind, gestureSettings)) {
      resolve(GestureDisposition.rejected);
      _stopTimer();
    }
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }
}

/// A rounded rect outlined with dashes, optionally filled: the drop ghost and
/// the empty-column zone.
class DashedRRect extends StatelessWidget {
  const DashedRRect({
    super.key,
    required this.color,
    this.strokeWidth = 1,
    this.fill,
    this.height,
    this.child,
  });

  final Color color;
  final double strokeWidth;
  final Color? fill;
  final double? height;
  final Widget? child;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _DashedRRectPainter(
      color: color,
      strokeWidth: strokeWidth,
      fill: fill,
    ),
    child: SizedBox(width: double.infinity, height: height, child: child),
  );
}

class _DashedRRectPainter extends CustomPainter {
  const _DashedRRectPainter({
    required this.color,
    required this.strokeWidth,
    this.fill,
  });

  final Color color;
  final double strokeWidth;
  final Color? fill;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(strokeWidth / 2),
      const Radius.circular(Radii.md),
    );
    if (fill case final fill?) {
      canvas.drawRRect(rrect, Paint()..color = fill);
    }
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final dash = 4 * strokeWidth;
    for (final metric in (Path()..addRRect(rrect)).computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += dash * 1.75) {
        canvas.drawPath(metric.extractPath(d, d + dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRRectPainter old) =>
      old.color != color || old.strokeWidth != strokeWidth || old.fill != fill;
}
