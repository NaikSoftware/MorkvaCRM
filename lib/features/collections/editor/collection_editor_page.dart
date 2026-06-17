import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/domain/domain.dart';
import '../../../design/design.dart';
import '../field_editors/field_editor.dart';
import 'card_preview.dart';
import 'collection_editor_cubit.dart';
import 'collection_editor_state.dart';
import 'field_config_panel.dart';
import 'field_list.dart';

/// Host for `/collections/:id` — the full schema editor.
///
/// Renders the [CollectionEditorCubit] over its three states (loading, a
/// friendly not-found, and the ready editor). The ready editor frames an
/// in-content page header (editable collection name + description, a Save
/// affordance that lights up only when dirty, and a back action) over a
/// responsive workspace:
///
/// - **wide (>= [_threePaneBreakpoint])**: three regions — field list, config
///   panel, and a card preview rail.
/// - **medium**: two regions — field list and config panel.
/// - **narrow**: a single scrolling column (list + collapsible preview); the
///   config panel opens as a modal bottom sheet when a field is selected.
///
/// The reference picker inside per-type config editors needs the workspace's
/// collections; the [CollectionEditorCubit] loads them once into
/// [CollectionEditorReady.availableCollections], and this page threads that
/// snapshot down to [FieldConfigPanel] and the field rows. Save failures surface
/// as a non-destructive snackbar (the draft is retained and stays dirty for
/// retry).
class CollectionEditorPage extends StatelessWidget {
  const CollectionEditorPage({super.key, required this.registry});

  final FieldEditorRegistry registry;

  /// Width at/above which the card-preview rail joins the layout.
  static const double _threePaneBreakpoint = 1100;

  /// Width at/above which the config panel docks beside the list.
  static const double _twoPaneBreakpoint = 760;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CollectionEditorCubit, CollectionEditorState>(
      listenWhen: (prev, next) =>
          next is CollectionEditorReady && next.error != null,
      listener: (context, state) {
        if (state is CollectionEditorReady && state.error != null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(state.error!),
                behavior: SnackBarBehavior.floating,
              ),
            );
        }
      },
      builder: (context, state) {
        return switch (state) {
          CollectionEditorLoading() => const _EditorScaffold(
            child: LoadingIndicator(),
          ),
          CollectionEditorNotFound() => const _NotFoundView(),
          CollectionEditorReady() => _ReadyEditor(
            state: state,
            registry: registry,
          ),
        };
      },
    );
  }
}

/// A bare scaffold the loading/not-found states sit on, matching the shell
/// surface color so the transition into the editor is seamless.
class _EditorScaffold extends StatelessWidget {
  const _EditorScaffold({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(child: child),
    );
  }
}

/// The friendly missing-collection state (deleted / bad deep link).
class _NotFoundView extends StatelessWidget {
  const _NotFoundView();

  @override
  Widget build(BuildContext context) {
    return _EditorScaffold(
      child: EmptyState(
        icon: Icons.search_off_outlined,
        title: 'Collection not found',
        message:
            "This collection may have been deleted, or the link is wrong. "
            "Head back home to pick another.",
        action: PrimaryButton(
          label: 'Back to collections',
          icon: Icons.arrow_back,
          onPressed: () => context.go('/'),
        ),
      ),
    );
  }
}

class _ReadyEditor extends StatelessWidget {
  const _ReadyEditor({required this.state, required this.registry});

  final CollectionEditorReady state;
  final FieldEditorRegistry registry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final collections = state.availableCollections;

    return PopScope(
      canPop: !state.dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final action = await _confirmLeave(context);
        if (action == _LeaveAction.cancel || !context.mounted) return;
        final cubit = context.read<CollectionEditorCubit>();
        final router = GoRouter.of(context);
        if (action == _LeaveAction.save) {
          final ok = await cubit.save();
          if (!ok) return; // validation/save failed → stay, snackbar shown.
        }
        router.go('/');
      },
      child: Scaffold(
        backgroundColor: scheme.surface,
        body: SafeArea(
          child: Column(
            children: [
              _EditorHeader(state: state),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    if (width >= CollectionEditorPage._threePaneBreakpoint) {
                      return _ThreePaneLayout(
                        state: state,
                        registry: registry,
                        collections: collections,
                      );
                    }
                    if (width >= CollectionEditorPage._twoPaneBreakpoint) {
                      return _TwoPaneLayout(
                        state: state,
                        registry: registry,
                        collections: collections,
                      );
                    }
                    return _NarrowLayout(
                      state: state,
                      registry: registry,
                      collections: collections,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

/// The in-content header: a back action, the editable collection name (and
/// optional description), and a Save affordance that promotes to a filled
/// carrot button only when the draft is dirty.
class _EditorHeader extends StatefulWidget {
  const _EditorHeader({required this.state});

  final CollectionEditorReady state;

  @override
  State<_EditorHeader> createState() => _EditorHeaderState();
}

class _EditorHeaderState extends State<_EditorHeader> {
  late final TextEditingController _nameController = TextEditingController(
    text: widget.state.draft.name,
  );
  final FocusNode _nameFocus = FocusNode();
  bool _nameHovered = false;

  @override
  void initState() {
    super.initState();
    // Repaint the editable affordance (underline + pencil) as focus changes.
    _nameFocus.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(_EditorHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-sync the controller when the draft name changed elsewhere (a discard,
    // an external rename) — but only while the user is NOT editing the field,
    // so we never stomp the caret mid-type. The caret is placed at the end.
    final draftName = widget.state.draft.name;
    if (draftName != _nameController.text && !_nameFocus.hasFocus) {
      _nameController.value = TextEditingValue(
        text: draftName,
        selection: TextSelection.collapsed(offset: draftName.length),
      );
    }
  }

  @override
  void dispose() {
    _nameFocus.removeListener(_onFocusChanged);
    _nameController.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  Future<void> _back() async {
    // Defer to PopScope's leave guard via Navigator/router.
    final router = GoRouter.of(context);
    if (!widget.state.dirty) {
      router.go('/');
      return;
    }
    final action = await _confirmLeave(context);
    if (action == _LeaveAction.cancel || !mounted) return;
    if (action == _LeaveAction.save) {
      final ok = await context.read<CollectionEditorCubit>().save();
      if (!ok) return;
    }
    router.go('/');
  }

  void _editDescription() async {
    final cubit = context.read<CollectionEditorCubit>();
    final controller = TextEditingController(
      text: widget.state.draft.description ?? '',
    );
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: Radii.lgAll),
        title: const Text('Collection description'),
        content: MorkvaTextField(
          controller: controller,
          hint: 'What this collection holds',
          autofocus: true,
        ),
        actions: [
          TextActionButton(
            label: 'Cancel',
            onPressed: () => Navigator.of(context).pop(),
          ),
          PrimaryButton(
            label: 'Save',
            onPressed: () => Navigator.of(context).pop(controller.text),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null) return;
    cubit.renameCollection(_nameController.text, description: result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final state = widget.state;
    final cubit = context.read<CollectionEditorCubit>();
    final description = state.draft.description;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.md,
        vertical: Spacing.sm,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: [
          IconActionButton(
            icon: Icons.arrow_back,
            tooltip: 'Back to collections',
            onPressed: _back,
          ),
          const SizedBox(width: Spacing.xs),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _NameEditAffordance(
                  focused: _nameFocus.hasFocus,
                  hovered: _nameHovered,
                  onHover: (value) => setState(() => _nameHovered = value),
                  field: TextField(
                    controller: _nameController,
                    focusNode: _nameFocus,
                    style: theme.textTheme.titleLarge,
                    cursorColor: scheme.primary,
                    textInputAction: TextInputAction.done,
                    onChanged: (value) => cubit.renameCollection(
                      value,
                      description: state.draft.description,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                      hintText: 'Collection name',
                      hintStyle: theme.textTheme.titleLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                _DescriptionLine(
                  description: description,
                  onEdit: _editDescription,
                ),
              ],
            ),
          ),
          const SizedBox(width: Spacing.md),
          _SaveControl(state: state),
        ],
      ),
    );
  }
}

/// Wraps the collection-name [field] with a quiet but clear editable
/// affordance: a bottom border that is invisible at rest, warms to [outline] on
/// hover, and to carrot on focus, plus a trailing pencil glyph at rest (dropped
/// once focused, where the underline + caret already signal editing). This keeps
/// the borderless title feel while making it obvious the name is editable — and
/// reads as a sibling of the description line below it.
class _NameEditAffordance extends StatelessWidget {
  const _NameEditAffordance({
    required this.field,
    required this.focused,
    required this.hovered,
    required this.onHover,
  });

  final Widget field;
  final bool focused;
  final bool hovered;
  final ValueChanged<bool> onHover;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final borderColor = focused
        ? scheme.primary
        : hovered
        ? scheme.outline
        : Colors.transparent;

    return MouseRegion(
      onEnter: (_) => onHover(true),
      onExit: (_) => onHover(false),
      child: AnimatedContainer(
        duration: MotionDurations.fast,
        curve: MotionCurves.standard,
        padding: const EdgeInsets.only(bottom: 3),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: borderColor, width: focused ? 2 : 1),
          ),
        ),
        child: Row(
          children: [
            Expanded(child: field),
            if (!focused) ...[
              const SizedBox(width: Spacing.xs),
              Icon(
                Icons.edit_outlined,
                size: 16,
                color: hovered ? scheme.onSurface : scheme.onSurfaceVariant,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The description affordance under the name: shows the text (or a quiet "Add
/// description" prompt) and opens an editor on tap.
class _DescriptionLine extends StatelessWidget {
  const _DescriptionLine({required this.description, required this.onEdit});

  final String? description;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasDescription =
        description != null && description!.trim().isNotEmpty;
    return InkWell(
      onTap: onEdit,
      borderRadius: Radii.smAll,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                hasDescription ? description! : 'Add a description',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontStyle: hasDescription ? null : FontStyle.italic,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: Spacing.xxs),
            Icon(Icons.edit_outlined, size: 12, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

/// The dirty-aware save control. When the draft is clean it reads as a quiet
/// "Saved" marker; once dirty it becomes the prominent carrot Save button.
class _SaveControl extends StatelessWidget {
  const _SaveControl({required this.state});

  final CollectionEditorReady state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (!state.dirty && !state.saving) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline, size: 18, color: scheme.secondary),
          const SizedBox(width: Spacing.xxs),
          Text(
            'Saved',
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    }

    return PrimaryButton(
      label: 'Save',
      icon: Icons.save_outlined,
      loading: state.saving,
      onPressed: () => context.read<CollectionEditorCubit>().save(),
    );
  }
}

// ---------------------------------------------------------------------------
// Layouts
// ---------------------------------------------------------------------------

class _ThreePaneLayout extends StatelessWidget {
  const _ThreePaneLayout({
    required this.state,
    required this.registry,
    required this.collections,
  });

  final CollectionEditorReady state;
  final FieldEditorRegistry registry;
  final List<Collection> collections;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 4,
          child: Padding(
            padding: const EdgeInsets.all(Spacing.lg),
            child: FieldList(state: state, registry: registry),
          ),
        ),
        VerticalDivider(width: 1, color: scheme.outlineVariant),
        Expanded(
          flex: 4,
          child: _ConfigRegion(
            state: state,
            registry: registry,
            collections: collections,
          ),
        ),
        VerticalDivider(width: 1, color: scheme.outlineVariant),
        Expanded(
          flex: 3,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Spacing.lg),
            child: CardPreview(collection: state.draft, registry: registry),
          ),
        ),
      ],
    );
  }
}

class _TwoPaneLayout extends StatelessWidget {
  const _TwoPaneLayout({
    required this.state,
    required this.registry,
    required this.collections,
  });

  final CollectionEditorReady state;
  final FieldEditorRegistry registry;
  final List<Collection> collections;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 1,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Spacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FieldList(state: state, registry: registry, scrollable: false),
                const SizedBox(height: Spacing.lg),
                CardPreview(collection: state.draft, registry: registry),
              ],
            ),
          ),
        ),
        VerticalDivider(width: 1, color: scheme.outlineVariant),
        Expanded(
          flex: 1,
          child: _ConfigRegion(
            state: state,
            registry: registry,
            collections: collections,
          ),
        ),
      ],
    );
  }
}

/// On narrow screens: a single scrolling column. The config panel for the
/// selected field is presented as a modal bottom sheet (driven by selection
/// changes) instead of a docked pane.
class _NarrowLayout extends StatefulWidget {
  const _NarrowLayout({
    required this.state,
    required this.registry,
    required this.collections,
  });

  final CollectionEditorReady state;
  final FieldEditorRegistry registry;
  final List<Collection> collections;

  @override
  State<_NarrowLayout> createState() => _NarrowLayoutState();
}

class _NarrowLayoutState extends State<_NarrowLayout> {
  String? _sheetFieldId;

  /// Whether a config sheet is currently on screen. Guards against stacking a
  /// second sheet when the selection changes while one is already open — the
  /// open sheet already rebuilds from cubit state, so it tracks the new field.
  bool _sheetOpen = false;

  @override
  void didUpdateWidget(_NarrowLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    final selected = widget.state.selectedFieldId;
    // A newly selected field opens the sheet (post-frame, so we're out of
    // build); deselection or a removed field closes it. Never schedule a second
    // open while one is already showing — the live sheet follows the selection.
    if (!_sheetOpen &&
        selected != null &&
        selected != _sheetFieldId &&
        widget.state.draft.fieldById(selected) != null) {
      _sheetFieldId = selected;
      WidgetsBinding.instance.addPostFrameCallback((_) => _openSheet());
    }
  }

  Future<void> _openSheet() async {
    if (!mounted || _sheetOpen) return;
    _sheetOpen = true;
    final cubit = context.read<CollectionEditorCubit>();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.lg)),
      ),
      builder: (sheetContext) {
        // Rebuild the sheet body from the live cubit state so edits reflect.
        return BlocBuilder<CollectionEditorCubit, CollectionEditorState>(
          bloc: cubit,
          builder: (context, state) {
            if (state is! CollectionEditorReady) {
              return const SizedBox.shrink();
            }
            final field = state.selectedField;
            if (field == null) return const SizedBox.shrink();
            return FractionallySizedBox(
              heightFactor: 0.85,
              child: _ConfigSheet(
                state: state,
                child: FieldConfigPanel(
                  field: field,
                  editor: widget.registry.forType(field.type),
                  collections: widget.collections,
                  editingCollectionId: state.draft.id,
                  typeLocked: state.isFieldTypeLocked(field.id),
                ),
              ),
            );
          },
        );
      },
    );
    // Sheet dismissed → clear selection so reopening the same field works.
    _sheetOpen = false;
    _sheetFieldId = null;
    if (mounted) cubit.selectField(null);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FieldList(
            state: widget.state,
            registry: widget.registry,
            scrollable: false,
          ),
          const SizedBox(height: Spacing.lg),
          CardPreview(
            collection: widget.state.draft,
            registry: widget.registry,
          ),
        ],
      ),
    );
  }
}

/// Frames the narrow-layout config bottom sheet: a compact header ("Configure
/// field" + a close action) and a pinned footer with a dirty/saved indicator and
/// a prominent "Done" button — so a mobile user always has an obvious exit. The
/// [child] is the scrolling [FieldConfigPanel]; both the close and Done actions
/// simply dismiss the sheet (the draft is already live in the cubit).
class _ConfigSheet extends StatelessWidget {
  const _ConfigSheet({required this.state, required this.child});

  final CollectionEditorReady state;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Spacing.lg,
            0,
            Spacing.xs,
            Spacing.xs,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Configure field',
                  style: theme.textTheme.titleMedium,
                ),
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
        Expanded(child: child),
        Divider(height: 1, color: scheme.outlineVariant),
        Padding(
          padding: EdgeInsets.fromLTRB(
            Spacing.lg,
            Spacing.sm,
            Spacing.lg,
            Spacing.sm + MediaQuery.of(context).padding.bottom,
          ),
          child: Row(
            children: [
              Expanded(child: _SheetSaveStatus(state: state)),
              PrimaryButton(
                label: 'Done',
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The dirty/saved indicator inside the config sheet footer, mirroring the
/// header's [_SaveControl] language ("Saving…", a carrot "Unsaved changes", or a
/// calm "Saved") so the mobile user knows the draft's state without the header.
class _SheetSaveStatus extends StatelessWidget {
  const _SheetSaveStatus({required this.state});

  final CollectionEditorReady state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final (IconData icon, String label, Color color) = state.saving
        ? (Icons.sync, 'Saving…', scheme.onSurfaceVariant)
        : state.dirty
        ? (Icons.edit_outlined, 'Unsaved changes', scheme.primary)
        : (Icons.check_circle_outline, 'Saved', scheme.secondary);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: Spacing.xxs),
        Flexible(
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(color: color),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// The docked config region used by the wide/medium layouts: the selected
/// field's [FieldConfigPanel], or a calm "select a field" placeholder.
class _ConfigRegion extends StatelessWidget {
  const _ConfigRegion({
    required this.state,
    required this.registry,
    required this.collections,
  });

  final CollectionEditorReady state;
  final FieldEditorRegistry registry;
  final List<Collection> collections;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final field = state.selectedField;

    if (field == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.tune,
                size: 32,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
              const SizedBox(height: Spacing.sm),
              Text(
                'Select a field to configure it',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return FieldConfigPanel(
      field: field,
      editor: registry.forType(field.type),
      collections: collections,
      editingCollectionId: state.draft.id,
      typeLocked: state.isFieldTypeLocked(field.id),
    );
  }
}

// ---------------------------------------------------------------------------
// Leave guard
// ---------------------------------------------------------------------------

enum _LeaveAction { save, discard, cancel }

/// Prompts the unsaved-changes guard. Returns the chosen action (defaults to
/// cancel on dismiss).
///
/// This is a three-way choice (save / discard / cancel), so it does not use the
/// binary [MorkvaConfirmDialog]; it is assembled from the same design primitives
/// — a quiet [TextActionButton] cancel, an error-tinted discard, and the carrot
/// [PrimaryButton] save — so it still matches the confirm-dialog family.
Future<_LeaveAction> _confirmLeave(BuildContext context) async {
  final theme = Theme.of(context);
  final scheme = theme.colorScheme;
  final action = await showDialog<_LeaveAction>(
    context: context,
    builder: (context) => AlertDialog(
      shape: const RoundedRectangleBorder(borderRadius: Radii.lgAll),
      title: const Text('Save your changes?'),
      content: const Text(
        'You have unsaved changes to this collection. Save them before '
        'leaving, or discard them.',
      ),
      actions: [
        TextActionButton(
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(_LeaveAction.cancel),
        ),
        const SizedBox(width: Spacing.xxs),
        PressableScale(
          onPressed: () => Navigator.of(context).pop(_LeaveAction.discard),
          semanticLabel: 'Discard',
          borderRadius: Radii.mdAll,
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
            alignment: Alignment.center,
            child: Text(
              'Discard',
              style: theme.textTheme.labelLarge?.copyWith(color: scheme.error),
            ),
          ),
        ),
        const SizedBox(width: Spacing.xxs),
        PrimaryButton(
          label: 'Save',
          onPressed: () => Navigator.of(context).pop(_LeaveAction.save),
        ),
      ],
    ),
  );
  return action ?? _LeaveAction.cancel;
}
