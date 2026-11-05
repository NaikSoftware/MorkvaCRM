import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../tokens/colors.dart';

/// Static decor behind [child]: a faint repeating tile of line doodles
/// (carrot, sprout, tag, card, calendar, parcel, clip, check, envelope,
/// needle). Never interactive, never read by screen readers.
class DoodleBackground extends StatelessWidget {
  const DoodleBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color =
        theme.extension<MorkvaSemanticColors>()?.doodle ??
        theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.08);
    return Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: DoodlePainter(
                    color,
                    pixelRatio: MediaQuery.devicePixelRatioOf(context),
                  ),
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// Paints the doodle tile across its size in [color].
///
/// The strokes are rasterized once per colour and [pixelRatio] into a tile
/// image, then repeated with one image-shader fill: on web every frame
/// re-rasterizes the whole scene, and stroking the paths per tile per frame
/// starved the main thread whenever anything animated.
class DoodlePainter extends CustomPainter {
  DoodlePainter(this.color, {this.pixelRatio = 1});

  final Color color;

  /// Device pixels per logical pixel the tile image is rendered at.
  final double pixelRatio;

  static const double tile = 240;

  /// The tile's strokes, built once.
  static final Path _tile = _buildTile();

  // shortcut: never evicted — a handful of entries (theme colours × device
  // pixel ratios); upgrade to an LRU if colours become user-configurable.
  static final Map<(Color, double), ui.Image> _images = {};

  static ui.Image _tileImage(Color color, double pixelRatio) =>
      _images[(color, pixelRatio)] ??= () {
        final recorder = ui.PictureRecorder();
        // Clipped to the canvas like an SVG <pattern>: strokes past the
        // tile edge are cut.
        Canvas(recorder)
          ..scale(pixelRatio)
          ..drawPath(
            _tile,
            Paint()
              ..color = color
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.6
              ..strokeCap = StrokeCap.round
              ..strokeJoin = StrokeJoin.round,
          );
        final side = (tile * pixelRatio).round();
        final picture = recorder.endRecording();
        final image = picture.toImageSync(side, side);
        picture.dispose();
        return image;
      }();

  @override
  void paint(Canvas canvas, Size size) {
    final image = _tileImage(color, pixelRatio);
    // Map image pixels back to logical pixels, so a tile spans [tile].
    final scale = tile / image.width;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ImageShader(
          image,
          TileMode.repeated,
          TileMode.repeated,
          Matrix4.diagonal3Values(scale, scale, 1).storage,
        ),
    );
  }

  @override
  bool shouldRepaint(DoodlePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.pixelRatio != pixelRatio;

  /// Ported 1:1 from docs/superpowers/mockups/epic-05/Pattern.dc.html.
  static Path _buildTile() {
    final tile = Path();
    void add(double dx, double dy, double degrees, Path Function() draw) {
      final m = Matrix4.translationValues(dx, dy, 0)
        ..rotateZ(degrees * math.pi / 180);
      tile.addPath(draw(), Offset.zero, matrix4: m.storage);
    }

    Path circle(double cx, double cy, double r) =>
        Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));
    Path rrect(double x, double y, double w, double h, double r) => Path()
      ..addRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r)),
      );

    // Carrot.
    add(28, 30, -24, () {
      return Path()
        ..moveTo(0, 0)
        ..lineTo(22, 6)
        ..lineTo(4, 24)
        ..close()
        ..moveTo(-2, -2)
        ..cubicTo(-8, -12, -2, -16, 2, -8)
        ..moveTo(-2, -2)
        ..cubicTo(-12, -6, -14, 0, -6, 2)
        ..moveTo(8, 8)
        ..lineTo(12, 12)
        ..moveTo(4, 14)
        ..lineTo(8, 16);
    });
    // Sprout.
    add(120, 22, 0, () {
      return Path()
        ..moveTo(10, 26)
        ..lineTo(10, 10)
        ..moveTo(10, 14)
        ..cubicTo(2, 14, 0, 6, 2, 2)
        ..cubicTo(8, 2, 12, 8, 10, 14)
        ..moveTo(10, 12)
        ..cubicTo(16, 10, 20, 4, 18, 0)
        ..cubicTo(12, 0, 9, 6, 10, 12);
    });
    // Price tag.
    add(190, 40, 14, () {
      return Path()
        ..moveTo(0, 6)
        ..lineTo(14, 0)
        ..lineTo(28, 0)
        ..lineTo(28, 14)
        ..lineTo(14, 20)
        ..lineTo(0, 20)
        ..close()
        ..addPath(circle(6, 10, 2), Offset.zero);
    });
    // List card.
    add(36, 108, 8, () {
      return rrect(0, 0, 34, 26, 5)
        ..moveTo(6, 8)
        ..lineTo(24, 8)
        ..moveTo(6, 14)
        ..lineTo(18, 14)
        ..moveTo(6, 20)
        ..lineTo(14, 20);
    });
    // Calendar.
    add(112, 92, 0, () {
      return rrect(0, 4, 30, 26, 5)
        ..moveTo(0, 12)
        ..lineTo(30, 12)
        ..moveTo(8, 0)
        ..lineTo(8, 8)
        ..moveTo(22, 0)
        ..lineTo(22, 8)
        ..addPath(circle(9, 20, 1.4), Offset.zero)
        ..addPath(circle(16, 20, 1.4), Offset.zero);
    });
    // Parcel.
    add(184, 116, -10, () {
      return Path()
        ..moveTo(0, 8)
        ..lineTo(16, 0)
        ..lineTo(32, 8)
        ..lineTo(32, 26)
        ..lineTo(16, 34)
        ..lineTo(0, 26)
        ..close()
        ..moveTo(0, 8)
        ..lineTo(16, 16)
        ..lineTo(32, 8)
        ..moveTo(16, 16)
        ..lineTo(16, 34);
    });
    // Paperclip.
    add(20, 184, 30, () {
      return Path()
        ..moveTo(6, 24)
        ..lineTo(6, 6)
        ..cubicTo(6, 0, 16, 0, 16, 6)
        ..lineTo(16, 26)
        ..cubicTo(16, 32, 2, 32, 2, 26)
        ..lineTo(2, 10);
    });
    // Check circle.
    add(98, 176, 0, () {
      return circle(14, 14, 13)
        ..moveTo(8, 14)
        ..lineTo(12, 18)
        ..lineTo(20, 10);
    });
    // Envelope.
    add(160, 186, -6, () {
      return rrect(0, 0, 34, 24, 4)
        ..moveTo(0, 2)
        ..lineTo(17, 14)
        ..lineTo(34, 2);
    });
    // Needle and thread.
    add(214, 196, 40, () {
      return Path()
        ..moveTo(0, 0)
        ..lineTo(0, 26)
        ..moveTo(-3, 26)
        ..lineTo(3, 26)
        ..moveTo(0, 0)
        ..cubicTo(10, 6, -10, 12, 0, 18)
        ..cubicTo(8, 22, -6, 28, 2, 34);
    });
    // Dots.
    for (final (x, y) in const [
      (84.0, 62.0),
      (170.0, 86.0),
      (72.0, 150.0),
      (150.0, 160.0),
      (230.0, 150.0),
      (60.0, 226.0),
    ]) {
      tile.addPath(circle(x, y, 1.6), Offset.zero);
    }
    return tile;
  }
}
