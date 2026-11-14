import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/domain/inbox/inbox.dart';
import '../../../design/design.dart';
import '../../../l10n/l10n.dart';
import '../../automation/widgets/action_buttons.dart' show maybeRead;
import '../bloc/inbox_cubit.dart';
import '../view/inbox_chips.dart' show showInboxSnack;
import '../view/inbox_format.dart';
import '../view/inbox_item_editor.dart';
import '../view/inbox_link_chip.dart';
import 'reminder_scheduler.dart';

/// The reminder toasts over [child] (spec §4 "Reminders: delivery on web"):
/// bottom-right on wide screens, at the top on phones; at most three, then
/// "+N more". Each renders from the live item, so it vanishes when the item
/// is done, deleted or rescheduled. Catch-up entries share one toast.
///
/// Mount exactly one (the shell does). Renders just [child] where no
/// [ReminderScheduler] or [InboxCubit] is provided.
///
/// Also the app's one "Couldn't save — …" snackbar for failed Inbox writes
/// (page, toasts, card button), wherever an [InboxCubit] is provided.
class ReminderToastHost extends StatelessWidget {
  const ReminderToastHost({super.key, required this.child});

  final Widget child;

  /// Toast stack width on wide screens.
  static const double width = 400;

  /// Most toasts shown at once.
  static const int maxShown = 3;

  @override
  Widget build(BuildContext context) {
    final scheduler = maybeRead<ReminderScheduler>(context);
    final inbox = maybeRead<InboxCubit>(context);
    // Always a Stack, so the toasts coming and going never remount the page.
    return _SaveErrors(
      inbox: inbox,
      child: Stack(
        fit: StackFit.expand,
        children: [
          child,
          if (scheduler != null && inbox != null)
            _Toasts(scheduler: scheduler, inbox: inbox),
        ],
      ),
    );
  }
}

/// Shows [InboxCubit.errors] as "Couldn't save — …" snackbars.
class _SaveErrors extends StatefulWidget {
  const _SaveErrors({required this.inbox, required this.child});

  final InboxCubit? inbox;
  final Widget child;

  @override
  State<_SaveErrors> createState() => _SaveErrorsState();
}

class _SaveErrorsState extends State<_SaveErrors> {
  StreamSubscription<String>? _sub;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void didUpdateWidget(_SaveErrors old) {
    super.didUpdateWidget(old);
    if (old.inbox != widget.inbox) {
      unawaited(_sub?.cancel());
      _listen();
    }
  }

  void _listen() {
    _sub = widget.inbox?.errors.listen((e) {
      if (!mounted) return;
      showInboxSnack(
        ScaffoldMessenger.maybeOf(context),
        context.l10n.inboxSaveFailed(e),
      );
    });
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _Toasts extends StatefulWidget {
  const _Toasts({required this.scheduler, required this.inbox});

  final ReminderScheduler scheduler;
  final InboxCubit inbox;

  @override
  State<_Toasts> createState() => _ToastsState();
}

class _ToastsState extends State<_Toasts> {
  late Stream<List<PendingReminder>> _pending = widget.scheduler.pending;

  @override
  void didUpdateWidget(_Toasts old) {
    super.didUpdateWidget(old);
    if (old.scheduler != widget.scheduler) _pending = widget.scheduler.pending;
  }

  void _open(InboxItem item, Iterable<String> keys) {
    keys.forEach(widget.scheduler.dismiss);
    unawaited(showInboxItemEditor(context, item: item));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PendingReminder>>(
      stream: _pending,
      initialData: widget.scheduler.currentPending,
      builder: (context, pending) => BlocBuilder<InboxCubit, InboxState>(
        bloc: widget.inbox,
        builder: (context, _) => _stack(context, pending.data ?? const []),
      ),
    );
  }

  Widget _stack(BuildContext context, List<PendingReminder> pending) {
    final items = {for (final i in widget.inbox.items) i.id: i};
    final live = [
      for (final e in pending)
        if (items[e.itemId] case final item?) (entry: e, item: item),
    ]..sort((a, b) => b.entry.fireAt.compareTo(a.entry.fireAt));
    final away = [
      for (final t in live)
        if (t.entry.catchUp) t,
    ];
    final scheduler = widget.scheduler;
    // Newest first; the away group takes the place of its newest entry.
    final cards = <Widget>[
      for (final t in live)
        if (!t.entry.catchUp)
          _ReminderToast(
            key: ValueKey(t.entry.key),
            item: t.item,
            onDone: t.item.isTask
                ? () {
                    widget.inbox.setDone(t.item.id, true);
                    scheduler.dismissItem(t.item.id);
                  }
                : null,
            onOpen: () => _open(t.item, [t.entry.key]),
            onDismiss: () => scheduler.dismiss(t.entry.key),
          )
        else if (t == away.first)
          _AwayToast(
            key: const ValueKey('away'),
            entries: away,
            onOpen: (t) => _open(t.item, [t.entry.key]),
            onDismiss: () {
              for (final t in away) {
                scheduler.dismiss(t.entry.key);
              }
            },
          ),
    ];
    if (cards.isEmpty) return const SizedBox.shrink();
    final shown = cards.take(ReminderToastHost.maxShown).toList();
    final more = cards.length - shown.length;
    final moreLabel = more > 0 ? _MoreLabel(count: more) : null;
    final wide = MediaQuery.sizeOf(context).width >= 840;
    // Newest nearest the screen edge the stack grows from.
    final column = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: Spacing.sm,
      children: wide ? [?moreLabel, ...shown.reversed] : [...shown, ?moreLabel],
    );
    return Positioned(
      right: Spacing.md,
      left: wide ? null : Spacing.md,
      bottom: wide ? Spacing.md : null,
      top: wide ? null : Spacing.xs,
      child: SafeArea(
        child: Semantics(
          container: true,
          label: context.l10n.inboxReminders,
          child: SizedBox(
            width: wide ? ReminderToastHost.width : null,
            child: column,
          ),
        ),
      ),
    );
  }
}

typedef _Live = ({PendingReminder entry, InboxItem item});

/// The white toast card.
class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: Radii.lgAll,
        boxShadow: MorkvaElevation.level3,
      ),
      child: Material(
        color: scheme.surfaceContainerLowest,
        borderRadius: Radii.lgAll,
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: Spacing.xs,
            horizontal: Spacing.xxs,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// The kind's glyph on a 32 px tile (task: carrot, note: the note yellow).
class _KindTile extends StatelessWidget {
  const _KindTile({required this.kind});

  final InboxKind? kind;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // The note's sand, as [InboxNoteGlyph].
    final sand = theme.brightness == Brightness.light
        ? CollectionTints.light[4]
        : CollectionTints.dark[4];
    final (icon, bg, fg) = switch (kind) {
      InboxKind.task => (
        MorkvaIcons.taskAlt,
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
      ),
      InboxKind.note => (
        MorkvaIcons.stickyNote,
        sand.background,
        sand.foreground,
      ),
      null => (
        MorkvaIcons.schedule,
        scheme.surfaceContainer,
        scheme.onSurfaceVariant,
      ),
    };
    return SizedBox.square(
      dimension: 44,
      child: Center(
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: fg),
        ),
      ),
    );
  }
}

class _DismissButton extends StatelessWidget {
  const _DismissButton({required this.onPressed, this.tooltip});

  final VoidCallback onPressed;

  /// Null: "Dismiss".
  final String? tooltip;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip ?? context.l10n.inboxDismiss,
    icon: const Icon(MorkvaIcons.close, size: 18),
    color: Theme.of(context).colorScheme.onSurfaceVariant,
    onPressed: onPressed,
  );
}

/// One fired reminder: kind tile, title, time and linked card; Done (tasks)
/// · Open · ×.
class _ReminderToast extends StatelessWidget {
  const _ReminderToast({
    super.key,
    required this.item,
    required this.onDone,
    required this.onOpen,
    required this.onDismiss,
  });

  final InboxItem item;
  final VoidCallback? onDone;
  final VoidCallback onOpen;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final minutes = itemMinutes(item);
    final link = item.link;
    return Semantics(
      container: true,
      liveRegion: true,
      label: l10n.inboxReminderFor(item.title),
      child: _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _KindTile(kind: item.kind),
                const SizedBox(width: Spacing.xxs),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: Spacing.xs),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (minutes != null || link != null)
                          Padding(
                            padding: const EdgeInsets.only(top: Spacing.xxs),
                            child: Row(
                              spacing: Spacing.xs,
                              children: [
                                if (minutes != null)
                                  Text(
                                    timeLabel(minutes),
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                if (link != null)
                                  Flexible(child: InboxLinkChip(link: link)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                _DismissButton(onPressed: onDismiss),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: Row(
                spacing: Spacing.xxs,
                children: [
                  if (onDone case final onDone?)
                    TextButton.icon(
                      // The check lines up with the title (44 + 4 px in).
                      style: TextButton.styleFrom(
                        padding: const EdgeInsetsDirectional.only(
                          start: Spacing.xs,
                          end: Spacing.sm,
                        ),
                      ),
                      onPressed: onDone,
                      icon: const Icon(MorkvaIcons.check, size: 16),
                      label: Text(l10n.inboxDone),
                    ),
                  TextButton(onPressed: onOpen, child: Text(l10n.commonOpen)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "3 reminders while you were away", listing them; a row opens its item.
class _AwayToast extends StatelessWidget {
  const _AwayToast({
    super.key,
    required this.entries,
    required this.onOpen,
    required this.onDismiss,
  });

  final List<_Live> entries;
  final ValueChanged<_Live> onOpen;
  final VoidCallback onDismiss;

  /// Rows listed before "+N more".
  static const int maxRows = 5;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final n = entries.length;
    final title = l10n.inboxRemindersAway(n);
    final now = DateTime.now();
    final meta = theme.textTheme.labelMedium?.copyWith(
      color: scheme.onSurfaceVariant,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Semantics(
      container: true,
      liveRegion: true,
      label: title,
      child: _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const _KindTile(kind: null),
                const SizedBox(width: Spacing.xxs),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _DismissButton(
                  onPressed: onDismiss,
                  tooltip: l10n.inboxDismissAll,
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, Spacing.xxs, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final t in entries.take(maxRows))
                    InkWell(
                      onTap: () => onOpen(t),
                      borderRadius: BorderRadius.circular(10),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 44),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Spacing.sm,
                          ),
                          child: Row(
                            spacing: 10,
                            children: [
                              // A circle-check, not the row checkbox: nothing to tick here.
                              Icon(
                                t.item.isTask
                                    ? MorkvaIcons.taskAlt
                                    : MorkvaIcons.stickyNote,
                                size: 16,
                                color: scheme.onSurfaceVariant,
                              ),
                              Expanded(
                                child: Text(
                                  t.item.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ),
                              Text(
                                _when(t.item, now, l10n, locale),
                                style: meta,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (n > maxRows)
                    Padding(
                      padding: const EdgeInsets.all(Spacing.sm),
                      child: Text(
                        l10n.inboxMoreCount(n - maxRows),
                        style: meta,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Today", "Sun 15 · 09:00".
String _when(
  InboxItem item,
  DateTime now,
  AppLocalizations l10n,
  String locale,
) {
  final day = item.day;
  return [
    if (day != null)
      day == localDay(now) ? l10n.commonToday : dayLabel(day, locale),
    if (itemMinutes(item) case final m?) timeLabel(m),
  ].join(' · ');
}

class _MoreLabel extends StatelessWidget {
  const _MoreLabel({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.sm,
          vertical: Spacing.xxs,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.inverseSurface,
          borderRadius: Radii.fullAll,
        ),
        child: Text(
          context.l10n.inboxMoreCount(count),
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onInverseSurface,
          ),
        ),
      ),
    );
  }
}
