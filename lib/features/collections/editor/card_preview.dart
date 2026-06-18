import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/domain/domain.dart';
import '../../../design/design.dart';
import '../field_editors/field_editor.dart';
import '../field_editors/widgets/preview_affordances.dart';
import 'collection_editor_cubit.dart';

/// Width at/below which cells render full-width (one per line).
const double _narrowBreakpoint = 600;

/// A compact, read-only preview of an empty card rendered from [Collection.layout].
///
/// Sections are shown with a header (title + collapse chevron) and their rows.
/// Each row distributes cells using span-based flex (12-column grid). Below
/// [_narrowBreakpoint] every cell expands to full width (stacked layout).
///
/// Task 10 adds section controls: collapse chevron, inline rename, delete
/// (visible only when there is more than one section), and an "Add section"
/// button. The section body is wrapped in a coarse [DragTarget] so a dragged
/// field dropped anywhere in a section appends as a new full-width row.
class CardPreview extends StatelessWidget {
  const CardPreview({
    super.key,
    required this.collection,
    required this.registry,
  });

  final Collection collection;
  final FieldEditorRegistry registry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isEmpty = collection.layout.fieldIds.isEmpty;
    final sectionCount = collection.layout.sections.length;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: Radii.lgAll,
        border: Border.all(color: scheme.outlineVariant),
      ),
      padding: const EdgeInsets.all(Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header bar ──────────────────────────────────────────────────────
          Row(
            children: [
              Icon(
                Icons.preview_outlined,
                size: 16,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: Spacing.xs),
              Text(
                'Card preview',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.md),
          // ── Collection name ──────────────────────────────────────────────────
          Text(
            collection.name.trim().isEmpty
                ? 'Untitled collection'
                : collection.name,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: Spacing.md),
          // ── Body ─────────────────────────────────────────────────────────────
          if (isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
              child: Text(
                'Add fields to see the card take shape.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth <= _narrowBreakpoint;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < collection.layout.sections.length; i++)
                      _SectionView(
                        section: collection.layout.sections[i],
                        registry: registry,
                        collection: collection,
                        narrow: narrow,
                        isFirst: i == 0,
                        showDelete: sectionCount > 1,
                      ),
                  ],
                );
              },
            ),
          // ── Add section button ────────────────────────────────────────────────
          const SizedBox(height: Spacing.xs),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('add_section'),
              onPressed: () =>
                  context.read<CollectionEditorCubit>().addSection(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add section'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section ────────────────────────────────────────────────────────────────

class _SectionView extends StatelessWidget {
  const _SectionView({
    required this.section,
    required this.registry,
    required this.collection,
    required this.narrow,
    required this.isFirst,
    required this.showDelete,
  });

  final LayoutSection section;
  final FieldEditorRegistry registry;
  final Collection collection;
  final bool narrow;
  final bool isFirst;

  /// Whether to show the delete button — false when only one section exists.
  final bool showDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Hairline divider between sections (not above the first) ──────
        if (!isFirst) ...[
          Divider(height: 1, thickness: 1, color: scheme.outlineVariant),
          const SizedBox(height: Spacing.md),
        ],
        // ── Section header ────────────────────────────────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Collapse chevron
            IconButton(
              key: Key('collapse_${section.id}'),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
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
            Expanded(child: _SectionTitle(section: section)),
            // Delete button — only when multiple sections exist
            if (showDelete)
              IconButton(
                key: Key('delete_${section.id}'),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
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
        // ── Rows (hidden when collapsed) ──────────────────────────────────
        if (!section.collapsed) ...[
          const SizedBox(height: Spacing.md),
          // Coarse section-body DragTarget — dropping a field here appends it
          // as a new full-width row at the end of the section.
          // The finer _BetweenRowDropTarget and _RowDropTarget widgets are
          // rendered *inside* this DragTarget's subtree and receive events first
          // (Flutter hit-tests innermost first), so they take priority over the
          // coarse section target when the pointer is over them.
          DragTarget<String>(
            onWillAcceptWithDetails: (_) => true,
            onAcceptWithDetails: (details) {
              context.read<CollectionEditorCubit>().moveCellToNewRow(
                    details.data,
                    section.id,
                    section.rows.length,
                  );
            },
            builder: (context, candidateData, rejectedData) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (
                    var rowIndex = 0;
                    rowIndex < section.rows.length;
                    rowIndex++
                  ) ...[
                    // Between-row drop target (before each row)
                    if (!narrow)
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
                        narrow: narrow,
                      ),
                    ),
                  ],
                  // Between-row drop target after the last row
                  if (!narrow)
                    _BetweenRowDropTarget(
                      key: Key('newrowdrop_${section.id}_${section.rows.length}'),
                      sectionId: section.id,
                      rowIndex: section.rows.length,
                    ),
                ],
              );
            },
          ),
        ] else
          const SizedBox(height: Spacing.md),
      ],
    );
  }
}

// ─── Inline section title (editable) ─────────────────────────────────────────

/// Displays the section title as tappable text. On tap, switches to an inline
/// [TextField] seeded with the current title. Commits via [renameSection] on
/// submit or focus loss. Shows a muted italic placeholder when not editing and
/// the title is empty.
class _SectionTitle extends StatefulWidget {
  const _SectionTitle({required this.section});

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
    // Sync controller when the section title changes externally (e.g. cubit
    // rebuild after another user action) but only when not actively editing.
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
    final value = _controller.text.trim().isEmpty ? null : _controller.text.trim();
    context.read<CollectionEditorCubit>().renameSection(widget.section.id, value);
    setState(() => _editing = false);
  }

  void _startEditing() {
    setState(() {
      _editing = true;
      _controller.text = widget.section.title ?? '';
    });
    // Request focus after the frame so the TextField is mounted.
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
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(
            horizontal: Spacing.xs,
            vertical: Spacing.xxs,
          ),
          border: OutlineInputBorder(),
        ),
        onSubmitted: (_) => _commit(),
        textInputAction: TextInputAction.done,
      );
    }

    final isPlaceholder = !(widget.section.title?.trim().isNotEmpty ?? false);
    return InkWell(
      onTap: _startEditing,
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

// ─── Row ─────────────────────────────────────────────────────────────────────

class _RowView extends StatelessWidget {
  const _RowView({
    required this.row,
    required this.registry,
    required this.collection,
    required this.narrow,
  });

  final LayoutRow row;
  final FieldEditorRegistry registry;
  final Collection collection;
  final bool narrow;

  @override
  Widget build(BuildContext context) {
    if (narrow) {
      // Narrow: every cell is its own full-width line (no DnD in narrow mode).
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < row.cells.length; i++) ...[
            if (i > 0) const SizedBox(height: Spacing.xs),
            _LayoutCellTile(
              field: collection.fieldById(row.cells[i].fieldId),
              registry: registry,
            ),
          ],
        ],
      );
    }

    // Wide: cells share the row, sized by span (flex). Wrap in LayoutBuilder
    // to compute columnWidth for the resize handle.
    return LayoutBuilder(
      builder: (context, constraints) {
        final columnWidth = constraints.maxWidth / kLayoutColumns;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < row.cells.length; i++) ...[
              if (i > 0) const SizedBox(width: Spacing.sm),
              Expanded(
                flex: row.cells[i].span,
                child: _DraggableCell(
                  fieldId: row.cells[i].fieldId,
                  child: _LayoutCellTile(
                    field: collection.fieldById(row.cells[i].fieldId),
                    registry: registry,
                    rowId: row.id,
                    span: row.cells[i].span,
                    columnWidth: columnWidth,
                  ),
                ),
              ),
            ],
            // Trailing drop slot — accepts a cell dragged onto this row.
            _RowDropTarget(
              key: Key('rowdrop_${row.id}'),
              rowId: row.id,
              cellCount: row.cells.length,
            ),
          ],
        );
      },
    );
  }
}

// ─── Cell tile ───────────────────────────────────────────────────────────────

/// One field's label + inert affordance. Shared by the canvas tasks (8–10).
///
/// When [rowId], [span], and [columnWidth] are all provided (wide mode only),
/// a right-edge drag handle is overlaid so the user can resize the cell's span.
/// The three params are optional/nullable so the narrow branch and plain test
/// callers work without them.
class _LayoutCellTile extends StatelessWidget {
  const _LayoutCellTile({
    required this.field,
    required this.registry,
    this.rowId,
    this.span,
    this.columnWidth,
  });

  final FieldDefinition? field;
  final FieldEditorRegistry registry;

  /// The id of the containing [LayoutRow] — present only in wide mode.
  final String? rowId;

  /// The cell's current column span — present only in wide mode.
  final int? span;

  /// Width of a single grid column (row width / [kLayoutColumns]) — wide mode.
  final double? columnWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final f = field;
    if (f == null) return const SizedBox.shrink();

    final editor = registry.forType(f.type);

    final tile = Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: Radii.smAll,
        border: Border.all(color: scheme.outlineVariant),
      ),
      padding: const EdgeInsets.all(Spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Label row ──────────────────────────────────────────────────────
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
            ],
          ),
          const SizedBox(height: Spacing.xs),
          // ── Inert affordance ───────────────────────────────────────────────
          editor?.buildPreviewAffordance(context, f) ??
              const PreviewStubInput(height: 36),
        ],
      ),
    );

    // Only render the resize handle in wide mode (all three params present).
    if (rowId == null || span == null || columnWidth == null) return tile;

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
          width: Spacing.lg, // 24 px — meets the minimum touch target
          child: GestureDetector(
            key: Key('resize_${rId}_${f.id}'),
            behavior: HitTestBehavior.translucent,
            onHorizontalDragUpdate: (d) {
              final deltaCols = (d.primaryDelta! / colW).round();
              if (deltaCols == 0) return;
              context.read<CollectionEditorCubit>().setCellSpan(
                rId,
                f.id,
                currentSpan + deltaCols,
              );
            },
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeLeftRight,
              child: Center(
                child: Container(
                  width: 3,
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Drag-and-drop widgets ────────────────────────────────────────────────────

/// Wraps a cell tile in a [LongPressDraggable] that carries [fieldId] as its
/// data. The tile body becomes the draggable surface; the resize handle
/// (GestureDetector overlay) uses horizontal-drag and therefore does not
/// conflict with the long-press gesture here.
class _DraggableCell extends StatelessWidget {
  const _DraggableCell({required this.fieldId, required this.child});

  final String fieldId;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LongPressDraggable<String>(
      data: fieldId,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: Opacity(
        opacity: 0.9,
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

/// Trailing [DragTarget] on a row — accepting a dragged field drops it into
/// this row at the trailing position.
class _RowDropTarget extends StatelessWidget {
  const _RowDropTarget({
    super.key,
    required this.rowId,
    required this.cellCount,
  });

  final String rowId;
  final int cellCount;

  @override
  Widget build(BuildContext context) {
    return DragTarget<String>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) {
        context.read<CollectionEditorCubit>().moveCellToRow(
          details.data,
          rowId,
          cellCount,
        );
      },
      builder: (context, candidateData, rejectedData) {
        return _DropSlot(active: candidateData.isNotEmpty, axis: Axis.vertical);
      },
    );
  }
}

/// A horizontal drop target placed between rows (or before/after all rows).
/// Accepts a dragged field and creates a new row at [rowIndex] within
/// [sectionId].
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
    return DragTarget<String>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) {
        context.read<CollectionEditorCubit>().moveCellToNewRow(
          details.data,
          sectionId,
          rowIndex,
        );
      },
      builder: (context, candidateData, rejectedData) {
        return _DropSlot(
          active: candidateData.isNotEmpty,
          axis: Axis.horizontal,
        );
      },
    );
  }
}

/// A thin rounded highlight strip that signals an active drop zone.
///
/// [axis] controls orientation:
/// - [Axis.vertical]   → a narrow vertical strip (trailing row slot, 8 px wide)
/// - [Axis.horizontal] → a narrow horizontal bar (between-rows slot, 8 px tall)
///
/// Uses a fixed minimum dimension so it always occupies its space even when
/// inactive, preventing layout jumps.
class _DropSlot extends StatelessWidget {
  const _DropSlot({required this.active, required this.axis});

  final bool active;
  final Axis axis;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final color = active
        ? scheme.primary.withValues(alpha: 0.25)
        : Colors.transparent;

    final borderColor = active
        ? scheme.primary.withValues(alpha: 0.6)
        : Colors.transparent;

    if (axis == Axis.vertical) {
      // Trailing slot alongside row cells — 8 px wide, fills row height.
      return AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 8,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: borderColor, width: 1.5),
        ),
      );
    }

    // Between-rows horizontal bar — full width, 8 px tall.
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      height: 8,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: borderColor, width: 1.5),
      ),
    );
  }
}
