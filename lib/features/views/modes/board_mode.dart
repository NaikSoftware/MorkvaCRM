import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/shell/app_shell.dart';
import '../../../core/domain/domain.dart';
import '../../../design/design.dart';
import '../../../l10n/l10n.dart';
import '../collection_views_cubit.dart';
import '../collection_views_state.dart';
import '../widgets/board/board_card_draggable.dart';
import '../widgets/board/board_column.dart';
import '../widgets/edge_fade.dart';
import '../widgets/no_matches_notice.dart';
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
  String get label => l10n.viewsModeBoard;

  @override
  IconData get icon => MorkvaIcons.viewBoard;

  @override
  String get description => l10n.viewsModeBoardDescription;

  @override
  bool get needsLayoutField => true;

  @override
  bool get drawsNoMatches => true;

  @override
  bool acceptsLayoutField(FieldDefinition field) => isGroupable(field);

  @override
  bool get supportsManualOrder => true;

  @override
  String? unavailableReason(Collection collection) =>
      groupableFields(collection).isEmpty
      ? l10n.viewsNeedsChoiceOrReference
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
        icon: MorkvaIcons.viewBoard,
        label: switch (data.state.layoutField?.name) {
          final name? => context.l10n.viewsGroupChip(name),
          null => context.l10n.viewsGroupChipNone,
        },
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
                ? const Icon(MorkvaIcons.check, size: 20)
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

/// The Board mode body: columns side by side, scrolling sideways; on phones
/// one column per page with the next one peeking in.
class BoardView extends StatefulWidget {
  const BoardView({super.key, required this.data});

  final ViewModeData data;

  /// Phone: how much of the next column shows beside the current one.
  static const double peek = 72;

  /// Phone: how long a held card rests at the edge before the page turns.
  static const Duration edgeHold = Duration(milliseconds: 500);

  @override
  State<BoardView> createState() => _BoardViewState();
}

class _BoardViewState extends State<BoardView> {
  final _horizontal = ScrollController();
  EdgeDraggingAutoScroller? _autoScroller;

  /// Phone pager; recreated when the width (and so the peek) changes.
  PageController? _pages;
  final _pageKey = GlobalKey();
  final _page = ValueNotifier(0);
  Timer? _edgeTimer;
  bool _compact = false;

  /// The lifted card. Tracked here, not via the card's Draggable, which
  /// skips its end callbacks once its column scrolls out and is disposed.
  BoardDrag? _drag;

  /// Where the held pointer is, for re-checking the edge after each step.
  Offset? _pointer;

  /// Focused only while a card is held, so Esc cancels the drag without
  /// taking the key from anything else.
  final _escape = FocusNode(debugLabel: 'board drag');

  @override
  void dispose() {
    _escape.dispose();
    _autoScroller?.stopAutoScroll();
    _edgeTimer?.cancel();
    _horizontal.dispose();
    _pages?.dispose();
    _page.dispose();
    super.dispose();
  }

  /// Only the pointer holding the card counts; other fingers are ignored.
  bool _isDragPointer(PointerEvent event) =>
      _drag != null && event.pointer == _drag!.pointer;

  void _pointerMove(PointerMoveEvent event) {
    if (!_isDragPointer(event)) return;
    _pointer = event.position;
    _compact ? _edgeHold() : _autoScroll();
  }

  void _autoScroll() {
    final pointer = _pointer;
    if (_drag == null || pointer == null || !_horizontal.hasClients) return;
    final board = _horizontal.position.context;
    if (board is! ScrollableState) return;
    if (_autoScroller?.scrollable != board) {
      _autoScroller = EdgeDraggingAutoScroller(
        board,
        velocityScalar: 7,
        onScrollViewScrolled: _scrolled,
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

  /// Columns moved under a still pointer: let the one now under it take
  /// the card, and keep scrolling while the pointer rests at the edge.
  void _scrolled() {
    final drag = _drag;
    if (drag == null) return;
    // Pause a frame: a scrolling list ignores hit tests.
    _autoScroller?.stopAutoScroll();
    drag.retarget(then: _autoScroll);
  }

  /// Phone: holding the card at the left / right edge for
  /// [BoardView.edgeHold] turns one page.
  void _edgeHold() {
    final pointer = _pointer;
    final box = _pageKey.currentContext?.findRenderObject() as RenderBox?;
    if (pointer == null || box == null || !box.hasSize) return;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    final step = pointer.dx < rect.left + BoardColumn.autoScrollEdge
        ? -1
        : pointer.dx > rect.right - BoardColumn.autoScrollEdge
        ? 1
        : 0;
    if (step == 0) {
      _edgeTimer?.cancel();
      _edgeTimer = null;
    } else {
      _edgeTimer ??= Timer(BoardView.edgeHold, () => _turn(step));
    }
  }

  Future<void> _turn(int step) async {
    final pages = _pages;
    final count = widget.data.state.groups?.length ?? 0;
    if (pages == null || !pages.hasClients || _drag == null || count == 0) {
      return;
    }
    final target = (_page.value + step).clamp(0, count - 1);
    // At the first / last page: keep the spent timer so it doesn't re-arm
    // until the pointer leaves the edge.
    if (target == _page.value) return;
    await pages.animateToPage(
      target,
      duration: MotionDurations.base,
      curve: MotionCurves.standard,
    );
    _edgeTimer = null;
    final drag = _drag;
    if (!mounted || drag == null) return;
    drag.retarget();
    _edgeHold();
  }

  void _dragStarted(BoardDrag drag) {
    _drag = drag;
    _escape.requestFocus();
  }

  /// Esc: the card goes back where it was; nothing is written.
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final drag = _drag;
    if (drag == null ||
        event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.escape) {
      return KeyEventResult.ignored;
    }
    drag.cancel();
    _endDrag();
    return KeyEventResult.handled;
  }

  void _pointerEnd(PointerEvent event) {
    if (_isDragPointer(event)) _endDrag();
  }

  void _endDrag() {
    if (_escape.hasFocus) _escape.unfocus();
    _drag = null;
    _pointer = null;
    _edgeTimer?.cancel();
    _edgeTimer = null;
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
    final l10n = context.l10n;
    final message = switch ((within, sorted, hidden)) {
      (true, true, _) => l10n.viewsReorderedInSortOff(to.label),
      (true, false, _) => l10n.viewsReorderedIn(to.label),
      (false, _, true) => l10n.viewsMovedToHidden(to.label),
      (false, _, false) => l10n.viewsMovedTo(to.label),
    };
    widget.data.notify(message, undo: undo);
  }

  /// The pager for [fraction]; its viewport fraction is fixed, so a new
  /// width needs a new controller (keeping the page).
  PageController _pagesFor(double fraction) {
    final current = _pages;
    if (current != null && current.viewportFraction == fraction) {
      return current;
    }
    final next = PageController(
      viewportFraction: fraction,
      initialPage: _page.value,
    );
    _pages = next;
    // The old one is still attached during this build.
    if (current != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => current.dispose());
    }
    return next;
  }

  /// Wide again: forget the pager, so a later phone layout starts it afresh
  /// on [_page] rather than a stale position.
  void _dropPager() {
    final pages = _pages;
    if (pages == null) return;
    _pages = null;
    // Still attached during this build.
    WidgetsBinding.instance.addPostFrameCallback((_) => pages.dispose());
  }

  Future<void> _openJumpList(List<ViewGroup> groups) async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      builder: (_) => ColumnJumpList(groups: groups, current: _page.value),
    );
    final pages = _pages;
    if (picked == null || !mounted || pages == null || !pages.hasClients) {
      return;
    }
    await pages.animateToPage(
      picked,
      duration: MotionDurations.base,
      curve: MotionCurves.standard,
    );
  }

  Widget _column(
    BuildContext context,
    ViewGroup group,
    FieldDefinition field, {
    double width = BoardColumn.defaultWidth,
    VoidCallback? onJump,
    bool fill = false,
    bool collapsible = false,
    Widget? footer,
  }) {
    final data = widget.data;
    final state = data.state;
    final collection = state.collection;
    final itemsLabel = collection.name.trim().toLowerCase();
    return BoardColumn(
      key: ValueKey(('column', group.key)),
      group: group,
      collection: collection,
      view: state.activeView,
      field: field,
      width: width,
      itemLabel: data.itemLabel,
      itemsLabel: itemsLabel.isEmpty
          ? context.l10n.viewsItemsFallback
          : itemsLabel,
      referenceLabels: state.referenceLabels,
      onOpen: data.openObject,
      onAdd: () => data.quickAdd(groupKey: group.key),
      onDrop: (drag, beforeId) => _drop(group, drag, beforeId),
      // Phone (not collapsible) shows every column expanded.
      collapsed: collapsible && state.activeView.isGroupCollapsed(group.key),
      onToggleCollapsed: collapsible
          ? () => context.read<CollectionViewsCubit>().toggleGroupCollapsed(
              group.key,
            )
          : null,
      onDragStarted: _dragStarted,
      onJump: onJump,
      fill: fill,
      footer: footer,
    );
  }

  Widget _desktop(List<ViewGroup> groups, FieldDefinition field) => Scrollbar(
    controller: _horizontal,
    // Pointer users get a visible track; touch scrolls by swiping.
    thumbVisibility: RendererBinding.instance.mouseTracker.mouseIsConnected,
    // A vertical wheel no column takes (background, a column that can't
    // scroll) scrolls the board sideways.
    child: Listener(
      // The gaps around columns hit nothing inside: still take the wheel.
      behavior: HitTestBehavior.translucent,
      onPointerSignal: (event) {
        if (event is PointerScrollEvent &&
            event.scrollDelta.dy != 0 &&
            _horizontal.hasClients) {
          GestureBinding.instance.pointerSignalResolver.register(
            event,
            (_) => _horizontal.position.pointerScroll(event.scrollDelta.dy),
          );
        }
      },
      // Lazy: a reference board can have hundreds of columns.
      child: EdgeFade(
        child: ListView.separated(
          controller: _horizontal,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(bottom: Spacing.sm),
          itemCount: groups.length,
          separatorBuilder: (_, _) => const SizedBox(width: Spacing.md),
          itemBuilder: (context, i) => Align(
            alignment: Alignment.topCenter,
            child: _column(context, groups[i], field, collapsible: true),
          ),
        ),
      ),
    ),
  );

  /// One column per page, the next one peeking in by [BoardView.peek].
  Widget _phone(List<ViewGroup> groups, FieldDefinition field) => LayoutBuilder(
    builder: (context, constraints) {
      final w = constraints.maxWidth;
      final pages = _pagesFor((w - BoardView.peek) / w);
      final columnWidth = w - BoardView.peek - Spacing.sm;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: PageView.builder(
              key: _pageKey,
              controller: pages,
              padEnds: false,
              itemCount: groups.length,
              onPageChanged: (i) => _page.value = i,
              // The whole page takes drops for its column.
              itemBuilder: (context, i) => _column(
                context,
                groups[i],
                field,
                width: columnWidth,
                fill: true,
                onJump: () => _openJumpList(groups),
                // The dots sit under the shown column, not at the page foot.
                footer: ValueListenableBuilder(
                  valueListenable: _page,
                  builder: (_, page, _) => page.clamp(0, groups.length - 1) == i
                      ? BoardPageIndicator(count: groups.length, current: i)
                      : const SizedBox(height: BoardPageIndicator.height),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final state = data.state;
    final groups = state.groups;
    final field = state.layoutField;
    if (groups == null || field == null) return _NoGrouping(data: data);

    _compact = MediaQuery.sizeOf(context).width < AppShell.expandedBreakpoint;
    if (!_compact) _dropPager();
    // Android reports a ~8 dp touch slop: the jitter of a resting finger would
    // let the board scroll grab a card's long press. Hold both to at least
    // Flutter's default.
    final slop = MediaQuery.gestureSettingsOf(context).touchSlop ?? kTouchSlop;
    final columns = Focus(
      focusNode: _escape,
      skipTraversal: true,
      onKeyEvent: _onKey,
      child: Listener(
        onPointerMove: _pointerMove,
        onPointerUp: _pointerEnd,
        onPointerCancel: _pointerEnd,
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(
            gestureSettings: DeviceGestureSettings(
              touchSlop: slop < kTouchSlop ? kTouchSlop : slop,
            ),
          ),
          // A mouse drag moves cards: drag-to-scroll would win the arena at
          // 1 px, before a card lifts at 4. Wheel, trackpad and the
          // scrollbar still scroll.
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              dragDevices: {...ScrollConfiguration.of(context).dragDevices}
                ..remove(PointerDeviceKind.mouse),
            ),
            child: _compact ? _phone(groups, field) : _desktop(groups, field),
          ),
        ),
      ),
    );
    if (!(state.objects.isEmpty && state.isFiltered)) return columns;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NoMatchesNotice(
          onClear: () => context.read<CollectionViewsCubit>().clearFilters(),
        ),
        const SizedBox(height: Spacing.xs),
        Expanded(child: columns),
      ],
    );
  }
}

/// Phone board position: dots for up to [maxDots] columns, else "2 / 9".
class BoardPageIndicator extends StatelessWidget {
  const BoardPageIndicator({
    super.key,
    required this.count,
    required this.current,
  });

  static const int maxDots = 7;
  static const double height = 20;

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      container: true,
      label: context.l10n.viewsColumnOf(current + 1, count),
      excludeSemantics: true,
      child: SizedBox(
        height: BoardPageIndicator.height,
        child: Center(
          child: count <= maxDots
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < count; i++)
                      AnimatedContainer(
                        key: ValueKey(('dot', i)),
                        duration: MotionDurations.fast,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: i == current ? 16 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: i == current
                              ? scheme.primary
                              : scheme.outlineVariant,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                  ],
                )
              : Text(
                  '${current + 1} / $count',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
        ),
      ),
    );
  }
}

/// The phone board's column jump list; pops the picked column's index.
class ColumnJumpList extends StatelessWidget {
  const ColumnJumpList({
    super.key,
    required this.groups,
    required this.current,
  });

  final List<ViewGroup> groups;
  final int current;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.7,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.lg,
              0,
              Spacing.lg,
              Spacing.xs,
            ),
            child: Text(
              context.l10n.viewsJumpToColumn,
              style: theme.textTheme.titleMedium,
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: Spacing.md),
              itemCount: groups.length,
              itemBuilder: (context, i) {
                final group = groups[i];
                return ListTile(
                  selected: i == current,
                  selectedTileColor: scheme.secondaryContainer,
                  selectedColor: scheme.onSecondaryContainer,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: Spacing.lg,
                  ),
                  minLeadingWidth: 10,
                  leading: Container(
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
                  title: Text(
                    group.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text(
                    '${group.objects.length}',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  onTap: () => Navigator.of(context).pop(i),
                );
              },
            ),
          ),
        ],
      ),
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
        icon: MorkvaIcons.viewBoard,
        title: context.l10n.viewsBoardNeedsField,
        message: context.l10n.viewsBoardNeedsFieldMessage(
          switch (collection.name.trim().toLowerCase()) {
            '' => context.l10n.viewsItemsFallback,
            final items => items,
          },
        ),
        action: PrimaryButton(
          label: context.l10n.viewsAddField,
          icon: MorkvaIcons.add,
          onPressed: () => context.go('/collections/${collection.id}/edit'),
        ),
      );
    }
    return EmptyState(
      icon: MorkvaIcons.viewBoard,
      title: context.l10n.viewsBoardChooseGroup,
      message: context.l10n.viewsBoardChooseGroupMessage,
      action: GroupByMenu(
        fields: fields,
        selectedId: null,
        builder: (open) => PrimaryButton(
          label: context.l10n.viewsGroupByAction,
          icon: MorkvaIcons.viewBoard,
          onPressed: open,
        ),
      ),
    );
  }
}
