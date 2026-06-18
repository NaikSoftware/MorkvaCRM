import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/domain/domain.dart';
import '../../../design/design.dart';
import '../field_editors/field_editor.dart';
import '../field_editors/widgets/preview_affordances.dart';
import 'add_field_sheet.dart';
import 'collection_editor_cubit.dart';
import 'collection_editor_state.dart';

// ---------------------------------------------------------------------------
// Payload types for typed drag-and-drop (no cross-accept)
// ---------------------------------------------------------------------------

/// Sealed hierarchy of drag payloads so field, row, and section drags cannot
/// be accidentally accepted by mismatched DragTargets.
sealed class _DragPayload {
  const _DragPayload();
}

/// Payload when dragging a field cell.
final class _FieldPayload extends _DragPayload {
  const _FieldPayload(this.fieldId);
  final String fieldId;
}

/// Payload when dragging an entire row via its gutter grip.
final class _RowPayload extends _DragPayload {
  const _RowPayload(this.rowId);
  final String rowId;
}

/// Payload when dragging a section header.
final class _SectionPayload extends _DragPayload {
  const _SectionPayload(this.sectionId);
  final String sectionId;
}

// ---------------------------------------------------------------------------
// LayoutCanvas (was CardPreview)
// ---------------------------------------------------------------------------

/// The direct-manipulation visual builder canvas for a card's layout.
///
/// Renders sections → rows → cells with:
/// - Selection (tap cell → selectField, tap header → selectSection, tap
///   background → clear selection). Selected element gets a 2 px primary outline.
/// - Immediate-gesture Draggable cells (field, row-gutter, section-header).
/// - AnimatedContainer drop zones that expand while a drag is active.
/// - A persistent right-edge resize handle on non-last cells in multi-cell rows.
/// - Per-group "+ Add field" and global "+ Add group" buttons.
///
/// The canvas always uses the 12-column grid; no narrow stacking.
/// A [SingleChildScrollView] with minWidth 380 keeps it usable when the pane is
/// dragged narrow.
class LayoutCanvas extends StatefulWidget {
  const LayoutCanvas({
    super.key,
    required this.collection,
    required this.registry,
  });

  final Collection collection;
  final FieldEditorRegistry registry;

  @override
  State<LayoutCanvas> createState() => _LayoutCanvasState();
}

class _LayoutCanvasState extends State<LayoutCanvas> {
  /// True while any drag is in flight. Notifies drop-zone widgets to expand.
  final ValueNotifier<bool> _dragActive = ValueNotifier(false);

  @override
  void dispose() {
    _dragActive.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final collection = widget.collection;
    final registry = widget.registry;

    final sectionCount = collection.layout.sections.length;
    final selectedFieldId = context
        .select<CollectionEditorCubit, String?>((c) {
          final s = c.state;
          return s is CollectionEditorReady ? s.selectedFieldId : null;
        });
    final selectedSectionId = context
        .select<CollectionEditorCubit, String?>((c) {
          final s = c.state;
          return s is CollectionEditorReady ? s.selectedSectionId : null;
        });

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        context.read<CollectionEditorCubit>().selectField(null);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: Radii.lgAll,
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        padding: const EdgeInsets.all(Spacing.md),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final contentWidth = constraints.maxWidth.isFinite
                ? constraints.maxWidth.clamp(380.0, double.infinity)
                : 380.0;
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: contentWidth,
                child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Collection title
                Text(
                  collection.name.trim().isEmpty
                      ? 'Untitled collection'
                      : collection.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: Spacing.md),
                // Sections
                for (var i = 0; i < collection.layout.sections.length; i++)
                  _SectionView(
                    section: collection.layout.sections[i],
                    sectionIndex: i,
                    registry: registry,
                    collection: collection,
                    isFirst: i == 0,
                    showDelete: sectionCount > 1,
                    selectedFieldId: selectedFieldId,
                    selectedSectionId: selectedSectionId,
                    dragActive: _dragActive,
                    onDragStarted: () => _dragActive.value = true,
                    onDragEnded: () => _dragActive.value = false,
                  ),
                // Trailing between-section drop target for reordering
                if (collection.layout.sections.length > 1)
                  _BetweenSectionDropTarget(
                    sectionIndex: collection.layout.sections.length,
                    dragActive: _dragActive,
                  ),
                // Add group button
                const SizedBox(height: Spacing.xs),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const Key('add_section'),
                    onPressed: () => context
                        .read<CollectionEditorCubit>()
                        .addSection(title: 'New group'),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add group'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  ),
);
  }
}

// ---------------------------------------------------------------------------
// Section
// ---------------------------------------------------------------------------

class _SectionView extends StatelessWidget {
  const _SectionView({
    required this.section,
    required this.sectionIndex,
    required this.registry,
    required this.collection,
    required this.isFirst,
    required this.showDelete,
    required this.selectedFieldId,
    required this.selectedSectionId,
    required this.dragActive,
    required this.onDragStarted,
    required this.onDragEnded,
  });

  final LayoutSection section;
  final int sectionIndex;
  final FieldEditorRegistry registry;
  final Collection collection;
  final bool isFirst;
  final bool showDelete;
  final String? selectedFieldId;
  final String? selectedSectionId;
  final ValueNotifier<bool> dragActive;
  final VoidCallback onDragStarted;
  final VoidCallback onDragEnded;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isGroup = section.title?.trim().isNotEmpty ?? false;
    final collapsed = isGroup && section.collapsed;
    final isSelected = selectedSectionId == section.id;

    Widget sectionContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hairline divider above named groups (not the first)
        if (!isFirst && isGroup) ...[
          Divider(height: 1, thickness: 1, color: scheme.outlineVariant),
          const SizedBox(height: Spacing.md),
        ],
        // Group header (named sections only) — draggable for reordering
        if (isGroup)
          _SectionHeader(
            section: section,
            sectionIndex: sectionIndex,
            showDelete: showDelete,
            isSelected: isSelected,
            onDragStarted: onDragStarted,
            onDragEnded: onDragEnded,
          ),
        // Rows (hidden when collapsed)
        if (!collapsed) ...[
          if (isGroup) const SizedBox(height: Spacing.md),
          _SectionBody(
            section: section,
            registry: registry,
            collection: collection,
            selectedFieldId: selectedFieldId,
            dragActive: dragActive,
            onDragStarted: onDragStarted,
            onDragEnded: onDragEnded,
          ),
        ] else
          const SizedBox(height: Spacing.md),
      ],
    );

    // Wrap in a between-section drop target above this section (for reorder)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (collection.layout.sections.length > 1)
          _BetweenSectionDropTarget(
            sectionIndex: sectionIndex,
            dragActive: dragActive,
          ),
        sectionContent,
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Section header (draggable for reorder)
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.section,
    required this.sectionIndex,
    required this.showDelete,
    required this.isSelected,
    required this.onDragStarted,
    required this.onDragEnded,
  });

  final LayoutSection section;
  final int sectionIndex;
  final bool showDelete;
  final bool isSelected;
  final VoidCallback onDragStarted;
  final VoidCallback onDragEnded;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final headerRow = GestureDetector(
      onTap: () {
        context.read<CollectionEditorCubit>().selectSection(section.id);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          borderRadius: Radii.smAll,
          border: isSelected
              ? Border.all(color: scheme.primary, width: 2)
              : Border.all(color: Colors.transparent, width: 2),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Drag grip for reordering sections
            MouseRegion(
              cursor: SystemMouseCursors.grab,
              child: Icon(
                Icons.drag_indicator,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
            ),
            // Collapse chevron
            IconButton(
              key: Key('collapse_${section.id}'),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              icon: Icon(
                section.collapsed ? Icons.chevron_right : Icons.expand_more,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
              onPressed: () => context
                  .read<CollectionEditorCubit>()
                  .toggleSectionCollapsed(section.id),
            ),
            const SizedBox(width: Spacing.xxs),
            // Editable title
            Expanded(
              child: _SectionTitle(
                key: ValueKey(section.id),
                section: section,
              ),
            ),
            if (showDelete) const SizedBox(width: Spacing.xxs),
            if (showDelete)
              IconButton(
                key: Key('delete_${section.id}'),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                icon: Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
                onPressed: () => context
                    .read<CollectionEditorCubit>()
                    .deleteSection(section.id),
              ),
          ],
        ),
      ),
    );

    // Make the header a Draggable for section reordering
    return Draggable<_DragPayload>(
      data: _SectionPayload(section.id),
      dragAnchorStrategy: pointerDragAnchorStrategy,
      onDragStarted: onDragStarted,
      onDragEnd: (_) => onDragEnded(),
      onDraggableCanceled: (velocity, offset) => onDragEnded(),
      feedback: Material(
        elevation: 4,
        borderRadius: Radii.smAll,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220),
          child: Opacity(
            opacity: 0.85,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.md,
                vertical: Spacing.sm,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: Radii.smAll,
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Text(
                section.title ?? 'Section',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.4, child: headerRow),
      child: headerRow,
    );
  }
}

// ---------------------------------------------------------------------------
// Between-section drop target
// ---------------------------------------------------------------------------

class _BetweenSectionDropTarget extends StatelessWidget {
  const _BetweenSectionDropTarget({
    required this.sectionIndex,
    required this.dragActive,
  });

  final int sectionIndex;
  final ValueNotifier<bool> dragActive;

  @override
  Widget build(BuildContext context) {
    return DragTarget<_DragPayload>(
      onWillAcceptWithDetails: (details) =>
          details.data is _SectionPayload,
      onAcceptWithDetails: (details) {
        final payload = details.data;
        if (payload is! _SectionPayload) return;
        // Find old index of this section
        final cubit = context.read<CollectionEditorCubit>();
        final state = cubit.state;
        if (state is! CollectionEditorReady) return;
        final sections = state.draft.layout.sections;
        final oldIndex =
            sections.indexWhere((s) => s.id == payload.sectionId);
        if (oldIndex < 0) return;
        cubit.reorderSections(oldIndex, sectionIndex);
      },
      builder: (context, candidateData, rejectedData) {
        final hasSection =
            candidateData.any((d) => d is _SectionPayload);
        return ValueListenableBuilder<bool>(
          valueListenable: dragActive,
          builder: (context, active, _) {
            final scheme = Theme.of(context).colorScheme;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: active ? 24 : 4,
              margin: const EdgeInsets.symmetric(vertical: 2),
              decoration: BoxDecoration(
                color: hasSection
                    ? scheme.primary.withValues(alpha: 0.25)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: hasSection
                      ? scheme.primary.withValues(alpha: 0.6)
                      : Colors.transparent,
                  width: 1.5,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Section body (rows + coarse drop)
// ---------------------------------------------------------------------------

class _SectionBody extends StatelessWidget {
  const _SectionBody({
    required this.section,
    required this.registry,
    required this.collection,
    required this.selectedFieldId,
    required this.dragActive,
    required this.onDragStarted,
    required this.onDragEnded,
  });

  final LayoutSection section;
  final FieldEditorRegistry registry;
  final Collection collection;
  final String? selectedFieldId;
  final ValueNotifier<bool> dragActive;
  final VoidCallback onDragStarted;
  final VoidCallback onDragEnded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // Coarse section body DragTarget — accepts field and row drops, highlights
    // the whole body. Fine inner targets (between-row, row slot) win first
    // because Flutter hit-tests innermost first.
    return DragTarget<_DragPayload>(
      onWillAcceptWithDetails: (details) =>
          details.data is _FieldPayload || details.data is _RowPayload,
      onAcceptWithDetails: (details) {
        final payload = details.data;
        final cubit = context.read<CollectionEditorCubit>();
        if (payload is _FieldPayload) {
          cubit.moveCellToNewRow(
            payload.fieldId,
            section.id,
            section.rows.length,
          );
        } else if (payload is _RowPayload) {
          cubit.moveRowToSection(
            payload.rowId,
            section.id,
            section.rows.length,
          );
        }
      },
      builder: (context, candidateData, rejectedData) {
        final active = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          constraints: const BoxConstraints(minHeight: 16),
          decoration: BoxDecoration(
            color: active
                ? scheme.primary.withValues(alpha: 0.06)
                : Colors.transparent,
            borderRadius: Radii.smAll,
            border: Border.all(
              color: active
                  ? scheme.primary.withValues(alpha: 0.5)
                  : Colors.transparent,
              width: 1.5,
            ),
          ),
          padding: const EdgeInsets.all(2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (section.rows.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: Spacing.sm,
                    horizontal: Spacing.xs,
                  ),
                  child: Text(
                    'Drop a field here',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              for (
                var rowIndex = 0;
                rowIndex < section.rows.length;
                rowIndex++
              ) ...[
                _BetweenRowDropTarget(
                  key: Key('newrowdrop_${section.id}_$rowIndex'),
                  sectionId: section.id,
                  rowIndex: rowIndex,
                  dragActive: dragActive,
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: Spacing.md),
                  child: _RowView(
                    row: section.rows[rowIndex],
                    registry: registry,
                    collection: collection,
                    selectedFieldId: selectedFieldId,
                    dragActive: dragActive,
                    onDragStarted: onDragStarted,
                    onDragEnded: onDragEnded,
                  ),
                ),
              ],
              if (section.rows.isNotEmpty)
                _BetweenRowDropTarget(
                  key: Key('newrowdrop_${section.id}_${section.rows.length}'),
                  sectionId: section.id,
                  rowIndex: section.rows.length,
                  dragActive: dragActive,
                ),
              // Per-group add field button
              const SizedBox(height: Spacing.xs),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: Key('add_field_${section.id}'),
                  onPressed: () async {
                    final cubit = context.read<CollectionEditorCubit>();
                    final state = cubit.state;
                    if (state is! CollectionEditorReady) return;
                    // Capture existing field IDs before adding
                    final existingIds =
                        state.draft.fields.map((f) => f.id).toSet();
                    final typeId = await AddFieldSheet.show(
                      context,
                      editors: registry.all,
                    );
                    if (typeId == null) return;
                    cubit.addField(typeId);
                    // Identify the new field id from the updated state
                    final newState = cubit.state;
                    if (newState is! CollectionEditorReady) return;
                    final newFieldId = newState.selectedFieldId;
                    if (newFieldId == null) return;
                    if (existingIds.contains(newFieldId)) return;
                    // Move the new field into this section
                    cubit.moveCellToNewRow(
                      newFieldId,
                      section.id,
                      section.rows.length,
                    );
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add field'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Inline section title (editable)
// ---------------------------------------------------------------------------

class _SectionTitle extends StatefulWidget {
  const _SectionTitle({super.key, required this.section});

  final LayoutSection section;

  @override
  State<_SectionTitle> createState() => _SectionTitleState();
}

class _SectionTitleState extends State<_SectionTitle> {
  bool _editing = false;
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.section.title ?? '');
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(_SectionTitle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_editing && oldWidget.section.title != widget.section.title) {
      _controller.text = widget.section.title ?? '';
    }
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus && _editing) {
      _commit();
    }
  }

  void _commit() {
    final value =
        _controller.text.trim().isEmpty ? null : _controller.text.trim();
    context.read<CollectionEditorCubit>().renameSection(widget.section.id, value);
    setState(() => _editing = false);
  }

  void _startEditing() {
    // Select the section when the title is tapped (title tap doubles as select)
    context.read<CollectionEditorCubit>().selectSection(widget.section.id);
    setState(() {
      _editing = true;
      _controller.text = widget.section.title ?? '';
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (_editing) {
      return TextField(
        controller: _controller,
        focusNode: _focusNode,
        style: theme.textTheme.titleSmall,
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: Spacing.xs,
            vertical: Spacing.xxs,
          ),
          border: OutlineInputBorder(
            borderRadius: Radii.mdAll,
            borderSide: BorderSide(color: scheme.outlineVariant),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: Radii.mdAll,
            borderSide: BorderSide(color: scheme.outlineVariant),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: Radii.mdAll,
            borderSide: BorderSide(color: scheme.primary, width: 2),
          ),
        ),
        onSubmitted: (_) => _commit(),
        textInputAction: TextInputAction.done,
      );
    }

    final isPlaceholder =
        !(widget.section.title?.trim().isNotEmpty ?? false);
    return InkWell(
      onTap: _startEditing,
      mouseCursor: SystemMouseCursors.click,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.xs,
          vertical: Spacing.xxs,
        ),
        child: Text(
          isPlaceholder ? 'Untitled section' : widget.section.title!,
          style: theme.textTheme.titleSmall?.copyWith(
            color: isPlaceholder ? scheme.onSurfaceVariant : scheme.onSurface,
            fontStyle: isPlaceholder ? FontStyle.italic : FontStyle.normal,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Row
// ---------------------------------------------------------------------------

class _RowView extends StatelessWidget {
  const _RowView({
    required this.row,
    required this.registry,
    required this.collection,
    required this.selectedFieldId,
    required this.dragActive,
    required this.onDragStarted,
    required this.onDragEnded,
  });

  final LayoutRow row;
  final FieldEditorRegistry registry;
  final Collection collection;
  final String? selectedFieldId;
  final ValueNotifier<bool> dragActive;
  final VoidCallback onDragStarted;
  final VoidCallback onDragEnded;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columnWidth = constraints.maxWidth / kLayoutColumns;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row gutter grip (hover-revealed, draggable for row-move)
            _RowGutterGrip(
              row: row,
              onDragStarted: onDragStarted,
              onDragEnded: onDragEnded,
            ),
            // Cells
            for (var i = 0; i < row.cells.length; i++) ...[
              if (i > 0) const SizedBox(width: Spacing.sm),
              Expanded(
                flex: row.cells[i].span,
                child: _DraggableCell(
                  fieldId: row.cells[i].fieldId,
                  rowId: row.id,
                  onDragStarted: onDragStarted,
                  onDragEnded: onDragEnded,
                  child: _LayoutCellTile(
                    field: collection.fieldById(row.cells[i].fieldId),
                    registry: registry,
                    rowId: row.id,
                    span: row.cells[i].span,
                    isLastInRow: i == row.cells.length - 1,
                    columnWidth: columnWidth,
                    isSelected: selectedFieldId == row.cells[i].fieldId,
                  ),
                ),
              ),
            ],
            // Trailing drop slot — accepts a cell dragged onto this row
            _RowDropTarget(
              key: Key('rowdrop_${row.id}'),
              rowId: row.id,
              cellCount: row.cells.length,
              dragActive: dragActive,
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Row gutter grip (for row-move)
// ---------------------------------------------------------------------------

class _RowGutterGrip extends StatefulWidget {
  const _RowGutterGrip({
    required this.row,
    required this.onDragStarted,
    required this.onDragEnded,
  });

  final LayoutRow row;
  final VoidCallback onDragStarted;
  final VoidCallback onDragEnded;

  @override
  State<_RowGutterGrip> createState() => _RowGutterGripState();
}

class _RowGutterGripState extends State<_RowGutterGrip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final grip = AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: _hovered ? 1.0 : 0.0,
      child: MouseRegion(
        cursor: SystemMouseCursors.grab,
        child: SizedBox(
          width: 20,
          child: Center(
            child: Icon(
              Icons.drag_indicator,
              size: 14,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Draggable<_DragPayload>(
        data: _RowPayload(widget.row.id),
        dragAnchorStrategy: pointerDragAnchorStrategy,
        onDragStarted: widget.onDragStarted,
        onDragEnd: (_) => widget.onDragEnded(),
        onDraggableCanceled: (velocity, offset) => widget.onDragEnded(),
        feedback: Material(
          elevation: 4,
          borderRadius: Radii.smAll,
          child: Opacity(
            opacity: 0.85,
            child: Container(
              width: 120,
              height: 48,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: Radii.smAll,
                border: Border.all(color: scheme.outlineVariant),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.drag_indicator,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.4, child: grip),
        child: grip,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Cell tile
// ---------------------------------------------------------------------------

class _LayoutCellTile extends StatelessWidget {
  const _LayoutCellTile({
    required this.field,
    required this.registry,
    this.rowId,
    this.span,
    this.isLastInRow,
    this.columnWidth,
    this.isSelected = false,
  });

  final FieldDefinition? field;
  final FieldEditorRegistry registry;
  final String? rowId;
  final int? span;
  final bool? isLastInRow;
  final double? columnWidth;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final f = field;
    if (f == null) return const SizedBox.shrink();

    final editor = registry.forType(f.type);

    // Selection or hover removes outline
    final tile = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        context.read<CollectionEditorCubit>().selectField(f.id);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          borderRadius: Radii.smAll,
          border: isSelected
              ? Border.all(color: scheme.primary, width: 2)
              : Border.all(color: scheme.outlineVariant),
        ),
        padding: const EdgeInsets.all(Spacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Label row
            Row(
              children: [
                Icon(
                  editor?.icon ?? Icons.help_outline,
                  size: 13,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: Spacing.xxs),
                Flexible(
                  child: Text.rich(
                    TextSpan(
                      text: f.name.trim().isEmpty ? 'Untitled field' : f.name,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                      children: f.isRequired
                          ? [
                              TextSpan(
                                text: ' *',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: scheme.error,
                                ),
                              ),
                            ]
                          : null,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Delete affordance (visible on selected cell)
                if (isSelected) ...[
                  const SizedBox(width: Spacing.xxs),
                  InkWell(
                    onTap: () {
                      context
                          .read<CollectionEditorCubit>()
                          .removeField(f.id);
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Icon(
                        Icons.close,
                        size: 14,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: Spacing.xs),
            // Inert affordance
            editor?.buildPreviewAffordance(context, f) ??
                const PreviewStubInput(height: 36),
          ],
        ),
      ),
    );

    // Only render the resize handle in wide mode with row context,
    // and only when this is NOT the last cell in the row.
    final showResize = rowId != null &&
        span != null &&
        columnWidth != null &&
        isLastInRow != null &&
        !(isLastInRow!);

    if (!showResize) return tile;

    final rId = rowId!;
    final currentSpan = span!;
    final colW = columnWidth!;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        tile,
        Positioned(
          top: 0,
          bottom: 0,
          right: -Spacing.xs,
          width: 20,
          child: _ResizeHandle(
            key: Key('resize_${rId}_${f.id}'),
            rowId: rId,
            fieldId: f.id,
            currentSpan: currentSpan,
            columnWidth: colW,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Resize handle — Part C: persistent, with fractional delta accumulation
// ---------------------------------------------------------------------------

class _ResizeHandle extends StatefulWidget {
  const _ResizeHandle({
    super.key,
    required this.rowId,
    required this.fieldId,
    required this.currentSpan,
    required this.columnWidth,
  });

  final String rowId;
  final String fieldId;
  final int currentSpan;
  final double columnWidth;

  @override
  State<_ResizeHandle> createState() => _ResizeHandleState();
}

class _ResizeHandleState extends State<_ResizeHandle> {
  bool _hovered = false;

  /// Accumulated fractional delta; only calls setCellSpan when crossing ±1 col.
  double _residual = 0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: (d) {
          _residual += (d.primaryDelta ?? 0) / widget.columnWidth;
          final deltaCols = _residual.truncate();
          if (deltaCols == 0) return;
          _residual -= deltaCols;
          context.read<CollectionEditorCubit>().setCellSpan(
            widget.rowId,
            widget.fieldId,
            widget.currentSpan + deltaCols,
          );
        },
        onHorizontalDragEnd: (_) {
          _residual = 0;
        },
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 4,
            decoration: BoxDecoration(
              color: _hovered
                  ? scheme.outline
                  : scheme.outlineVariant.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Draggable cell wrapper
// ---------------------------------------------------------------------------

class _DraggableCell extends StatelessWidget {
  const _DraggableCell({
    required this.fieldId,
    required this.rowId,
    required this.onDragStarted,
    required this.onDragEnded,
    required this.child,
  });

  final String fieldId;
  final String rowId;
  final VoidCallback onDragStarted;
  final VoidCallback onDragEnded;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Draggable<_DragPayload>(
      data: _FieldPayload(fieldId),
      dragAnchorStrategy: pointerDragAnchorStrategy,
      onDragStarted: onDragStarted,
      onDragEnd: (_) => onDragEnded(),
      onDraggableCanceled: (velocity, offset) => onDragEnded(),
      feedback: Opacity(
        opacity: 0.85,
        child: Material(
          elevation: 4,
          borderRadius: Radii.smAll,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: child,
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.4, child: child),
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// Row drop target (trailing slot)
// ---------------------------------------------------------------------------

class _RowDropTarget extends StatelessWidget {
  const _RowDropTarget({
    super.key,
    required this.rowId,
    required this.cellCount,
    required this.dragActive,
  });

  final String rowId;
  final int cellCount;
  final ValueNotifier<bool> dragActive;

  @override
  Widget build(BuildContext context) {
    return DragTarget<_DragPayload>(
      onWillAcceptWithDetails: (details) => details.data is _FieldPayload,
      onAcceptWithDetails: (details) {
        final payload = details.data;
        if (payload is! _FieldPayload) return;
        context.read<CollectionEditorCubit>().moveCellToRow(
          payload.fieldId,
          rowId,
          cellCount,
        );
      },
      builder: (context, candidateData, rejectedData) {
        final active = candidateData.isNotEmpty;
        return ValueListenableBuilder<bool>(
          valueListenable: dragActive,
          builder: (context, isDragging, _) {
            final scheme = Theme.of(context).colorScheme;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: isDragging ? 24 : 8,
              decoration: BoxDecoration(
                color: active
                    ? scheme.primary.withValues(alpha: 0.25)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: active
                      ? scheme.primary.withValues(alpha: 0.6)
                      : Colors.transparent,
                  width: 1.5,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Between-row drop target
// ---------------------------------------------------------------------------

class _BetweenRowDropTarget extends StatelessWidget {
  const _BetweenRowDropTarget({
    super.key,
    required this.sectionId,
    required this.rowIndex,
    required this.dragActive,
  });

  final String sectionId;
  final int rowIndex;
  final ValueNotifier<bool> dragActive;

  @override
  Widget build(BuildContext context) {
    return DragTarget<_DragPayload>(
      onWillAcceptWithDetails: (details) =>
          details.data is _FieldPayload || details.data is _RowPayload,
      onAcceptWithDetails: (details) {
        final payload = details.data;
        final cubit = context.read<CollectionEditorCubit>();
        if (payload is _FieldPayload) {
          cubit.moveCellToNewRow(payload.fieldId, sectionId, rowIndex);
        } else if (payload is _RowPayload) {
          cubit.moveRowToSection(payload.rowId, sectionId, rowIndex);
        }
      },
      builder: (context, candidateData, rejectedData) {
        final active = candidateData.isNotEmpty;
        return ValueListenableBuilder<bool>(
          valueListenable: dragActive,
          builder: (context, isDragging, _) {
            final scheme = Theme.of(context).colorScheme;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: isDragging ? 24 : 4,
              margin: const EdgeInsets.symmetric(vertical: 2),
              decoration: BoxDecoration(
                color: active
                    ? scheme.primary.withValues(alpha: 0.25)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: active
                      ? scheme.primary.withValues(alpha: 0.6)
                      : Colors.transparent,
                  width: 1.5,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
