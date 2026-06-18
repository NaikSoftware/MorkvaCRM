import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/domain/domain.dart';
import '../../../design/design.dart';
import '../field_editors/field_editor.dart';
import 'layout_canvas.dart';
import 'collection_editor_cubit.dart';
import 'collection_editor_state.dart';
import 'field_config_panel.dart';
import 'section_config_panel.dart';

/// Host for `/collections/:id` — the full schema editor.
///
/// Renders the [CollectionEditorCubit] over its three states (loading, a
/// friendly not-found, and the ready editor). The ready editor frames an
/// in-content page header (editable collection name + description, a Save
/// affordance that lights up only when dirty, and a back action) over a
/// responsive 2-panel workspace:
///
/// - **wide (>= [_twoPaneBreakpoint])**: two docked panels — a [LayoutCanvas]
///   direct-manipulation builder on the left and a Properties inspector on the
///   right. The inspector dispatches based on selection: [FieldConfigPanel] for
///   a selected field, [SectionConfigPanel] for a selected group, or a calm
///   placeholder when nothing is selected.
/// - **narrow**: a single scrolling column showing the [LayoutCanvas]; the
///   inspector opens as a modal bottom sheet when a field or group is selected.
///
/// The reference picker inside per-type config editors needs the workspace's
/// collections; the [CollectionEditorCubit] loads them once into
/// [CollectionEditorReady.availableCollections], and this page threads that
/// snapshot down to [FieldConfigPanel]. Save failures surface as a
/// non-destructive snackbar (the draft is retained and stays dirty for retry).
class CollectionEditorPage extends StatelessWidget {
  const CollectionEditorPage({super.key, required this.registry});

  final FieldEditorRegistry registry;

  /// Width at/above which the Properties inspector docks beside the canvas.
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

  Future<void> _pickIcon() async {
    final cubit = context.read<CollectionEditorCubit>();
    final selection = await CollectionIconPicker.show(
      context,
      current: widget.state.draft.icon,
    );
    if (selection == null) return;
    cubit.setIcon(selection.key);
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
        actionsPadding: const EdgeInsets.fromLTRB(
          Spacing.lg,
          0,
          Spacing.lg,
          Spacing.md,
        ),
        // A single Wrap, not a bare actions list: AlertDialog's OverflowBar
        // mis-stacks our (now content-sized) buttons; Wrap keeps the pair on
        // one baseline and only stacks if the dialog is too narrow to fit them.
        actions: [
          Wrap(
            alignment: WrapAlignment.end,
            spacing: Spacing.xxs,
            runSpacing: Spacing.xs,
            children: [
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
          CollectionGlyph(
            iconKey: state.draft.icon,
            onTap: _pickIcon,
            tooltip: 'Choose icon',
          ),
          const SizedBox(width: Spacing.sm),
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
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    cursorColor: scheme.primary,
                    textInputAction: TextInputAction.done,
                    onChanged: (value) => cubit.renameCollection(
                      value,
                      description: state.draft.description,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      // Opt out of the global filled/rounded input theme so the
                      // title reads as a heading, not an input chip — our own
                      // hover/focus underline is the only affordance.
                      filled: false,
                      fillColor: Colors.transparent,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      hintText: 'Collection name',
                      hintStyle: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: Spacing.xxs),
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
/// hover, and to carrot on focus. The text itself is the affordance — no
/// trailing pencil — so the title reads as a heading, not a control, and the
/// underline + caret carry the "editable" signal once you reach for it.
///
/// The underline hugs the title's content width (via [IntrinsicWidth], capped by
/// [_maxWidth]) rather than stretching the full header. A long name fills up to
/// the cap and then scrolls within the field.
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

  /// Upper bound for the content-hugging title, so the underline never sprawls
  /// across a wide header.
  static const double _maxWidth = 480;

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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: AnimatedContainer(
              duration: MotionDurations.fast,
              curve: MotionCurves.standard,
              padding: const EdgeInsets.only(bottom: 3),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: borderColor,
                    width: focused ? 2 : 1,
                  ),
                ),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _maxWidth),
                child: IntrinsicWidth(child: field),
              ),
            ),
          ),
        ],
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

/// The docked 2-pane layout for wide screens.
///
/// Left pane (weight 3): the [LayoutCanvas] in a vertically scrollable
/// container — the canvas handles its own horizontal layout. Right pane
/// (weight 2): the [_ConfigRegion] inspector.
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
    return _ResizablePanes(
      initialWeights: const [3, 2],
      minPaneWidth: 320,
      panes: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(Spacing.lg),
          child: LayoutCanvas(collection: state.draft, registry: registry),
        ),
        _ConfigRegion(
          state: state,
          registry: registry,
          collections: collections,
        ),
      ],
    );
  }
}

/// A horizontal row of [panes] separated by draggable splitters, letting the
/// user size the designer regions (fields / settings / preview) themselves.
///
/// Widths are held as fractions of the available width (persisted for the life
/// of the editor session) and clamped so no pane shrinks below [minPaneWidth].
/// Initial split comes from [initialWeights] (any positive scale).
class _ResizablePanes extends StatefulWidget {
  const _ResizablePanes({
    required this.panes,
    required this.initialWeights,
    this.minPaneWidth = 260,
  }) : assert(panes.length == initialWeights.length),
       assert(panes.length >= 2);

  final List<Widget> panes;
  final List<double> initialWeights;
  final double minPaneWidth;

  @override
  State<_ResizablePanes> createState() => _ResizablePanesState();
}

class _ResizablePanesState extends State<_ResizablePanes> {
  static const double _dividerHit = 10;

  late List<double> _fractions;

  @override
  void initState() {
    super.initState();
    final total = widget.initialWeights.fold<double>(0, (a, b) => a + b);
    _fractions = widget.initialWeights.map((w) => w / total).toList();
  }

  void _drag(int dividerIndex, double dx, double available) {
    if (available <= 0) return;
    final minF = (widget.minPaneWidth / available).clamp(0.0, 0.49);
    final df = dx / available;
    setState(() {
      var left = _fractions[dividerIndex] + df;
      var right = _fractions[dividerIndex + 1] - df;
      if (left < minF) {
        right -= minF - left;
        left = minF;
      }
      if (right < minF) {
        left -= minF - right;
        right = minF;
      }
      if (left >= minF && right >= minF) {
        _fractions[dividerIndex] = left;
        _fractions[dividerIndex + 1] = right;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final n = widget.panes.length;
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth - _dividerHit * (n - 1);
        final children = <Widget>[];
        for (var i = 0; i < n; i++) {
          children.add(
            SizedBox(
              width: (_fractions[i] * available).clamp(0.0, available),
              child: widget.panes[i],
            ),
          );
          if (i < n - 1) {
            children.add(
              _PaneDivider(
                width: _dividerHit,
                color: scheme.outlineVariant,
                hoverColor: scheme.outline,
                onDrag: (dx) => _drag(i, dx, available),
              ),
            );
          }
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        );
      },
    );
  }
}

/// The draggable splitter between two [_ResizablePanes] regions: a hairline that
/// thickens on hover, with a resize cursor and a generous invisible hit area.
class _PaneDivider extends StatefulWidget {
  const _PaneDivider({
    required this.width,
    required this.color,
    required this.hoverColor,
    required this.onDrag,
  });

  final double width;
  final Color color;
  final Color hoverColor;
  final ValueChanged<double> onDrag;

  @override
  State<_PaneDivider> createState() => _PaneDividerState();
}

class _PaneDividerState extends State<_PaneDivider> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: (d) => widget.onDrag(d.delta.dx),
        child: SizedBox(
          width: widget.width,
          child: Center(
            child: Container(
              width: _hover ? 2 : 1,
              color: _hover ? widget.hoverColor : widget.color,
            ),
          ),
        ),
      ),
    );
  }
}

/// On narrow screens: a single scrolling column showing only the [LayoutCanvas].
///
/// The inspector (field or group config) opens as a modal bottom sheet driven
/// by selection changes. Tapping a field or a group header on the canvas
/// selects it; the sheet auto-opens and renders the matching inspector.
/// On dismiss the selection is cleared so re-tapping the same element reopens
/// the sheet.
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
  /// The id of the element for which the sheet is currently open (field or
  /// section id). Used to avoid stacking a second sheet for the same element.
  String? _sheetElementId;

  /// Whether a config sheet is currently on screen. Guards against stacking a
  /// second sheet when the selection changes while one is already open — the
  /// open sheet rebuilds from cubit state and tracks the live selection.
  bool _sheetOpen = false;

  @override
  void didUpdateWidget(_NarrowLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Check for a newly selected field or section.
    final fieldId = widget.state.selectedFieldId;
    final sectionId = widget.state.selectedSectionId;

    if (!_sheetOpen) {
      if (fieldId != null &&
          fieldId != _sheetElementId &&
          widget.state.draft.fieldById(fieldId) != null) {
        _sheetElementId = fieldId;
        WidgetsBinding.instance.addPostFrameCallback((_) => _openSheet());
      } else if (sectionId != null &&
          sectionId != _sheetElementId &&
          widget.state.draft.layout.sections.any((s) => s.id == sectionId)) {
        _sheetElementId = sectionId;
        WidgetsBinding.instance.addPostFrameCallback((_) => _openSheet());
      }
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
            if (field != null) {
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
            }
            final section = state.selectedSection;
            if (section != null) {
              return FractionallySizedBox(
                heightFactor: 0.85,
                child: _ConfigSheet(
                  state: state,
                  child: SectionConfigPanel(
                    section: section,
                    canDelete: state.draft.layout.sections.length > 1,
                  ),
                ),
              );
            }
            return const SizedBox.shrink();
          },
        );
      },
    );
    // Sheet dismissed → clear selection so re-tapping the same element works.
    _sheetOpen = false;
    _sheetElementId = null;
    if (mounted) cubit.selectField(null);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.lg),
      child: LayoutCanvas(
        collection: widget.state.draft,
        registry: widget.registry,
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

/// The docked inspector region for wide layouts.
///
/// Dispatches based on the cubit's selection:
/// - A selected field → [FieldConfigPanel].
/// - A selected section → [SectionConfigPanel].
/// - Nothing selected → a calm "select a field or group" placeholder.
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
    final field = state.selectedField;
    if (field != null) {
      return FieldConfigPanel(
        field: field,
        editor: registry.forType(field.type),
        collections: collections,
        editingCollectionId: state.draft.id,
        typeLocked: state.isFieldTypeLocked(field.id),
      );
    }

    final section = state.selectedSection;
    if (section != null) {
      return SectionConfigPanel(
        section: section,
        canDelete: state.draft.layout.sections.length > 1,
      );
    }

    // Nothing selected — empty-state placeholder.
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
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
              'Select a field or group to edit it.',
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
      actionsPadding: const EdgeInsets.fromLTRB(
        Spacing.lg,
        0,
        Spacing.lg,
        Spacing.md,
      ),
      // A single Wrap keeps the three actions on one baseline; AlertDialog's
      // OverflowBar mis-stacks our buttons into a diagonal. Wrap also lets the
      // trio drop to stacked rows when a narrow phone can't fit them side by
      // side (the buttons are content-sized, so they don't balloon in a Wrap).
      actions: [
        Wrap(
          alignment: WrapAlignment.end,
          spacing: Spacing.xxs,
          runSpacing: Spacing.xs,
          children: [
            TextActionButton(
              label: 'Cancel',
              onPressed: () => Navigator.of(context).pop(_LeaveAction.cancel),
            ),
            PressableScale(
              onPressed: () => Navigator.of(context).pop(_LeaveAction.discard),
              semanticLabel: 'Discard',
              borderRadius: Radii.mdAll,
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Discard',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: scheme.error,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            PrimaryButton(
              label: 'Save',
              onPressed: () => Navigator.of(context).pop(_LeaveAction.save),
            ),
          ],
        ),
      ],
    ),
  );
  return action ?? _LeaveAction.cancel;
}
