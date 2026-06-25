import 'package:flutter/foundation.dart';
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

/// Payload when dragging a whole group (named section).
final class _SectionPayload extends _DragPayload {
  const _SectionPayload(this.sectionId);
  final String sectionId;
}

// ---------------------------------------------------------------------------
// Adaptive draggable: immediate with a pointer, long-press on touch
// ---------------------------------------------------------------------------

/// True on touch-first platforms, where a drag must start with a long-press so
/// that an ordinary drag scrolls the surrounding canvas instead of grabbing an
/// element (mirrors how [ReorderableListView] picks its input model).
bool get _touchToDrag {
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
    case TargetPlatform.iOS:
    case TargetPlatform.fuchsia:
      return true;
    case TargetPlatform.macOS:
    case TargetPlatform.linux:
    case TargetPlatform.windows:
      return false;
  }
}

/// A [Draggable] that begins immediately under a pointer (mouse / trackpad) but
/// requires a long-press on touch devices, so a plain touch drag scrolls the
/// canvas rather than picking the element up. [affinity] constrains only the
/// pointer (immediate) variant — the long-press variant is direction-agnostic.
class _AdaptiveDraggable<T extends Object> extends StatelessWidget {
  const _AdaptiveDraggable({
    required this.data,
    required this.feedback,
    required this.childWhenDragging,
    required this.child,
    this.affinity,
  });

  final T data;
  final Widget feedback;
  final Widget childWhenDragging;
  final Widget child;
  final Axis? affinity;

  @override
  Widget build(BuildContext context) {
    // Paint the dragged element centred on the cursor (cursor at its middle)
    // rather than with its top-left corner at the cursor. Detection stays
    // cursor-based, so the user aims the element's centre at the drop target.
    // FractionalTranslation shifts by half the feedback's own size, so it works
    // for any feedback size (cell, row, group).
    final centeredFeedback = FractionalTranslation(
      translation: const Offset(-0.5, -0.5),
      child: feedback,
    );
    if (_touchToDrag) {
      return LongPressDraggable<T>(
        data: data,
        dragAnchorStrategy: pointerDragAnchorStrategy,
        feedback: centeredFeedback,
        childWhenDragging: childWhenDragging,
        child: child,
      );
    }
    return Draggable<T>(
      data: data,
      affinity: affinity,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: centeredFeedback,
      childWhenDragging: childWhenDragging,
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// LayoutCanvas (was CardPreview)
// ---------------------------------------------------------------------------

/// The direct-manipulation visual builder canvas for a card's layout.
///
/// Renders sections → rows → cells with:
/// - Selection: tap anywhere in a named group → selectSection; tap a cell →
///   selectField; tap the canvas background → clear. The selected element gets
///   a 2 px primary outline.
/// - Whole-element drags: a field cell drags by its body, a row by its gutter
///   grip, and a named group by grabbing it anywhere and moving vertically
///   (`affinity: Axis.vertical`) so it never steals a cell's resize / drag.
///   Drags start immediately under a pointer but require a long-press on touch
///   (see [_AdaptiveDraggable]) so a plain swipe scrolls the canvas.
/// - Drop zones expand and highlight only while the dragged element hovers
///   over them (driven by each target's own `candidateData`), so starting a
///   drag never reflows the whole canvas.
/// - A persistent right-edge resize handle on non-last cells in multi-cell rows.
/// - Per-group "+ Add field" and global "+ Add group" buttons.
///
/// The canvas always uses the 12-column grid; no narrow stacking.
/// A [SingleChildScrollView] with minWidth 380 keeps it usable when the pane is
/// dragged narrow.
class LayoutCanvas extends StatelessWidget {
  const LayoutCanvas({
    super.key,
    required this.collection,
    required this.registry,
  });

  final Collection collection;
  final FieldEditorRegistry registry;

  @override
  Widget build(BuildContext context) {
    final sectionCount = collection.layout.sections.length;
    final selectedFieldId = context.select<CollectionEditorCubit, String?>((c) {
      final s = c.state;
      return s is CollectionEditorReady ? s.selectedFieldId : null;
    });
    final selectedSectionId = context.select<CollectionEditorCubit, String?>((
      c,
    ) {
      final s = c.state;
      return s is CollectionEditorReady ? s.selectedSectionId : null;
    });

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        context.read<CollectionEditorCubit>().selectField(null);
      },
      child: Container(
        // No outer border: the per-group outlined panels are the only frames,
        // so groups read as thin outlined cards floating on the canvas surface.
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: Radii.lgAll,
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
                    for (var i = 0; i < sectionCount; i++)
                      _SectionView(
                        section: collection.layout.sections[i],
                        sectionIndex: i,
                        registry: registry,
                        collection: collection,
                        showDelete: sectionCount > 1,
                        selectedFieldId: selectedFieldId,
                        selectedSectionId: selectedSectionId,
                      ),
                    // Trailing between-section drop target for reordering
                    if (sectionCount > 1)
                      _BetweenSectionDropTarget(sectionIndex: sectionCount),
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
    required this.showDelete,
    required this.selectedFieldId,
    required this.selectedSectionId,
  });

  final LayoutSection section;
  final int sectionIndex;
  final FieldEditorRegistry registry;
  final Collection collection;
  final bool showDelete;
  final String? selectedFieldId;
  final String? selectedSectionId;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasTitle = section.title?.trim().isNotEmpty ?? false;
    final collapsed = hasTitle && section.collapsed;
    final isSelected = selectedSectionId == section.id;
    final multiSection = collection.layout.sections.length > 1;

    final body = collapsed
        ? null
        : _SectionBody(
            section: section,
            registry: registry,
            collection: collection,
            selectedFieldId: selectedFieldId,
          );

    // Ungrouped (headerless) fields: no frame, no whole-group drag/select.
    if (!hasTitle) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (multiSection)
            _BetweenSectionDropTarget(sectionIndex: sectionIndex),
          ?body,
        ],
      );
    }

    // Named group: a thin outlined panel (like a Material outlined input).
    // The whole panel is selectable (tap) and draggable (vertical drag).
    final groupBox = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.only(bottom: Spacing.md),
      decoration: BoxDecoration(
        borderRadius: Radii.mdAll,
        border: Border.all(
          color: isSelected ? scheme.primary : scheme.outlineVariant,
          width: isSelected ? 2 : 1,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        Spacing.sm,
        Spacing.xs,
        Spacing.sm,
        Spacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(section: section, showDelete: showDelete),
          if (body != null) ...[const SizedBox(height: Spacing.xs), body],
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (multiSection) _BetweenSectionDropTarget(sectionIndex: sectionIndex),
        // Vertical affinity (pointer): dragging the panel up/down reorders it,
        // while a horizontal drag on a cell's resize handle and an immediate
        // drag on a cell still win their own gesture arenas. On touch the panel
        // is long-press-to-drag so a plain swipe scrolls the canvas.
        _AdaptiveDraggable<_DragPayload>(
          data: _SectionPayload(section.id),
          affinity: Axis.vertical,
          feedback: _SectionDragFeedback(section: section),
          childWhenDragging: Opacity(opacity: 0.4, child: groupBox),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () =>
                context.read<CollectionEditorCubit>().selectSection(section.id),
            child: groupBox,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Section header (no drag handle — the whole group is the drag surface)
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.section, required this.showDelete});

  final LayoutSection section;
  final bool showDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
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
          child: _SectionTitle(key: ValueKey(section.id), section: section),
        ),
        if (showDelete) ...[
          const SizedBox(width: Spacing.xxs),
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
            onPressed: () =>
                context.read<CollectionEditorCubit>().deleteSection(section.id),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Drag feedback shown while a whole group is being dragged
// ---------------------------------------------------------------------------

class _SectionDragFeedback extends StatelessWidget {
  const _SectionDragFeedback({required this.section});

  final LayoutSection section;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      elevation: 4,
      borderRadius: Radii.smAll,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 240),
        child: Opacity(
          opacity: 0.9,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.md,
              vertical: Spacing.sm,
            ),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: Radii.smAll,
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.drag_indicator,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: Spacing.xs),
                Flexible(
                  child: Text(
                    section.title ?? 'Group',
                    style: theme.textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
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

// ---------------------------------------------------------------------------
// Between-section drop target
// ---------------------------------------------------------------------------

class _BetweenSectionDropTarget extends StatelessWidget {
  const _BetweenSectionDropTarget({required this.sectionIndex});

  final int sectionIndex;

  @override
  Widget build(BuildContext context) {
    return DragTarget<_DragPayload>(
      onWillAcceptWithDetails: (details) => details.data is _SectionPayload,
      onAcceptWithDetails: (details) {
        final payload = details.data;
        if (payload is! _SectionPayload) return;
        final cubit = context.read<CollectionEditorCubit>();
        final state = cubit.state;
        if (state is! CollectionEditorReady) return;
        final sections = state.draft.layout.sections;
        final oldIndex = sections.indexWhere((s) => s.id == payload.sectionId);
        if (oldIndex < 0) return;
        cubit.reorderSections(oldIndex, sectionIndex);
      },
      builder: (context, candidateData, rejectedData) {
        final active = candidateData.isNotEmpty;
        final scheme = Theme.of(context).colorScheme;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: active ? 24 : 6,
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
  });

  final LayoutSection section;
  final FieldEditorRegistry registry;
  final Collection collection;
  final String? selectedFieldId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // Coarse section body DragTarget — only accepts drops when the section is
    // EMPTY (the "Drop a field here" affordance for a fresh group). When the
    // section has rows, precise placement is handled by the fine inner targets
    // (between-row slots, row edge / free-space); an imprecise release that
    // misses them is rejected here so the dragged element returns to its
    // original place instead of being appended to the end of the section.
    return DragTarget<_DragPayload>(
      onWillAcceptWithDetails: (details) =>
          section.rows.isEmpty &&
          (details.data is _FieldPayload || details.data is _RowPayload),
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
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: Spacing.md),
                  child: _RowView(
                    row: section.rows[rowIndex],
                    registry: registry,
                    collection: collection,
                    selectedFieldId: selectedFieldId,
                  ),
                ),
              ],
              if (section.rows.isNotEmpty)
                _BetweenRowDropTarget(
                  key: Key('newrowdrop_${section.id}_${section.rows.length}'),
                  sectionId: section.id,
                  rowIndex: section.rows.length,
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
                    final existingIds = state.draft.fields
                        .map((f) => f.id)
                        .toSet();
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
    final value = _controller.text.trim().isEmpty
        ? null
        : _controller.text.trim();
    context.read<CollectionEditorCubit>().renameSection(
      widget.section.id,
      value,
    );
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

    final isPlaceholder = !(widget.section.title?.trim().isNotEmpty ?? false);
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
  });

  final LayoutRow row;
  final FieldEditorRegistry registry;
  final Collection collection;
  final String? selectedFieldId;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columnWidth = constraints.maxWidth / kLayoutColumns;
        final usedColumns = row.cells.fold<int>(0, (sum, c) => sum + c.span);
        final freeColumns = kLayoutColumns - usedColumns;
        // IntrinsicHeight + stretch so the trailing drop zone (and cells) fill
        // the full row height rather than sitting shorter than the cards.
        return IntrinsicHeight(
          child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Row gutter grip (hover-revealed, draggable for row-move)
            _RowGutterGrip(row: row),
            // Cells
            for (var i = 0; i < row.cells.length; i++) ...[
              if (i > 0) const SizedBox(width: Spacing.sm),
              Expanded(
                flex: row.cells[i].span,
                // The resize handle is a SIBLING of the draggable cell, not a
                // child. Kept outside _DraggableCell so a horizontal drag on the
                // right edge wins its own gesture arena instead of being
                // swallowed by the cell's immediate Draggable. Every cell gets a
                // handle — including a lone full-width field, which can be
                // dragged narrower to free columns for a neighbour.
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _DraggableCell(
                      fieldId: row.cells[i].fieldId,
                      child: _LayoutCellTile(
                        field: collection.fieldById(row.cells[i].fieldId),
                        registry: registry,
                        isSelected: selectedFieldId == row.cells[i].fieldId,
                      ),
                    ),
                    Positioned(
                      top: 0,
                      bottom: 0,
                      right: -Spacing.xs,
                      width: 20,
                      child: _ResizeHandle(
                        key: Key('resize_${row.id}_${row.cells[i].fieldId}'),
                        rowId: row.id,
                        fieldId: row.cells[i].fieldId,
                        currentSpan: row.cells[i].span,
                        columnWidth: columnWidth,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // Trailing slot. When the row has unused columns it expands to fill
            // them, so shrinking a cell reveals a real, droppable gap; when the
            // row is full it stays a thin slot.
            if (freeColumns > 0)
              Expanded(
                flex: freeColumns,
                child: _RowDropTarget(
                  key: Key('rowdrop_${row.id}'),
                  rowId: row.id,
                  cellCount: row.cells.length,
                  fill: true,
                ),
              )
            else
              _RowDropTarget(
                key: Key('rowdrop_${row.id}'),
                rowId: row.id,
                cellCount: row.cells.length,
              ),
          ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Row gutter grip (for row-move)
// ---------------------------------------------------------------------------

class _RowGutterGrip extends StatefulWidget {
  const _RowGutterGrip({required this.row});

  final LayoutRow row;

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
      child: _AdaptiveDraggable<_DragPayload>(
        data: _RowPayload(widget.row.id),
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
    this.isSelected = false,
  });

  final FieldDefinition? field;
  final FieldEditorRegistry registry;
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
            // Label row — name only; the field's type icon lives as a prefix
            // inside the value silhouette below, not here.
            Row(
              children: [
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
                      context.read<CollectionEditorCubit>().removeField(f.id);
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

    return tile;
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
        // Opaque so the right-edge strip is resize-only: it absorbs the press
        // and the cell's immediate Draggable (now a sibling, not an ancestor)
        // never joins the gesture arena, so a horizontal drag here resizes the
        // cell instead of picking it up.
        behavior: HitTestBehavior.opaque,
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
            width: _hovered ? 6 : 4,
            decoration: BoxDecoration(
              // Highlights to the brand colour on hover so the edge reads as a
              // resize affordance (paired with the resizeLeftRight cursor).
              color: _hovered ? scheme.primary : scheme.outlineVariant,
              borderRadius: BorderRadius.circular(3),
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
  const _DraggableCell({required this.fieldId, required this.child});

  final String fieldId;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _AdaptiveDraggable<_DragPayload>(
      data: _FieldPayload(fieldId),
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
    this.fill = false,
  });

  final String rowId;
  final int cellCount;

  /// When true the target fills its parent (the row's free columns) and shows a
  /// dashed "drop a field here" gap; otherwise it is a thin trailing slot.
  final bool fill;

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
        final scheme = Theme.of(context).colorScheme;
        if (fill) {
          // Fills the row's free columns (and full height, via the row's
          // IntrinsicHeight + stretch) so a shrunk cell shows a visible gap.
          return Container(
            margin: const EdgeInsets.only(left: Spacing.sm),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active
                  ? scheme.primary.withValues(alpha: 0.18)
                  : scheme.surfaceContainerLowest.withValues(alpha: 0.4),
              borderRadius: Radii.smAll,
              border: Border.all(
                color: active
                    ? scheme.primary.withValues(alpha: 0.7)
                    : scheme.outlineVariant.withValues(alpha: 0.6),
                width: 1.5,
              ),
            ),
            child: Icon(
              Icons.add,
              size: 18,
              color: active ? scheme.primary : scheme.onSurfaceVariant,
            ),
          );
        }
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: active ? 24 : 8,
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
  });

  final String sectionId;
  final int rowIndex;

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
        final scheme = Theme.of(context).colorScheme;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: active ? 24 : 6,
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
  }
}
