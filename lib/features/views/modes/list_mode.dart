import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/shell/app_shell.dart';
import '../../../core/domain/domain.dart';
import '../../../design/design.dart';
import '../collection_views_cubit.dart';
import '../collection_views_state.dart';
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
  bool acceptsLayoutField(FieldDefinition field) =>
      field is SingleSelectFieldDefinition ||
      (field is ReferenceFieldDefinition && !field.multiple);

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
class ViewList extends StatelessWidget {
  const ViewList({super.key, required this.data});

  final ViewModeData data;

  static const double headerHeight = 36;
  static const double addHeight = 44;

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
    final beforeId = switch (next.elementAtOrNull(to + 1)) {
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
    // it is the first section.
    final header =
        next.take(to).whereType<_Header>().lastOrNull ??
        next.whereType<_Header>().first;
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
      child: SingleChildScrollView(
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: Radii.lgAll,
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: ClipRRect(
            borderRadius: Radii.lgAll,
            child: ColoredBox(
              color: scheme.surfaceContainerLowest,
              child: ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
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
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({super.key, required this.group});

  final ViewGroup group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final style = theme.textTheme.labelMedium?.copyWith(
      color: scheme.onSurfaceVariant,
      letterSpacing: 0.6,
    );
    return Semantics(
      header: true,
      child: Container(
        height: ViewList.headerHeight,
        padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
        color: scheme.surfaceContainerLow,
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Flexible(
              child: Text(
                group.label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: Spacing.xs),
            Text(
              '${group.objects.length}',
              style: style?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
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
                  color: scheme.outline.withValues(alpha: _hovered ? 1 : 0.4),
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
      child: Stack(
        children: [
          row,
          if (widget.divider)
            Positioned(
              left: Spacing.md,
              right: 0,
              bottom: 0,
              height: 1,
              child: ColoredBox(color: scheme.outlineVariant),
            ),
        ],
      ),
    );
  }
}
