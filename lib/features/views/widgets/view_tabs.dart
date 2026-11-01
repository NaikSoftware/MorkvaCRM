import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/domain/domain.dart';
import '../../../design/design.dart';
import '../modes/view_mode.dart';

/// The saved views as scrollable tabs with a trailing "+". The active tab
/// carries a ⋯ menu (also on long-press / right-click of any tab): Rename
/// (inline), Duplicate, Delete — never for the last view.
class ViewTabs extends StatefulWidget {
  const ViewTabs({
    super.key,
    required this.views,
    required this.activeViewId,
    required this.modes,
    required this.onSelect,
    required this.onNewView,
    required this.onRename,
    required this.onDuplicate,
    required this.onDelete,
    this.horizontalPadding = Spacing.lg,
  });

  final List<ViewDefinition> views;
  final String activeViewId;
  final ViewModeRegistry modes;
  final ValueChanged<String> onSelect;
  final VoidCallback onNewView;
  final void Function(String viewId, String name) onRename;
  final ValueChanged<String> onDuplicate;
  final ValueChanged<String> onDelete;
  final double horizontalPadding;

  @override
  State<ViewTabs> createState() => _ViewTabsState();
}

enum _TabAction { rename, duplicate, delete }

class _ViewTabsState extends State<ViewTabs> with TickerProviderStateMixin {
  late TabController _controller = _newController();
  String? _renaming;
  final _renameController = TextEditingController();
  final _renameFocus = FocusNode();
  bool _fadeStart = false;
  bool _fadeEnd = false;

  int get _activeIndex {
    final i = widget.views.indexWhere((v) => v.id == widget.activeViewId);
    return i < 0 ? 0 : i;
  }

  TabController _newController() => TabController(
    length: widget.views.length,
    initialIndex: _activeIndex,
    vsync: this,
  );

  @override
  void initState() {
    super.initState();
    _renameFocus.addListener(() {
      if (!_renameFocus.hasFocus && _renaming != null) _commitRename();
    });
  }

  @override
  void didUpdateWidget(ViewTabs old) {
    super.didUpdateWidget(old);
    if (old.views.length != widget.views.length) {
      _controller.dispose();
      _controller = _newController();
    } else if (_controller.index != _activeIndex) {
      _controller.animateTo(_activeIndex);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _renameController.dispose();
    _renameFocus.dispose();
    super.dispose();
  }

  void _startRename(ViewDefinition view) {
    widget.onSelect(view.id);
    setState(() {
      _renaming = view.id;
      _renameController.text = view.name;
      _renameController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: view.name.length,
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _renameFocus.requestFocus();
    });
  }

  void _commitRename() {
    final id = _renaming;
    if (id == null) return;
    setState(() => _renaming = null);
    widget.onRename(id, _renameController.text);
  }

  void _cancelRename() => setState(() => _renaming = null);

  Future<void> _openMenu(ViewDefinition view, Offset globalPosition) async {
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final canDelete = widget.views.length > 1;
    final action = await showMenu<_TabAction>(
      context: context,
      position: RelativeRect.fromRect(
        globalPosition & const Size(1, 1),
        Offset.zero & overlay.size,
      ),
      items: [
        const PopupMenuItem(
          value: _TabAction.rename,
          child: _MenuRow(icon: Icons.edit_outlined, label: 'Rename'),
        ),
        const PopupMenuItem(
          value: _TabAction.duplicate,
          child: _MenuRow(
            icon: Icons.content_copy_outlined,
            label: 'Duplicate',
          ),
        ),
        PopupMenuItem(
          value: _TabAction.delete,
          enabled: canDelete,
          child: Tooltip(
            message: canDelete ? '' : "The last view can't be deleted",
            child: const _MenuRow(icon: Icons.delete_outline, label: 'Delete'),
          ),
        ),
      ],
    );
    if (!mounted) return;
    switch (action) {
      case _TabAction.rename:
        _startRename(view);
      case _TabAction.duplicate:
        widget.onDuplicate(view.id);
      case _TabAction.delete:
        widget.onDelete(view.id);
      case null:
    }
  }

  bool _onScroll(ScrollMetricsNotification n) {
    final m = n.metrics;
    if (m.axis != Axis.horizontal) return false;
    final start = m.extentBefore > 0.5;
    final end = m.extentAfter > 0.5;
    if (start != _fadeStart || end != _fadeEnd) {
      setState(() {
        _fadeStart = start;
        _fadeEnd = end;
      });
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tabs = TabBar(
      controller: _controller,
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      padding: EdgeInsets.zero,
      labelPadding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
      dividerColor: Colors.transparent,
      indicatorSize: TabBarIndicatorSize.tab,
      indicator: UnderlineTabIndicator(
        borderSide: BorderSide(color: scheme.primary, width: 3),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
      ),
      labelColor: scheme.onSurface,
      unselectedLabelColor: scheme.onSurfaceVariant,
      labelStyle: theme.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: theme.textTheme.labelLarge,
      overlayColor: WidgetStatePropertyAll(
        scheme.onSurface.withValues(alpha: 0.06),
      ),
      splashBorderRadius: Radii.smAll,
      onTap: (i) => widget.onSelect(widget.views[i].id),
      tabs: [for (final v in widget.views) _tab(v)],
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: widget.horizontalPadding - Spacing.sm,
          right: widget.horizontalPadding - Spacing.xs,
        ),
        child: Row(
          children: [
            Flexible(
              child: NotificationListener<ScrollMetricsNotification>(
                onNotification: _onScroll,
                child: ShaderMask(
                  blendMode: BlendMode.dstIn,
                  shaderCallback: (rect) => LinearGradient(
                    colors: [
                      _fadeStart ? Colors.transparent : Colors.black,
                      Colors.black,
                      Colors.black,
                      _fadeEnd ? Colors.transparent : Colors.black,
                    ],
                    stops: [
                      0,
                      (24 / rect.width).clamp(0, 0.5),
                      (1 - 24 / rect.width).clamp(0.5, 1),
                      1,
                    ],
                  ).createShader(rect),
                  child: tabs,
                ),
              ),
            ),
            IconButton(
              onPressed: widget.onNewView,
              tooltip: 'New view',
              icon: const Icon(Icons.add),
              color: scheme.onSurfaceVariant,
              constraints: const BoxConstraints.tightFor(width: 44, height: 44),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tab(ViewDefinition view) {
    final active = view.id == widget.activeViewId;
    final mode = widget.modes.resolve(view.mode);
    final renaming = _renaming == view.id;
    return GestureDetector(
      onLongPressStart: (d) => _openMenu(view, d.globalPosition),
      onSecondaryTapUp: (d) => _openMenu(view, d.globalPosition),
      child: SizedBox(
        height: 48,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(mode.icon, size: 18),
            const SizedBox(width: Spacing.xs),
            if (renaming)
              SizedBox(
                width: 160,
                child: CallbackShortcuts(
                  bindings: {
                    const SingleActivator(LogicalKeyboardKey.escape):
                        _cancelRename,
                  },
                  child: TextField(
                    controller: _renameController,
                    focusNode: _renameFocus,
                    style: Theme.of(context).textTheme.labelLarge,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: Spacing.xs,
                        vertical: Spacing.xs,
                      ),
                    ),
                    onSubmitted: (_) => _commitRename(),
                  ),
                ),
              )
            else
              Text(view.name),
            if (active && !renaming)
              Builder(
                builder: (context) => SizedBox(
                  width: 32,
                  height: 32,
                  child: IconButton(
                    tooltip: 'View options',
                    padding: EdgeInsets.zero,
                    iconSize: 18,
                    onPressed: () {
                      final box = context.findRenderObject()! as RenderBox;
                      _openMenu(
                        view,
                        box.localToGlobal(box.size.bottomLeft(Offset.zero)),
                      );
                    },
                    icon: const Icon(Icons.more_horiz),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 20),
      const SizedBox(width: Spacing.sm),
      Flexible(child: Text(label)),
    ],
  );
}
