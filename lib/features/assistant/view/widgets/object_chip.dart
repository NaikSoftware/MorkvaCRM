import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../../../../l10n/l10n.dart';
import '../../bloc/chat_item.dart';
import 'assistant_scope.dart';
import 'plan_card_scope.dart';

/// A `#1042`-style chip that opens a card (or a collection / view) through
/// the deep-link contract. The tinted pill is 26 px; its hit area is 44 px
/// tall.
class ObjectChip extends StatelessWidget {
  const ObjectChip({
    super.key,
    required this.label,
    this.onTap,
    this.leading,
    this.semanticLabel,
  });

  final String label;
  final VoidCallback? onTap;

  /// A 16 px glyph before the label (the table's `#` tile, a view icon).
  final Widget? leading;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = AssistantColors.of(context);
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: colors.objectChipText,
      letterSpacing: 0,
    );
    final pill = Container(
      height: 26,
      padding: EdgeInsetsDirectional.only(
        start: leading == null ? 10 : 6,
        end: 10,
      ),
      decoration: BoxDecoration(
        color: colors.objectChip,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 6)],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
        ],
      ),
    );
    return PressableScale(
      onPressed: onTap,
      semanticLabel: semanticLabel ?? context.l10n.assistantOpenObject(label),
      borderRadius: BorderRadius.circular(13),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Align(widthFactor: 1, heightFactor: 1, child: pill),
      ),
    );
  }
}

/// The table's first-column glyph: a 16 px carrot tile with `#`.
class HashGlyph extends StatelessWidget {
  const HashGlyph({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 16,
      height: 16,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        '#',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontSize: 10,
          color: scheme.onPrimaryContainer,
          letterSpacing: 0,
          height: 1,
        ),
      ),
    );
  }
}

/// A chip the assistant posted with `ui.open`; navigates only on tap.
class ObjectChipMessage extends StatelessWidget {
  const ObjectChipMessage({super.key, required this.item});

  final ObjectChipItem item;

  @override
  Widget build(BuildContext context) {
    final actions = PlanCardScope.of(context).actions;
    final colors = AssistantColors.of(context);
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: ObjectChip(
        label: item.label,
        leading: Icon(
          item.cardId != null
              ? Icons.description_outlined
              : Icons.view_agenda_outlined,
          size: 14,
          color: colors.objectChipText,
        ),
        onTap: () => actions.openObject(
          collectionId: item.collectionId,
          cardId: item.cardId,
          viewId: item.viewId,
        ),
      ),
    );
  }
}
