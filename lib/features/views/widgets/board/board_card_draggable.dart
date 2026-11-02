import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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

  /// The pointer holding the card, once lifted.
  int? pointer;

  _HeldDrag? _avatar;

  /// Re-runs hit testing at the held position once the current frame is laid
  /// out, so drop targets that moved under a still pointer (auto-scroll,
  /// paging) take over; then runs [then]. Does nothing once the card is
  /// dropped. A scrolling list ignores pointers, so stop it first.
  void retarget({VoidCallback? then}) {
    final avatar = _avatar;
    if (avatar == null || avatar.ended) return;
    SchedulerBinding.instance
      ..addPostFrameCallback((_) {
        if (avatar.ended) return;
        avatar.refresh();
        then?.call();
      })
      ..ensureVisualUpdate();
  }
}

/// The avatar of a lifted card, remembering when it was dropped.
class _HeldDrag implements Drag {
  _HeldDrag(this._inner);

  final Drag _inner;
  bool ended = false;

  /// A zero move: hit tests again at the same position.
  void refresh() {
    if (!ended) _inner.update(DragUpdateDetails(globalPosition: Offset.zero));
  }

  @override
  void update(DragUpdateDetails details) => _inner.update(details);

  @override
  void end(DragEndDetails details) {
    ended = true;
    _inner.end(details);
  }

  @override
  void cancel() {
    ended = true;
    _inner.cancel();
  }
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
    this.onDragStarted,
  });

  final BoardDrag drag;

  /// Width of the lifted copy (the overlay doesn't constrain it).
  final double width;
  final Widget child;
  final ValueChanged<BoardDrag>? onDragStarted;

  static const double liftScale = 1.03;
  static const double tiltRadians = 2 * math.pi / 180;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return _CardDraggable(
      data: drag,
      onDragStarted: () {
        drag.height = context.size?.height ?? 0;
        onDragStarted?.call(drag);
      },
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
  });

  @override
  MultiDragGestureRecognizer createRecognizer(
    GestureMultiDragStartCallback onStart,
  ) {
    final recognizer = BoardDragGestureRecognizer();
    return recognizer
      ..onStart = (position) {
        final avatar = switch (onStart(position)) {
          final drag? => _HeldDrag(drag),
          null => null,
        };
        data!
          ..pointer = recognizer.startingPointer
          .._avatar = avatar;
        return avatar;
      };
  }
}

/// Starts a drag after [slop] px for mouse / trackpad / pen and after a
/// [delay] long press for touch, per pointer.
class BoardDragGestureRecognizer extends MultiDragGestureRecognizer {
  BoardDragGestureRecognizer({super.debugOwner});

  static const double slop = 4;
  static const Duration delay = Duration(milliseconds: 300);

  /// The pointer whose drag is starting, set just before [onStart] runs.
  int? startingPointer;

  @override
  MultiDragPointerState createNewPointerState(PointerDownEvent event) {
    void starting() => startingPointer = event.pointer;
    return event.kind == PointerDeviceKind.touch
        ? _LongPressState(event.position, event.kind, gestureSettings, starting)
        : _SlopState(event.position, event.kind, gestureSettings, starting);
  }

  @override
  String get debugDescription => 'board card drag';
}

class _SlopState extends MultiDragPointerState {
  _SlopState(
    super.initialPosition,
    super.kind,
    super.gestureSettings,
    this._starting,
  );

  final VoidCallback _starting;

  @override
  void checkForResolutionAfterMove() {
    if (pendingDelta!.distance > BoardDragGestureRecognizer.slop) {
      resolve(GestureDisposition.accepted);
    }
  }

  @override
  void accepted(GestureMultiDragStartCallback starter) {
    _starting();
    starter(initialPosition);
  }
}

/// Accepts once the pointer has rested for [BoardDragGestureRecognizer.delay];
/// moving past the touch slop first gives the gesture to scrolling.
class _LongPressState extends MultiDragPointerState {
  _LongPressState(
    super.initialPosition,
    super.kind,
    super.gestureSettings,
    this._starting,
  ) {
    _timer = Timer(BoardDragGestureRecognizer.delay, _delayPassed);
  }

  final VoidCallback _starting;

  Timer? _timer;
  GestureMultiDragStartCallback? _starter;

  void _delayPassed() {
    _timer = null;
    HapticFeedback.selectionClick();
    if (_starter case final starter?) {
      _starter = null;
      _starting();
      starter(initialPosition);
    } else {
      resolve(GestureDisposition.accepted);
    }
  }

  @override
  void accepted(GestureMultiDragStartCallback starter) {
    if (_timer == null) {
      _starting();
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
