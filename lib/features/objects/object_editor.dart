import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api/data/data_repository.dart';
import '../../api/files/attachment_store.dart';
import '../../app/shell/app_shell.dart';
import '../../core/domain/domain.dart';
import '../../design/design.dart';
import '../views/widgets/view_labels.dart';
import 'object_editor_cubit.dart';
import 'value_editors/field_value_editor.dart';

/// How an editor session ended (null = closed without saving).
sealed class ObjectEditorResult {
  const ObjectEditorResult();
}

/// Saved; [object] is the whole object as it now stands.
final class ObjectEditorSaved extends ObjectEditorResult {
  const ObjectEditorSaved(this.object);

  final MorkvaObject object;

  String get id => object.id;
}

/// The user asked to delete the object; the caller deletes it (with Undo).
final class ObjectEditorDeleted extends ObjectEditorResult {
  const ObjectEditorDeleted();
}

/// Width of the side panel on wide screens.
const double kObjectEditorPanelWidth = 560;

/// Opens the object form: editing [object], or creating one (starting from
/// [prefill]) when it is null. Wide screens get a 560 px side panel over a
/// scrim; phones a full-screen page. [prefillNote] ("Filled from the Lead
/// column") is the helper under each prefilled field besides the title.
Future<ObjectEditorResult?> showObjectEditor(
  BuildContext context, {
  required Collection collection,
  MorkvaObject? object,
  Map<String, FieldValue> prefill = const {},
  String? prefillNote,
  String? titleFieldId,
}) {
  final repository = context.read<DataRepository>();
  final attachments = _attachmentStoreOf(context);
  final wide = MediaQuery.sizeOf(context).width >= AppShell.expandedBreakpoint;
  Widget host(BuildContext _) => BlocProvider(
    create: (_) {
      final cubit = ObjectEditorCubit(
        repository,
        collection,
        object: object,
        prefill: prefill,
        titleFieldId: titleFieldId,
        attachments: attachments,
      );
      unawaited(cubit.initialize());
      return cubit;
    },
    child: _EditorHost(
      compact: !wide,
      prefillNote: prefillNote,
      prefilledIds: {
        for (final id in prefill.keys)
          if (id != titleFieldId) id,
      },
    ),
  );

  if (!wide) {
    return Navigator.of(context).push(
      MaterialPageRoute<ObjectEditorResult>(
        fullscreenDialog: true,
        builder: host,
      ),
    );
  }
  final scheme = Theme.of(context).colorScheme;
  final reduceMotion = MediaQuery.disableAnimationsOf(context);
  return showGeneralDialog<ObjectEditorResult>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close editor',
    barrierColor: scheme.onSurface.withValues(alpha: 0.32),
    transitionDuration: reduceMotion
        ? MotionDurations.none
        : MotionDurations.slow,
    pageBuilder: (context, _, _) => Align(
      alignment: Alignment.centerRight,
      child: Container(
        width: kObjectEditorPanelWidth,
        height: double.infinity,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: MorkvaElevation.level3,
        ),
        child: Material(type: MaterialType.transparency, child: host(context)),
      ),
    ),
    transitionBuilder: (_, animation, _, child) => SlideTransition(
      position: Tween(begin: const Offset(1, 0), end: Offset.zero).animate(
        CurvedAnimation(parent: animation, curve: MotionCurves.emphasized),
      ),
      child: child,
    ),
  );
}

/// The app's [AttachmentStore], or null where none is provided (file fields
/// then can't upload).
AttachmentStore? _attachmentStoreOf(BuildContext context) {
  try {
    return context.read<AttachmentStore>();
  } on ProviderNotFoundException {
    return null;
  }
}

/// Closes on save/delete with the result; guards closing over unsaved
/// changes with "Discard changes?". While saving, closing is blocked.
class _EditorHost extends StatelessWidget {
  const _EditorHost({
    required this.compact,
    required this.prefillNote,
    required this.prefilledIds,
  });

  final bool compact;
  final String? prefillNote;
  final Set<String> prefilledIds;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ObjectEditorCubit, ObjectEditorState>(
      listenWhen: (prev, next) => prev.status != next.status,
      listener: (context, state) {
        final result = switch (state.status) {
          ObjectEditorStatus.saved => ObjectEditorSaved(state.savedObject!),
          ObjectEditorStatus.deleted => const ObjectEditorDeleted(),
          _ => null,
        };
        if (result == null) return;
        // Close this editor's own route, even if something sits on top.
        final route = ModalRoute.of(context);
        final navigator = Navigator.of(context);
        if (route != null) navigator.popUntil((r) => r == route);
        navigator.pop(result);
      },
      buildWhen: (prev, next) =>
          prev.hasUnsavedChanges != next.hasUnsavedChanges ||
          prev.isSaving != next.isSaving,
      builder: (context, state) => PopScope<ObjectEditorResult>(
        canPop: !state.hasUnsavedChanges && !state.isSaving,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop || state.isSaving) return;
          final discard = await MorkvaConfirmDialog.show(
            context,
            title: 'Discard changes?',
            message:
                "Your changes to this ${itemLabelOf(state.collection)} "
                "haven't been saved.",
            confirmLabel: 'Discard',
            cancelLabel: 'Keep editing',
            destructive: true,
          );
          if (discard == true && context.mounted) Navigator.of(context).pop();
        },
        child: ObjectEditor(
          compact: compact,
          prefillNote: prefillNote,
          prefilledIds: prefilledIds,
        ),
      ),
    );
  }
}

/// The object form: header, banners, the collection's card layout of field
/// editors, and the actions (a footer in the panel, the app bar on phones).
/// Reads [ObjectEditorCubit] from the context.
class ObjectEditor extends StatefulWidget {
  const ObjectEditor({
    super.key,
    required this.compact,
    this.prefillNote,
    this.prefilledIds = const {},
  });

  /// Phone page (app bar) instead of the side panel (header + footer).
  final bool compact;
  final String? prefillNote;

  /// Fields that show [prefillNote] while unchanged.
  final Set<String> prefilledIds;

  @override
  State<ObjectEditor> createState() => _ObjectEditorState();
}

class _ObjectEditorState extends State<ObjectEditor> {
  final _scroll = ScrollController();
  final Map<String, GlobalKey> _keys = {};
  late final Set<String> _collapsed = {
    for (final s
        in context.read<ObjectEditorCubit>().state.collection.layout.sections)
      if (s.collapsed && _hasTitle(s)) s.id,
  };

  static bool _hasTitle(LayoutSection s) => s.title?.trim().isNotEmpty ?? false;

  GlobalKey _keyFor(String fieldId) =>
      _keys.putIfAbsent(fieldId, () => GlobalKey(debugLabel: fieldId));

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _close() => Navigator.of(context).maybePop();

  /// Close/Cancel: disabled while a save is in flight.
  VoidCallback? _closeFor(ObjectEditorState state) =>
      state.isSaving ? null : _close;

  Future<void> _save() async {
    final cubit = context.read<ObjectEditorCubit>();
    final saved = await cubit.save();
    if (saved || !mounted) return;
    _revealFirstError(cubit.state);
  }

  /// Expands the section holding the first invalid field and scrolls to it.
  void _revealFirstError(ObjectEditorState state) {
    final errors = state.visibleErrors;
    if (errors.isEmpty) return;
    for (final section in _layoutOf(state.collection).sections) {
      for (final row in section.rows) {
        for (final cell in row.cells) {
          if (!errors.containsKey(cell.fieldId)) continue;
          setState(() => _collapsed.remove(section.id));
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final target = _keys[cell.fieldId]?.currentContext;
            if (target == null || !target.mounted) return;
            Scrollable.ensureVisible(
              target,
              alignment: 0.1,
              duration: MediaQuery.disableAnimationsOf(context)
                  ? MotionDurations.none
                  : MotionDurations.slow,
              curve: MotionCurves.emphasized,
            );
          });
          return;
        }
      }
    }
  }

  static CardLayout _layoutOf(Collection c) =>
      c.layout.reconcile([for (final f in c.fields) f.id]);

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ObjectEditorCubit>();
    return BlocBuilder<ObjectEditorCubit, ObjectEditorState>(
      builder: (context, state) {
        final errors = state.visibleErrors;
        final layout = _layoutOf(state.collection);
        final gutter = widget.compact ? Spacing.md : Spacing.lg;
        final sections = layout.sections;
        final form = ListView(
          controller: _scroll,
          padding: EdgeInsets.fromLTRB(gutter, Spacing.md, gutter, Spacing.lg),
          children: [
            for (final section in sections)
              _Section(
                section: section,
                showHeader: _hasTitle(section),
                collapsed: _collapsed.contains(section.id),
                onToggle: () => setState(() {
                  if (!_collapsed.remove(section.id)) {
                    _collapsed.add(section.id);
                  }
                }),
                cellBuilder: (fieldId) {
                  final field = state.collection.fieldById(fieldId);
                  if (field == null) return const SizedBox.shrink();
                  return _FieldCell(
                    key: _keyFor(fieldId),
                    field: field,
                    editor: cubit.editors.editorFor(field.type),
                    state: state,
                    error: errors[fieldId],
                    note:
                        widget.prefilledIds.contains(fieldId) &&
                            !state.changedFieldIds.contains(fieldId)
                        ? widget.prefillNote
                        : null,
                  );
                },
              ),
            if (widget.compact && !state.isCreate && !state.remoteDeleted) ...[
              const SizedBox(height: Spacing.lg),
              Align(
                alignment: Alignment.centerLeft,
                child: _DeleteButton(
                  label: 'Delete ${itemLabelOf(state.collection)}',
                  onPressed: state.isSaving ? null : cubit.requestDelete,
                ),
              ),
            ],
          ],
        );
        final body = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Banners(state: state, gutter: gutter),
            Expanded(child: form),
          ],
        );
        final saveLabel = state.isUploading
            ? 'Uploading…'
            : state.remoteDeleted
            ? 'Save as new'
            : 'Save';
        final onSave = state.isUploading ? null : _save;
        if (widget.compact) {
          final theme = Theme.of(context);
          return Scaffold(
            backgroundColor: theme.colorScheme.surface,
            appBar: AppBar(
              backgroundColor: theme.colorScheme.surface,
              surfaceTintColor: Colors.transparent,
              titleSpacing: 0,
              shape: Border(
                bottom: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
              leading: IconButton(
                tooltip: 'Close',
                icon: const Icon(Icons.close),
                onPressed: _closeFor(state),
              ),
              title: Text(
                state.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge,
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: Spacing.xs),
                  child: PrimaryButton(
                    label: saveLabel,
                    loading: state.isSaving,
                    onPressed: onSave,
                  ),
                ),
              ],
            ),
            body: SafeArea(top: false, child: body),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(state: state, onClose: _closeFor(state)),
            Expanded(child: body),
            _Footer(
              saveLabel: saveLabel,
              saving: state.isSaving,
              onSave: onSave,
              onCancel: _closeFor(state),
              onDelete: state.isCreate || state.remoteDeleted
                  ? null
                  : cubit.requestDelete,
            ),
          ],
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// Chrome
// -----------------------------------------------------------------------------

class _Header extends StatelessWidget {
  const _Header({required this.state, required this.onClose});

  final ObjectEditorState state;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final collection = state.collection;
    final stored = state.stored;
    final item = itemLabelOf(collection);
    final meta = stored == null
        ? collection.name
        : '${item[0].toUpperCase()}${item.substring(1)}'
              ' · created ${_shortDate(stored.createdAt)}'
              ' · edited ${_ago(stored.updatedAt)}';
    return Container(
      padding: const EdgeInsets.fromLTRB(
        Spacing.lg,
        Spacing.md + Spacing.xxs,
        Spacing.md + Spacing.xxs,
        Spacing.md,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CollectionGlyph(iconKey: collection.icon, size: 40, iconSize: 20),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: state.isCreate ? scheme.onSurfaceVariant : null,
                  ),
                ),
                const SizedBox(height: Spacing.xxs / 2),
                Text(
                  meta,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconActionButton(
            icon: Icons.close,
            tooltip: 'Close',
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

/// "Oct 12, 2026" for the local day of [t].
String _shortDate(DateTime t) {
  final l = t.toLocal();
  return formatFieldValue(
    const DateFieldDefinition(id: '', name: ''),
    DateFieldValue(DateTime.utc(l.year, l.month, l.day)),
  );
}

/// "just now", "5 min ago", "2 h ago", else the date.
String _ago(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inHours < 1) return '${d.inMinutes} min ago';
  if (d.inDays < 1) return '${d.inHours} h ago';
  return _shortDate(t);
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.saveLabel,
    required this.saving,
    required this.onSave,
    required this.onCancel,
    required this.onDelete,
  });

  final String saveLabel;
  final bool saving;
  final VoidCallback? onSave;
  final VoidCallback? onCancel;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.md + Spacing.xxs,
        vertical: Spacing.sm,
      ),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: [
          if (onDelete case final delete?)
            _DeleteButton(label: 'Delete', onPressed: saving ? null : delete),
          const Spacer(),
          TextActionButton(label: 'Cancel', onPressed: onCancel),
          const SizedBox(width: Spacing.xs),
          PrimaryButton(label: saveLabel, loading: saving, onPressed: onSave),
        ],
      ),
    );
  }
}

class _DeleteButton extends StatelessWidget {
  const _DeleteButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => TextButton.icon(
    style: TextButton.styleFrom(
      foregroundColor: Theme.of(context).colorScheme.error,
      minimumSize: const Size(44, 44),
    ),
    onPressed: onPressed,
    icon: const Icon(Icons.delete_outline, size: 18),
    label: Text(label),
  );
}

/// Errors to fix, a failed save, conflicts and a remote delete.
class _Banners extends StatelessWidget {
  const _Banners({required this.state, required this.gutter});

  final ObjectEditorState state;
  final double gutter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final semantic = theme.extension<MorkvaSemanticColors>();
    final warning = (semantic?.warning ?? scheme.tertiary).withValues(
      alpha: 0.24,
    );
    final count = state.showAllErrors ? state.errorCount : 0;
    final conflicts = [
      for (final f in state.collection.fields)
        if (state.conflictFieldIds.contains(f.id)) f.name,
    ];
    final item = itemLabelOf(state.collection);
    final banners = [
      if (count > 0)
        _Banner(
          icon: Icons.error_outline,
          background: scheme.errorContainer,
          foreground: scheme.onErrorContainer,
          alert: true,
          title: 'Fix $count ${count == 1 ? 'field' : 'fields'} to save',
        ),
      if (state.status == ObjectEditorStatus.saveFailed)
        _Banner(
          icon: Icons.cloud_off_outlined,
          background: scheme.errorContainer,
          foreground: scheme.onErrorContainer,
          alert: true,
          title: "Couldn't save — check your connection",
        ),
      if (state.remoteDeleted)
        _Banner(
          icon: Icons.warning_amber_rounded,
          background: warning,
          foreground: scheme.onSurface,
          title: 'This $item was deleted elsewhere.',
          message: 'Save as new to restore it.',
        )
      else if (conflicts.isNotEmpty)
        _Banner(
          icon: Icons.warning_amber_rounded,
          background: warning,
          foreground: scheme.onSurface,
          title:
              '${_names(conflicts)} ${conflicts.length == 1 ? 'was' : 'were'} '
              'changed elsewhere.',
          message: 'Saving will overwrite it with your value.',
        ),
    ];
    if (banners.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.fromLTRB(gutter, Spacing.md, gutter, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: Spacing.xs,
        children: banners,
      ),
    );
  }

  static String _names(List<String> names) => names.length == 1
      ? names.single
      : '${names.take(names.length - 1).join(', ')} and ${names.last}';
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.icon,
    required this.background,
    required this.foreground,
    required this.title,
    this.message,
    this.alert = false,
  });

  final IconData icon;
  final Color background;
  final Color foreground;
  final String title;
  final String? message;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.sm + Spacing.xxs / 2,
          vertical: Spacing.sm,
        ),
        decoration: BoxDecoration(color: background, borderRadius: Radii.mdAll),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: foreground),
            const SizedBox(width: Spacing.xs),
            Expanded(
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
                style: theme.textTheme.bodyMedium?.copyWith(color: foreground),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Layout
// -----------------------------------------------------------------------------

/// Cells narrower than this stack full width instead (same rule as the card
/// preview).
const double _minCellWidth = 240;
const double _cellGap = Spacing.md;

class _Section extends StatelessWidget {
  const _Section({
    required this.section,
    required this.showHeader,
    required this.collapsed,
    required this.onToggle,
    required this.cellBuilder,
  });

  final LayoutSection section;
  final bool showHeader;
  final bool collapsed;
  final VoidCallback onToggle;
  final Widget Function(String fieldId) cellBuilder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final count = [for (final r in section.rows) ...r.cells].length;
    final rows = [
      for (final row in section.rows)
        Padding(
          padding: const EdgeInsets.only(bottom: Spacing.md + Spacing.xxs / 2),
          child: _Row(row: row, cellBuilder: cellBuilder),
        ),
    ];
    if (!showHeader) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: rows,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          key: ValueKey('section-${section.id}'),
          button: true,
          expanded: !collapsed,
          child: InkWell(
            onTap: onToggle,
            borderRadius: Radii.smAll,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Row(
                children: [
                  Icon(
                    collapsed ? Icons.chevron_right : Icons.expand_more,
                    size: 20,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: Spacing.xs),
                  Flexible(
                    child: Text(
                      section.title!,
                      style: theme.textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (collapsed)
                    Text(
                      ' · $count ${count == 1 ? 'field' : 'fields'}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: Spacing.xs),
        if (!collapsed) ...rows,
      ],
    );
  }
}

/// One layout row: cells side by side by their 12-column spans, or stacked
/// when any cell would be narrower than [_minCellWidth].
class _Row extends StatelessWidget {
  const _Row({required this.row, required this.cellBuilder});

  final LayoutRow row;
  final Widget Function(String fieldId) cellBuilder;

  @override
  Widget build(BuildContext context) {
    final cells = row.cells;
    if (cells.length == 1) return cellBuilder(cells.single.fieldId);
    return LayoutBuilder(
      builder: (context, constraints) {
        final usable = constraints.maxWidth - _cellGap * (cells.length - 1);
        final stack = cells.any(
          (c) => usable * c.span / kLayoutColumns < _minCellWidth,
        );
        if (stack) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: Spacing.md + Spacing.xxs / 2,
            children: [for (final c in cells) cellBuilder(c.fieldId)],
          );
        }
        final rest =
            kLayoutColumns - cells.fold<int>(0, (sum, c) => sum + c.span);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: _cellGap,
          children: [
            for (final c in cells)
              Expanded(flex: c.span, child: cellBuilder(c.fieldId)),
            if (rest > 0) Spacer(flex: rest),
          ],
        );
      },
    );
  }
}

/// One field: label (name, `*` when required, a dot when changed), its
/// editor, and the error / prefill note / description line.
class _FieldCell extends StatelessWidget {
  const _FieldCell({
    super.key,
    required this.field,
    required this.editor,
    required this.state,
    required this.error,
    required this.note,
  });

  final FieldDefinition field;
  final FieldValueEditor editor;
  final ObjectEditorState state;
  final String? error;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final cubit = context.read<ObjectEditorCubit>();
    final changed = !state.isCreate && state.changedFieldIds.contains(field.id);
    final message = error ?? state.uploadErrors[field.id];
    final helpStyle = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final description = field.description?.trim();
    final help =
        note ??
        (description == null || description.isEmpty ? null : description);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!editor.rendersOwnLabel) ...[
          Row(
            children: [
              Flexible(
                child: Text.rich(
                  TextSpan(
                    text: field.name,
                    children: [
                      if (field.isRequired)
                        TextSpan(
                          text: ' *',
                          style: TextStyle(color: scheme.error),
                        ),
                    ],
                  ),
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (changed) ...[
                const SizedBox(width: Spacing.xs),
                Semantics(
                  label: 'Changed',
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: Spacing.xs - Spacing.xxs / 2),
        ],
        // Blur (focus leaving the editor) marks the field visited.
        Focus(
          canRequestFocus: false,
          skipTraversal: true,
          onFocusChange: (focused) {
            if (!focused) cubit.touch(field.id);
          },
          child: Builder(
            builder: (inner) => editor.build(
              inner,
              ValueEditorContext(
                field: field,
                value: state.valueOf(field),
                error: error,
                enabled: !state.isSaving,
                references: state.references,
                attachments: field is FileFieldDefinition && cubit.canUpload
                    ? AttachmentActions(
                        upload: (files) => cubit.upload(field.id, files),
                        open: (a) => _openAttachment(context, cubit, a),
                        cancel: cubit.cancelUpload,
                        uploads: [
                          for (final u in state.uploads)
                            if (u.fieldId == field.id) u,
                        ],
                      )
                    : null,
                onChanged: (value) {
                  cubit.change(field.id, value);
                  // Pickers never hold focus: they count as visited at once.
                  if (!Focus.of(inner).hasFocus) cubit.touch(field.id);
                },
                onInputError: (message) =>
                    cubit.setInputError(field.id, message),
              ),
            ),
          ),
        ),
        if (message != null) ...[
          const SizedBox(height: Spacing.xxs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline, size: 14, color: scheme.error),
              const SizedBox(width: Spacing.xxs),
              Expanded(
                child: Text(
                  message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.error,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ] else if (help != null) ...[
          const SizedBox(height: Spacing.xxs),
          Text(help, style: helpStyle),
        ],
      ],
    );
  }
}

/// Opens [attachment]'s download URL in a new tab / external app; a failure
/// shows "Couldn't open ⟨name⟩".
Future<void> _openAttachment(
  BuildContext context,
  ObjectEditorCubit cubit,
  FileAttachment attachment,
) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    final url = await cubit.downloadUrl(attachment);
    if (await launchUrl(url, mode: LaunchMode.externalApplication)) return;
  } catch (_) {
    // Reported below.
  }
  messenger?.showSnackBar(
    SnackBar(content: Text("Couldn't open ${attachment.name}")),
  );
}
