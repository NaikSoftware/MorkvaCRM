import 'package:flutter/material.dart';

import '../../../design/design.dart';

/// Shows [builder] as a 360 px popover dropping from [anchor] on wide
/// screens, or as a bottom sheet when [compact].
///
/// The popover hangs below [anchor] (a global rect), inset by
/// [horizontalInset] from its left edge, or from its right edge when
/// [alignEnd]. Tapping outside or Esc dismisses it.
Future<T?> showViewPopover<T>(
  BuildContext context, {
  required bool compact,
  required Rect anchor,
  required WidgetBuilder builder,
  bool alignEnd = false,
  double horizontalInset = 0,
  String label = 'Popover',
}) {
  if (compact) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.lg)),
      ),
      builder: (context) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: builder(context),
        ),
      ),
    );
  }
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.transparent,
    transitionDuration: MotionDurations.fast,
    pageBuilder: (context, _, _) => _Popover(
      anchor: anchor,
      alignEnd: alignEnd,
      horizontalInset: horizontalInset,
      label: label,
      child: builder(context),
    ),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: MotionCurves.standard,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, -0.02),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// The global rect of [context]'s render box.
Rect globalRectOf(BuildContext context) {
  final box = context.findRenderObject() as RenderBox?;
  if (box == null || !box.hasSize) return Rect.zero;
  return box.localToGlobal(Offset.zero) & box.size;
}

class _Popover extends StatelessWidget {
  const _Popover({
    required this.anchor,
    required this.alignEnd,
    required this.horizontalInset,
    required this.label,
    required this.child,
  });

  static const width = 360.0;
  static const _margin = Spacing.md;

  final Rect anchor;
  final bool alignEnd;
  final double horizontalInset;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final scheme = Theme.of(context).colorScheme;
    final top = anchor.bottom + Spacing.xxs;
    final rawLeft = alignEnd
        ? anchor.right - horizontalInset - width
        : anchor.left + horizontalInset;
    final left = rawLeft.clamp(_margin, screen.width - width - _margin);
    final maxHeight = (screen.height - top - _margin).clamp(200.0, 520.0);
    return Stack(
      children: [
        Positioned(
          top: top,
          left: left,
          width: width,
          child: Semantics(
            scopesRoute: true,
            namesRoute: true,
            explicitChildNodes: true,
            label: label,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                borderRadius: Radii.mdAll,
                boxShadow: MorkvaElevation.level3,
              ),
              child: Material(
                color: scheme.surfaceContainerLowest,
                shape: RoundedRectangleBorder(
                  borderRadius: Radii.mdAll,
                  side: BorderSide(color: scheme.outlineVariant),
                ),
                clipBehavior: Clip.antiAlias,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxHeight),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
