import 'package:flutter/material.dart';

import '../../../design/design.dart';
import '../../../l10n/l10n.dart';

/// What [QuickAddDialog] resolves to.
typedef QuickAddResult = ({String title, bool details});

/// Asks for a new object's title. [prefill] names the value it will also get
/// ("Stage · Won"). Resolves to the entered title — with `details` true when
/// the user chose "Add details" (open the full form) — or null on cancel.
class QuickAddDialog extends StatefulWidget {
  const QuickAddDialog({
    super.key,
    required this.itemLabel,
    required this.titleLabel,
    this.prefill,
  });

  final String itemLabel;
  final String titleLabel;
  final String? prefill;

  static Future<QuickAddResult?> show(
    BuildContext context, {
    required String itemLabel,
    required String titleLabel,
    String? prefill,
  }) => showDialog<QuickAddResult>(
    context: context,
    builder: (_) => QuickAddDialog(
      itemLabel: itemLabel,
      titleLabel: titleLabel,
      prefill: prefill,
    ),
  );

  @override
  State<QuickAddDialog> createState() => _QuickAddDialogState();
}

class _QuickAddDialogState extends State<QuickAddDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit({bool details = false}) => Navigator.of(
    context,
  ).pop((title: _controller.text.trim(), details: details));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.viewWidgetsNewItem(widget.itemLabel)),
      content: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 320, maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MorkvaTextField(
              controller: _controller,
              label: widget.titleLabel,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
            ),
            if (widget.prefill case final prefill?) ...[
              const SizedBox(height: Spacing.sm),
              Row(
                children: [
                  Icon(
                    MorkvaIcons.subdirectory,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: Spacing.xxs),
                  Text(
                    prefill,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextActionButton(
          label: l10n.viewWidgetsAddDetails,
          onPressed: () => _submit(details: true),
        ),
        TextActionButton(
          label: l10n.commonCancel,
          onPressed: () => Navigator.of(context).pop(),
        ),
        PrimaryButton(label: l10n.commonAdd, onPressed: _submit),
      ],
    );
  }
}
