import 'package:flutter/material.dart';

import '../tokens/radii.dart';
import '../tokens/spacing.dart';
import 'buttons/primary_button.dart';
import 'buttons/text_action_button.dart';
import 'pressable_scale.dart';

/// A single, consistent confirmation dialog for the whole app.
///
/// Frames a [title], a body [message], a quiet [TextActionButton] cancel, and a
/// confirm action that supports a [destructive] error tint. The confirm button
/// uses the shared [PressableScale] press feel and a 44px hit target so it
/// matches the rest of the button family. Reads every color/text value from the
/// theme and every spacing/radius from tokens — never hardcoded.
///
/// Use [show] to present it and await the boolean result (`true` = confirmed,
/// `null`/`false` = dismissed or cancelled), so no caller hand-rolls an
/// [AlertDialog] with mismatched buttons.
class MorkvaConfirmDialog extends StatelessWidget {
  const MorkvaConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
    this.cancelLabel = 'Cancel',
    this.destructive = false,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;

  /// When true, the confirm button is tinted with the error role (a deletion or
  /// other irreversible action).
  final bool destructive;

  /// Shows the dialog and resolves to `true` when confirmed, or `null` when
  /// cancelled / dismissed.
  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    String cancelLabel = 'Cancel',
    bool destructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => MorkvaConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        destructive: destructive,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: const RoundedRectangleBorder(borderRadius: Radii.lgAll),
      title: Text(title),
      content: Text(message),
      actionsPadding: const EdgeInsets.fromLTRB(
        Spacing.lg,
        0,
        Spacing.lg,
        Spacing.md,
      ),
      // A single Wrap, not a bare actions list: AlertDialog's OverflowBar
      // mis-stacks our (now content-sized) buttons; Wrap keeps the pair on one
      // baseline and only stacks if the dialog is too narrow to fit them.
      actions: [
        Wrap(
          alignment: WrapAlignment.end,
          spacing: Spacing.xxs,
          runSpacing: Spacing.xs,
          children: [
            TextActionButton(
              label: cancelLabel,
              onPressed: () => Navigator.of(context).pop(false),
            ),
            _ConfirmButton(
              label: confirmLabel,
              destructive: destructive,
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      ],
    );
  }
}

/// The confirm affordance: the carrot [PrimaryButton] by default, or an
/// error-tinted pressable when [destructive] so a delete reads as dangerous
/// without leaving the button family.
class _ConfirmButton extends StatelessWidget {
  const _ConfirmButton({
    required this.label,
    required this.destructive,
    required this.onPressed,
  });

  final String label;
  final bool destructive;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (!destructive) {
      return PrimaryButton(label: label, onPressed: onPressed);
    }

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return PressableScale(
      onPressed: onPressed,
      semanticLabel: label,
      borderRadius: Radii.mdAll,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
        decoration: BoxDecoration(
          color: scheme.error,
          borderRadius: Radii.mdAll,
        ),
        // A min-size centered Row (not Container.alignment, which grows to fill
        // a bounded width) keeps the button hugging its label inside a Wrap.
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.onError,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
