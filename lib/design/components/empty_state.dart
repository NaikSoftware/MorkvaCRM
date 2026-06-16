import 'package:flutter/material.dart';

import '../tokens/radii.dart';
import '../tokens/spacing.dart';
import 'buttons/primary_button.dart';

/// A calm, centered placeholder for "nothing here yet" states: an empty
/// collection, no search results, a fresh workspace.
///
/// Anchored by a large [icon] tinted in the carrot [ColorScheme.primary] inside
/// a rounded [ColorScheme.surfaceContainerHighest] tile, followed by a headline
/// and a short supporting line. An optional call to action is rendered with the
/// shared [PrimaryButton]; pass either [actionLabel] + [onAction] for the common
/// case, or a custom [action] widget when you need something else.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.action,
  });

  /// The anchoring glyph (tinted [ColorScheme.primary]).
  final IconData icon;

  /// Short headline, rendered with [TextTheme.headlineSmall].
  final String title;

  /// Supporting sentence, rendered with [TextTheme.bodyMedium] in
  /// [ColorScheme.onSurfaceVariant], constrained to a comfortable reading width.
  final String message;

  /// Label for the built-in [PrimaryButton]. Used only when [action] is null.
  final String? actionLabel;

  /// Callback for the built-in [PrimaryButton]. Used only when [action] is null.
  final VoidCallback? onAction;

  /// A custom action widget; takes precedence over [actionLabel] / [onAction].
  final Widget? action;

  /// Comfortable reading measure for the supporting line (~65 characters).
  static const double _messageMaxWidth = 320;

  Widget? _buildAction() {
    if (action != null) return action;
    if (actionLabel != null && onAction != null) {
      return PrimaryButton(label: actionLabel!, onPressed: onAction);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final resolvedAction = _buildAction();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(Spacing.lg),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: Radii.lgAll,
              ),
              child: Icon(icon, size: 48, color: scheme.primary),
            ),
            const SizedBox(height: Spacing.lg),
            Text(
              title,
              style: textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Spacing.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _messageMaxWidth),
              child: Text(
                message,
                style: textTheme.bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ),
            if (resolvedAction != null) ...[
              const SizedBox(height: Spacing.xl),
              resolvedAction,
            ],
          ],
        ),
      ),
    );
  }
}
