import 'package:flutter/material.dart';

import '../../../design/design.dart';
import '../../../l10n/l10n.dart';

/// Filters hide every object: an inline banner with a way out, above the
/// mode's own frame (Board columns, the Table header) which stays visible.
class NoMatchesNotice extends StatelessWidget {
  const NoMatchesNotice({super.key, required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.only(left: Spacing.sm),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: Radii.mdAll,
      ),
      child: Row(
        children: [
          Icon(
            Icons.filter_alt_off_outlined,
            size: 18,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: Spacing.xs),
          Expanded(
            child: Text(
              context.l10n.viewWidgetsNothingMatchesFilters,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          TextActionButton(
            label: context.l10n.viewWidgetsClearFilters,
            onPressed: onClear,
          ),
        ],
      ),
    );
  }
}
