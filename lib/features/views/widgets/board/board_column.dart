import 'package:flutter/material.dart';

import '../../../../core/domain/domain.dart';
import '../../../../design/design.dart';
import '../object_card.dart';
import 'board_card_draggable.dart';

/// One board column: header (colour dot, name, count, "+", ⋯) over its cards.
/// A drop target: while a card hovers it, the column tints and a dashed ghost
/// marks where the card will land. Counts change on drop only.
class BoardColumn extends StatefulWidget {
  const BoardColumn({
    super.key,
    required this.group,
    required this.collection,
    required this.view,
    required this.field,
    required this.itemLabel,
    required this.itemsLabel,
    required this.referenceLabels,
    required this.onOpen,
    required this.onAdd,
    required this.onDrop,
    this.onEditOptions,
    this.onDragUpdate,
    this.onDragEnd,
  });

  static const double width = 272;
  static const double padding = Spacing.sm;
  static const double cardGap = Spacing.xs;
  static const double emptyHeight = 72;

  /// Distance from a list edge where a held card scrolls it.
  static const double autoScrollEdge = 48;

  final ViewGroup group;
  final Collection collection;
  final ViewDefinition view;

  /// The layout field the board groups by.
  final FieldDefinition field;

  /// The noun for one card ("deal"), for the "+" tooltip.
  final String itemLabel;

  /// Plural noun for the empty zone ("deals").
  final String itemsLabel;
  final Map<String, String> referenceLabels;
  final ValueChanged<MorkvaObject> onOpen;
  final VoidCallback onAdd;

  /// A card was dropped here, before [beforeId] (null = at the end).
  final void Function(BoardDrag drag, String? beforeId) onDrop;

  /// Opens the field's options in Build (select fields only).
  final VoidCallback? onEditOptions;
  final ValueChanged<Offset>? onDragUpdate;
  final VoidCallback? onDragEnd;

  @override
  State<BoardColumn> createState() => _BoardColumnState();
}

class _BoardColumnState extends State<BoardColumn> {
  final _keys = <String, GlobalKey>{};
  final _scroll = ScrollController();
  final _listKey = GlobalKey();
  EdgeDraggingAutoScroller? _autoScroller;

  /// Where the ghost sits among the cards other than the dragged one.
  int? _insertAt;

  @override
  void dispose() {
    _autoScroller?.stopAutoScroll();
    _scroll.dispose();
    super.dispose();
  }

  List<MorkvaObject> _others(BoardDrag drag) => [
    for (final o in widget.group.objects)
      if (o.id != drag.object.id) o,
  ];

  void _move(DragTargetDetails<BoardDrag> details) {
    final drag = details.data;
    final centre =
        details.offset + Offset(BoardColumn.width / 2, drag.height / 2);
    final others = _others(drag);
    var index = others.length;
    for (var i = 0; i < others.length; i++) {
      final box =
          _keys[others[i].id]?.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) continue;
      final mid = box.localToGlobal(Offset(0, box.size.height / 2)).dy;
      if (centre.dy < mid) {
        index = i;
        break;
      }
    }
    if (index != _insertAt) setState(() => _insertAt = index);
    _autoScroll(centre);
  }

  void _autoScroll(Offset point) {
    final listContext = _listKey.currentContext;
    final box = listContext?.findRenderObject() as RenderBox?;
    // The scroller asserts its probe fits the viewport; tiny lists don't scroll.
    if (box == null ||
        !_scroll.hasClients ||
        _scroll.position.maxScrollExtent <= 0 ||
        box.size.height <= 2 * BoardColumn.autoScrollEdge) {
      return;
    }
    _autoScroller ??= EdgeDraggingAutoScroller(
      Scrollable.of(listContext!),
      velocityScalar: 7,
    );
    _autoScroller!.startAutoScrollIfNecessary(
      Rect.fromLTRB(
        point.dx,
        point.dy - BoardColumn.autoScrollEdge,
        point.dx,
        point.dy + BoardColumn.autoScrollEdge,
      ),
    );
  }

  void _clear() {
    _autoScroller?.stopAutoScroll();
    if (_insertAt != null) setState(() => _insertAt = null);
  }

  void _accept(DragTargetDetails<BoardDrag> details) {
    final drag = details.data;
    final others = _others(drag);
    final index = (_insertAt ?? others.length).clamp(0, others.length);
    _clear();
    final from = widget.group.objects.indexWhere((o) => o.id == drag.object.id);
    // Dropped back where it was: nothing to do (a sorted view would
    // otherwise switch to manual order).
    if (from >= 0 && from == index) return;
    widget.onDrop(drag, index < others.length ? others[index].id : null);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ids = {for (final o in widget.group.objects) o.id};
    _keys.removeWhere((id, _) => !ids.contains(id));

    return DragTarget<BoardDrag>(
      onMove: _move,
      onLeave: (_) => _clear(),
      onAcceptWithDetails: _accept,
      builder: (context, candidates, _) {
        final drag = candidates.whereType<BoardDrag>().firstOrNull;
        final hovered = drag != null;
        return Container(
          width: BoardColumn.width,
          padding: const EdgeInsets.fromLTRB(
            BoardColumn.padding,
            BoardColumn.padding,
            BoardColumn.padding,
            BoardColumn.padding - BoardColumn.cardGap,
          ),
          decoration: BoxDecoration(
            color: hovered
                ? scheme.surfaceContainerHigh
                : scheme.surfaceContainerLow,
            borderRadius: Radii.lgAll,
          ),
          foregroundDecoration: hovered
              ? BoxDecoration(
                  borderRadius: Radii.lgAll,
                  border: Border.all(color: scheme.primary, width: 2),
                )
              : null,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(
                group: widget.group,
                itemLabel: widget.itemLabel,
                onAdd: widget.onAdd,
                onEditOptions: widget.onEditOptions,
              ),
              const SizedBox(height: Spacing.xs),
              Flexible(child: _cards(context, drag)),
            ],
          ),
        );
      },
    );
  }

  Widget _cards(BuildContext context, BoardDrag? drag) {
    final scheme = Theme.of(context).colorScheme;
    final objects = widget.group.objects;
    final ghost = drag == null
        ? null
        : Padding(
            key: const ValueKey('ghost'),
            padding: const EdgeInsets.only(bottom: BoardColumn.cardGap),
            child: DashedRRect(
              color: scheme.primary,
              strokeWidth: 2,
              fill: scheme.primary.withValues(alpha: 0.06),
              height: drag.height,
            ),
          );
    final onlyDragged =
        objects.isEmpty ||
        (objects.length == 1 && objects.first.id == drag?.object.id);
    if (objects.isEmpty && ghost == null) return _EmptyZone(widget: widget);

    final slots = <Widget>[];
    var others = 0;
    for (final o in objects) {
      final dragged = o.id == drag?.object.id;
      if (!dragged && others == _insertAt && ghost != null) slots.add(ghost);
      if (!dragged) others++;
      slots.add(_slot(o));
    }
    if (ghost != null && (_insertAt == null || _insertAt! >= others)) {
      slots.add(ghost);
    }
    if (onlyDragged && ghost == null) slots.add(_EmptyZone(widget: widget));

    return ListView(
      key: _listKey,
      controller: _scroll,
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      children: slots,
    );
  }

  Widget _slot(MorkvaObject object) {
    final key = _keys.putIfAbsent(object.id, GlobalKey.new);
    return Padding(
      key: key,
      padding: const EdgeInsets.only(bottom: BoardColumn.cardGap),
      child: BoardCardDraggable(
        drag: BoardDrag(object: object, fromKey: widget.group.key),
        width: BoardColumn.width - 2 * BoardColumn.padding,
        onDragUpdate: widget.onDragUpdate,
        onDragEnd: widget.onDragEnd,
        child: ObjectCard(
          object: object,
          collection: widget.collection,
          view: widget.view,
          referenceLabels: widget.referenceLabels,
          onTap: () => widget.onOpen(object),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.group,
    required this.itemLabel,
    required this.onAdd,
    required this.onEditOptions,
  });

  final ViewGroup group;
  final String itemLabel;
  final VoidCallback onAdd;
  final VoidCallback? onEditOptions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = switch (group.color) {
      final hex? => colorFromHex(hex),
      null => null,
    };
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          const SizedBox(width: Spacing.xxs),
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color ?? scheme.outline,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: Spacing.xs),
          Flexible(
            child: Text(
              group.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall,
            ),
          ),
          const SizedBox(width: Spacing.xs),
          Text(
            '${group.objects.length}',
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'New $itemLabel in ${group.label}',
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 20),
            color: scheme.onSurfaceVariant,
          ),
          if (onEditOptions case final edit?)
            PopupMenuButton<void>(
              tooltip: 'Column options',
              icon: Icon(
                Icons.more_horiz,
                size: 20,
                color: scheme.onSurfaceVariant,
              ),
              itemBuilder: (_) => [
                PopupMenuItem(
                  onTap: edit,
                  child: const Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 20),
                      SizedBox(width: Spacing.sm),
                      Flexible(child: Text('Edit options')),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// The dashed zone of a column without cards; never a tall blank.
class _EmptyZone extends StatelessWidget {
  const _EmptyZone({required this.widget});

  final BoardColumn widget;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = widget.group.key == null
        ? 'Drop here to clear ${widget.field.name}'
        : 'No ${widget.itemsLabel}';
    return Padding(
      padding: const EdgeInsets.only(bottom: BoardColumn.cardGap),
      child: DashedRRect(
        color: scheme.outlineVariant,
        height: BoardColumn.emptyHeight,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
