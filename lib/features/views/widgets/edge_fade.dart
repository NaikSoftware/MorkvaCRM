import 'package:flutter/material.dart';

/// Fades [child]'s left / right edge over [extent] px while its horizontal
/// scroll view (at depth 0 below this widget) has more content that way — the
/// cue that a row of tabs, board columns or table columns continues.
class EdgeFade extends StatefulWidget {
  const EdgeFade({super.key, required this.child, this.extent = 24});

  final Widget child;
  final double extent;

  @override
  State<EdgeFade> createState() => EdgeFadeState();
}

class EdgeFadeState extends State<EdgeFade> {
  bool _start = false;
  bool _end = false;

  /// Whether the left / right edge is faded (more content that way).
  bool get fadesStart => _start;
  bool get fadesEnd => _end;

  bool _onNotification(Notification n) {
    final (metrics, depth) = switch (n) {
      ScrollMetricsNotification(:final metrics, :final depth) => (
        metrics,
        depth,
      ),
      ScrollNotification(:final metrics, :final depth) => (metrics, depth),
      _ => (null, -1),
    };
    final m = metrics;
    if (m == null || m.axis != Axis.horizontal || depth != 0) return false;
    final start = m.extentBefore > 0.5;
    final end = m.extentAfter > 0.5;
    if (start != _start || end != _end) {
      setState(() {
        _start = start;
        _end = end;
      });
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    // Metrics notifications cover layout changes, scroll ones the scrolling.
    return NotificationListener<Notification>(
      onNotification: _onNotification,
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (rect) {
          final edge = rect.width <= 0 ? 0.0 : widget.extent / rect.width;
          return LinearGradient(
            colors: [
              _start ? Colors.transparent : Colors.black,
              Colors.black,
              Colors.black,
              _end ? Colors.transparent : Colors.black,
            ],
            stops: [0, edge.clamp(0, 0.5), (1 - edge).clamp(0.5, 1), 1],
          ).createShader(rect);
        },
        child: widget.child,
      ),
    );
  }
}
