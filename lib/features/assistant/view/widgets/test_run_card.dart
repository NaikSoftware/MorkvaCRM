import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../../../automation/view/test_run_sheet.dart' show TestRunResultView;
import '../../bloc/chat_item.dart';
import 'assistant_scope.dart';

/// A `modules.testRun` result in the thread, read-only (UX §10): the
/// Test-run sheet's result block (status line, plan rows, Calls, Console),
/// so the user sees the same dry run the assistant reads. Test runs are
/// never written to `runs`, so there is no log to open.
class TestRunCard extends StatelessWidget {
  const TestRunCard({super.key, required this.item});

  final TestRunItem item;

  @override
  Widget build(BuildContext context) {
    final colors = AssistantColors.of(context);
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      label: item.title,
      // A Material, not a decorated box: the Calls / Console tiles ink on it.
      child: Material(
        color: colors.panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: colors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Spacing.md,
            Spacing.sm,
            Spacing.md,
            Spacing.xs,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    MorkvaIcons.science,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: Spacing.xs),
                  Expanded(
                    child: Text(
                      item.title,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Spacing.xs),
              TestRunResultView(result: item.result),
            ],
          ),
        ),
      ),
    );
  }
}
