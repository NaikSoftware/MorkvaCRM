import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/domain/domain.dart';
import '../../../design/design.dart';
import '../collection_views_cubit.dart';
import '../collection_views_state.dart';
import '../widgets/board/board_card_draggable.dart';
import '../widgets/board/board_column.dart';
import '../widgets/view_labels.dart';
import '../widgets/view_toolbar.dart';
import 'view_mode.dart';

/// Cards in columns, one per value of a single-select or single-reference
/// field. Dragging a card to another column writes that field; dragging it
/// within a column saves a manual order.
class BoardMode extends ViewMode {
  const BoardMode();

  @override
  String get id => ViewModeIds.board;

  @override
  String get label => 'Board';

  @override
  IconData get icon => Icons.view_kanban_outlined;

  @override
  String get description => 'Cards in columns by a choice or reference field.';

  @override
  bool get needsLayoutField => true;

  @override
  bool get drawsNoMatches => true;

  @override
  bool acceptsLayoutField(FieldDefinition field) =>
      field is SingleSelectFieldDefinition ||
      (field is ReferenceFieldDefinition && !field.multiple);

  @override
  String? unavailableReason(Collection collection) =>
      groupableFields(collection).isEmpty
      ? 'Needs a choice or reference field'
      : null;

  @override
  Widget buildBody(BuildContext context, ViewModeData data) =>
      BoardView(data: data);

  @override
  Widget? buildSettingsChip(BuildContext context, ViewModeData data) {
    final fields = groupableFields(data.state.collection);
    if (fields.isEmpty) return null;
    return GroupByMenu(
      fields: fields,
      selectedId: data.state.layoutField?.id,
      builder: (open) => ToolbarButton(
        icon: Icons.view_kanban_outlined,
        label: 'Group: ${data.state.layoutField?.name ?? 'None'}',
        onPressed: open,
      ),
    );
  }
}

/// A menu of the fields a board can group by, opened from [builder]'s
/// callback; picking one sets the view's layout field.
class GroupByMenu extends StatelessWidget {
  const GroupByMenu({
    super.key,
    required this.fields,
    required this.selectedId,
    required this.builder,
  });

  final List<FieldDefinition> fields;
  final String? selectedId;
  final Widget Function(VoidCallback open) builder;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CollectionViewsCubit>();
    return MenuAnchor(
      menuChildren: [
        for (final f in fields)
          MenuItemButton(
            leadingIcon: Icon(fieldTypeIcon(f), size: 20),
            trailingIcon: f.id == selectedId
                ? const Icon(Icons.check, size: 20)
                : null,
            onPressed: () => cubit.setLayoutField(f.id),
            child: Text(f.name),
          ),
      ],
      builder: (context, controller, _) => builder(
        () => controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}

/// The Board mode body: columns side by side, scrolling sideways.
class BoardView extends StatefulWidget {
  const BoardView({super.key, required this.data});

  final ViewModeData data;

  @override
  State<BoardView> createState() => _BoardViewState();
}

class _BoardViewState extends State<BoardView> {
  final _horizontal = ScrollController();
  EdgeDraggingAutoScroller? _autoScroller;

  /// A card is lifted. Tracked here, not via the card's Draggable, which
  /// skips its end callbacks once its column scrolls out and is disposed.
  bool _dragging = false;

  @override
  void dispose() {
    _autoScroller?.stopAutoScroll();
    _horizontal.dispose();
    super.dispose();
  }

  /// Where the held pointer is, for re-checking the edge after each step.
  Offset? _pointer;

  void _pointerMove(PointerMoveEvent event) {
    _pointer = event.position;
    _autoScroll();
  }

  void _autoScroll() {
    final pointer = _pointer;
    if (!_dragging || pointer == null || !_horizontal.hasClients) return;
    final board = _horizontal.position.context;
    if (board is! ScrollableState) return;
    if (_autoScroller?.scrollable != board) {
      _autoScroller = EdgeDraggingAutoScroller(
        board,
        velocityScalar: 7,
        // Keep going while the pointer rests near the edge.
        onScrollViewScrolled: _autoScroll,
      );
    }
    _autoScroller!.startAutoScrollIfNecessary(
      Rect.fromLTRB(
        pointer.dx - BoardColumn.autoScrollEdge,
        pointer.dy,
        pointer.dx + BoardColumn.autoScrollEdge,
        pointer.dy,
      ),
    );
  }

  void _pointerEnd(PointerEvent _) {
    _dragging = false;
    _pointer = null;
    _autoScroller?.stopAutoScroll();
  }

  void _drop(ViewGroup to, BoardDrag drag, String? beforeId) {
    final cubit = context.read<CollectionViewsCubit>();
    final id = drag.object.id;
    final sorted = widget.data.state.activeView.sort != null;
    final within = drag.fromKey == to.key;
    final undo = within
        ? cubit.reorder(id, beforeId: beforeId)
        : cubit.moveToGroup(id, to.key, beforeId: beforeId);
    if (undo == null) return;
    final now = cubit.state;
    final hidden = now is ViewsReady && now.objectById(id) == null;
    final message = within
        ? 'Reordered in ${to.label}${sorted ? ' — sort turned off' : ''}'
        : 'Moved to ${to.label}${hidden ? ' — hidden by filter' : ''}';
    widget.data.notify(message, undo: undo);
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final state = data.state;
    final collection = state.collection;
    final groups = state.groups;
    final field = state.layoutField;
    if (groups == null || field == null) return _NoGrouping(data: data);

    final itemsLabel = collection.name.trim().toLowerCase();
    final columns = Listener(
      onPointerMove: _pointerMove,
      onPointerUp: _pointerEnd,
      onPointerCancel: _pointerEnd,
      child: Scrollbar(
        controller: _horizontal,
        // Lazy: a reference board can have hundreds of columns.
        child: ListView.separated(
          controller: _horizontal,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(bottom: Spacing.sm),
          itemCount: groups.length,
          separatorBuilder: (_, _) => const SizedBox(width: Spacing.md),
          itemBuilder: (context, i) {
            final group = groups[i];
            return Align(
              alignment: Alignment.topCenter,
              child: BoardColumn(
                key: ValueKey(('column', group.key)),
                group: group,
                collection: collection,
                view: state.activeView,
                field: field,
                itemLabel: data.itemLabel,
                itemsLabel: itemsLabel.isEmpty ? 'items' : itemsLabel,
                referenceLabels: state.referenceLabels,
                onOpen: data.openObject,
                onAdd: () => data.quickAdd(groupKey: group.key),
                onDrop: (drag, beforeId) => _drop(group, drag, beforeId),
                onEditOptions: field is SingleSelectFieldDefinition
                    ? () => context.go(
                        '/collections/${collection.id}/edit?field=${field.id}',
                      )
                    : null,
                onDragStarted: () => _dragging = true,
              ),
            );
          },
        ),
      ),
    );
    if (!(state.objects.isEmpty && state.isFiltered)) return columns;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _NoMatchesNotice(
          onClear: () =>
              context.read<CollectionViewsCubit>().setFilters(const []),
        ),
        const SizedBox(height: Spacing.xs),
        Expanded(child: columns),
      ],
    );
  }
}

/// The board has no field to group by: point to adding one, or let the user
/// pick among the fields that can.
class _NoGrouping extends StatelessWidget {
  const _NoGrouping({required this.data});

  final ViewModeData data;

  @override
  Widget build(BuildContext context) {
    final collection = data.state.collection;
    final fields = groupableFields(collection);
    if (fields.isEmpty) {
      return EmptyState(
        icon: Icons.view_kanban_outlined,
        title: 'Board needs a choice or reference field',
        message:
            'Add a choice or reference field, and each of its values '
            'becomes a column you can drag ${data.itemLabel}s between.',
        action: PrimaryButton(
          label: 'Add field',
          icon: Icons.add,
          onPressed: () => context.go('/collections/${collection.id}/edit'),
        ),
      );
    }
    return EmptyState(
      icon: Icons.view_kanban_outlined,
      title: 'Choose how to group this board',
      message: 'Each value of the field becomes a column.',
      action: GroupByMenu(
        fields: fields,
        selectedId: null,
        builder: (open) => PrimaryButton(
          label: 'Group by…',
          icon: Icons.view_kanban_outlined,
          onPressed: open,
        ),
      ),
    );
  }
}

/// Filters hide every card: the columns stay as drop targets, with a way
/// out above them.
class _NoMatchesNotice extends StatelessWidget {
  const _NoMatchesNotice({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.only(left: Spacing.sm),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: Radii.mdAll,
      ),
      child: Row(
        children: [
          Icon(
            Icons.filter_alt_off_outlined,
            size: 18,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: Spacing.xs),
          Expanded(
            child: Text(
              'Nothing matches these filters',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          TextActionButton(label: 'Clear filters', onPressed: onClear),
        ],
      ),
    );
  }
}
