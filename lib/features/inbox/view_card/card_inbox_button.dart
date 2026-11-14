import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/domain/inbox/inbox.dart';
import '../../../design/design.dart';
import '../../../l10n/l10n.dart';
import '../../automation/widgets/action_buttons.dart' show maybeRead;
import '../bloc/inbox_cubit.dart';
import '../view/inbox_format.dart';
import '../view/inbox_item_editor.dart';
import '../view/inbox_kind_glyph.dart';

/// The card editor's Inbox button (spec §4 "From a card"): a count badge of
/// the open items linked to this card; with none it opens the item editor
/// pre-linked, else a menu of those items and "Add to Inbox…".
///
/// Renders nothing where no [InboxCubit] is provided ([shownIn]).
class CardInboxButton extends StatelessWidget {
  const CardInboxButton({
    super.key,
    required this.collectionId,
    required this.cardId,
    required this.label,
  });

  final String collectionId;
  final String cardId;

  /// The card's title, stored as the link's label.
  final String label;

  /// Whether the button takes space in [context] (the header subtracts it).
  static bool shownIn(BuildContext context) =>
      maybeRead<InboxCubit>(context) != null;

  /// The button's width.
  static const double width = 44;

  /// The linked items menu's width.
  static const double menuWidth = 320;

  @override
  Widget build(BuildContext context) {
    final inbox = maybeRead<InboxCubit>(context);
    if (inbox == null) return const SizedBox.shrink();
    return BlocBuilder<InboxCubit, InboxState>(
      bloc: inbox,
      builder: (context, _) {
        final linked =
            inbox.items
                .where(
                  (i) =>
                      i.isOpen &&
                      i.link?.collectionId == collectionId &&
                      i.link?.cardId == cardId,
                )
                .toList()
              ..sort(_byDue);
        void add() => unawaited(
          showInboxItemEditor(
            context,
            link: InboxLink.toCard(
              collectionId: collectionId,
              cardId: cardId,
              label: label,
            ),
          ),
        );
        if (linked.isEmpty) {
          return IconActionButton(
            icon: Icons.inbox_outlined,
            tooltip: context.l10n.inboxAddToInbox,
            onPressed: add,
          );
        }
        return MenuAnchor(
          // The panel opens leftwards under the button.
          alignmentOffset: const Offset(width - menuWidth, Spacing.xxs),
          menuChildren: [
            // A fixed width (items stretch), so the right edges align.
            SizedBox(
              width: menuWidth,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final item in linked)
                    _ItemEntry(
                      item: item,
                      onOpen: () =>
                          unawaited(showInboxItemEditor(context, item: item)),
                    ),
                  const Divider(height: Spacing.xs),
                  MenuItemButton(
                    leadingIcon: const Icon(Icons.add_rounded),
                    onPressed: add,
                    child: Text(context.l10n.inboxAddToInboxMenu),
                  ),
                ],
              ),
            ),
          ],
          builder: (context, menu, _) => _Badged(
            count: linked.length,
            child: IconActionButton(
              icon: Icons.inbox_outlined,
              tooltip: context.l10n.inboxCardOpenCount(linked.length),
              filled: menu.isOpen,
              onPressed: () => menu.isOpen ? menu.close() : menu.open(),
            ),
          ),
        );
      },
    );
  }
}

/// Dated first, by due moment; undated last.
int _byDue(InboxItem a, InboxItem b) => switch ((a.dueAt, b.dueAt)) {
  (final x?, final y?) => x.compareTo(y),
  (null, null) => b.createdAt.compareTo(a.createdAt),
  (null, _) => 1,
  (_, null) => -1,
};

/// A 16 px carrot count on a 2 px surface ring at the button's corner.
class _Badged extends StatelessWidget {
  const _Badged({required this.count, required this.child});

  final int count;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          top: 2,
          right: 2,
          child: IgnorePointer(
            child: Container(
              height: 20,
              constraints: const BoxConstraints(minWidth: 20),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: Radii.fullAll,
                border: Border.all(color: scheme.surface, width: 2),
              ),
              child: Text(
                '$count',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onPrimary,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A linked item: kind glyph, title and when ("Today · 10:00", "Thu 12 ·
/// 2 d late"); opens its editor.
class _ItemEntry extends StatelessWidget {
  const _ItemEntry({required this.item, required this.onOpen});

  final InboxItem item;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.l10n;
    final now = DateTime.now();
    final today = localDay(now);
    final day = item.day;
    final late = item.isTask && day != null && day.isBefore(today);
    final when = [
      if (day == null)
        l10n.inboxNoDate
      else if (day == today)
        l10n.commonToday
      else
        dayLabel(day, Localizations.localeOf(context).toString()),
      if (late)
        l10n.inboxDaysLate(daysBetween(day, today))
      else if (itemMinutes(item) case final m?)
        timeLabel(m),
    ].join(' · ');
    return MenuItemButton(
      leadingIcon: InboxKindGlyph(kind: item.kind),
      onPressed: onOpen,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: CardInboxButton.menuWidth - 80,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(
              when,
              style: theme.textTheme.labelSmall?.copyWith(
                color: late ? scheme.error : scheme.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
