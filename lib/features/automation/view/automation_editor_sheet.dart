import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../api/auth/auth_cubit.dart';
import '../../../api/data/data_repository.dart';
import '../../../app/shell/app_shell.dart';
import '../../../core/automation/runner_api.dart';
import '../../../core/domain/automation/automation.dart';
import '../../../core/domain/domain.dart';
import '../../../design/design.dart';
import '../../views/widgets/filter_builder.dart';
import '../../views/widgets/view_labels.dart';
import '../../views/widgets/view_popover.dart';
import '../bloc/automation_editor_cubit.dart';
import '../bloc/modules_cubit.dart';
import '../widgets/action_buttons.dart';

/// Opens the automation editor over the app's runner, modules and
/// collections: editing [existing], or a new automation prefilled with
/// [collectionId] / [moduleId] / [actionId] / [kind]. True when it was saved
/// or deleted. Does nothing without the app's automation wiring.
Future<bool> showAutomationEditor(
  BuildContext context, {
  AutomationRecord? existing,
  String? collectionId,
  String? moduleId,
  String? actionId,
  EditorKind kind = EditorKind.cardButton,
}) async {
  final runner = maybeRead<AutomationRunnerApi>(context);
  final modules = maybeRead<ModulesCubit>(context);
  final repository = maybeRead<DataRepository>(context);
  final uid = switch (maybeRead<AuthCubit>(context)?.state) {
    AuthAuthenticated(:final user) => user.uid,
    _ => null,
  };
  if (runner == null || modules == null || repository == null || uid == null) {
    return false;
  }
  List<Collection> collections;
  try {
    collections = await repository.getCollections();
  } catch (_) {
    collections = const [];
  }
  if (!context.mounted) return false;
  final cubit = AutomationEditorCubit(
    runner,
    uid: uid,
    modules: modules.state.modules,
    collections: collections,
    moduleChanges: modules.stream.map((s) => s.modules),
    existing: existing,
    collectionId: collectionId,
    moduleId: moduleId,
    actionId: actionId,
    kind: kind,
  );
  return presentAutomationEditor(context, cubit);
}

/// Shows [cubit]'s editor: a 480 px side sheet over a scrim on wide screens,
/// a full-screen route on phones (UX breakpoints). Closes [cubit] after.
Future<bool> presentAutomationEditor(
  BuildContext context,
  AutomationEditorCubit cubit,
) async {
  final wide = MediaQuery.sizeOf(context).width >= AppShell.expandedBreakpoint;
  Widget editor(bool compact) => BlocProvider.value(
    value: cubit,
    child: AutomationEditorSheet(compact: compact),
  );
  bool? result;
  if (wide) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    result = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close editor',
      barrierColor: Colors.black54,
      transitionDuration: reduceMotion
          ? MotionDurations.none
          : MotionDurations.base,
      pageBuilder: (context, _, _) => Align(
        alignment: Alignment.centerRight,
        child: SizedBox(
          width: 480,
          height: double.infinity,
          child: Material(
            color: Theme.of(context).colorScheme.surface,
            elevation: 0,
            child: SafeArea(left: false, child: editor(false)),
          ),
        ),
      ),
      transitionBuilder: (_, animation, _, child) => SlideTransition(
        position: Tween(begin: const Offset(1, 0), end: Offset.zero).animate(
          CurvedAnimation(parent: animation, curve: MotionCurves.emphasized),
        ),
        child: child,
      ),
    );
  } else {
    result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(fullscreenDialog: true, builder: (_) => editor(true)),
    );
  }
  unawaited(cubit.close());
  return result ?? false;
}

/// The automation form (UX §3) over [AutomationEditorCubit].
class AutomationEditorSheet extends StatefulWidget {
  const AutomationEditorSheet({super.key, required this.compact});

  final bool compact;

  @override
  State<AutomationEditorSheet> createState() => _AutomationEditorSheetState();
}

class _AutomationEditorSheetState extends State<AutomationEditorSheet> {
  late final AutomationEditorCubit _cubit = context.read();
  late final _name = TextEditingController(text: _cubit.state.name);
  late final _label = TextEditingController(text: _cubit.state.label);
  bool _resumed = false;

  @override
  void dispose() {
    _name.dispose();
    _label.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (await _cubit.save() && mounted) Navigator.of(context).pop(true);
  }

  Future<void> _delete() async {
    final confirmed = await MorkvaConfirmDialog.show(
      context,
      title: 'Delete "${_cubit.state.name}"?',
      message: 'Its button disappears. Run history stays.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (confirmed != true || !mounted) return;
    if (await _cubit.delete() && mounted) Navigator.of(context).pop(true);
  }

  Future<void> _resume() async {
    if (await _cubit.resume() && mounted) setState(() => _resumed = true);
  }

  /// Leaves the editor for [path] (module details: Change access, turn on
  /// auto-apply).
  void _leave(String path) {
    final router = GoRouter.maybeOf(context);
    Navigator.of(context).pop(false);
    router?.go(path);
  }

  void _sync(AutomationEditorState s) {
    if (_name.text != s.name) _name.text = s.name;
    if (_label.text != s.label) _label.text = s.label;
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AutomationEditorCubit, AutomationEditorState>(
      listener: (_, s) => _sync(s),
      builder: (context, s) {
        final theme = Theme.of(context);
        final title = s.existing == null ? 'New automation' : 'Edit automation';
        final gutter = widget.compact ? Spacing.md : Spacing.lg;
        final form = ListView(
          padding: EdgeInsets.fromLTRB(gutter, Spacing.md, gutter, Spacing.xl),
          children: [
            ..._banners(context, s),
            _Field(
              label: 'Name',
              child: MorkvaTextField(
                controller: _name,
                hint: 'Stamp when shipped',
                errorText: s.problemAt('name'),
                onChanged: _cubit.setName,
              ),
            ),
            _Field(
              label: 'When',
              child: _KindGrid(
                kind: s.kind,
                columns: widget.compact ? 1 : 2,
                onChanged: _cubit.setKind,
              ),
            ),
            _Field(
              label: 'In',
              child: _CollectionPicker(
                state: s,
                onChanged: _cubit.setCollection,
                onChangeAccess: s.moduleId == null
                    ? null
                    : () => _leave(AutomationPaths.module(s.moduleId!)),
              ),
            ),
            if (!s.kind.isButton && s.collection != null)
              _Conditions(state: s, cubit: _cubit),
            _Field(
              label: 'Do',
              child: _Do(state: s, cubit: _cubit),
            ),
            if (s.kind.isButton)
              _Field(
                label: 'Button',
                child: _ButtonLook(state: s, cubit: _cubit, label: _label),
              ),
            _Field(
              label: 'Apply',
              child: _Apply(
                state: s,
                onChanged: _cubit.setApply,
                onModuleDetails: s.moduleId == null
                    ? null
                    : () => _leave(AutomationPaths.module(s.moduleId!)),
              ),
            ),
            _SwitchRow(
              label: 'Enabled',
              value: s.enabled,
              onChanged: _cubit.setEnabled,
            ),
            const Divider(height: Spacing.lg),
            _Advanced(state: s, onChanged: _cubit.setScope),
            if (widget.compact && s.existing != null) ...[
              const SizedBox(height: Spacing.lg),
              Align(
                alignment: Alignment.centerLeft,
                child: _DeleteButton(onPressed: s.saving ? null : _delete),
              ),
            ],
          ],
        );
        if (widget.compact) {
          return Scaffold(
            backgroundColor: theme.colorScheme.surface,
            appBar: AppBar(
              backgroundColor: theme.colorScheme.surface,
              surfaceTintColor: Colors.transparent,
              titleSpacing: 0,
              leading: IconButton(
                tooltip: 'Close',
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              title: Text(title, style: theme.textTheme.titleLarge),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: Spacing.xs),
                  child: PrimaryButton(
                    label: 'Save',
                    loading: s.saving,
                    onPressed: _save,
                  ),
                ),
              ],
            ),
            body: SafeArea(top: false, child: form),
          );
        }
        final scheme = theme.colorScheme;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Spacing.lg,
                Spacing.md,
                Spacing.sm,
                Spacing.xs,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(title, style: theme.textTheme.headlineSmall),
                  ),
                  IconActionButton(
                    icon: Icons.close,
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: scheme.outlineVariant),
            Expanded(child: form),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.md,
                vertical: Spacing.sm,
              ),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: scheme.outlineVariant)),
              ),
              child: Row(
                children: [
                  if (s.existing != null)
                    _DeleteButton(onPressed: s.saving ? null : _delete),
                  const Spacer(),
                  TextActionButton(
                    label: 'Cancel',
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: Spacing.xs),
                  PrimaryButton(
                    label: 'Save',
                    loading: s.saving,
                    onPressed: _save,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _banners(BuildContext context, AutomationEditorState s) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final semantic = theme.extension<MorkvaSemanticColors>()!;
    final warning = (
      background: semantic.warningContainer,
      foreground: semantic.onWarningContainer,
    );
    final error = (
      background: scheme.errorContainer,
      foreground: scheme.onErrorContainer,
    );
    final existing = s.existing;
    final paused = _resumed ? null : existing?.pausedReason;
    return [
      if (paused == PausedReason.broken)
        _Banner(
          colors: error,
          title: 'This automation is paused.',
          message: existing?.brokenDetail,
        ),
      if (paused == PausedReason.loopSuspected)
        _Banner(
          colors: warning,
          title: 'Paused: it ran too often in a minute,',
          message:
              'which looks like a loop (it may be changing the cards it '
              'watches).',
          onResume: _resume,
        ),
      if (paused == PausedReason.crashed)
        _Banner(
          colors: warning,
          title: 'Paused: Morkva stopped while this ran',
          message: '(probably out of memory).',
          onResume: _resume,
        ),
      if (s.error case final message?) _Banner(colors: error, title: message),
    ];
  }
}

// -----------------------------------------------------------------------------
// Pieces
// -----------------------------------------------------------------------------

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Spacing.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: Spacing.xs),
        child,
      ],
    ),
  );
}

TextStyle? _muted(BuildContext context) => Theme.of(context).textTheme.bodySmall
    ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);

TextStyle? _errorStyle(BuildContext context) => Theme.of(
  context,
).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.error);

/// A label above a control, as `MorkvaTextField` draws its own.
class _Labeled extends StatelessWidget {
  const _Labeled(this.label, this.child);

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: theme.textTheme.labelMedium),
        const SizedBox(height: Spacing.xs),
        child,
      ],
    );
  }
}

class _Problem extends StatelessWidget {
  const _Problem(this.message);

  final String? message;

  @override
  Widget build(BuildContext context) {
    final m = message;
    if (m == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: Spacing.xxs),
      child: Semantics(
        liveRegion: true,
        child: Text(m, style: _errorStyle(context)),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.colors,
    required this.title,
    this.message,
    this.onResume,
  });

  final ({Color background, Color foreground}) colors;
  final String title;
  final String? message;
  final VoidCallback? onResume;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Spacing.md),
    child: Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          Spacing.sm,
          Spacing.xs,
          Spacing.xs,
          Spacing.xs,
        ),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: Radii.mdAll,
        ),
        child: Row(
          children: [
            Icon(
              Icons.pause_circle_outline,
              size: 20,
              color: colors.foreground,
            ),
            const SizedBox(width: Spacing.xs),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Spacing.xxs),
                child: Text.rich(
                  TextSpan(
                    text: title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    children: [
                      if (message != null)
                        TextSpan(
                          text: ' $message',
                          style: const TextStyle(fontWeight: FontWeight.w400),
                        ),
                    ],
                  ),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: colors.foreground),
                ),
              ),
            ),
            if (onResume != null) ...[
              const SizedBox(width: Spacing.xs),
              SecondaryButton(label: 'Resume', onPressed: onResume),
            ],
          ],
        ),
      ),
    ),
  );
}

/// "When": five radio cards (2 columns wide, 1 on phones).
class _KindGrid extends StatelessWidget {
  const _KindGrid({
    required this.kind,
    required this.columns,
    required this.onChanged,
  });

  final EditorKind kind;
  final int columns;
  final ValueChanged<EditorKind> onChanged;

  static const _cards = [
    (
      EditorKind.cardButton,
      Icons.smart_button_outlined,
      'Button on a card',
      "Shows in the card's header.",
    ),
    (
      EditorKind.collectionButton,
      Icons.table_chart_outlined,
      'Button on a collection',
      "Shows in the collection's Actions menu.",
    ),
    (
      EditorKind.created,
      Icons.add_box_outlined,
      'When a card is created',
      null,
    ),
    (EditorKind.updated, Icons.edit_outlined, 'When a card is updated', null),
    (EditorKind.deleted, Icons.delete_outline, 'When a card is deleted', null),
  ];

  @override
  Widget build(BuildContext context) => RadioGroup<EditorKind>(
    groupValue: kind,
    onChanged: (k) => k == null ? null : onChanged(k),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final width =
            (constraints.maxWidth - Spacing.xs * (columns - 1)) / columns;
        return Wrap(
          spacing: Spacing.xs,
          runSpacing: Spacing.xs,
          children: [
            for (final (k, icon, title, hint) in _cards)
              SizedBox(
                width: width,
                child: _RadioCard(
                  value: k,
                  selected: k == kind,
                  icon: icon,
                  title: title,
                  hint: hint,
                  onTap: () => onChanged(k),
                ),
              ),
          ],
        );
      },
    ),
  );
}

class _RadioCard extends StatelessWidget {
  const _RadioCard({
    required this.value,
    required this.selected,
    required this.icon,
    required this.title,
    required this.hint,
    required this.onTap,
  });

  final EditorKind value;
  final bool selected;
  final IconData icon;
  final String title;
  final String? hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: selected
          ? scheme.primary.withValues(alpha: 0.06)
          : scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: Radii.mdAll,
        side: BorderSide(
          color: selected ? scheme.primary : scheme.outlineVariant,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: Radii.mdAll,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Spacing.sm,
            Spacing.sm,
            Spacing.xxs,
            Spacing.sm,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, size: 20, color: scheme.onSurfaceVariant),
                    const SizedBox(height: Spacing.xs),
                    Text(title, style: theme.textTheme.titleSmall),
                    if (hint != null) ...[
                      const SizedBox(height: Spacing.xxs),
                      Text(hint!, style: _muted(context)),
                    ],
                  ],
                ),
              ),
              Radio<EditorKind>(value: value),
            ],
          ),
        ),
      ),
    );
  }
}

/// "In": the collections, the ones the module isn't allowed in disabled.
class _CollectionPicker extends StatelessWidget {
  const _CollectionPicker({
    required this.state,
    required this.onChanged,
    required this.onChangeAccess,
  });

  final AutomationEditorState state;
  final ValueChanged<String> onChanged;
  final VoidCallback? onChangeAccess;

  @override
  Widget build(BuildContext context) {
    final s = state;
    final blocked = s.collections.where((c) => !s.collectionAllowed(c.id));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          initialValue: s.collectionId,
          key: ValueKey('in/${s.collectionId}'),
          isExpanded: true,
          hint: const Text('Pick a collection'),
          decoration: InputDecoration(errorText: s.problemAt('collectionId')),
          items: [
            for (final c in s.collections)
              DropdownMenuItem(
                value: c.id,
                enabled: s.collectionAllowed(c.id),
                child: _CollectionLabel(
                  collection: c,
                  note: s.collectionAllowed(c.id)
                      ? null
                      : 'Not allowed for this module',
                ),
              ),
          ],
          onChanged: (id) => id == null ? null : onChanged(id),
        ),
        if (blocked.isNotEmpty && onChangeAccess != null)
          Row(
            children: [
              Flexible(
                child: Text(
                  '${blocked.map((c) => c.name).join(', ')} '
                  "${blocked.length == 1 ? "isn't" : "aren't"} allowed for "
                  'this module.',
                  style: _muted(context),
                ),
              ),
              TextActionButton(
                label: 'Change access',
                onPressed: onChangeAccess,
              ),
            ],
          ),
      ],
    );
  }
}

class _CollectionLabel extends StatelessWidget {
  const _CollectionLabel({required this.collection, this.note});

  final Collection collection;
  final String? note;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      CollectionGlyph(
        iconKey: collection.icon,
        tintSeed: collection.id,
        size: 24,
        iconSize: 14,
      ),
      const SizedBox(width: Spacing.xs),
      Flexible(child: Text(collection.name, overflow: TextOverflow.ellipsis)),
      if (note != null) ...[
        const SizedBox(width: Spacing.xs),
        Flexible(
          child: Text(
            '· $note',
            style: _muted(context),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ],
  );
}

/// "If" (events): condition chips, "+ Condition"; for updated also the
/// watched fields and Once / Every; the help and last-checked lines.
class _Conditions extends StatelessWidget {
  const _Conditions({required this.state, required this.cubit});

  final AutomationEditorState state;
  final AutomationEditorCubit cubit;

  Future<void> _edit(BuildContext context, {int? index, Rect? anchor}) async {
    final collection = state.collection!;
    final initial = index == null ? null : filterOf(state.where[index]);
    final result = await showViewPopover<ViewFilter>(
      context,
      compact: anchor == null,
      anchor: anchor ?? Rect.zero,
      label: initial == null ? 'Add condition' : 'Edit condition',
      builder: (sheet) => FilterBuilder(
        collection: collection,
        initial: initial,
        onApply: (f) => Navigator.of(sheet).pop(f),
      ),
    );
    if (result == null) return;
    if (index == null) {
      cubit.addCondition(result);
    } else {
      cubit.replaceCondition(index, result);
    }
  }

  Rect? _anchorOf(BuildContext context) {
    if (MediaQuery.sizeOf(context).width < AppShell.expandedBreakpoint) {
      return null;
    }
    final box = context.findRenderObject() as RenderBox?;
    return box == null ? null : box.localToGlobal(Offset.zero) & box.size;
  }

  @override
  Widget build(BuildContext context) {
    final s = state;
    final collection = s.collection!;
    final updated = s.kind == EditorKind.updated;
    final check = s.lastCheck;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Field(
          label: 'If',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: Spacing.xs,
                runSpacing: Spacing.xs,
                children: [
                  for (var i = 0; i < s.where.length; i++)
                    _ConditionChip(
                      label: _conditionLabel(s.where[i], collection),
                      onTap: filterOf(s.where[i]) == null
                          ? null
                          : () => _edit(context, index: i),
                      onRemove: () => cubit.removeCondition(i),
                    ),
                  Builder(
                    builder: (anchor) => _AddButton(
                      label: 'Condition',
                      onPressed: () => _edit(anchor, anchor: _anchorOf(anchor)),
                    ),
                  ),
                ],
              ),
              _Problem(s.problemAt('where')),
              if (updated && s.where.isEmpty && s.fields.isEmpty)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: s.anyChange,
                  onChanged: (v) => cubit.setAnyChange(v ?? false),
                  title: const Text('Run on any change'),
                ),
            ],
          ),
        ),
        if (updated) ...[
          _Field(
            label: 'Only when these fields change',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: Spacing.xs,
                  runSpacing: Spacing.xs,
                  children: [
                    for (final f in collection.fields)
                      FilterChip(
                        label: Text(f.name),
                        selected: s.fields.contains(f.id),
                        onSelected: (on) => cubit.setFields([
                          for (final id in s.fields)
                            if (id != f.id) id,
                          if (on) f.id,
                        ]),
                      ),
                  ],
                ),
                const SizedBox(height: Spacing.xxs),
                Text(
                  'Leave empty to react to any change.',
                  style: _muted(context),
                ),
              ],
            ),
          ),
          _Field(
            label: 'Run',
            child: RadioGroup<TriggerMode>(
              groupValue: s.mode,
              onChanged: (m) => m == null ? null : cubit.setMode(m),
              child: const Column(
                children: [
                  _RadioRow(
                    value: TriggerMode.enters,
                    title: 'Once, when the card starts matching',
                    hint: "Won't run again while it keeps matching.",
                  ),
                  _RadioRow(
                    value: TriggerMode.matches,
                    title: "Every time it's updated and matches",
                  ),
                ],
              ),
            ),
          ),
        ],
        _HelpLine(
          icon: Icons.info_outline,
          text:
              'Runs on the device where the change is made, while Morkva is '
              'open there. Offline changes run when they sync. Calculated '
              "values don't trigger on their own.",
        ),
        if (check != null)
          _HelpLine(
            icon: Icons.history,
            lead: 'Last checked',
            text: '${check.cardLabel} · ${_clock(check.at)} · ${check.why}',
          ),
        const SizedBox(height: Spacing.md),
      ],
    );
  }
}

String _clock(DateTime t) {
  final l = t.toLocal();
  return '${l.hour.toString().padLeft(2, '0')}:'
      '${l.minute.toString().padLeft(2, '0')}';
}

/// "Status is Shipped"; a relative condition written by Ask Morkva reads
/// "Due · today".
String _conditionLabel(Map<String, Object?> condition, Collection collection) {
  final filter = filterOf(condition);
  if (filter != null) return filterLabel(filter, collection);
  final field = collection.fieldById('${condition['field']}')?.name ?? 'Field';
  final value = condition['relative'] ?? condition['value'] ?? condition['op'];
  return '$field · $value';
}

class _ConditionChip extends StatelessWidget {
  const _ConditionChip({
    required this.label,
    required this.onTap,
    required this.onRemove,
  });

  final String label;

  /// Null: read-only (relative), ✕ only.
  final VoidCallback? onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.primary.withValues(alpha: 0.12),
      borderRadius: Radii.smAll,
      child: InkWell(
        onTap: onTap,
        borderRadius: Radii.smAll,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.only(left: Spacing.sm),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.onSurface,
                  ),
                ),
                IconButton(
                  tooltip: 'Remove $label',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: onRemove,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The dashed "+ Condition".
class _AddButton extends StatelessWidget {
  const _AddButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ink = Theme.of(
      context,
    ).extension<MorkvaSemanticColors>()!.primaryText;
    return PressableScale(
      onPressed: onPressed,
      semanticLabel: 'Add $label',
      borderRadius: Radii.smAll,
      child: SizedBox(
        height: 44,
        child: Center(
          widthFactor: 1,
          child: CustomPaint(
            painter: _DashedBorder(color: scheme.outline),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.sm,
                vertical: Spacing.xs,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, size: 16, color: ink),
                  const SizedBox(width: Spacing.xxs),
                  Text(
                    label,
                    style: Theme.of(
                      context,
                    ).textTheme.labelLarge?.copyWith(color: ink),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorder extends CustomPainter {
  _DashedBorder({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(Radii.sm),
        ),
      );
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 7) {
        canvas.drawPath(metric.extractPath(d, d + 4), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) => old.color != color;
}

class _RadioRow<T> extends StatelessWidget {
  const _RadioRow({
    required this.value,
    required this.title,
    this.hint,
    this.enabled = true,
  });

  final T value;
  final String title;
  final String? hint;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink = enabled
        ? theme.colorScheme.onSurface
        : theme.colorScheme.onSurface.withValues(alpha: 0.38);
    return InkWell(
      onTap: enabled
          ? () => RadioGroup.maybeOf<T>(context)?.onChanged(value)
          : null,
      borderRadius: Radii.smAll,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Radio<T>(value: value, enabled: enabled),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: Spacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyLarge?.copyWith(color: ink),
                    ),
                    if (hint != null)
                      Text(
                        hint!,
                        style: _muted(
                          context,
                        )?.copyWith(color: enabled ? null : ink),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HelpLine extends StatelessWidget {
  const _HelpLine({required this.icon, required this.text, this.lead});

  final IconData icon;
  final String text;
  final String? lead;

  @override
  Widget build(BuildContext context) {
    final style = _muted(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 14, color: style?.color),
          ),
          const SizedBox(width: Spacing.xs),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  if (lead != null)
                    TextSpan(
                      text: '$lead ',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  TextSpan(text: text),
                ],
              ),
              style: style,
            ),
          ),
        ],
      ),
    );
  }
}

/// "Do": module → action, then the action's inputs.
class _Do extends StatelessWidget {
  const _Do({required this.state, required this.cubit});

  final AutomationEditorState state;
  final AutomationEditorCubit cubit;

  @override
  Widget build(BuildContext context) {
    final s = state;
    final wide =
        MediaQuery.sizeOf(context).width >= AppShell.expandedBreakpoint;
    final module = DropdownButtonFormField<String>(
      key: ValueKey('module/${s.moduleId}'),
      initialValue: s.moduleId,
      isExpanded: true,
      hint: const Text('Pick a module'),
      decoration: const InputDecoration(),
      items: [
        for (final m in s.usableModules)
          DropdownMenuItem(
            value: m.module.id,
            child: Text(m.module.name, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (id) => id == null ? null : cubit.setModule(id),
    );
    final actions = s.module?.module.manifest?.actions ?? const <ActionSpec>[];
    final action = DropdownButtonFormField<String>(
      key: ValueKey('action/${s.moduleId}/${s.actionId}'),
      initialValue: s.actionId,
      isExpanded: true,
      hint: const Text('Pick an action'),
      decoration: InputDecoration(
        errorText: s.problemAt('actionId'),
        errorMaxLines: 2,
      ),
      items: [
        for (final a in actions)
          DropdownMenuItem(
            value: a.id,
            enabled: s.kind.fits(a.scope),
            child: Text(
              s.kind.fits(a.scope)
                  ? a.label
                  : '${a.label} · Runs on a '
                        '${a.scope == ActionScope.collection ? 'collection' : 'card'}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: s.module == null
          ? null
          : (id) => id == null ? null : cubit.setAction(id),
    );
    final input = s.action?.input;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _Labeled('Module', module)),
              const SizedBox(width: Spacing.sm),
              Expanded(child: _Labeled('Action', action)),
            ],
          )
        else ...[
          _Labeled('Module', module),
          const SizedBox(height: Spacing.sm),
          _Labeled('Action', action),
        ],
        if (input != null)
          for (final MapEntry(:key, :value) in input.properties.entries)
            Padding(
              padding: const EdgeInsets.only(top: Spacing.md),
              child: _Param(
                key: ValueKey('${s.actionId}/$key'),
                name: key,
                property: value,
                required: input.required.contains(key),
                state: s,
                onChanged: (v) => cubit.setParam(key, v),
              ),
            ),
      ],
    );
  }
}

/// One action input: a field / collection / enum dropdown, a switch, a
/// number or a text field.
class _Param extends StatefulWidget {
  const _Param({
    super.key,
    required this.name,
    required this.property,
    required this.required,
    required this.state,
    required this.onChanged,
  });

  final String name;
  final InputProperty property;
  final bool required;
  final AutomationEditorState state;
  final ValueChanged<Object?> onChanged;

  @override
  State<_Param> createState() => _ParamState();
}

class _ParamState extends State<_Param> {
  late final _text = TextEditingController(
    text: '${widget.state.params[widget.name] ?? ''}',
  );

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.property;
    final s = widget.state;
    final value = s.params[widget.name];
    final title = '${p.title ?? widget.name}${widget.required ? ' *' : ''}';
    final error = s.problemAt('params.${widget.name}');
    Widget dropdown(List<(String, String, bool)> items) => _Labeled(
      title,
      DropdownButtonFormField<String>(
        initialValue: items.any((i) => i.$1 == value) ? value as String : null,
        isExpanded: true,
        decoration: InputDecoration(errorText: error),
        items: [
          for (final (id, label, enabled) in items)
            DropdownMenuItem(
              value: id,
              enabled: enabled,
              child: Text(label, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: widget.onChanged,
      ),
    );
    final control = switch (p) {
      InputProperty(format: InputFormat.field) => dropdown([
        for (final f in s.collection?.fields ?? const <FieldDefinition>[])
          (f.id, f.name, true),
      ]),
      InputProperty(format: InputFormat.collection) => dropdown([
        for (final c in s.collections)
          (c.id, c.name, s.collectionAllowed(c.id)),
      ]),
      InputProperty(enumValues: final values?) => dropdown([
        for (final v in values) (v, v, true),
      ]),
      InputProperty(type: InputType.boolean) => _SwitchRow(
        label: title,
        value: value == true,
        onChanged: widget.onChanged,
      ),
      InputProperty(type: InputType.number || InputType.integer) =>
        MorkvaTextField(
          controller: _text,
          label: title,
          errorText: error,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (t) => widget.onChanged(
            p.type == InputType.integer ? int.tryParse(t) : num.tryParse(t),
          ),
        ),
      _ => MorkvaTextField(
        controller: _text,
        label: title,
        errorText: error,
        onChanged: (t) => widget.onChanged(t.isEmpty ? null : t),
      ),
    };
    final hint =
        p.description ??
        (p.format == InputFormat.field && s.collection != null
            ? 'Fields of ${s.collection!.name}.'
            : null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        control,
        if (hint != null)
          Padding(
            padding: const EdgeInsets.only(top: Spacing.xxs),
            child: Text(hint, style: _muted(context)),
          ),
      ],
    );
  }
}

/// "Button": label, icon grid, tint swatches and a live preview.
class _ButtonLook extends StatelessWidget {
  const _ButtonLook({
    required this.state,
    required this.cubit,
    required this.label,
  });

  final AutomationEditorState state;
  final AutomationEditorCubit cubit;
  final TextEditingController label;

  @override
  Widget build(BuildContext context) {
    final s = state;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final seed = s.collectionId ?? '';
    final palette = theme.brightness == Brightness.light
        ? CollectionTints.light
        : CollectionTints.dark;
    final tint = buttonTintOf(s.tint, seed, theme.brightness);
    final shown = s.label.trim().isEmpty
        ? s.defaultLabel
        : buttonLabelOf(s.label.trim());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MorkvaTextField(
          controller: label,
          label: 'Label',
          hint: s.defaultLabel,
          suffixText: '${label.text.length}/${ButtonSpec.kMaxLabel}',
          onChanged: cubit.setLabel,
        ),
        const SizedBox(height: Spacing.md),
        Text('Icon', style: theme.textTheme.labelMedium),
        const SizedBox(height: Spacing.xxs),
        LayoutBuilder(
          builder: (context, c) => Wrap(
            children: [
              for (final option in CollectionIcons.all)
                SizedBox(
                  width: c.maxWidth / 6,
                  height: 44,
                  child: Tooltip(
                    message: option.label,
                    child: InkWell(
                      borderRadius: Radii.smAll,
                      onTap: () => cubit.setIcon(option.key),
                      child: Center(
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: s.icon == option.key
                                ? tint.background
                                : null,
                            borderRadius: Radii.smAll,
                            border: s.icon == option.key
                                ? Border.all(color: tint.foreground)
                                : null,
                          ),
                          child: Icon(
                            option.icon,
                            size: 20,
                            color: s.icon == option.key
                                ? tint.foreground
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: Spacing.sm),
        Text('Color', style: theme.textTheme.labelMedium),
        const SizedBox(height: Spacing.xxs),
        Wrap(
          children: [
            for (var i = 0; i < kButtonTintIds.length; i++)
              Semantics(
                selected: s.tint == kButtonTintIds[i],
                label: kButtonTintIds[i],
                button: true,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => cubit.setTint(kButtonTintIds[i]),
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Center(
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: palette[i].background,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: s.tint == kButtonTintIds[i]
                                ? palette[i].foreground
                                : scheme.outlineVariant,
                            width: s.tint == kButtonTintIds[i] ? 2 : 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: Spacing.sm),
        Text('Preview', style: theme.textTheme.labelMedium),
        const SizedBox(height: Spacing.xxs),
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            key: const ValueKey('button-preview'),
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
            decoration: BoxDecoration(
              color: tint.background,
              borderRadius: Radii.mdAll,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  s.icon == null && s.action?.icon == null
                      ? Icons.bolt_rounded
                      : CollectionIcons.byKey(s.icon ?? s.action?.icon),
                  size: 18,
                  color: tint.foreground,
                ),
                const SizedBox(width: Spacing.xs),
                Text(
                  shown.isEmpty ? 'Button' : shortButtonLabel(shown),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: tint.foreground,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// "Apply": Ask first / Apply automatically, the latter disabled with its
/// reason as visible text.
class _Apply extends StatelessWidget {
  const _Apply({
    required this.state,
    required this.onChanged,
    required this.onModuleDetails,
  });

  final AutomationEditorState state;
  final ValueChanged<ApplyMode> onChanged;
  final VoidCallback? onModuleDetails;

  @override
  Widget build(BuildContext context) {
    final s = state;
    final available = s.autoAvailability == AutoAvailability.available;
    return RadioGroup<ApplyMode>(
      groupValue: s.apply,
      onChanged: (m) => m == null ? null : onChanged(m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _RadioRow(
            value: ApplyMode.ask,
            title: 'Ask first',
            hint: s.kind.isButton
                ? 'You review each change in a preview.'
                : 'Each card waits in Needs review.',
          ),
          _RadioRow(
            value: ApplyMode.auto,
            enabled: available,
            title: 'Apply automatically',
            hint:
                'Small card creates and edits apply without asking. Bigger '
                'changes, deletes and structure changes still wait.',
          ),
          if (!available)
            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: Row(
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 14,
                    color: _muted(context)?.color,
                  ),
                  const SizedBox(width: Spacing.xxs),
                  Flexible(
                    child: Text(
                      s.autoAvailability == AutoAvailability.alwaysAsks
                          ? 'This module can delete or change structure, so '
                                'it always asks.'
                          : 'Turn on auto-apply for this module first.',
                      style: _muted(context),
                    ),
                  ),
                  if (s.autoAvailability == AutoAvailability.turnOnFirst &&
                      onModuleDetails != null)
                    TextActionButton(
                      label: 'Module details',
                      onPressed: onModuleDetails,
                    ),
                ],
              ),
            ),
          _Problem(s.problemAt('apply')),
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.titleSmall),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    ),
  );
}

/// "Advanced": the collections this automation may touch, narrowing the
/// module's access.
class _Advanced extends StatefulWidget {
  const _Advanced({required this.state, required this.onChanged});

  final AutomationEditorState state;
  final ValueChanged<List<String>?> onChanged;

  @override
  State<_Advanced> createState() => _AdvancedState();
}

class _AdvancedState extends State<_Advanced> {
  late bool _open = widget.state.scope != null;

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final theme = Theme.of(context);
    final scope = s.scope;
    final summary = scope == null
        ? "Collections it may touch: same as the module's access"
        : 'Collections it may touch: ${scope.length}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => setState(() => _open = !_open),
          borderRadius: Radii.smAll,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Row(
              children: [
                Icon(_open ? Icons.expand_more : Icons.chevron_right, size: 20),
                const SizedBox(width: Spacing.xs),
                Text('Advanced', style: theme.textTheme.titleSmall),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: Text(
                    summary,
                    textAlign: TextAlign.end,
                    style: _muted(context),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_open)
          RadioGroup<bool>(
            groupValue: scope != null,
            onChanged: (only) => widget.onChanged(
              only == true ? [for (final c in s.scopeChoices) c.id] : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _RadioRow(
                  value: false,
                  title: "Same as the module's access",
                ),
                const _RadioRow(value: true, title: 'Only these'),
                if (scope != null)
                  for (final c in s.scopeChoices)
                    CheckboxListTile(
                      contentPadding: const EdgeInsets.only(left: 40),
                      controlAffinity: ListTileControlAffinity.leading,
                      value: scope.contains(c.id),
                      title: _CollectionLabel(collection: c),
                      onChanged: (on) => widget.onChanged([
                        for (final id in scope)
                          if (id != c.id) id,
                        if (on == true) c.id,
                      ]),
                    ),
              ],
            ),
          ),
      ],
    );
  }
}

class _DeleteButton extends StatelessWidget {
  const _DeleteButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => TextButton.icon(
    style: TextButton.styleFrom(
      foregroundColor: Theme.of(context).colorScheme.error,
      minimumSize: const Size(44, 44),
    ),
    onPressed: onPressed,
    icon: const Icon(Icons.delete_outline, size: 18),
    label: const Text('Delete'),
  );
}
