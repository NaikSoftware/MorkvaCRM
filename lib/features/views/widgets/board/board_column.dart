import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/domain/domain.dart';
import '../../../../design/design.dart';
import '../object_card.dart';
import 'board_card_draggable.dart';

/// One board column: header (colour dot, name, count, "+", collapse) over its
/// cards. A drop target: while a card hovers it, the column tints and a dashed
/// ghost marks where the card will land. Counts change on drop only.
/// [collapsed], it is a narrow strip (name written vertically) that still
/// takes drops, at the end of the group.
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
    this.collapsed = false,
    this.onToggleCollapsed,
    this.onDragStarted,
    this.onJump,
    this.width = BoardColumn.defaultWidth,
    this.fill = false,
    this.footer,
  });

  static const double defaultWidth = 272;
  static const double collapsedWidth = 48;
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

  /// Drawn as the narrow strip; tapping it calls [onToggleCollapsed].
  final bool collapsed;

  /// Collapses / expands the column; null (phone) hides the control.
  final VoidCallback? onToggleCollapsed;

  /// A card of this column was lifted.
  final ValueChanged<BoardDrag>? onDragStarted;

  /// When set (phone), the column name is a button opening a jump list.
  final VoidCallback? onJump;

  final double width;

  /// Whether the whole area given (a phone page) takes drops, not just the
  /// column, which stays top-aligned in it.
  final bool fill;

  /// Shown right under the column (phone: the page dots).
  final Widget? footer;

  @override
  State<BoardColumn> createState() => _BoardColumnState();
}

class _BoardColumnState extends State<BoardColumn> {
  final _keys = <String, GlobalKey>{};

  /// One drag payload per card, kept as long as the card (see [BoardDrag]).
  final _drags = <String, BoardDrag>{};
  final _scroll = ScrollController();
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
    final centre = details.offset + Offset(widget.width / 2, drag.height / 2);
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
    _drag = drag;
    _autoScroll(centre);
  }

  /// The card held over this column, while it is.
  BoardDrag? _drag;

  /// After each auto-scroll step the cards moved under a still pointer:
  /// re-hit-test so the ghost (and the drop) follow.
  void _scrolled() {
    final drag = _drag;
    if (_point == null || drag == null) return;
    // Pause a frame: a scrolling list ignores hit tests.
    _autoScroller?.stopAutoScroll();
    drag.retarget(then: () => _autoScroll());
  }

  /// The held card's centre, for re-checking the edge after each step.
  Offset? _point;

  void _autoScroll([Offset? at]) {
    final point = at ?? _point;
    _point = point;
    if (point == null || !_scroll.hasClients) return;
    final position = _scroll.position;
    // The list's own Scrollable (Scrollable.of from above it would find the
    // board's). The scroller asserts its probe fits the viewport.
    final list = position.context;
    if (list is! ScrollableState ||
        position.maxScrollExtent <= 0 ||
        position.viewportDimension <= 2 * BoardColumn.autoScrollEdge) {
      return;
    }
    if (_autoScroller?.scrollable != list) {
      _autoScroller = EdgeDraggingAutoScroller(
        list,
        velocityScalar: 7,
        onScrollViewScrolled: _scrolled,
      );
    }
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
    _point = null;
    _drag = null;
    _autoScroller?.stopAutoScroll();
    if (_insertAt != null) setState(() => _insertAt = null);
  }

  void _accept(DragTargetDetails<BoardDrag> details) {
    final drag = details.data;
    if (widget.collapsed) {
      _clear();
      widget.onDrop(drag, null);
      return;
    }
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
    _drags.removeWhere((id, _) => !ids.contains(id));

    return DragTarget<BoardDrag>(
      // A strip has no cards to place the ghost among.
      onMove: (details) => widget.collapsed ? null : _move(details),
      onLeave: (_) => _clear(),
      onAcceptWithDetails: _accept,
      builder: (context, candidates, _) {
        final drag = candidates.whereType<BoardDrag>().firstOrNull;
        final hovered = drag != null;
        if (widget.collapsed) {
          return _AnimatedWidth(
            width: BoardColumn.collapsedWidth,
            child: _CollapsedStrip(
              group: widget.group,
              itemLabel: widget.itemLabel,
              itemsLabel: widget.itemsLabel,
              hovered: hovered,
              onExpand: widget.onToggleCollapsed,
            ),
          );
        }
        final column = Container(
          width: widget.width,
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
          // Always set, so hovering doesn't change the tree (and reset the
          // list's scroll position).
          foregroundDecoration: BoxDecoration(
            borderRadius: Radii.lgAll,
            border: Border.all(
              color: hovered ? scheme.primary : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(
                group: widget.group,
                itemLabel: widget.itemLabel,
                onAdd: widget.onAdd,
                onCollapse: widget.onToggleCollapsed,
                onJump: widget.onJump,
              ),
              const SizedBox(height: Spacing.xs),
              Flexible(child: _cards(context, drag)),
            ],
          ),
        );
        final footer = widget.footer;
        final framed = footer == null
            ? column
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(child: column),
                  const SizedBox(height: Spacing.xs),
                  SizedBox(width: widget.width, child: footer),
                ],
              );
        return widget.fill
            ? Align(alignment: Alignment.topLeft, child: framed)
            : _AnimatedWidth(width: widget.width, child: framed);
      },
    );
  }

  Widget _cards(BuildContext context, BoardDrag? drag) {
    final scheme = Theme.of(context).colorScheme;
    final objects = widget.group.objects;
    final onlyDragged =
        objects.isEmpty ||
        (objects.length == 1 && objects.first.id == drag?.object.id);
    final ghost = drag == null
        ? null
        : Padding(
            key: const ValueKey('ghost'),
            padding: const EdgeInsets.only(bottom: BoardColumn.cardGap),
            child: DashedRRect(
              color: scheme.primary,
              strokeWidth: 2,
              fill: scheme.primary.withValues(alpha: 0.06),
              // Alone in the column, the ghost keeps the empty zone's
              // height, so the column doesn't shrink out from under the
              // pointer and flicker.
              height: onlyDragged
                  ? math.max(drag.height, BoardColumn.emptyHeight)
                  : drag.height,
            ),
          );
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
        drag: _drags.putIfAbsent(
          object.id,
          () => BoardDrag(object: object, fromKey: widget.group.key),
        )..object = object,
        width: widget.width - 2 * BoardColumn.padding,
        onDragStarted: widget.onDragStarted,
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

/// Header buttons: exactly 44 px, visual and hit area alike.
final _square44 = IconButton.styleFrom(
  fixedSize: const Size.square(44),
  minimumSize: const Size.square(44),
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  padding: EdgeInsets.zero,
);

class _Header extends StatelessWidget {
  const _Header({
    required this.group,
    required this.itemLabel,
    required this.onAdd,
    required this.onCollapse,
    required this.onJump,
  });

  final ViewGroup group;
  final String itemLabel;
  final VoidCallback onAdd;
  final VoidCallback? onCollapse;
  final VoidCallback? onJump;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = switch (group.color) {
      final hex? => colorFromHex(hex),
      null => null,
    };
    final name = Row(
      mainAxisSize: MainAxisSize.min,
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
        // Phone: "Lead 5 ▾" — the caret ends the button it belongs to.
        if (onJump != null)
          Icon(Icons.arrow_drop_down, size: 20, color: scheme.onSurfaceVariant),
        const SizedBox(width: Spacing.xs),
      ],
    );
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          // Name and count share one flex, so "+" and ⋯ sit flush right.
          Expanded(
            child: switch (onJump) {
              final jump? => Align(
                alignment: Alignment.centerLeft,
                child: Semantics(
                  button: true,
                  label:
                      '${group.label}, ${group.objects.length}. '
                      'Jump to column',
                  excludeSemantics: true,
                  child: Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      key: const ValueKey('column-jump'),
                      onTap: jump,
                      borderRadius: Radii.smAll,
                      child: SizedBox(height: 44, child: name),
                    ),
                  ),
                ),
              ),
              null => name,
            },
          ),
          IconButton(
            style: _square44,
            tooltip: 'New $itemLabel in ${group.label}',
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 20),
            color: scheme.onSurfaceVariant,
          ),
          if (onCollapse case final collapse?)
            IconButton(
              style: _square44,
              tooltip: 'Collapse ${group.label}',
              onPressed: collapse,
              icon: const RotatedBox(
                quarterTurns: 1,
                child: Icon(Icons.unfold_less, size: 20),
              ),
              color: scheme.onSurfaceVariant,
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

/// Animates its child's width to [width] (instantly under reduced motion),
/// clipping while it changes; the child is laid out at [width] throughout.
class _AnimatedWidth extends StatelessWidget {
  const _AnimatedWidth({required this.width, required this.child});

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(end: width),
    duration: MediaQuery.disableAnimationsOf(context)
        ? MotionDurations.none
        : MotionDurations.base,
    curve: MotionCurves.standard,
    child: child,
    builder: (context, w, child) => ClipRect(
      child: SizedBox(
        width: w,
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: width,
          maxWidth: width,
          child: child,
        ),
      ),
    ),
  );
}

/// A collapsed column: one button the board's height, with the expand icon,
/// the colour dot, a count badge, then the name written top to bottom. Tints like a column while a card hovers it.
class _CollapsedStrip extends StatelessWidget {
  const _CollapsedStrip({
    required this.group,
    required this.itemLabel,
    required this.itemsLabel,
    required this.hovered,
    required this.onExpand,
  });

  final ViewGroup group;
  final String itemLabel;
  final String itemsLabel;
  final bool hovered;
  final VoidCallback? onExpand;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final count = group.objects.length;
    final summary = switch (count) {
      0 => 'No $itemsLabel',
      1 => '1 $itemLabel',
      _ => '$count $itemsLabel',
    };
    return Semantics(
      button: true,
      label: 'Expand ${group.label}, $summary',
      excludeSemantics: true,
      child: Material(
        color: hovered
            ? scheme.surfaceContainerHigh
            : scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.lgAll,
          side: BorderSide(
            color: hovered ? scheme.primary : Colors.transparent,
            width: 2,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const ValueKey('column-expand'),
          onTap: onExpand,
          child: SizedBox(
            width: BoardColumn.collapsedWidth,
            height: double.infinity,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, Spacing.xs, 0, Spacing.md),
              child: Column(
                children: [
                  SizedBox.square(
                    dimension: 32,
                    child: RotatedBox(
                      quarterTurns: 1,
                      child: Icon(
                        Icons.unfold_more,
                        size: 20,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: Spacing.sm),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: switch (group.color) {
                        final hex? => colorFromHex(hex),
                        null => scheme.outline,
                      },
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(height: Spacing.sm),
                  Container(
                    constraints: const BoxConstraints(minWidth: 24),
                    height: 22,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Text(
                      '$count',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  const SizedBox(height: Spacing.sm),
                  Flexible(
                    child: RotatedBox(
                      quarterTurns: 1,
                      child: Text(
                        group.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
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
