import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../api/auth/auth_cubit.dart';
import '../../../app/shell/app_shell.dart';
import '../../../core/domain/inbox/inbox.dart';
import '../../../design/design.dart';
import '../../../l10n/l10n.dart';
import '../bloc/inbox_cubit.dart';
import '../bloc/inbox_page_cubit.dart';
import '../reminders/reminder_platform.dart';
import '../reminders/reminder_scheduler.dart';
import 'card_link_picker.dart';
import 'inbox_chips.dart';
import 'inbox_format.dart';
import 'inbox_kind_glyph.dart';
import 'inbox_link_chip.dart';

/// The editor dialog's width on wide screens.
const double kInboxEditorMaxWidth = 480;

/// How much of the page shows above the phone editor sheet.
const double _sheetPeek = 40;

/// The signed-in member's uid, or null when signed out.
String? inboxUid(BuildContext context) =>
    switch (context.read<AuthCubit?>()?.state) {
      AuthAuthenticated(:final user) => user.uid,
      _ => null,
    };

/// Opens the Inbox item editor: [item] to edit, or a new item of [kind]
/// pre-linked to [link] and dated [day] (a local calendar day). A 480 px
/// dialog on wide screens, a near-full-height root bottom sheet on phones.
///
/// [now] and [notifier] are for tests (the clock; the browser's
/// notification permission).
Future<void> showInboxItemEditor(
  BuildContext context, {
  InboxItem? item,
  InboxLink? link,
  InboxKind kind = InboxKind.task,
  DateTime? day,
  DateTime Function() now = DateTime.now,
  SystemNotifier? notifier,
}) async {
  final inbox = context.read<InboxCubit>();
  final uid = inboxUid(context);
  if (item == null && uid == null) return;
  final messenger = ScaffoldMessenger.maybeOf(context);
  final l10n = context.l10n;
  final wide = MediaQuery.sizeOf(context).width >= AppShell.expandedBreakpoint;
  final editor = BlocProvider(
    create: (_) => InboxDraftCubit(
      item == null
          ? InboxDraft(kind: kind, link: link).withDate(day)
          : InboxDraft.of(item),
    ),
    child: InboxItemEditor(
      item: item,
      onSave: (draft) {
        if (item == null) {
          inbox.add(draft.toItem(id: inbox.newId(), uid: uid!, now: now()));
          return;
        }
        final changes = draft.changesFrom(item);
        if (changes.isNotEmpty) inbox.update(item.id, changes);
      },
      onDelete: item == null
          ? null
          : () {
              final removed = inbox.delete(item.id);
              if (removed == null) return;
              showInboxSnack(
                messenger,
                l10n.inboxDeleted,
                onUndo: () => inbox.restore(removed),
              );
            },
      now: now,
      notifier: notifier ?? createReminderPlatform().notifier,
      sheet: !wide,
    ),
  );

  if (!wide) {
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      // A drag would close it past "Discard changes?", so no handle either.
      enableDrag: false,
      backgroundColor: Theme.of(context).colorScheme.surface,
      // The page peeks above the sheet (below the safe area).
      builder: (context) => LayoutBuilder(
        builder: (context, constraints) => SizedBox(
          height: constraints.maxHeight - _sheetPeek,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: editor,
          ),
        ),
      ),
    );
    return;
  }
  final reduceMotion = MediaQuery.disableAnimationsOf(context);
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: l10n.objectsCloseEditor,
    barrierColor: Colors.black54,
    transitionDuration: reduceMotion
        ? MotionDurations.none
        : MotionDurations.base,
    pageBuilder: (context, _, _) => SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kInboxEditorMaxWidth),
            child: DecoratedBox(
              decoration: const BoxDecoration(
                borderRadius: Radii.fullAll,
                boxShadow: MorkvaElevation.level3,
              ),
              child: Material(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: Radii.fullAll,
                clipBehavior: Clip.antiAlias,
                child: editor,
              ),
            ),
          ),
        ),
      ),
    ),
    transitionBuilder: (_, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: MotionCurves.emphasized,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween(begin: 0.96, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// The editor's body over an [InboxDraftCubit]. Save hands the draft to
/// [onSave] and closes; closing with changes asks "Discard changes?".
class InboxItemEditor extends StatefulWidget {
  const InboxItemEditor({
    super.key,
    this.item,
    required this.onSave,
    this.onDelete,
    required this.now,
    required this.notifier,
    this.sheet = false,
  });

  final InboxItem? item;
  final ValueChanged<InboxDraft> onSave;
  final VoidCallback? onDelete;
  final DateTime Function() now;
  final SystemNotifier notifier;

  /// In the phone's full-height sheet: the footer sits at the bottom.
  final bool sheet;

  @override
  State<InboxItemEditor> createState() => _InboxItemEditorState();
}

class _InboxItemEditorState extends State<InboxItemEditor> {
  late final InboxDraftCubit _cubit = context.read<InboxDraftCubit>();
  late final _title = TextEditingController(text: _cubit.state.title);
  late final _details = TextEditingController(text: _cubit.state.details);
  late final _turnOn = TapGestureRecognizer()..onTap = _requestPermission;
  late NotificationPermission _permission = widget.notifier.permission;

  @override
  void dispose() {
    _title.dispose();
    _details.dispose();
    _turnOn.dispose();
    super.dispose();
  }

  Future<void> _requestPermission() async {
    final p = await widget.notifier.requestPermission();
    if (mounted) setState(() => _permission = p);
  }

  void _edit(InboxDraft Function(InboxDraft d) change) => _cubit.edit(change);

  void _save() {
    if (_cubit.state.title.trim().isEmpty) return;
    widget.onSave(_cubit.state);
    Navigator.of(context).pop();
  }

  void _delete() {
    widget.onDelete?.call();
    Navigator.of(context).pop();
  }

  Future<void> _pickDate() async {
    final now = widget.now();
    final initial = _cubit.state.date ?? localDay(now);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(initial.year - 10),
      lastDate: DateTime(initial.year + 10, 12, 31),
      builder: (_, child) => MondayFirst(child: child!),
    );
    if (picked != null) _edit((d) => d.withDate(picked));
  }

  Future<void> _pickTime() async {
    final m = _cubit.state.minutes ?? 9 * 60;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: m ~/ 60, minute: m % 60),
    );
    if (picked != null) {
      _edit((d) => d.withMinutes(picked.hour * 60 + picked.minute));
    }
  }

  Future<void> _pickLink() async {
    final link = await showCardLinkPicker(context);
    if (link != null) _edit((d) => d.copyWith(link: () => link));
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<InboxDraftCubit, InboxDraft>(
      builder: (context, draft) {
        final dirty = draft != _cubit.initial;
        return PopScope(
          canPop: !dirty,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            final l10n = context.l10n;
            final discard = await MorkvaConfirmDialog.show(
              context,
              title: l10n.objectsDiscardTitle,
              message: l10n.inboxDiscardMessage,
              confirmLabel: l10n.objectsDiscard,
              cancelLabel: l10n.objectsKeepEditing,
              destructive: true,
            );
            if (discard == true && context.mounted) {
              Navigator.of(context).pop();
            }
          },
          child: _body(context, draft),
        );
      },
    );
  }

  Widget _body(BuildContext context, InboxDraft draft) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.l10n;
    final divider = Divider(height: 1, color: scheme.outlineVariant);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Spacing.lg,
            Spacing.md,
            Spacing.sm,
            Spacing.md,
          ),
          child: Row(
            children: [
              _KindToggle(
                kind: draft.kind,
                onChanged: (kind) => _edit((d) => d.copyWith(kind: kind)),
              ),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: TextField(
                  controller: _title,
                  autofocus: widget.item == null,
                  maxLength: InboxItem.titleMax,
                  maxLines: 1,
                  textInputAction: TextInputAction.done,
                  style: theme.textTheme.headlineSmall,
                  decoration: InputDecoration(
                    hintText: l10n.inboxTitleHint,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    counterText: '',
                    isDense: true,
                    // Not the theme's 16 px inset: text starts at the gap.
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: Spacing.xs,
                    ),
                  ),
                  onChanged: (t) => _edit((d) => d.copyWith(title: t)),
                  onSubmitted: (_) => _save(),
                ),
              ),
              IconButton(
                tooltip: l10n.commonClose,
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        divider,
        Flexible(
          fit: widget.sheet ? FlexFit.tight : FlexFit.loose,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              Spacing.lg,
              Spacing.md,
              Spacing.lg,
              Spacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MorkvaTextField(
                  controller: _details,
                  hint: l10n.inboxDetailsHint,
                  minLines: 2,
                  maxLines: 6,
                  onChanged: (t) => _edit((d) => d.copyWith(details: t)),
                ),
                const SizedBox(height: Spacing.sm),
                _dateRow(context, draft),
                _reminderRow(context, draft),
                _linkRow(context, draft),
              ],
            ),
          ),
        ),
        divider,
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Spacing.sm,
            Spacing.sm,
            Spacing.lg,
            Spacing.sm,
          ),
          child: Row(
            children: [
              if (widget.onDelete != null)
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: scheme.error,
                    minimumSize: const Size(44, 44),
                  ),
                  onPressed: _delete,
                  icon: const Icon(Icons.delete_outline, size: 20),
                  label: Text(l10n.commonDelete),
                ),
              const Spacer(),
              PrimaryButton(
                label: l10n.commonSave,
                onPressed: draft.title.trim().isEmpty ? null : _save,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _row(IconData icon, Widget child) => Padding(
    padding: const EdgeInsets.only(top: Spacing.xxs),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 32,
          height: 44,
          child: Icon(
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: Spacing.xs),
        Expanded(child: child),
      ],
    ),
  );

  Widget _muted(String text, {VoidCallback? onTap}) {
    final theme = Theme.of(context);
    final label = Text(
      text,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
    return Align(
      alignment: Alignment.centerLeft,
      child: onTap == null
          ? SizedBox(
              height: 44,
              child: Align(alignment: Alignment.centerLeft, child: label),
            )
          : TextButton(
              onPressed: onTap,
              style: TextButton.styleFrom(
                minimumSize: const Size(44, 44),
                padding: const EdgeInsets.symmetric(horizontal: Spacing.xs),
              ),
              child: label,
            ),
    );
  }

  Widget _dateRow(BuildContext context, InboxDraft draft) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final now = widget.now();
    final date = draft.date;
    final presets = [
      (l10n.commonToday, InboxDatePresets.today(now)),
      (l10n.inboxTomorrow, InboxDatePresets.tomorrow(now)),
      (l10n.inboxNextMon, InboxDatePresets.nextMonday(now)),
    ];
    final minutes = draft.minutes;
    return _row(
      Icons.calendar_today_outlined,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: date == null
                    ? _muted(l10n.inboxNoDate)
                    : Row(
                        children: [
                          Flexible(
                            child: Text(
                              dayMonthLabel(
                                date,
                                Localizations.localeOf(context).toString(),
                              ),
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: l10n.inboxClearDate,
                            iconSize: 18,
                            color: theme.colorScheme.onSurfaceVariant,
                            onPressed: () => _edit((d) => d.withDate(null)),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
              ),
              InboxChip(
                icon: Icons.schedule,
                label: minutes == null ? null : timeLabel(minutes),
                tooltip: date == null
                    ? l10n.inboxSetDateForTime
                    : minutes == null
                    ? l10n.inboxAddTime
                    : null,
                outlined: minutes == null,
                onPressed: date == null ? null : _pickTime,
                onClear: minutes == null
                    ? null
                    : () => _edit((d) => d.withMinutes(null)),
                clearTooltip: l10n.inboxClearTime,
              ),
            ],
          ),
          Wrap(
            spacing: Spacing.xxs,
            children: [
              for (final (label, day) in presets)
                InboxChip(
                  label: label,
                  selected: date == day,
                  outlined: date != day,
                  onPressed: () => _edit((d) => d.withDate(day)),
                ),
              InboxChip(
                label: l10n.inboxPickDate,
                outlined: true,
                onPressed: _pickDate,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _reminderRow(BuildContext context, InboxDraft draft) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    if (draft.date == null) {
      return _row(
        Icons.notifications_none,
        _muted(l10n.inboxSetDateForReminders),
      );
    }
    final available = [
      for (final r in InboxReminders.presetsFor(allDay: draft.allDay))
        if (!draft.reminders.contains(r)) r,
    ];
    final canAdd =
        available.isNotEmpty && draft.reminders.length < InboxReminders.max;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    // The link sits mid-sentence: split the whole message around it.
    final turnOn = l10n.inboxTurnOnNotifications;
    final [before, after] = l10n
        .inboxNotificationsDefault(turnOn)
        .split(turnOn);
    final line = switch (_permission) {
      NotificationPermission.defaultState => Text.rich(
        TextSpan(
          children: [
            TextSpan(text: before),
            TextSpan(
              text: turnOn,
              recognizer: _turnOn,
              style: TextStyle(
                color: theme.extension<MorkvaSemanticColors>()?.primaryText,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
              ),
            ),
            TextSpan(text: after),
          ],
        ),
        style: muted,
      ),
      NotificationPermission.granted => Text(
        l10n.inboxNotificationsGranted,
        style: muted,
      ),
      NotificationPermission.denied => Text(
        l10n.inboxNotificationsDenied,
        style: muted,
      ),
      NotificationPermission.unsupported => null,
    };
    return _row(
      Icons.notifications_none,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: Spacing.xxs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final r in draft.reminders)
                InboxChip(
                  label: reminderLabel(l10n, r),
                  onClear: () => _edit((d) => d.toggleReminder(r)),
                  clearTooltip: l10n.inboxRemoveReminder,
                ),
              MenuAnchor(
                menuChildren: [
                  for (final r in available)
                    MenuItemButton(
                      onPressed: () => _edit((d) => d.toggleReminder(r)),
                      child: Text(reminderLabel(l10n, r)),
                    ),
                ],
                builder: (context, controller, _) => InboxChip(
                  icon: Icons.add,
                  outlined: true,
                  tooltip: l10n.inboxAddReminder,
                  onPressed: canAdd
                      ? () => controller.isOpen
                            ? controller.close()
                            : controller.open()
                      : null,
                ),
              ),
            ],
          ),
          if (line != null)
            Padding(
              padding: const EdgeInsets.only(bottom: Spacing.xs),
              child: line,
            ),
        ],
      ),
    );
  }

  Widget _linkRow(BuildContext context, InboxDraft draft) {
    final link = draft.link;
    return _row(
      Icons.link,
      Align(
        alignment: Alignment.centerLeft,
        child: link == null
            ? _muted(context.l10n.inboxLinkCard, onTap: _pickLink)
            : InboxLinkChip(
                link: link,
                onTap: _pickLink,
                onClear: () => _edit((d) => d.copyWith(link: () => null)),
              ),
      ),
    );
  }
}

/// Task | note: two 36 px segments in a pill; the current one raised.
class _KindToggle extends StatelessWidget {
  const _KindToggle({required this.kind, required this.onChanged});

  final InboxKind kind;
  final ValueChanged<InboxKind> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    Widget segment(InboxKind k, String tooltip, Widget glyph) {
      final on = kind == k;
      return Tooltip(
        message: tooltip,
        child: Semantics(
          button: true,
          selected: on,
          label: tooltip,
          excludeSemantics: true,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: on ? null : () => onChanged(k),
            child: SizedBox.square(
              dimension: 44,
              child: Center(
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: on ? scheme.surfaceContainerLowest : null,
                    boxShadow: on ? MorkvaElevation.level1 : null,
                  ),
                  alignment: Alignment.center,
                  child: glyph,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          segment(InboxKind.task, l10n.inboxTask, const InboxTaskCircle()),
          segment(
            InboxKind.note,
            l10n.inboxNote,
            Icon(
              Icons.sticky_note_2_outlined,
              size: 18,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
