import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/shell/app_shell.dart';
import '../../../core/domain/domain.dart';
import '../../../design/design.dart';
import '../collection_views_cubit.dart';
import '../collection_views_state.dart';
import '../widgets/list_parts.dart';
import '../widgets/object_card.dart';
import '../widgets/view_toolbar.dart';
import 'view_mode.dart';

/// One scannable column of rows, optionally in sections by a choice or
/// reference field. With manual order, rows can be dragged to reorder (and,
/// across sections, to change the value) by long-press or the hover handle.
class ListMode extends ViewMode {
  const ListMode();

  @override
  String get id => ViewModeIds.list;

  @override
  String get label => 'List';

  @override
  IconData get icon => Icons.view_list_outlined;

  @override
  String get description => 'Compact rows, optionally in sections.';

  @override
  bool acceptsLayoutField(FieldDefinition field) => isGroupable(field);

  @override
  bool get supportsManualOrder => true;

  @override
  Widget buildBody(BuildContext context, ViewModeData data) =>
      ViewList(data: data);

  @override
  Widget? buildSettingsChip(BuildContext context, ViewModeData data) {
    final state = data.state;
    final fields = [
      for (final f in state.collection.fields)
        if (acceptsLayoutField(f)) f,
    ];
    if (fields.isEmpty) return null;
    final current = state.layoutField;
    final cubit = context.read<CollectionViewsCubit>();
    return Builder(
      builder: (context) => ToolbarButton(
        icon: Icons.view_agenda_outlined,
        label: 'Group: ${current != null ? current.name : 'None'}',
        onPressed: () async {
          final box = context.findRenderObject() as RenderBox;
          final overlay =
              Overlay.of(context).context.findRenderObject() as RenderBox;
          final origin = box.localToGlobal(Offset.zero, ancestor: overlay);
          final picked = await showMenu<String>(
            context: context,
            position: RelativeRect.fromLTRB(
              origin.dx,
              origin.dy + box.size.height,
              overlay.size.width - origin.dx - box.size.width,
              0,
            ),
            items: [
              CheckedPopupMenuItem(
                value: '',
                checked: current == null,
                child: const Text('None'),
              ),
              for (final f in fields)
                CheckedPopupMenuItem(
                  value: f.id,
                  checked: current?.id == f.id,
                  child: Text(f.name),
                ),
            ],
          );
          if (picked != null) {
            cubit.setLayoutField(picked.isEmpty ? null : picked);
          }
        },
      ),
    );
  }
}

sealed class _Item {
  const _Item();
  String get key;
}

class _Header extends _Item {
  const _Header(this.group);
  final ViewGroup group;
  @override
  String get key => 'h:${group.key}';
}

class _RowItem extends _Item {
  const _RowItem(this.object);
  final MorkvaObject object;
  @override
  String get key => 'o:${object.id}';
}

class _AddItem extends _Item {
  const _AddItem(this.groupKey);
  final String? groupKey;
  @override
  String get key => 'a:$groupKey';
}

/// The List mode body.
class ViewList extends StatefulWidget {
  const ViewList({super.key, required this.data});

  final ViewModeData data;

  static const double headerHeight = ListSectionHeader.height;
  static const double addHeight = 44;

  @override
  State<ViewList> createState() => _ViewListState();
}

class _ViewListState extends State<ViewList> {
  final _scroll = ScrollController();
  final _stackKey = GlobalKey();

  /// Bumped after layout when the data changed so the sticky header is
  /// recomputed against the new header positions without a scroll.
  final _relayout = ValueNotifier<int>(0);

  ViewModeData get data => widget.data;

  @override
  void didUpdateWidget(ViewList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (data.state.groups == oldWidget.data.state.groups) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _relayout.value++;
    });
  }

  @override
  void dispose() {
    _relayout.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// The list's sliver, whose laid-out children give the item offsets (rows
  /// are built lazily, so far-away headers have no render box).
  RenderSliverMultiBoxAdaptor? _sliver() {
    RenderSliverMultiBoxAdaptor? found;
    void visit(RenderObject o) {
      if (found != null) return;
      if (o is RenderSliverMultiBoxAdaptor) {
        found = o;
      } else {
        o.visitChildren(visit);
      }
    }

    _stackKey.currentContext?.findRenderObject()?.visitChildren(visit);
    return found;
  }

  /// The section whose header has scrolled past the top, and how far the
  /// next header pushes it up (classic sticky headers). Null while the first
  /// header is still in view.
  ({ViewGroup group, double dy})? _pinned(List<_Item> items) {
    final groups = data.state.groups;
    final sliver = _sliver();
    if (groups == null || sliver == null || !_scroll.hasClients) return null;
    final pixels = _scroll.position.pixels;
    // Item index → top relative to the viewport, for the built items.
    final tops = <int, double>{};
    for (var c = sliver.firstChild; c != null; c = sliver.childAfter(c)) {
      final offset = sliver.childScrollOffset(c);
      if (offset != null) tops[sliver.indexOf(c)] = offset - pixels;
    }
    // The item covering the top edge decides the section.
    final covering = tops.keys
        .where((i) => i < items.length && tops[i]! < -0.5)
        .fold<int?>(null, (a, b) => a == null || b > a ? b : a);
    if (covering == null) return null;
    final header = items.take(covering + 1).whereType<_Header>().lastOrNull;
    if (header == null) return null;
    var next = covering + 1;
    while (next < items.length && items[next] is! _Header) {
      next++;
    }
    final nextTop = tops[next];
    final dy = nextTop == null
        ? 0.0
        : (nextTop - ViewList.headerHeight).clamp(-ViewList.headerHeight, 0.0);
    return (group: header.group, dy: dy);
  }

  List<_Item> _items() {
    final groups = data.state.groups;
    if (groups == null) {
      return [
        for (final o in data.state.objects) _RowItem(o),
        const _AddItem(null),
      ];
    }
    return [
      for (final g in groups) ...[
        _Header(g),
        for (final o in g.objects) _RowItem(o),
        _AddItem(g.key),
      ],
    ];
  }

  void _reorder(BuildContext context, List<_Item> items, int from, int to) {
    final moved = items[from];
    if (moved is! _RowItem) return;
    final next = List.of(items)
      ..removeAt(from)
      ..insert(to, moved);
    String? beforeId = switch (next.elementAtOrNull(to + 1)) {
      _RowItem(:final object) => object.id,
      _ => null,
    };
    final cubit = context.read<CollectionViewsCubit>();
    final groups = data.state.groups;
    if (groups == null) {
      final undo = cubit.reorder(moved.object.id, beforeId: beforeId);
      if (undo != null) {
        data.notify('Order changed', undo: undo);
      }
      return;
    }
    // The section is the nearest header above the drop; above the first one
    // it is the first section, and the row lands before that section's
    // first row.
    final above = next.take(to).whereType<_Header>().lastOrNull;
    final header = above ?? next.whereType<_Header>().first;
    if (above == null) {
      beforeId = next
          .skipWhile((e) => e is! _Header)
          .whereType<_RowItem>()
          .where((r) => r != moved)
          .firstOrNull
          ?.object
          .id;
      // Rows of later sections must not count.
      final firstGroupRows = groups.first.objects.map((o) => o.id);
      if (beforeId != null && !firstGroupRows.contains(beforeId)) {
        beforeId = null;
      }
    }
    final before = data.state.groups!
        .where((g) => g.objects.any((o) => o.id == moved.object.id))
        .firstOrNull;
    final undo = cubit.moveToGroup(
      moved.object.id,
      header.group.key,
      beforeId: beforeId,
    );
    if (undo != null) {
      data.notify(
        before?.key == header.group.key
            ? 'Order changed'
            : 'Moved to ${header.group.label}',
        undo: undo,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = data.state;
    final scheme = Theme.of(context).colorScheme;
    final items = _items();
    final manual = state.activeView.sort == null;
    final wide =
        MediaQuery.sizeOf(context).width >= AppShell.expandedBreakpoint;

    return Align(
      alignment: Alignment.topCenter,
      child: Stack(
        key: _stackKey,
        children: [
          // The list is the scroll view itself (shrink-wrapped so the card
          // hugs short lists), so a drag auto-scrolls it and rows build
          // lazily.
          ListCard(
            child: ReorderableListView.builder(
              scrollController: _scroll,
              shrinkWrap: true,
              buildDefaultDragHandles: false,
              itemCount: items.length,
              onReorderItem: (from, to) => _reorder(context, items, from, to),
              proxyDecorator: (child, _, _) => Material(
                color: scheme.surfaceContainerLowest,
                elevation: 6,
                borderRadius: Radii.mdAll,
                child: child,
              ),
              itemBuilder: (context, i) {
                final item = items[i];
                return switch (item) {
                  _Header(:final group) => _SectionHeader(
                    key: ValueKey(item.key),
                    group: group,
                  ),
                  _AddItem(:final groupKey) => _AddRow(
                    key: ValueKey(item.key),
                    label: 'New ${data.itemLabel}',
                    onTap: () => data.quickAdd(groupKey: groupKey),
                  ),
                  _RowItem(:final object) => _ObjectRow(
                    key: ValueKey(item.key),
                    index: i,
                    object: object,
                    state: state,
                    draggable: manual,
                    showHandle: manual && wide,
                    divider: items.elementAtOrNull(i + 1) is _RowItem,
                    onOpen: () => data.openObject(object),
                  ),
                };
              },
            ),
          ),
          // The sticky copy of the section header under the top edge.
          Positioned.fill(
            child: IgnorePointer(
              child: ListenableBuilder(
                listenable: Listenable.merge([_scroll, _relayout]),
                builder: (context, _) {
                  final pinned = _pinned(items);
                  if (pinned == null) return const SizedBox.shrink();
                  return Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: Transform.translate(
                        key: const ValueKey('pinned-header'),
                        offset: Offset(0, pinned.dy),
                        child: ExcludeSemantics(
                          child: _SectionHeader(group: pinned.group),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({super.key, required this.group});

  final ViewGroup group;

  @override
  Widget build(BuildContext context) =>
      ListSectionHeader(label: group.label, count: group.objects.length);
}

class _AddRow extends StatelessWidget {
  const _AddRow({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final link =
        theme.extension<MorkvaSemanticColors>()?.primaryText ?? scheme.primary;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        hoverColor: scheme.surfaceContainerLow,
        child: SizedBox(
          height: ViewList.addHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
            child: Row(
              children: [
                Icon(Icons.add, size: 20, color: link),
                const SizedBox(width: Spacing.xs),
                Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(color: link),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ObjectRow extends StatefulWidget {
  const _ObjectRow({
    super.key,
    required this.index,
    required this.object,
    required this.state,
    required this.draggable,
    required this.showHandle,
    required this.divider,
    required this.onOpen,
  });

  final int index;
  final MorkvaObject object;
  final ViewsReady state;
  final bool draggable;
  final bool showHandle;
  final bool divider;
  final VoidCallback onOpen;

  @override
  State<_ObjectRow> createState() => _ObjectRowState();
}

class _ObjectRowState extends State<_ObjectRow> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final state = widget.state;
    Widget row = Row(
      children: [
        Expanded(
          child: ObjectCard(
            object: widget.object,
            collection: state.collection,
            view: state.activeView,
            density: ObjectCardDensity.list,
            referenceLabels: state.referenceLabels,
            onTap: widget.onOpen,
          ),
        ),
        if (widget.showHandle)
          ReorderableDragStartListener(
            index: widget.index,
            child: MouseRegion(
              cursor: SystemMouseCursors.grab,
              child: SizedBox(
                width: 44,
                height: 44,
                child: Icon(
                  Icons.drag_indicator,
                  size: 20,
                  semanticLabel: 'Drag to reorder',
                  color: scheme.onSurfaceVariant.withValues(
                    alpha: _hovered || _focused ? 1 : 0.7,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
    if (widget.draggable) {
      row = ReorderableDelayedDragStartListener(
        index: widget.index,
        child: row,
      );
    }
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onFocusChange: (f) => setState(() => _focused = f),
        child: ListRowFrame(divider: widget.divider, child: row),
      ),
    );
  }
}
