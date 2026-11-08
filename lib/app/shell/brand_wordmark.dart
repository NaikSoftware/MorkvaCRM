import 'package:flutter/material.dart';

import '../../design/design.dart';

/// The Morkva brand: a carrot logomark on a carrot tile, plus the "Morkva"
/// wordmark over a quiet "CRM" line when [extended].
class BrandWordmark extends StatelessWidget {
  const BrandWordmark({
    super.key,
    this.extended = true,
    this.onTap,
    this.tooltip = 'All collections',
  });

  /// Whether to show the wordmark beside the logomark.
  final bool extended;

  /// Called when the brand is tapped. Null = not tappable.
  final VoidCallback? onTap;

  /// What a tap does, shown on hover.
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final brand = extended
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BrandLogomark(),
              const SizedBox(width: Spacing.sm),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Morkva',
                      style: theme.textTheme.titleLarge?.copyWith(height: 1.1),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'CRM',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          )
        : const BrandLogomark();

    if (onTap == null) return Semantics(label: 'Morkva CRM', child: brand);
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: Radii.mdAll,
        child: Semantics(label: 'Morkva CRM', child: brand),
      ),
    );
  }
}

/// The carrot tile on its own (rail, phone header, sign-in).
class BrandLogomark extends StatelessWidget {
  const BrandLogomark({super.key, this.size = 38});

  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(size * 0.32),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.35),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: CustomPaint(
        size: Size.square(size * 0.63),
        painter: _CarrotPainter(scheme.onPrimary),
      ),
    );
  }
}

/// A diagonal carrot with three leaves, drawn on a 24×24 grid.
class _CarrotPainter extends CustomPainter {
  const _CarrotPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24);
    // The drawing sits off-centre on its grid; shift its bounds to the middle.
    final ink = Rect.fromLTRB(2.4, 0.6, 21.9, 19.6);
    canvas.translate(12 - ink.center.dx, 12 - ink.center.dy);
    final body = Path()
      ..moveTo(4.5, 19.5)
      ..relativeCubicTo(2.6, -1, 8.3, -5.6, 10.3, -8.6)
      ..relativeArcToPoint(
        const Offset(-3.7, -3.7),
        radius: const Radius.circular(2.7),
        clockwise: false,
      )
      ..cubicTo(8.1, 9.2, 3.5, 14.9, 2.5, 17.5)
      ..relativeCubicTo(-0.4, 1.1, 1, 2.4, 2, 2)
      ..close();
    canvas.drawPath(body, Paint()..color = color);
    final leaves = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawLine(const Offset(15.5, 6.5), const Offset(19, 3), leaves)
      ..drawLine(const Offset(17, 8.5), const Offset(21, 7), leaves)
      ..drawLine(const Offset(13.5, 5), const Offset(14.7, 1.5), leaves);
  }

  @override
  bool shouldRepaint(_CarrotPainter oldDelegate) => oldDelegate.color != color;
}
