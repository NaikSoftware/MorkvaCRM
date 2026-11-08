import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../api/auth/auth_user.dart';
import '../../api/sync/sync_status.dart';
import '../../api/sync/sync_status_cubit.dart';
import '../../core/domain/domain.dart';
import '../../design/design.dart';
import 'brand_wordmark.dart';
import 'sync_status_indicator.dart';

/// Where the user is, as far as the navigation is concerned.
enum ShellPlace { allCollections, collection, settings }

/// The wide-screen navigation: the brand, "Jump to…", All collections, the
/// pinned collections and the profile row with settings. [extended] false is
/// the slim icon rail.
///
/// Dumb: everything comes in as data and goes out through callbacks.
class ShellSidebar extends StatelessWidget {
  const ShellSidebar({
    super.key,
    required this.extended,
    required this.place,
    required this.pinned,
    required this.onAllCollections,
    required this.onCollection,
    required this.onSettings,
    required this.onJumpTo,
    required this.onUnpin,
    required this.onReorder,
    this.collectionId,
    this.user,
  });

  final bool extended;
  final ShellPlace place;

  /// The open collection's id when [place] is [ShellPlace.collection].
  final String? collectionId;

  /// The pinned collections, in pin order.
  final List<Collection> pinned;
  final AuthUser? user;

  final VoidCallback onAllCollections;
  final ValueChanged<String> onCollection;
  final VoidCallback onSettings;
  final VoidCallback onJumpTo;
  final ValueChanged<String> onUnpin;

  /// Moves the pin at `oldIndex` of [pinned] to `newIndex` (the index in the
  /// list without it, as [ReorderableListView.onReorderItem] reports).
  final void Function(int oldIndex, int newIndex) onReorder;

  /// Width of the full sidebar.
  static const double width = 272;

  /// Width of the slim rail.
  static const double railWidth = 76;

  /// A collection that isn't pinned still lives under All collections.
  bool get _allSelected =>
      place == ShellPlace.allCollections ||
      (place == ShellPlace.collection &&
          !pinned.any((c) => c.id == collectionId));

  bool _isOpen(Collection c) =>
      place == ShellPlace.collection && c.id == collectionId;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainer,
        child: SizedBox(
          width: extended ? width : railWidth,
          child: extended ? _full(context) : _rail(context),
        ),
      ),
    );
  }

  Widget _full(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Spacing.sm,
        Spacing.md,
        Spacing.sm,
        Spacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.xxs,
              Spacing.xxs,
              Spacing.xxs,
              Spacing.sm,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: BrandWordmark(onTap: onAllCollections),
            ),
          ),
          _JumpField(onTap: onJumpTo),
          const SizedBox(height: Spacing.xs),
          _NavRow(
            label: 'All collections',
            selected: _allSelected,
            leading: _AllTile(size: 28, selected: true),
            onTap: onAllCollections,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.sm,
              Spacing.md,
              Spacing.xxs,
              Spacing.xxs,
            ),
            child: Text('PINNED', style: _capStyle(theme)),
          ),
          Expanded(
            child: pinned.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Spacing.sm,
                      vertical: Spacing.xxs,
                    ),
                    child: Text(
                      'Pin the collections you use most — tap the pin on '
                      'any collection in All collections.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ReorderableListView.builder(
                    buildDefaultDragHandles: false,
                    itemCount: pinned.length,
                    onReorderItem: onReorder,
                    proxyDecorator: (child, _, _) => Material(
                      color: Colors.transparent,
                      elevation: 0,
                      child: child,
                    ),
                    itemBuilder: (context, i) {
                      final c = pinned[i];
                      return _NavRow(
                        key: ValueKey(c.id),
                        label: c.name,
                        selected: _isOpen(c),
                        leading: CollectionGlyph(
                          iconKey: c.icon,
                          tintSeed: c.id,
                          size: 28,
                          iconSize: 16,
                        ),
                        dragIndex: i,
                        onTap: () => onCollection(c.id),
                        onUnpin: () => onUnpin(c.id),
                      );
                    },
                  ),
          ),
          const Divider(height: Spacing.md),
          _ProfileRow(
            user: user,
            settingsSelected: place == ShellPlace.settings,
            onSettings: onSettings,
          ),
        ],
      ),
    );
  }

  Widget _rail(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.md),
      child: Column(
        children: [
          Tooltip(
            message: 'All collections',
            child: InkWell(
              onTap: onAllCollections,
              borderRadius: Radii.mdAll,
              child: const BrandLogomark(size: 40),
            ),
          ),
          const SizedBox(height: Spacing.sm),
          _RailButton(
            tooltip: jumpShortcutLabel == null
                ? 'Jump to…'
                : 'Jump to… ($jumpShortcutLabel)',
            onTap: onJumpTo,
            child: Icon(Icons.search_rounded, color: scheme.onSurfaceVariant),
          ),
          _RailButton(
            tooltip: 'All collections',
            selected: _allSelected,
            onTap: onAllCollections,
            child: _AllTile(size: 36, selected: _allSelected),
          ),
          SizedBox(
            width: 28,
            child: Divider(height: Spacing.md, color: scheme.outlineVariant),
          ),
          Expanded(
            child: ListView(
              children: [
                for (final c in pinned)
                  _RailButton(
                    tooltip: c.name,
                    marker: _isOpen(c),
                    onTap: () => onCollection(c.id),
                    onSecondaryTap: (position) =>
                        _showUnpinMenu(context, position, () => onUnpin(c.id)),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(13),
                        border: _isOpen(c)
                            ? Border.all(color: scheme.primary, width: 2)
                            : null,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: CollectionGlyph(
                          iconKey: c.icon,
                          tintSeed: c.id,
                          size: 36,
                          iconSize: 19,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          _RailButton(
            tooltip: 'Settings',
            selected: place == ShellPlace.settings,
            onTap: onSettings,
            child: Icon(Icons.tune_rounded, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: Spacing.xxs),
          UserAvatar(user: user, showSync: true),
        ],
      ),
    );
  }
}

TextStyle? _capStyle(ThemeData theme) => theme.textTheme.labelSmall?.copyWith(
  color: theme.colorScheme.onSurfaceVariant,
  fontWeight: FontWeight.w700,
  letterSpacing: 0.9,
);

Future<void> _showUnpinMenu(
  BuildContext context,
  Offset position,
  VoidCallback onUnpin,
) async {
  final picked = await showMenu<bool>(
    context: context,
    position: RelativeRect.fromLTRB(
      position.dx,
      position.dy,
      position.dx,
      position.dy,
    ),
    items: const [
      PopupMenuItem(
        value: true,
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.push_pin_outlined),
          title: Text('Unpin'),
        ),
      ),
    ],
  );
  if (picked == true) onUnpin();
}

/// The carrot "all collections" grid tile.
class _AllTile extends StatelessWidget {
  const _AllTile({required this.size, required this.selected});

  final double size;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: selected ? scheme.primary : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(
        Icons.grid_view_rounded,
        size: size * 0.57,
        color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
      ),
    );
  }
}

/// The "Jump to…" field-look button with its shortcut hint.
class _JumpField extends StatelessWidget {
  const _JumpField({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: Radii.mdAll,
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: Radii.mdAll,
        child: SizedBox(
          height: 40,
          child: Padding(
            padding: const EdgeInsets.only(left: Spacing.sm, right: Spacing.xs),
            child: Row(
              children: [
                Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: Spacing.xs),
                Expanded(child: Text('Jump to…', style: muted)),
                if (jumpShortcutLabel case final shortcut?)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: Text(
                      shortcut,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
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

/// One sidebar row: a [leading] tile and a label; [selected] lifts it onto a
/// raised pill. With [dragIndex] the row shows a drag handle on hover, and
/// [onUnpin] adds the right-click menu.
class _NavRow extends StatefulWidget {
  const _NavRow({
    super.key,
    required this.label,
    required this.selected,
    required this.leading,
    required this.onTap,
    this.dragIndex,
    this.onUnpin,
  });

  final String label;
  final bool selected;
  final Widget leading;
  final VoidCallback onTap;
  final int? dragIndex;
  final VoidCallback? onUnpin;

  @override
  State<_NavRow> createState() => _NavRowState();
}

class _NavRowState extends State<_NavRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    const radius = BorderRadius.all(Radius.circular(14));
    final index = widget.dragIndex;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: MotionDurations.fast,
          decoration: BoxDecoration(
            color: widget.selected
                ? scheme.surfaceContainerLowest
                : Colors.transparent,
            borderRadius: radius,
            boxShadow: widget.selected ? MorkvaElevation.level1 : null,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: widget.onTap,
              onSecondaryTapUp: widget.onUnpin == null
                  ? null
                  : (d) => _showUnpinMenu(
                      context,
                      d.globalPosition,
                      widget.onUnpin!,
                    ),
              borderRadius: radius,
              hoverColor: scheme.surfaceContainerLowest.withValues(alpha: 0.55),
              child: Semantics(
                selected: widget.selected,
                button: true,
                child: SizedBox(
                  height: 44,
                  child: Padding(
                    padding: const EdgeInsets.only(left: Spacing.xs, right: 6),
                    child: Row(
                      children: [
                        widget.leading,
                        const SizedBox(width: Spacing.sm),
                        Expanded(
                          child: Text(
                            widget.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: widget.selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                        if (index != null && _hovered)
                          ReorderableDragStartListener(
                            index: index,
                            child: MouseRegion(
                              cursor: SystemMouseCursors.grab,
                              child: Tooltip(
                                message: 'Drag to reorder',
                                child: Icon(
                                  Icons.drag_indicator_rounded,
                                  size: 18,
                                  color: scheme.outline,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A 52px square rail button; [selected] raises it, [marker] adds the carrot
/// bar at the rail's edge.
class _RailButton extends StatelessWidget {
  const _RailButton({
    required this.tooltip,
    required this.onTap,
    required this.child,
    this.selected = false,
    this.marker = false,
    this.onSecondaryTap,
  });

  final String tooltip;
  final VoidCallback onTap;
  final Widget child;
  final bool selected;
  final bool marker;
  final ValueChanged<Offset>? onSecondaryTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const radius = BorderRadius.all(Radius.circular(16));
    return SizedBox(
      width: ShellSidebar.railWidth,
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (marker)
            Positioned(
              left: 0,
              child: Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: const BorderRadius.horizontal(
                    right: Radius.circular(3),
                  ),
                ),
              ),
            ),
          Tooltip(
            message: tooltip,
            preferBelow: false,
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: selected ? scheme.surfaceContainerLowest : null,
                borderRadius: radius,
                boxShadow: selected ? MorkvaElevation.level1 : null,
              ),
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: onTap,
                  onSecondaryTapUp: onSecondaryTap == null
                      ? null
                      : (d) => onSecondaryTap!(d.globalPosition),
                  borderRadius: radius,
                  child: Semantics(
                    label: tooltip,
                    selected: selected || marker,
                    button: true,
                    child: Center(child: child),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The bottom profile block: avatar, name, sync status and the settings
/// button.
class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.user,
    required this.settingsSelected,
    required this.onSettings,
  });

  final AuthUser? user;
  final bool settingsSelected;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final name = user?.displayName?.trim();
    return Padding(
      padding: const EdgeInsets.only(left: Spacing.xxs),
      child: Row(
        children: [
          UserAvatar(user: user),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (name == null || name.isEmpty) ? (user?.email ?? '') : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge,
                ),
                const SyncStatusIndicator(dense: true),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Settings',
            isSelected: settingsSelected,
            onPressed: onSettings,
            style: IconButton.styleFrom(
              foregroundColor: scheme.onSurfaceVariant,
              backgroundColor: settingsSelected
                  ? scheme.surfaceContainerLowest
                  : null,
            ),
            icon: const Icon(Icons.tune_rounded),
          ),
        ],
      ),
    );
  }
}

/// The user's initials on a leaf disc; [showSync] adds a status dot.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    this.user,
    this.size = 34,
    this.showSync = false,
    this.dotRing,
  });

  final AuthUser? user;
  final double size;
  final bool showSync;

  /// The dot's ring colour: the surface the avatar sits on.
  final Color? dotRing;

  /// "Olena Kovalenko" → "OK"; falls back to the email's first letter.
  static String initialsOf(AuthUser? user) {
    final parts = (user?.displayName ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isNotEmpty) {
      return parts.take(2).map((p) => p[0]).join().toUpperCase();
    }
    final email = user?.email ?? '';
    return email.isEmpty ? '?' : email[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final disc = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.secondary,
        shape: BoxShape.circle,
      ),
      child: Text(
        initialsOf(user),
        style: theme.textTheme.labelLarge?.copyWith(
          color: scheme.onSecondary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    if (!showSync) return disc;
    final semantic = theme.extension<MorkvaSemanticColors>()!;
    return BlocBuilder<SyncStatusCubit, SyncStatus>(
      builder: (context, status) {
        final dot = switch (status) {
          SyncUnknown() => null,
          SyncSynced() => semantic.success,
          SyncPending() => semantic.info,
          SyncOffline() => scheme.outline,
          SyncConflict() => semantic.warning,
          SyncError() => scheme.error,
        };
        if (dot == null) return disc;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            disc,
            Positioned(
              right: -1,
              bottom: -1,
              child: Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  color: dot,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: dotRing ?? scheme.surfaceContainer,
                    width: 2,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The Jump to shortcut as the keyboard prints it; null on phones and
/// tablets (Android, iOS), where a hardware keyboard is the exception.
String? get jumpShortcutLabel => switch (defaultTargetPlatform) {
  TargetPlatform.macOS => '⌘ K',
  TargetPlatform.android || TargetPlatform.iOS => null,
  _ => 'Ctrl K',
};
