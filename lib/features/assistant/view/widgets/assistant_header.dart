import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../../../../l10n/l10n.dart';
import 'assistant_scope.dart';
import 'sparkle_icon.dart';

/// The 60 px header: the sparkle (or a back arrow on phone), "Ask Morkva"
/// over the thread title, then 44 px icon actions.
class AssistantHeader extends StatelessWidget {
  const AssistantHeader({
    super.key,
    this.subtitle,
    this.onBack,
    this.actions = const [],
  });

  final String? subtitle;

  /// Phone: a back arrow replaces the sparkle.
  final VoidCallback? onBack;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = AssistantColors.of(context);
    final phone = onBack != null;
    final sub = subtitle;
    return Container(
      height: 60,
      padding: phone
          ? const EdgeInsets.symmetric(horizontal: 6)
          : const EdgeInsetsDirectional.fromSTEB(18, 0, 10, 0),
      decoration: BoxDecoration(
        color: colors.panel,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          if (phone)
            IconActionButton(
              icon: Icons.arrow_back_rounded,
              tooltip: context.l10n.commonBack,
              onPressed: onBack,
            )
          else
            SparkleIcon(size: 20, color: scheme.primary),
          SizedBox(width: phone ? 4 : 10),
          Expanded(
            child: Semantics(
              header: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.assistantAskMorkva,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontSize: phone ? 17 : 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                      height: 1.25,
                    ),
                  ),
                  if (sub != null && sub.isNotEmpty)
                    Text(
                      sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}
