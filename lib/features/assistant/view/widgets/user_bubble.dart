import 'package:flutter/material.dart';

import 'assistant_scope.dart';

/// The user's message: a soft `surfaceContainerHigh` (dark:
/// `surfaceContainerHighest`) bubble with `onSurface` text, right-aligned, its bottom-right corner tucked (16/16/4/16).
class UserBubble extends StatelessWidget {
  const UserBubble({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final scope = AssistantScope.of(context);
    return LayoutBuilder(
      builder: (context, constraints) => Align(
        alignment: AlignmentDirectional.centerEnd,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: constraints.maxWidth * (scope.phone ? 0.85 : 0.82),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              // Dark: one step higher, so the bubble lifts off the canvas.
              color: scheme.brightness == Brightness.dark
                  ? scheme.surfaceContainerHighest
                  : scheme.surfaceContainerHigh,
              borderRadius: const BorderRadiusDirectional.only(
                topStart: Radius.circular(16),
                topEnd: Radius.circular(16),
                bottomStart: Radius.circular(16),
                bottomEnd: Radius.circular(4),
              ).resolve(Directionality.of(context)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: SelectionArea(
                child: Text(
                  text,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: scope.messageSize,
                    height: 1.45,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
