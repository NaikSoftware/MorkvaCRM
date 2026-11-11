import 'package:flutter/material.dart';

/// The Ask Morkva mark: a four-point sparkle with a small companion, drawn
/// from the mockup's 24×24 path so it matches at every size. Used in the
/// panel header, the empty state and (T13b) the entry points.
class SparkleIcon extends StatelessWidget {
  const SparkleIcon({super.key, this.size = 20, this.color});

  final double size;

  /// Defaults to the ambient [IconTheme] colour.
  final Color? color;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: Size.square(size),
      painter: _SparklePainter(color ?? IconTheme.of(context).color!),
    ),
  );
}

class _SparklePainter extends CustomPainter {
  const _SparklePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final path = Path()
      ..moveTo(12, 2.5)
      ..relativeCubicTo(.6, 4.6, 2.9, 6.9, 7.5, 7.5)
      ..relativeCubicTo(-4.6, .6, -6.9, 2.9, -7.5, 7.5)
      ..relativeCubicTo(-.6, -4.6, -2.9, -6.9, -7.5, -7.5)
      ..relativeCubicTo(4.6, -.6, 6.9, -2.9, 7.5, -7.5)
      ..close()
      ..moveTo(19, 15.5)
      ..relativeCubicTo(.3, 2, 1.2, 2.9, 3.2, 3.2)
      ..relativeCubicTo(-2, .3, -2.9, 1.2, -3.2, 3.2)
      ..relativeCubicTo(-.3, -2, -1.2, -2.9, -3.2, -3.2)
      ..relativeCubicTo(2, -.3, 2.9, -1.2, 3.2, -3.2)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SparklePainter oldDelegate) => color != oldDelegate.color;
}
