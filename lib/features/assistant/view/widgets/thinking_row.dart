import 'package:flutter/material.dart';

import 'sparkle_icon.dart';

/// "Thinking…" before the first token or step: a sparkle and a soft shimmer
/// sweeping the label (static when animations are off).
class ThinkingRow extends StatefulWidget {
  const ThinkingRow({super.key, this.label = 'Thinking…'});

  final String label;

  @override
  State<ThinkingRow> createState() => _ThinkingRowState();
}

class _ThinkingRowState extends State<ThinkingRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _sweep.stop();
    } else if (!_sweep.isAnimating) {
      _sweep.repeat();
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final base = scheme.onSurfaceVariant;
    final label = Text(
      widget.label,
      style: theme.textTheme.bodyMedium?.copyWith(color: base),
    );
    return Semantics(
      liveRegion: true,
      label: widget.label,
      excludeSemantics: true,
      child: SizedBox(
        height: 28,
        child: Row(
          children: [
            SparkleIcon(size: 16, color: scheme.primary),
            const SizedBox(width: 8),
            AnimatedBuilder(
              animation: _sweep,
              child: label,
              builder: (context, child) {
                if (!_sweep.isAnimating) return child!;
                final t = _sweep.value * 3 - 1;
                return ShaderMask(
                  blendMode: BlendMode.srcIn,
                  shaderCallback: (rect) => LinearGradient(
                    colors: [base, scheme.onSurface, base],
                    stops: const [0, 0.5, 1],
                    begin: Alignment(t - 1, 0),
                    end: Alignment(t + 1, 0),
                  ).createShader(rect),
                  child: child,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
