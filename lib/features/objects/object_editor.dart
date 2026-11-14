import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api/data/data_repository.dart';
import '../../api/files/attachment_store.dart';
import '../../app/shell/app_shell.dart';
import '../../core/automation/runner_api.dart';
import '../../core/domain/automation/automation.dart' show AutomationStatus;
import '../../core/domain/domain.dart';
import '../../design/design.dart';
import '../../l10n/l10n.dart';
import '../automation/bloc/automation_runs_cubit.dart';
import '../automation/bloc/modules_cubit.dart';
import '../automation/view/automations_page.dart' show automationsOffline;
import '../automation/view/review_sheet.dart';
import '../automation/widgets/action_buttons.dart';
import '../automation/widgets/reason_copy.dart' show CopyTone;
import '../automation/widgets/status_chip.dart';
import '../views/widgets/view_labels.dart';
import 'object_editor_cubit.dart';
import 'value_editors/field_value_editor.dart';
import 'widgets/sublist_section.dart';

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

/// Maximum width of the centered dialog on wide screens (room for two-column
/// layout rows).
const double kObjectEditorDialogMaxWidth = 720;

/// Opens the object form: editing [object], or creating one (starting from
/// [prefill]) when it is null. Wide screens get a centered dialog that grows
/// with the form up to the viewport; phones a full-screen page. [prefillNote] ("Filled from the Lead
/// column") is the helper under each prefilled field besides the title.
///
/// A card saved by "Save and run" and then closed still reports
/// [ObjectEditorSaved].
Future<ObjectEditorResult?> showObjectEditor(
  BuildContext context, {
  required Collection collection,
  MorkvaObject? object,
  Map<String, FieldValue> prefill = const {},
  String? prefillNote,
  String? titleFieldId,
  Map<String, FieldValue> Function(MorkvaObject draft)? derive,
  Map<String, String> notes = const {},
}) async {
  final repository = context.read<DataRepository>();
  final attachments = _attachmentStoreOf(context);
  final carry = automationCarrier(context);
  final wide = MediaQuery.sizeOf(context).width >= AppShell.expandedBreakpoint;
  ObjectEditorCubit? created;
  Widget host(BuildContext _) => carry(
    BlocProvider(
      create: (_) {
        final cubit = created = ObjectEditorCubit(
          repository,
          collection,
          object: object,
          prefill: prefill,
          titleFieldId: titleFieldId,
          attachments: attachments,
          derive: derive,
          notes: notes,
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
    ),
  );

  final ObjectEditorResult? result;
  if (!wide) {
    result = await Navigator.of(context).push(
      MaterialPageRoute<ObjectEditorResult>(
        fullscreenDialog: true,
        builder: host,
      ),
    );
  } else {
    result = await _showDialog(context, host);
  }
  final last = created?.state;
  if (result == null && last?.savedObject != null) {
    return ObjectEditorSaved(last!.stored ?? last.savedObject!);
  }
  return result;
}

Future<ObjectEditorResult?> _showDialog(
  BuildContext context,
  WidgetBuilder host,
) {
  final reduceMotion = MediaQuery.disableAnimationsOf(context);
  return showGeneralDialog<ObjectEditorResult>(
    context: context,
    barrierDismissible: true,
    barrierLabel: context.l10n.objectsCloseEditor,
    // The same dark scrim as showDialog; a theme color like onSurface turns
    // into a light wash in dark mode.
    barrierColor: Colors.black54,
    transitionDuration: reduceMotion
        ? MotionDurations.none
        : MotionDurations.base,
    pageBuilder: (context, _, _) => SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: kObjectEditorDialogMaxWidth,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: Radii.fullAll,
                boxShadow: MorkvaElevation.level3,
              ),
              child: Material(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: Radii.fullAll,
                clipBehavior: Clip.antiAlias,
                child: host(context),
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
          final l10n = context.l10n;
          final discard = await MorkvaConfirmDialog.show(
            context,
            title: l10n.objectsDiscardTitle,
            message: l10n.objectsDiscardMessage(itemLabelOf(state.collection)),
            confirmLabel: l10n.objectsDiscard,
            cancelLabel: l10n.objectsKeepEditing,
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

  /// Phone page (app bar) instead of the dialog (header + footer).
  final bool compact;
  final String? prefillNote;

  /// Fields that show [prefillNote] while unchanged.
  final Set<String> prefilledIds;

  @override
  State<ObjectEditor> createState() => _ObjectEditorState();
}

class _ObjectEditorState extends State<ObjectEditor> {
  /// Open editors, innermost last (an item's editor over its parent's): the
  /// innermost one shows run notices, and the runs cubit hears "editor open"
  /// while any is up.
  static final _open = <_ObjectEditorState>[];

  final _scroll = ScrollController();
  late final AutomationRunsCubit? _runs = maybeRead<AutomationRunsCubit>(
    context,
  );

  /// The finished run the banner tells about, or a refused press.
  RunView? _run;
  String? _runMessage;
  bool _runMessageError = true;
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
  void initState() {
    super.initState();
    if (_open.isEmpty) _runs?.editorOpened();
    _open.add(this);
  }

  @override
  void dispose() {
    _open.remove(this);
    if (_open.isEmpty && !(_runs?.isClosed ?? true)) _runs?.editorClosed();
    _scroll.dispose();
    super.dispose();
  }

  void _close() => Navigator.of(context).maybePop();

  /// "Save and run": saves without closing, then runs on the saved card.
  /// A failed save shows its usual error and nothing runs.
  Future<void> _saveAndRun(AutomationEntry entry) async {
    final cubit = context.read<ObjectEditorCubit>();
    final runs = _runs;
    if (runs == null) return;
    if (!await cubit.save(stayOpen: true)) {
      if (mounted) _revealFirstError(cubit.state);
      return;
    }
    final cardId = cubit.state.stored?.id;
    if (cardId == null) return;
    final runId = await runs.pressCard(entry.automation.id, cardId: cardId);
    if (runId == null && mounted) _showRunMessage(runs.state.error);
  }

  /// A refusal (the default) shows in the error tone, never as a success.
  void _showRunMessage(String? message, {bool error = true}) {
    if (message == null) return;
    setState(() {
      _run = null;
      _runMessage = message;
      _runMessageError = error;
    });
  }

  /// Leaves the editor for [path]: at once when nothing is unsaved, else
  /// through "Discard changes?" (and stays on the card).
  void _leaveTo(String path) {
    final state = context.read<ObjectEditorCubit>().state;
    if (state.hasUnsavedChanges || state.isSaving) {
      _close();
      return;
    }
    final router = GoRouter.maybeOf(context);
    Navigator.of(context).pop();
    router?.go(path);
  }

  late final _hooks = CardActionHooks(
    onSaveAndRun: _saveAndRun,
    onNavigate: _leaveTo,
    onMessage: _showRunMessage,
  );

  /// A run finished while this editor is the innermost one: the banner,
  /// or (a button run of this card, the editor on top) the review sheet.
  void _onNotice(BuildContext context, AutomationRunsState runs) {
    final notice = runs.notice;
    final cubit = _runs;
    if (notice == null || cubit == null || _open.lastOrNull != this) return;
    if (notice.surface == NoticeSurface.snackbar) return;
    cubit.noticeShown();
    final run = notice.run;
    if (notice.surface == NoticeSurface.reviewSheet &&
        run.trigger.cardId != null &&
        _otherCard(run) == null &&
        (ModalRoute.of(context)?.isCurrent ?? false)) {
      showReviewSheet(context, runId: run.runId, overEditor: true);
      return;
    }
    setState(() {
      _run = run;
      _runMessage = null;
    });
  }

  /// The label of the card [run] ran on when that isn't this editor's card;
  /// the banner names it so it never reads as this card's run.
  String? _otherCard(RunView run) {
    final cardId = run.trigger.cardId;
    if (cardId == null ||
        cardId == context.read<ObjectEditorCubit>().state.stored?.id) {
      return null;
    }
    return run.trigger.cardLabel ?? context.l10n.objectsAnotherCard;
  }

  Future<void> _onNoticeAction(NoticeAction action, RunView run) async {
    final runs = _runs;
    if (runs == null) return;
    switch (action) {
      case NoticeAction.undo:
        if (await runs.undo(run.runId)) {
          if (mounted) {
            final card = _otherCard(run);
            _showRunMessage(
              card == null
                  ? context.l10n.objectsRunReverted(run.label)
                  : context.l10n.objectsRunRevertedOnCard(run.label, card),
              error: false,
            );
          }
        } else if (mounted) {
          _showRunMessage(runs.state.error);
        }
      case NoticeAction.viewRun:
        _leaveTo(AutomationPaths.run(run.runId));
      case NoticeAction.review:
        await showReviewSheet(context, runId: run.runId, overEditor: true);
      case NoticeAction.runAgain:
        final id = await runs.runAgain(run.runId);
        if (id == null && mounted) _showRunMessage(runs.state.error);
    }
  }

  Widget? _runBanner() {
    final run = _run;
    final message = _runMessage;
    if (run == null && message == null) return null;
    return _RunBanner(
      copy: run == null
          ? (text: message!, actions: const [], error: _runMessageError)
          : runNoticeCopy(
              run,
              card: _otherCard(run),
              l10n: context.l10n,
              runnable:
                  maybeRead<ModulesCubit>(context)?.state.automations.any(
                    (a) =>
                        a.automation.id == run.automationId &&
                        a.status != AutomationStatus.needsConsent &&
                        a.status != AutomationStatus.broken,
                  ) ??
                  false,
            ),
      compact: widget.compact,
      onAction: run == null ? null : (a) => _onNoticeAction(a, run),
      onDismiss: () => setState(() {
        _run = null;
        _runMessage = null;
      }),
    );
  }

  /// Close/Cancel: disabled while a save is in flight.
  VoidCallback? _closeFor(ObjectEditorState state) =>
      state.isSaving ? null : _close;

  Future<void> _save() async {
    final cubit = context.read<ObjectEditorCubit>();
    final saved = await cubit.save();
    if (saved || !mounted) return;
    _revealFirstError(cubit.state);
  }

  /// Asks before deleting; the views page still offers Undo afterwards.
  Future<void> _delete() async {
    final cubit = context.read<ObjectEditorCubit>();
    final state = cubit.state;
    final item = itemLabelOf(state.collection);
    final l10n = context.l10n;
    final confirmed = await MorkvaConfirmDialog.show(
      context,
      title: l10n.objectsDeleteItemTitle(item),
      message: l10n.objectsDeleteItemMessage(state.title(l10n)),
      confirmLabel: l10n.commonDelete,
      destructive: true,
    );
    if (confirmed == true && mounted) cubit.requestDelete();
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
    final runs = _runs;
    final form = _form(context);
    if (runs == null) return form;
    return BlocListener<AutomationRunsCubit, AutomationRunsState>(
      bloc: runs,
      listenWhen: (prev, next) =>
          next.notice != null && prev.notice != next.notice,
      listener: _onNotice,
      child: form,
    );
  }

  Widget _form(BuildContext context) {
    final cubit = context.read<ObjectEditorCubit>();
    return BlocBuilder<ObjectEditorCubit, ObjectEditorState>(
      builder: (context, state) {
        final l10n = context.l10n;
        final errors = state.visibleErrorsWordedBy(l10n.validationMessage);
        final layout = _layoutOf(state.collection);
        final gutter = widget.compact ? Spacing.md : Spacing.lg;
        final sections = layout.sections;
        final form = ListView(
          controller: _scroll,
          // The dialog sizes to the form, up to the viewport.
          shrinkWrap: !widget.compact,
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
            for (final sublist in state.sublists) ...[
              const SizedBox(height: Spacing.md),
              SublistSection(sublist: sublist, parent: state.collection),
            ],
            if (widget.compact && !state.isCreate && !state.remoteDeleted) ...[
              const SizedBox(height: Spacing.lg),
              Align(
                alignment: Alignment.centerLeft,
                child: _DeleteButton(
                  label: l10n.objectsDeleteItem(itemLabelOf(state.collection)),
                  onPressed: state.isSaving ? null : _delete,
                ),
              ),
            ],
          ],
        );
        final body = Column(
          mainAxisSize: widget.compact ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Banners(state: state, gutter: gutter, run: _runBanner()),
            Flexible(
              fit: widget.compact ? FlexFit.tight : FlexFit.loose,
              child: form,
            ),
          ],
        );
        final saveLabel = state.isUploading
            ? l10n.objectsUploading
            : state.remoteDeleted
            ? l10n.objectsSaveAsNew
            : l10n.commonSave;
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
                tooltip: l10n.commonClose,
                icon: const Icon(MorkvaIcons.close),
                onPressed: _closeFor(state),
              ),
              title: Text(
                state.title(l10n),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge,
              ),
              bottom: _runs == null
                  ? null
                  : CardRunProgress(
                      collectionId: state.collection.id,
                      cardId: state.stored?.id,
                    ),
              actions: [
                CardActions(
                  compact: true,
                  collectionId: state.collection.id,
                  cardId: state.stored?.id,
                  dirty: state.hasUnsavedChanges,
                  hooks: _hooks,
                ),
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
            // A page left open while the window widens stays readable.
            body: SafeArea(
              top: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: kObjectEditorDialogMaxWidth,
                  ),
                  child: body,
                ),
              ),
            ),
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              state: state,
              onClose: _closeFor(state),
              actions: (width) => CardActions(
                collectionId: state.collection.id,
                cardId: state.stored?.id,
                dirty: state.hasUnsavedChanges,
                hooks: _hooks,
                headerWidth: width,
              ),
            ),
            Flexible(child: body),
            _Footer(
              saveLabel: saveLabel,
              saving: state.isSaving,
              onSave: onSave,
              onCancel: _closeFor(state),
              onDelete: state.isCreate || state.remoteDeleted ? null : _delete,
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
  const _Header({
    required this.state,
    required this.onClose,
    required this.actions,
  });

  final ObjectEditorState state;
  final VoidCallback? onClose;

  /// The card's action buttons for a header [width] wide.
  final Widget Function(double width) actions;

  @override
  Widget build(BuildContext context) {
    final collection = state.collection;
    final stored = state.stored;
    final item = itemLabelOf(collection);
    final l10n = context.l10n;
    final meta = stored == null
        ? collection.name
        : l10n.objectsHeaderMeta(
            '${item[0].toUpperCase()}${item.substring(1)}',
            _shortDate(stored.createdAt),
            _ago(l10n, stored.updatedAt),
          );
    return LayoutBuilder(
      builder: (context, constraints) =>
          _bar(context, meta: meta, buttons: actions(constraints.maxWidth)),
    );
  }

  Widget _bar(
    BuildContext context, {
    required String meta,
    required Widget buttons,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final collection = state.collection;
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
          CollectionGlyph(
            iconKey: collection.icon,
            tintSeed: collection.id,
            size: 40,
            iconSize: 20,
          ),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.title(context.l10n),
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
          buttons,
          IconActionButton(
            icon: MorkvaIcons.close,
            tooltip: context.l10n.commonClose,
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
String _ago(AppLocalizations l10n, DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return l10n.objectsJustNow;
  if (d.inHours < 1) return l10n.objectsMinutesAgo(d.inMinutes);
  if (d.inDays < 1) return l10n.objectsHoursAgo(d.inHours);
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
    final l10n = context.l10n;
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
            _DeleteButton(
              label: l10n.commonDelete,
              onPressed: saving ? null : delete,
            ),
          const Spacer(),
          TextActionButton(label: l10n.commonCancel, onPressed: onCancel),
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
    icon: const Icon(MorkvaIcons.delete, size: 18),
    label: Text(label),
  );
}

/// Errors to fix, a failed save, conflicts and a remote delete.
class _Banners extends StatelessWidget {
  const _Banners({required this.state, required this.gutter, this.run});

  final ObjectEditorState state;
  final double gutter;

  /// A finished automation run (never a shell snackbar under the editor's
  /// scrim).
  final Widget? run;

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
    final l10n = context.l10n;
    final banners = [
      ?run,
      if (count > 0)
        _Banner(
          icon: MorkvaIcons.error,
          background: scheme.errorContainer,
          foreground: scheme.onErrorContainer,
          alert: true,
          title: l10n.objectsFixFields(count),
        ),
      if (state.status == ObjectEditorStatus.saveFailed)
        _Banner(
          icon: MorkvaIcons.cloudOff,
          background: scheme.errorContainer,
          foreground: scheme.onErrorContainer,
          alert: true,
          title: l10n.objectsSaveFailed,
        ),
      if (state.remoteDeleted)
        _Banner(
          icon: MorkvaIcons.warning,
          background: warning,
          foreground: scheme.onSurface,
          title: l10n.objectsDeletedElsewhere(item),
          message: l10n.objectsSaveAsNewToRestore,
        )
      else if (conflicts.isNotEmpty)
        _Banner(
          icon: MorkvaIcons.warning,
          background: warning,
          foreground: scheme.onSurface,
          title: l10n.objectsChangedElsewhere(
            conflicts.length,
            _names(l10n, conflicts),
          ),
          message: l10n.objectsOverwriteNote,
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

  static String _names(AppLocalizations l10n, List<String> names) =>
      names.length == 1
      ? names.single
      : l10n.objectsNamesAnd(
          names.take(names.length - 1).join(', '),
          names.last,
        );
}

/// "Mark shipped · 1 order updated · Undo · View run" (UX §4).
class _RunBanner extends StatelessWidget {
  const _RunBanner({
    required this.copy,
    required this.compact,
    required this.onAction,
    required this.onDismiss,
  });

  final NoticeCopy copy;
  final bool compact;
  final ValueChanged<NoticeAction>? onAction;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final review = copy.actions.contains(NoticeAction.review);
    // Run again needs a connection, as on run detail.
    final offline =
        copy.actions.contains(NoticeAction.runAgain) &&
        automationsOffline(context);
    final colors = StatusChip.colorsOf(
      theme,
      copy.error
          ? CopyTone.error
          : review
          ? CopyTone.warning
          : CopyTone.success,
    );
    final (head, tail) = switch (copy.text.indexOf(' · ')) {
      -1 => (copy.text, ''),
      final i => (copy.text.substring(0, i), copy.text.substring(i)),
    };
    final text = Text.rich(
      TextSpan(
        text: head,
        style: const TextStyle(fontWeight: FontWeight.w600),
        children: [
          TextSpan(
            text: tail,
            style: const TextStyle(fontWeight: FontWeight.w400),
          ),
        ],
      ),
      style: theme.textTheme.bodyMedium?.copyWith(color: colors.foreground),
    );
    final buttons = [
      for (final a in copy.actions)
        TextButton.icon(
          style: TextButton.styleFrom(
            foregroundColor: colors.foreground,
            minimumSize: const Size(44, 44),
          ),
          onPressed: onAction == null || (offline && a == NoticeAction.runAgain)
              ? null
              : () => onAction!(a),
          icon: a == NoticeAction.undo
              ? const Icon(MorkvaIcons.undo, size: 18)
              : null,
          label: Text(a.labelIn(l10n)),
        ),
      if (offline)
        Padding(
          padding: const EdgeInsets.only(right: Spacing.xs),
          child: Text(
            l10n.objectsNeedsConnection,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.foreground,
            ),
          ),
        ),
      if (copy.actions.isEmpty)
        IconButton(
          tooltip: l10n.objectsDismiss,
          color: colors.foreground,
          icon: const Icon(MorkvaIcons.close, size: 18),
          onPressed: onDismiss,
        ),
    ];
    final icon = Icon(
      copy.error
          ? MorkvaIcons.error
          : review
          ? MorkvaIcons.review
          : MorkvaIcons.checkCircle,
      size: 20,
      color: colors.foreground,
    );
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        key: const ValueKey('run-banner'),
        padding: const EdgeInsets.fromLTRB(
          Spacing.sm + Spacing.xxs / 2,
          Spacing.xxs,
          Spacing.xxs,
          Spacing.xxs,
        ),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: Radii.mdAll,
        ),
        child: compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: Spacing.xs),
                    child: Row(
                      children: [
                        icon,
                        const SizedBox(width: Spacing.xs),
                        Expanded(child: text),
                      ],
                    ),
                  ),
                  // Wraps: View run, Run again and "Needs a connection"
                  // don't fit one phone row.
                  Wrap(
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: buttons,
                  ),
                ],
              )
            : Row(
                children: [
                  icon,
                  const SizedBox(width: Spacing.xs),
                  Expanded(child: text),
                  ...buttons,
                ],
              ),
      ),
    );
  }
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

/// Below this form width every cell stacks full width; at or above it rows
/// follow their 12-column spans, as drawn on the layout canvas.
const double _stackBelowWidth = 600;

/// A row with a cell narrower than this stacks too (only span-1 cells get
/// there): a switch or a read-only value can't fit.
const double _minCellWidth = 80;
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
                    collapsed ? MorkvaIcons.chevronRight : MorkvaIcons.expandMore,
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
                      ' · ${context.l10n.commonFieldCount(count)}',
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

/// One layout row: cells side by side by their 12-column spans (unused
/// columns stay empty), or stacked when the form is narrower than
/// [_stackBelowWidth] or a cell narrower than [_minCellWidth].
class _Row extends StatelessWidget {
  const _Row({required this.row, required this.cellBuilder});

  final LayoutRow row;
  final Widget Function(String fieldId) cellBuilder;

  @override
  Widget build(BuildContext context) {
    final cells = row.cells;
    if (cells.length == 1 && cells.single.span == kLayoutColumns) {
      return cellBuilder(cells.single.fieldId);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final usable = constraints.maxWidth - _cellGap * (cells.length - 1);
        final stack =
            constraints.maxWidth < _stackBelowWidth ||
            cells.any((c) => usable * c.span / kLayoutColumns < _minCellWidth);
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
    final upload = state.uploadErrors[field.id];
    final message =
        error ??
        switch (upload) {
          null => null,
          (:final file, tooLarge: true) => context.l10n.objectsUploadTooLarge(
            file,
          ),
          (:final file, tooLarge: false) => context.l10n.objectsUploadFailed(
            file,
          ),
        };
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
                  label: context.l10n.objectsChanged,
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
                note: state.notes[field.id],
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
              Icon(MorkvaIcons.error, size: 14, color: scheme.error),
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
  final l10n = context.l10n;
  try {
    final url = await cubit.downloadUrl(attachment);
    if (await launchUrl(url, mode: LaunchMode.externalApplication)) return;
  } catch (_) {
    // Reported below.
  }
  messenger?.showSnackBar(
    SnackBar(content: Text(l10n.objectsCouldNotOpen(attachment.name))),
  );
}
