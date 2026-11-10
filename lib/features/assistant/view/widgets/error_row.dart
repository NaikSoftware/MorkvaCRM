import 'package:flutter/material.dart';

import '../../bloc/chat_item.dart';
import 'assistant_scope.dart';
import 'chip_button.dart';
import 'dashed_border.dart';

/// A failed turn: a dashed card that says whether anything changed, with
/// "Try again" re-running the last turn when it can.
class ErrorRow extends StatelessWidget {
  const ErrorRow({super.key, required this.item});

  final ErrorItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = AssistantColors.of(context);
    final actions = AssistantScope.of(context).actions;
    final radius = BorderRadius.circular(12);
    return Semantics(
      container: true,
      liveRegion: true,
      child: DashedBorder(
        color: scheme.outline,
        borderRadius: radius,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: EdgeInsetsDirectional.fromSTEB(
            12,
            4,
            item.retryable ? 4 : 12,
            4,
          ),
          decoration: BoxDecoration(color: colors.panel, borderRadius: radius),
          child: Row(
            children: [
              Icon(
                item.kind == ChatErrorKind.blocked
                    ? Icons.block_rounded
                    : Icons.error_outline_rounded,
                size: 16,
                color: scheme.error,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    item.message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 13,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              if (item.retryable) ...[
                const SizedBox(width: 10),
                TintedButton(
                  label: 'Try again',
                  fontSize: 13,
                  foreground: scheme.onSurface,
                  onPressed: actions.retry,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
