import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../design/design.dart';
import '../../../l10n/l10n.dart';
import 'widgets/assistant_header.dart';
import 'widgets/assistant_scope.dart';
import 'widgets/limit_banner.dart' show clockTime;

/// A conversation in the history list, read from the thread-meta record
/// `ThreadRepository.watchThreads` emits (`{id, title, updatedAt,
/// lastSnippet, …}`, ISO UTC dates).
@immutable
class ThreadSummary {
  const ThreadSummary({
    required this.id,
    required this.title,
    required this.updatedAt,
    this.snippet,
    this.untitled = false,
  });

  /// Throws [FormatException] without an `id`; a bad date reads as epoch.
  factory ThreadSummary.fromRecord(Map<String, Object?> record) {
    final id = record['id'];
    if (id is! String || id.isEmpty) {
      throw const FormatException('A thread record needs an "id"');
    }
    final title = record['title'];
    final updated = record['updatedAt'] ?? record['createdAt'];
    final snippet = record['lastSnippet'];
    final named = title is String && title.trim().isNotEmpty;
    return ThreadSummary(
      id: id,
      title: named ? title.trim() : 'New conversation',
      untitled: !named,
      updatedAt:
          (updated is String ? DateTime.tryParse(updated) : null)?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      snippet: snippet is String && snippet.trim().isNotEmpty
          ? snippet.trim()
          : null,
    );
  }

  final String id;
  final String title;
  final DateTime updatedAt;

  /// "3 changes applied", "chart".
  final String? snippet;

  /// The record had no title: [title] is the English placeholder.
  final bool untitled;

  /// [title], or "New conversation" in [l10n]'s language.
  String titleIn(AppLocalizations l10n) =>
      untitled ? l10n.assistantNewConversation : title;
}

/// "Today", "Yesterday", "3 Nov" (with the year when it differs); English
/// without [l10n], the date in [locale] (default: `Intl.defaultLocale`).
String dayLabel(
  DateTime day,
  DateTime now, {
  AppLocalizations? l10n,
  String? locale,
}) {
  final t = l10n ?? lookupAppLocalizations(const Locale('en'));
  final d = DateTime(day.year, day.month, day.day);
  final today = DateTime(now.year, now.month, now.day);
  final diff = today.difference(d).inDays;
  if (diff == 0) return t.commonToday;
  if (diff == 1) return t.commonYesterday;
  return DateFormat(d.year == now.year ? 'd MMM' : 'd MMM y', locale).format(d);
}

/// The conversation list: search, grouped by day, delete with a confirm,
/// "No conversations yet" when empty. While changes apply ([disabled]) the
/// list is read-only.
class ThreadListView extends StatefulWidget {
  const ThreadListView({
    super.key,
    required this.threads,
    required this.onSelect,
    required this.onDelete,
    this.currentId,
    this.loading = false,
    this.disabled = false,
    this.now = DateTime.now,
  });

  final List<ThreadSummary> threads;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onDelete;

  /// The open conversation, raised on a white tile.
  final String? currentId;
  final bool loading;

  /// "Applying changes…": switching would interrupt the write.
  final bool disabled;
  final DateTime Function() now;

  @override
  State<ThreadListView> createState() => _ThreadListViewState();
}

class _ThreadListViewState extends State<ThreadListView> {
  String _query = '';

  Future<void> _confirmDelete(ThreadSummary t) async {
    final ok = await MorkvaConfirmDialog.show(
      context,
      title: context.l10n.assistantDeleteThreadTitle,
      message: context.l10n.assistantDeleteThreadBody(t.titleIn(context.l10n)),
      confirmLabel: context.l10n.commonDelete,
      destructive: true,
    );
    if (ok == true) widget.onDelete(t.id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final q = _query.trim().toLowerCase();
    final shown = [
      for (final t in widget.threads)
        if (q.isEmpty ||
            t.titleIn(context.l10n).toLowerCase().contains(q) ||
            (t.snippet?.toLowerCase().contains(q) ?? false))
          t,
    ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final now = widget.now();

    // Newest first, so each day's threads are contiguous.
    final days = <String, List<ThreadSummary>>{};
    for (final t in shown) {
      final label = dayLabel(
        t.updatedAt,
        now,
        l10n: context.l10n,
        locale: Localizations.localeOf(context).toString(),
      );
      (days[label] ??= []).add(t);
    }
    final children = <Widget>[
      for (final MapEntry(key: label, value: threads) in days.entries) ...[
        _DayHeader(label, threads.length),
        _DayCard([
          for (final (i, t) in threads.indexed)
            _ThreadTile(
              thread: t,
              divider: i > 0,
              current: t.id == widget.currentId,
              enabled: !widget.disabled,
              onTap: () => widget.onSelect(t.id),
              onDelete: () => _confirmDelete(t),
            ),
        ]),
      ],
    ];

    final Widget body;
    if (widget.loading) {
      body = const Padding(
        padding: EdgeInsets.only(top: Spacing.xl),
        child: LoadingIndicator(),
      );
    } else if (widget.threads.isEmpty) {
      body = _Empty(
        context.l10n.assistantNoThreads,
        context.l10n.assistantNoThreadsBody,
      );
    } else if (shown.isEmpty) {
      body = _Empty(
        context.l10n.assistantNothingFound,
        context.l10n.assistantNoThreadsMatch(_query),
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
    }

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        if (widget.disabled)
          Padding(
            padding: const EdgeInsets.only(bottom: Spacing.xs),
            child: Text(
              context.l10n.assistantApplyingSwitchLater,
              style: theme.textTheme.bodySmall,
            ),
          ),
        if (widget.threads.isNotEmpty)
          SearchField(
            dense: true,
            hintText: context.l10n.assistantSearchThreads,
            onChanged: (v) => setState(() => _query = v),
          ),
        body,
      ],
    );
  }
}

/// "TODAY  3 ————": the day, its conversation count and a rule to the edge.
class _DayHeader extends StatelessWidget {
  const _DayHeader(this.label, this.count);

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelSmall?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: 0.88,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, Spacing.md, 4, Spacing.xs),
      child: Semantics(
        header: true,
        label: context.l10n.assistantDayThreads(label, count),
        child: ExcludeSemantics(
          child: Row(
            children: [
              Text(label.toUpperCase(), style: style),
              const SizedBox(width: Spacing.xs),
              Text(
                '$count',
                style: style?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: Spacing.xs),
              Expanded(
                child: Container(
                  height: 1,
                  color: theme.colorScheme.outlineVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One day's conversations on a card.
class _DayCard extends StatelessWidget {
  const _DayCard(this.tiles);

  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = AssistantColors.of(context);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: colors.panel, borderRadius: Radii.lgAll),
      // In front, so a washed first or last row can't paint over the
      // outline's rounded corners.
      foregroundDecoration: BoxDecoration(
        // Light `border` is too faint against the paper canvas.
        border: Border.all(
          color: scheme.brightness == Brightness.dark
              ? colors.border
              : scheme.outlineVariant,
        ),
        borderRadius: Radii.lgAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: tiles,
      ),
    );
  }
}

/// The time sits at the end; with a mouse, hover or keyboard focus swaps it
/// for the delete button. On touch, a long press asks to delete.
class _ThreadTile extends StatefulWidget {
  const _ThreadTile({
    required this.thread,
    required this.divider,
    required this.current,
    required this.enabled,
    required this.onTap,
    required this.onDelete,
  });

  final ThreadSummary thread;

  /// A rule above the row, inset to the title. Drawn on the row's own fill
  /// so two washed rows don't show a card-coloured notch between them.
  final bool divider;
  final bool current;
  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  State<_ThreadTile> createState() => _ThreadTileState();
}

class _ThreadTileState extends State<_ThreadTile> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = AssistantColors.of(context);
    final _ThreadTile(
      :thread,
      :divider,
      :current,
      :enabled,
      :onTap,
      :onDelete,
    ) = widget;
    final time = clockTime(thread.updatedAt);
    final snippet = thread.snippet;
    final meta = snippet == null ? time : '$time · $snippet';
    final title = thread.titleIn(context.l10n);
    final hovered = _hovered && enabled;
    // Touch has no hover: a long press on the row asks to delete instead.
    final showDelete = _hovered || _focused;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: AnimatedContainer(
          duration: MotionDurations.fast,
          color: current
              ? colors.objectChip
              : hovered
              // A neutral state layer, so hover never reads as "current".
              ? Color.alphaBlend(
                  scheme.onSurface.withValues(alpha: 0.04),
                  colors.panel,
                )
              : colors.panel,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (divider)
                Container(
                  height: 1,
                  // Aligned with the title.
                  margin: const EdgeInsetsDirectional.only(start: 16),
                  color: scheme.outlineVariant,
                ),
              Row(
                children: [
                  Expanded(
                    child: PressableScale(
                      onPressed: enabled ? onTap : null,
                      onLongPress: onDelete,
                      semanticLabel: '$title, $meta',
                      child: ExcludeSemantics(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 56),
                          child: Padding(
                            padding: const EdgeInsetsDirectional.fromSTEB(
                              16,
                              10,
                              8,
                              10,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleSmall,
                                ),
                                if (snippet != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    snippet,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // The time, swapped for the delete button on hover or
                  // keyboard focus. Hidden, the button takes no pointer hits
                  // but stays in the focus order; focusing it reveals it.
                  Stack(
                    alignment: AlignmentDirectional.centerEnd,
                    children: [
                      IgnorePointer(
                        child: AnimatedOpacity(
                          opacity: showDelete ? 0 : 1,
                          duration: MotionDurations.fast,
                          child: Padding(
                            // Mirrors the title's 16 px inset with the 4 below.
                            padding: const EdgeInsetsDirectional.only(end: 12),
                            child: ExcludeSemantics(
                              child: Text(
                                time,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      IgnorePointer(
                        ignoring: !showDelete,
                        child: AnimatedOpacity(
                          opacity: showDelete ? 1 : 0,
                          duration: MotionDurations.fast,
                          child: Focus(
                            canRequestFocus: false,
                            skipTraversal: true,
                            onFocusChange: (f) => setState(() => _focused = f),
                            child: IconActionButton(
                              icon: MorkvaIcons.delete,
                              tooltip: context.l10n
                                  .assistantDeleteThreadTooltip(title),
                              onPressed: enabled ? onDelete : null,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.title, this.message);

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: Spacing.xl),
    child: EmptyState(icon: MorkvaIcons.forum, title: title, message: message),
  );
}

/// The phone history route (`/assistant/history`): the conversation list
/// full screen under a back arrow.
class ThreadListPage extends StatelessWidget {
  const ThreadListPage({
    super.key,
    required this.threads,
    required this.onSelect,
    required this.onDelete,
    required this.onBack,
    this.currentId,
    this.loading = false,
    this.disabled = false,
    this.now = DateTime.now,
  });

  final List<ThreadSummary> threads;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onDelete;
  final VoidCallback onBack;
  final String? currentId;
  final bool loading;
  final bool disabled;
  final DateTime Function() now;

  @override
  Widget build(BuildContext context) {
    final colors = AssistantColors.of(context);
    return Scaffold(
      backgroundColor: colors.canvas,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AssistantHeader(
              subtitle: context.l10n.assistantConversations,
              onBack: onBack,
            ),
            Expanded(
              child: ThreadListView(
                threads: threads,
                onSelect: onSelect,
                onDelete: onDelete,
                currentId: currentId,
                loading: loading,
                disabled: disabled,
                now: now,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
