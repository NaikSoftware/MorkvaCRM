import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
  return DateFormat(
    d.year == now.year ? 'd MMM' : 'd MMM y',
    locale,
  ).format(d);
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
      message: context.l10n.assistantDeleteThreadBody(
        t.titleIn(context.l10n),
      ),
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

    final children = <Widget>[];
    String? day;
    for (final t in shown) {
      final label = dayLabel(
        t.updatedAt,
        now,
        l10n: context.l10n,
        locale: Localizations.localeOf(context).toString(),
      );
      if (label != day) {
        day = label;
        children.add(_DayHeader(label));
      }
      children.add(
        _ThreadTile(
          thread: t,
          current: t.id == widget.currentId,
          enabled: !widget.disabled,
          onTap: () => widget.onSelect(t.id),
          onDelete: () => _confirmDelete(t),
        ),
      );
    }

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

class _DayHeader extends StatelessWidget {
  const _DayHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
    child: Semantics(
      header: true,
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.88,
        ),
      ),
    ),
  );
}

/// With a mouse, the delete button shows on hover or keyboard focus; on
/// touch-only screens it is always there.
class _ThreadTile extends StatefulWidget {
  const _ThreadTile({
    required this.thread,
    required this.current,
    required this.enabled,
    required this.onTap,
    required this.onDelete,
  });

  final ThreadSummary thread;
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
    final colors = AssistantColors.of(context);
    final _ThreadTile(:thread, :current, :enabled, :onTap, :onDelete) = widget;
    final time = clockTime(thread.updatedAt);
    final meta = thread.snippet == null ? time : '$time · ${thread.snippet}';
    final title = thread.titleIn(context.l10n);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Opacity(
          opacity: enabled ? 1 : 0.5,
          child: Container(
            decoration: BoxDecoration(
              color: current ? colors.panel : Colors.transparent,
              borderRadius: Radii.mdAll,
            ),
            child: Row(
              children: [
                Expanded(
                  child: PressableScale(
                    onPressed: enabled ? onTap : null,
                    semanticLabel: '$title, $meta',
                    borderRadius: Radii.mdAll,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 56),
                      child: Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          12,
                          8,
                          4,
                          8,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              meta,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                ListenableBuilder(
                  listenable: RendererBinding.instance.mouseTracker,
                  builder: (context, child) {
                    final shown =
                        _hovered ||
                        _focused ||
                        !RendererBinding.instance.mouseTracker.mouseIsConnected;
                    // Hidden: no pointer hits, but still in the focus order;
                    // focusing it reveals it.
                    return IgnorePointer(
                      ignoring: !shown,
                      child: AnimatedOpacity(
                        opacity: shown ? 1 : 0,
                        duration: MotionDurations.fast,
                        child: child,
                      ),
                    );
                  },
                  child: Focus(
                    canRequestFocus: false,
                    skipTraversal: true,
                    onFocusChange: (f) => setState(() => _focused = f),
                    child: IconActionButton(
                      icon: Icons.delete_outline_rounded,
                      tooltip: context.l10n.assistantDeleteThreadTooltip(title),
                      onPressed: enabled ? onDelete : null,
                    ),
                  ),
                ),
              ],
            ),
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
    child: EmptyState(
      icon: Icons.forum_outlined,
      title: title,
      message: message,
    ),
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
