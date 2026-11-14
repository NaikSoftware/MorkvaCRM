import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/shell/app_shell.dart';
import '../../../core/domain/inbox/inbox.dart';
import '../../../design/design.dart';
import '../../../l10n/l10n.dart';
import '../bloc/inbox_cubit.dart';
import '../bloc/inbox_page_cubit.dart';
import '../reminders/reminder_scheduler.dart';
import 'card_link_picker.dart';
import 'inbox_chips.dart';
import 'inbox_format.dart';
import 'inbox_item_editor.dart';
import 'inbox_kind_glyph.dart';
import 'inbox_link_chip.dart';
import 'week_strip.dart';

/// The Inbox content column's width.
const double kInboxColumnWidth = 760;

/// The Inbox page (`/inbox?day=yyyy-MM-dd&item=<id>`): the week strip, the
/// composer and the selected day's sections (spec §4). [day] selects a day;
/// [itemId] opens that item's editor once the items load (an unknown id
/// opens nothing).
///
/// [now] and [notifier] are for tests (the clock; the browser's
/// notification permission for the editor).
class InboxPage extends StatelessWidget {
  const InboxPage({
    super.key,
    this.day,
    this.itemId,
    this.now = DateTime.now,
    this.notifier,
  });

  final DateTime? day;
  final String? itemId;
  final DateTime Function() now;
  final SystemNotifier? notifier;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => InboxPageCubit(day: day, now: now),
    child: _InboxView(day: day, itemId: itemId, now: now, notifier: notifier),
  );
}

class _InboxView extends StatefulWidget {
  const _InboxView({
    required this.day,
    required this.itemId,
    required this.now,
    required this.notifier,
  });

  final DateTime? day;
  final String? itemId;
  final DateTime Function() now;
  final SystemNotifier? notifier;

  @override
  State<_InboxView> createState() => _InboxViewState();
}

class _InboxViewState extends State<_InboxView> {
  /// The `itemId` whose editor was opened (or the server says is unknown).
  String? _handledItemId;

  @override
  void initState() {
    super.initState();
    _openItem(context.read<InboxCubit>().state);
  }

  @override
  void didUpdateWidget(_InboxView old) {
    super.didUpdateWidget(old);
    final day = widget.day;
    if (day != null && day != old.day) {
      context.read<InboxPageCubit>().selectDay(day);
    }
    if (widget.itemId != old.itemId) {
      _handledItemId = null;
      _openItem(context.read<InboxCubit>().state);
    }
  }

  void _openItem(InboxState state) {
    final id = widget.itemId;
    if (id == null || id == _handledItemId || state is! InboxReady) return;
    final item = state.items.where((i) => i.id == id).firstOrNull;
    // The cache may not have it yet: wait for the server's list.
    if (item == null && state.fromCache) return;
    _handledItemId = id;
    if (item == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_editor(item).whenComplete(() => _dropItemParam(id)));
    });
  }

  void _edit(InboxItem item) => unawaited(_editor(item));

  Future<void> _editor(InboxItem item) => showInboxItemEditor(
    context,
    item: item,
    now: widget.now,
    notifier: widget.notifier,
  );

  /// Takes the handled `item` out of the location (in place, no history
  /// entry), so the same link or notification opens it again.
  void _dropItemParam(String id) {
    if (!mounted) return;
    final router = GoRouter.maybeOf(context);
    if (router == null) return;
    final uri = router.routerDelegate.currentConfiguration.uri;
    // Only while this page's linked location is still the current one.
    if (uri.path != GoRouterState.of(context).uri.path ||
        uri.queryParameters['item'] != id) {
      return;
    }
    final params = {...uri.queryParameters}..remove('item');
    final location = Uri(
      path: uri.path,
      queryParameters: params.isEmpty ? null : params,
    );
    Router.neglect(context, () => router.go(location.toString()));
  }

  void _setDone(InboxItem item, bool done) {
    final inbox = context.read<InboxCubit>();
    inbox.setDone(item.id, done);
    if (done) {
      showInboxSnack(
        ScaffoldMessenger.maybeOf(context),
        context.l10n.inboxDone,
        onUndo: () => inbox.setDone(item.id, false),
      );
    }
  }

  void _moveAllToToday() {
    final inbox = context.read<InboxCubit>();
    final previous = inbox.moveAllOverdueToToday();
    if (previous.isEmpty) return;
    showInboxSnack(
      ScaffoldMessenger.maybeOf(context),
      context.l10n.inboxMovedToToday(previous.length),
      onUndo: () => inbox.restoreDueAts(previous),
    );
  }

  @override
  Widget build(BuildContext context) {
    final compact =
        MediaQuery.sizeOf(context).width < AppShell.expandedBreakpoint;
    final gutter = compact ? Spacing.md : Spacing.xxl;
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return BlocListener<InboxCubit, InboxState>(
      listener: (_, state) => _openItem(state),
      child: Material(
        type: MaterialType.transparency,
        child: CollectionsWatcher(
          builder: (context, _) {
            final inboxState = context.watch<InboxCubit>().state;
            final page = context.watch<InboxPageCubit>().state;
            final items = switch (inboxState) {
              InboxReady(:final items) => items,
              _ => const <InboxItem>[],
            };
            return ListView(
              padding: EdgeInsets.fromLTRB(
                gutter,
                compact ? Spacing.xs : Spacing.lg,
                gutter,
                Spacing.xxl,
              ),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: kInboxColumnWidth,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!compact) ...[
                          Text(
                            l10n.inboxTitle,
                            style: theme.textTheme.headlineSmall,
                          ),
                          const SizedBox(height: Spacing.md),
                        ],
                        WeekStrip(
                          selected: page.day,
                          today: localDay(widget.now()),
                          dots: dotsByDay(items),
                          compact: compact,
                          onSelect: context.read<InboxPageCubit>().selectDay,
                        ),
                        const SizedBox(height: Spacing.md),
                        _Composer(compact: compact),
                        const SizedBox(height: Spacing.sm),
                        ...switch (inboxState) {
                          InboxLoading() => [
                            const Padding(
                              padding: EdgeInsets.all(Spacing.xl),
                              child: LoadingIndicator(),
                            ),
                          ],
                          InboxFailed() => [
                            _LoadError(
                              onRetry: context.read<InboxCubit>().retry,
                            ),
                          ],
                          InboxReady(:final items) when items.isEmpty => [
                            Padding(
                              padding: const EdgeInsets.only(top: Spacing.xl),
                              child: EmptyState(
                                icon: Icons.inbox_outlined,
                                title: l10n.inboxEmptyTitle,
                                message: l10n.inboxEmptyMessage,
                              ),
                            ),
                          ],
                          InboxReady(:final items) => [
                            _Sections(
                              sections: InboxSections.of(
                                items,
                                day: page.day,
                                now: widget.now(),
                              ),
                              day: page.day,
                              today: localDay(widget.now()),
                              now: widget.now(),
                              compact: compact,
                              onOpen: _edit,
                              onDone: _setDone,
                              onMoveAll: _moveAllToToday,
                            ),
                          ],
                        },
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.lg),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: theme.colorScheme.error),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Text(
              l10n.inboxLoadFailed,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          TextActionButton(label: l10n.commonRetry, onPressed: onRetry),
        ],
      ),
    );
  }
}

/// The one-line capture: the kind toggle, the title field and, while in
/// use, the date · time · reminder · link chips. Enter adds and keeps
/// focus.
class _Composer extends StatefulWidget {
  const _Composer({required this.compact});

  final bool compact;

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  final _text = TextEditingController();
  final _focus = FocusNode(debugLabel: 'Inbox composer');

  /// A chip's menu or picker is open: the chips stay although the field
  /// lost focus to it.
  var _busy = 0;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  InboxPageCubit get _page => context.read<InboxPageCubit>();

  void _add() {
    final uid = inboxUid(context);
    if (uid == null) return;
    final inbox = context.read<InboxCubit>();
    final item = _page.create(title: _text.text, id: inbox.newId(), uid: uid);
    if (item == null) return;
    inbox.add(item);
    _text.clear();
    _focus.requestFocus();
  }

  /// Keeps the chips up while [action] (a menu or picker) runs, then gives
  /// the field its focus back.
  Future<void> _hold(Future<void> Function() action) async {
    setState(() => _busy++);
    try {
      await action();
    } finally {
      if (mounted) {
        setState(() => _busy--);
        _focus.requestFocus();
      }
    }
  }

  Future<void> _pickDate() => _hold(() async {
    final current = _page.state.composerDate ?? _page.state.today;
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(current.year - 10),
      lastDate: DateTime(current.year + 10, 12, 31),
      builder: (_, child) => MondayFirst(child: child!),
    );
    if (picked != null) _page.setDate(picked);
  });

  Future<void> _pickTime() => _hold(() async {
    final m = _page.state.composer.minutes ?? 9 * 60;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: m ~/ 60, minute: m % 60),
    );
    if (picked != null) _page.setMinutes(picked.hour * 60 + picked.minute);
  });

  Future<void> _pickLink() => _hold(() async {
    final link = await showCardLinkPicker(context);
    if (link != null) _page.setLink(link);
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final state = context.watch<InboxPageCubit>().state;
    final draft = state.composer;
    final date = draft.date;
    final isTask = draft.kind == InboxKind.task;
    final placeholder = !isTask
        ? l10n.inboxAddNote
        : date == null
        ? l10n.inboxAddTask
        : date == state.today && state.day != state.today
        ? l10n.inboxAddTaskToday
        : l10n.inboxAddTaskFor(dayLabel(date, locale));
    final focused = _focus.hasFocus;
    final showChips =
        focused ||
        _busy > 0 ||
        _text.text.isNotEmpty ||
        state.dateTouched ||
        draft.minutes != null ||
        draft.reminders.isNotEmpty ||
        draft.link != null;

    return TextFieldTapRegion(
      child: AnimatedContainer(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : MotionDurations.fast,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          borderRadius: Radii.lgAll,
          boxShadow: MorkvaElevation.level1,
          border: Border.all(
            color: focused ? scheme.primary : Colors.transparent,
            width: 2,
          ),
        ),
        padding: const EdgeInsets.fromLTRB(4, 4, Spacing.sm, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox.square(
                  dimension: 44,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    tooltip: isTask
                        ? l10n.inboxTaskSwitchToNote
                        : l10n.inboxNoteSwitchToTask,
                    onPressed: _page.toggleKind,
                    icon: InboxKindGlyph(kind: draft.kind),
                  ),
                ),
                const SizedBox(width: Spacing.xxs),
                Expanded(
                  child: TextField(
                    controller: _text,
                    focusNode: _focus,
                    maxLength: InboxItem.titleMax,
                    textInputAction: TextInputAction.done,
                    style: theme.textTheme.bodyLarge?.copyWith(fontSize: 15),
                    decoration: InputDecoration(
                      hintText: placeholder,
                      hintStyle: theme.textTheme.bodyLarge?.copyWith(
                        fontSize: 15,
                        color: scheme.onSurfaceVariant,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      counterText: '',
                      isDense: true,
                    ),
                    onSubmitted: (_) => _add(),
                    // Non-null: Enter keeps the focus for the next item.
                    onEditingComplete: () {},
                  ),
                ),
              ],
            ),
            if (showChips)
              Padding(
                padding: const EdgeInsets.only(left: 48),
                child: Wrap(
                  spacing: Spacing.xxs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _dateChip(state, date, l10n, locale),
                    InboxChip(
                      icon: Icons.schedule,
                      label: draft.minutes == null
                          ? null
                          : timeLabel(draft.minutes!),
                      outlined: draft.minutes == null,
                      tooltip: date == null
                          ? l10n.inboxSetDateForTime
                          : draft.minutes == null
                          ? l10n.inboxTime
                          : null,
                      onPressed: date == null ? null : _pickTime,
                      onClear: draft.minutes == null
                          ? null
                          : () => _page.setMinutes(null),
                      clearTooltip: l10n.inboxClearTime,
                    ),
                    _reminderChip(draft, l10n),
                    if (draft.link case final link?)
                      InboxLinkChip(
                        link: link,
                        compact: widget.compact,
                        onTap: _pickLink,
                        onClear: () => _page.setLink(null),
                      )
                    else
                      InboxChip(
                        icon: Icons.link,
                        outlined: true,
                        tooltip: l10n.inboxLinkCard,
                        onPressed: _pickLink,
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _dateChip(
    InboxPageState state,
    DateTime? date,
    AppLocalizations l10n,
    String locale,
  ) {
    final now = _page.now;
    return MenuAnchor(
      onOpen: () => setState(() => _busy++),
      onClose: () {
        if (!mounted) return;
        setState(() => _busy--);
      },
      menuChildren: [
        for (final (label, day) in [
          (l10n.commonToday, InboxDatePresets.today(now)),
          (l10n.inboxTomorrow, InboxDatePresets.tomorrow(now)),
          (l10n.inboxNextMonday, InboxDatePresets.nextMonday(now)),
        ])
          MenuItemButton(
            onPressed: () => _page.setDate(day),
            trailingIcon: Text(dayLabel(day, locale)),
            child: Text(label),
          ),
        MenuItemButton(onPressed: _pickDate, child: Text(l10n.inboxPickDate)),
      ],
      builder: (context, controller, _) => InboxChip(
        icon: Icons.calendar_today_outlined,
        label: date == null ? null : dayLabel(date, locale),
        outlined: date == null,
        tooltip: date == null ? l10n.inboxDate : null,
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
        onClear: date == null ? null : () => _page.setDate(null),
        clearTooltip: l10n.inboxNoDate,
      ),
    );
  }

  Widget _reminderChip(InboxDraft draft, AppLocalizations l10n) {
    final reminders = draft.reminders;
    final enabled = draft.date != null;
    return MenuAnchor(
      onOpen: () => setState(() => _busy++),
      onClose: () {
        if (!mounted) return;
        setState(() => _busy--);
      },
      menuChildren: [
        for (final r in InboxReminders.presetsFor(allDay: draft.allDay))
          MenuItemButton(
            closeOnActivate: false,
            leadingIcon: Icon(
              reminders.contains(r) ? Icons.check : null,
              size: 18,
            ),
            onPressed:
                reminders.contains(r) || reminders.length < InboxReminders.max
                ? () => _page.toggleReminder(r)
                : null,
            child: Text(reminderLabel(l10n, r)),
          ),
      ],
      builder: (context, controller, _) => InboxChip(
        icon: Icons.notifications_none,
        label: reminders.isEmpty
            ? null
            : '${reminderLabel(l10n, reminders.first, short: true)}'
                  '${reminders.length > 1 ? ' +${reminders.length - 1}' : ''}',
        outlined: reminders.isEmpty,
        tooltip: enabled
            ? (reminders.isEmpty ? l10n.inboxReminder : null)
            : l10n.inboxSetDateForReminder,
        onPressed: enabled
            ? () => controller.isOpen ? controller.close() : controller.open()
            : null,
        onClear: reminders.isEmpty
            ? null
            : () {
                for (final r in reminders) {
                  _page.toggleReminder(r);
                }
              },
        clearTooltip: l10n.inboxNoReminders,
      ),
    );
  }
}

/// Overdue · the day · No date · Completed.
class _Sections extends StatefulWidget {
  const _Sections({
    required this.sections,
    required this.day,
    required this.today,
    required this.now,
    required this.compact,
    required this.onOpen,
    required this.onDone,
    required this.onMoveAll,
  });

  final InboxSections sections;
  final DateTime day;
  final DateTime today;
  final DateTime now;
  final bool compact;
  final ValueChanged<InboxItem> onOpen;
  final void Function(InboxItem item, bool done) onDone;
  final VoidCallback onMoveAll;

  @override
  State<_Sections> createState() => _SectionsState();
}

class _SectionsState extends State<_Sections> {
  var _noDateOpen = true;
  var _completedOpen = false;

  Widget _row(InboxItem item, {int? daysLate, bool timeColumn = false}) =>
      _ItemRow(
        item: item,
        daysLate: daysLate,
        timeColumn: timeColumn,
        now: widget.now,
        compact: widget.compact,
        onOpen: () => widget.onOpen(item),
        onDone: (done) => widget.onDone(item, done),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.l10n;
    final s = widget.sections;
    final isToday = widget.day == widget.today;
    final dayName = isToday
        ? l10n.commonToday
        : dayLabel(widget.day, Localizations.localeOf(context).toString());
    final timed = s.day.any((i) => !i.allDay);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (s.overdue.isNotEmpty) ...[
          _SectionHeader(
            caption: l10n.inboxOverdue,
            count: s.overdue.length,
            color: scheme.error,
            trailing: TextButton(
              style: TextButton.styleFrom(
                foregroundColor: theme
                    .extension<MorkvaSemanticColors>()
                    ?.primaryText,
                minimumSize: const Size(44, 44),
                textStyle: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: widget.onMoveAll,
              child: Text(l10n.inboxMoveAllToToday),
            ),
          ),
          _RowList([
            for (final (:item, :daysLate) in s.overdue)
              _row(item, daysLate: daysLate),
          ]),
        ],
        _SectionHeader(
          caption: dayName,
          count: s.day.length,
          color: isToday
              ? theme.extension<MorkvaSemanticColors>()?.primaryText
              : null,
        ),
        if (s.day.isEmpty)
          _QuietLine(
            isToday ? l10n.inboxNothingForToday : l10n.inboxNothingFor(dayName),
          )
        else
          _RowList([for (final i in s.day) _row(i, timeColumn: timed)]),
        if (s.noDate.isNotEmpty) ...[
          _SectionHeader(
            caption: l10n.inboxNoDate,
            count: s.noDate.length,
            open: _noDateOpen,
            onToggle: () => setState(() => _noDateOpen = !_noDateOpen),
          ),
          if (_noDateOpen) _RowList([for (final i in s.noDate) _row(i)]),
        ],
        if (s.completed.isNotEmpty) ...[
          _SectionHeader(
            caption: l10n.inboxCompleted,
            count: s.completed.length,
            open: _completedOpen,
            onToggle: () => setState(() => _completedOpen = !_completedOpen),
          ),
          if (_completedOpen) _RowList([for (final i in s.completed) _row(i)]),
        ],
      ],
    );
  }
}

/// A 44 px caps caption ("OVERDUE · 2"); [onToggle] makes it a collapse
/// button with the chevron on the left.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.caption,
    required this.count,
    this.color,
    this.trailing,
    this.open,
    this.onToggle,
  });

  final String caption;
  final int count;
  final Color? color;
  final Widget? trailing;
  final bool? open;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink = color ?? theme.colorScheme.onSurfaceVariant;
    final style = theme.textTheme.labelMedium?.copyWith(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.6,
      color: ink,
    );
    final text = Text.rich(
      TextSpan(
        children: [
          TextSpan(text: caption.toUpperCase()),
          if (count > 0)
            TextSpan(
              text: ' · $count',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
        ],
      ),
      style: style,
    );
    final open = this.open;
    final toggle = onToggle;
    final label = toggle == null || open == null
        ? Padding(
            padding: const EdgeInsets.only(left: Spacing.sm),
            child: Semantics(header: true, child: text),
          )
        : Semantics(
            header: true,
            expanded: open,
            child: InkWell(
              borderRadius: Radii.mdAll,
              onTap: toggle,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Spacing.xs,
                  0,
                  Spacing.sm,
                  0,
                ),
                child: SizedBox(
                  height: 44,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        open ? Icons.expand_more : Icons.chevron_right,
                        size: 18,
                        color: ink,
                      ),
                      const SizedBox(width: 6),
                      text,
                    ],
                  ),
                ),
              ),
            ),
          );
    return Padding(
      padding: const EdgeInsets.only(top: Spacing.sm),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Row(children: [label, const Spacer(), ?trailing]),
      ),
    );
  }
}

class _QuietLine extends StatelessWidget {
  const _QuietLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
      decoration: BoxDecoration(
        borderRadius: Radii.lgAll,
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// A raised list card with 1 px dividers between [rows].
class _RowList extends StatelessWidget {
  const _RowList(this.rows);

  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: const BoxDecoration(
        borderRadius: Radii.lgAll,
        boxShadow: MorkvaElevation.level1,
      ),
      child: Material(
        color: scheme.surfaceContainerLowest,
        borderRadius: Radii.lgAll,
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) Divider(height: 1, color: scheme.surfaceContainer),
              rows[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// One item: leading control · time · title · meta · link chip (phone:
/// meta under the title). Tapping the row opens the editor.
class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.item,
    required this.daysLate,
    required this.timeColumn,
    required this.now,
    required this.compact,
    required this.onOpen,
    required this.onDone,
  });

  final InboxItem item;
  final int? daysLate;

  /// Reserve the 44 px time column (the day section has a timed item).
  final bool timeColumn;
  final DateTime now;
  final bool compact;
  final VoidCallback onOpen;
  final ValueChanged<bool> onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.l10n;
    final minutes = daysLate == null ? itemMinutes(item) : null;
    final late = minutes != null && item.isOpen && item.dueAt!.isBefore(now);
    final metaStyle = theme.textTheme.labelMedium?.copyWith(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: scheme.onSurfaceVariant,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final reminders = item.dueAt == null ? const <int>[] : item.reminders;
    final meta = <Widget>[
      if (daysLate case final d?)
        Text(
          l10n.inboxDaysLate(d),
          style: metaStyle?.copyWith(color: scheme.error),
        ),
      if (reminders.isNotEmpty)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_none,
              size: 14,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 2),
            Text(
              '${reminderLabel(l10n, reminders.first, short: true)}'
              '${reminders.length > 1 ? ' +${reminders.length - 1}' : ''}',
              style: metaStyle,
            ),
          ],
        ),
    ];

    final lead = SizedBox.square(
      dimension: 44,
      child: item.isTask
          ? IconButton(
              tooltip: item.done ? l10n.inboxMarkNotDone : l10n.inboxMarkDone,
              onPressed: () => onDone(!item.done),
              icon: InboxTaskCircle(done: item.done),
            )
          : const Center(child: InboxNoteGlyph()),
    );
    final time = minutes == null
        ? null
        : Text(
            timeLabel(minutes),
            style: theme.textTheme.labelLarge?.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: late ? scheme.error : scheme.onSurface,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          );
    final title = Text(
      item.title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodyMedium?.copyWith(
        fontSize: compact ? 15 : 14,
        fontWeight: FontWeight.w500,
        color: item.done ? scheme.onSurfaceVariant : scheme.onSurface,
        decoration: item.done ? TextDecoration.lineThrough : null,
      ),
    );
    final link = item.link == null
        ? null
        // Capped so a long label never squeezes the title away.
        : ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: InboxLinkChip(link: item.link!, compact: compact),
          );

    final Widget body;
    if (compact) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (time != null) ...[time, const SizedBox(width: 6)],
              Expanded(child: title),
            ],
          ),
          if (meta.isNotEmpty) Wrap(spacing: Spacing.xs, children: meta),
        ],
      );
    } else {
      body = Row(
        children: [
          if (timeColumn || time != null) SizedBox(width: 48, child: time),
          Expanded(child: title),
          for (final m in meta)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Spacing.xxs),
              child: m,
            ),
        ],
      );
    }
    return InkWell(
      onTap: onOpen,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(2, 2, Spacing.xs, 2),
          child: Row(
            children: [
              lead,
              const SizedBox(width: Spacing.xxs),
              Expanded(child: body),
              ?link,
            ],
          ),
        ),
      ),
    );
  }
}
