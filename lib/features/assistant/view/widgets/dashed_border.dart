import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

/// Paints a dashed rounded-rect outline around its child (the error row, a
/// chart's partial-period bar).
class DashedBorder extends StatelessWidget {
  const DashedBorder({
    super.key,
    required this.color,
    required this.borderRadius,
    this.strokeWidth = 1,
    this.dash = 4,
    this.gap = 3,
    this.child,
  });

  final Color color;
  final BorderRadius borderRadius;
  final double strokeWidth;
  final double dash;
  final double gap;
  final Widget? child;

  @override
  Widget build(BuildContext context) => CustomPaint(
    foregroundPainter: _DashedPainter(
      color: color,
      borderRadius: borderRadius,
      strokeWidth: strokeWidth,
      dash: dash,
      gap: gap,
    ),
    child: child,
  );
}

class _DashedPainter extends CustomPainter {
  const _DashedPainter({
    required this.color,
    required this.borderRadius,
    required this.strokeWidth,
    required this.dash,
    required this.gap,
  });

  final Color color;
  final BorderRadius borderRadius;
  final double strokeWidth;
  final double dash;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(strokeWidth / 2);
    final outline = Path()..addRRect(borderRadius.toRRect(rect));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    for (final PathMetric metric in outline.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += dash + gap) {
        canvas.drawPath(metric.extractPath(d, d + dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedPainter old) =>
      color != old.color ||
      borderRadius != old.borderRadius ||
      strokeWidth != old.strokeWidth ||
      dash != old.dash ||
      gap != old.gap;
}
