import 'dart:async';

import 'package:flutter/material.dart';

import '../../../design/design.dart';

/// The loading placeholder in the Table's shape: a header, tabs, the toolbar
/// and rows of
/// `surfaceContainer` bars pulsing 0.5 ↔ 1 over 1.2 s (static with reduced
/// motion). Draws nothing for the first 150 ms so fast loads never flash.
class ViewsSkeleton extends StatefulWidget {
  const ViewsSkeleton({super.key, this.compact = false});

  final bool compact;

  static const delay = Duration(milliseconds: 150);

  @override
  State<ViewsSkeleton> createState() => _ViewsSkeletonState();
}

class _ViewsSkeletonState extends State<ViewsSkeleton>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
    lowerBound: 0.5,
  );
  Timer? _timer;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(ViewsSkeleton.delay, () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse
        ..stop()
        ..value = 1;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.expand();
    final scheme = Theme.of(context).colorScheme;
    final gutter = widget.compact ? Spacing.md : Spacing.lg;
    Widget bar(double width, double height, {double radius = Radii.sm}) =>
        Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: scheme.surfaceContainer,
            borderRadius: BorderRadius.circular(radius),
          ),
        );
    const widths = [0.62, 0.45, 0.7, 0.38, 0.55, 0.66, 0.42, 0.58];

    return Semantics(
      container: true,
      label: 'Loading',
      child: FadeTransition(
        opacity: _pulse,
        child: Padding(
          padding: EdgeInsets.fromLTRB(gutter, Spacing.lg, gutter, gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  bar(40, 40, radius: Radii.md),
                  const SizedBox(width: Spacing.sm),
                  bar(widget.compact ? 140 : 220, 28),
                ],
              ),
              const SizedBox(height: Spacing.lg),
              Row(
                children: [
                  bar(84, 20),
                  const SizedBox(width: Spacing.md),
                  bar(72, 20),
                ],
              ),
              const SizedBox(height: Spacing.lg),
              // The toolbar: a filter chip, then sort and columns.
              Row(
                children: [
                  bar(96, 32, radius: Radii.full),
                  const Spacer(),
                  bar(32, 32, radius: Radii.md),
                  const SizedBox(width: Spacing.xs),
                  bar(32, 32, radius: Radii.md),
                ],
              ),
              const SizedBox(height: Spacing.md),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: Radii.lgAll,
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      Container(height: 44, color: scheme.surfaceContainerLow),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, c) => ListView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            itemExtent: 52,
                            itemCount: (c.maxHeight / 52).ceil(),
                            itemBuilder: (context, i) => Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: Spacing.md,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: FractionallySizedBox(
                                      alignment: Alignment.centerLeft,
                                      widthFactor: widths[i % widths.length],
                                      child: bar(double.infinity, 14),
                                    ),
                                  ),
                                  if (!widget.compact) ...[
                                    const SizedBox(width: Spacing.xl),
                                    bar(88, 14),
                                    const SizedBox(width: Spacing.xl),
                                    bar(64, 22, radius: Radii.full),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
