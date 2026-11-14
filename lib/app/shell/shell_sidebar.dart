import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../api/auth/auth_user.dart';
import '../../api/sync/sync_status.dart';
import '../../api/sync/sync_status_cubit.dart';
import '../../core/domain/domain.dart';
import '../../design/design.dart';
import '../../features/assistant/view/widgets/sparkle_icon.dart';
import '../../features/automation/widgets/run_indicator.dart';
import '../../l10n/l10n.dart';
import 'brand_wordmark.dart';
import 'inbox_count.dart';
import 'sync_status_indicator.dart';

/// Where the user is, as far as the navigation is concerned.
enum ShellPlace { allCollections, automations, collection, inbox, settings }

/// The wide-screen navigation: the brand, "Jump to…", the Ask Morkva toggle,
/// All collections, the pinned collections and the profile row with
/// settings. [extended] false is the slim icon rail.
///
/// Dumb: everything comes in as data and goes out through callbacks.
class ShellSidebar extends StatelessWidget {
  const ShellSidebar({
    super.key,
    required this.extended,
    required this.place,
    required this.pinned,
    required this.onAllCollections,
    required this.onToggleExtended,
    required this.onCollection,
    required this.onSettings,
    required this.onJumpTo,
    required this.onUnpin,
    required this.onReorder,
    this.collectionId,
    this.user,
    this.onAssistant,
    this.assistantOpen = false,
    this.onAutomations,
    this.onInbox,
  });

  final bool extended;
  final ShellPlace place;

  /// The open collection's id when [place] is [ShellPlace.collection].
  final String? collectionId;

  /// The pinned collections, in pin order.
  final List<Collection> pinned;
  final AuthUser? user;

  final VoidCallback onAllCollections;

  /// The logo: collapses the full sidebar to the rail, or expands the rail.
  final VoidCallback onToggleExtended;
  final ValueChanged<String> onCollection;
  final VoidCallback onSettings;
  final VoidCallback onJumpTo;
  final ValueChanged<String> onUnpin;

  /// Moves the pin at `oldIndex` of [pinned] to `newIndex` (the index in the
  /// list without it, as [ReorderableListView.onReorderItem] reports).
  final void Function(int oldIndex, int newIndex) onReorder;

  /// Toggles the Ask Morkva panel; null hides the entry (feature off).
  final VoidCallback? onAssistant;

  /// The panel is open: the toggle is carrot-tinted (never "selected").
  final bool assistantOpen;

  /// Opens the Automations page; null hides the entry.
  final VoidCallback? onAutomations;

  /// Opens the Inbox; null hides the entry.
  final VoidCallback? onInbox;

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
    final l10n = context.l10n;
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
              child: BrandWordmark(
                onTap: onToggleExtended,
                tooltip: l10n.shellCollapseSidebar,
              ),
            ),
          ),
          _JumpField(onTap: onJumpTo),
          if (onAssistant case final onAssistant?) ...[
            const SizedBox(height: Spacing.xs),
            _AskButton(open: assistantOpen, onTap: onAssistant),
          ],
          const SizedBox(height: Spacing.xs),
          if (onInbox case final onInbox?)
            _NavRow(
              label: l10n.inboxTitle,
              selected: place == ShellPlace.inbox,
              leading: const _ToolTile(Icons.inbox_rounded),
              trailing: const _InboxPill(),
              onTap: onInbox,
            ),
          _NavRow(
            label: l10n.shellAllCollections,
            selected: _allSelected,
            leading: _AllTile(size: 28, selected: true),
            onTap: onAllCollections,
          ),
          if (onAutomations case final onAutomations?)
            _NavRow(
              label: l10n.commonAutomations,
              selected: place == ShellPlace.automations,
              leading: const _ToolTile(Icons.bolt_rounded),
              trailing: const RunIndicatorPill(),
              onTap: onAutomations,
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.sm,
              Spacing.md,
              Spacing.xxs,
              Spacing.xxs,
            ),
            child: Text(l10n.shellPinnedHeader, style: _capStyle(theme)),
          ),
          Expanded(
            child: pinned.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Spacing.sm,
                      vertical: Spacing.xxs,
                    ),
                    child: Text(
                      l10n.shellPinnedEmpty,
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
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.md),
      child: Column(
        children: [
          Tooltip(
            message: l10n.shellExpandSidebar,
            child: InkWell(
              onTap: onToggleExtended,
              borderRadius: Radii.mdAll,
              child: const BrandLogomark(size: 40),
            ),
          ),
          const SizedBox(height: Spacing.sm),
          _RailButton(
            tooltip: switch (jumpShortcutLabel) {
              final shortcut? => l10n.shellJumpToShortcut(shortcut),
              null => l10n.shellJumpTo,
            },
            onTap: onJumpTo,
            child: Icon(Icons.search_rounded, color: scheme.onSurfaceVariant),
          ),
          if (onAssistant case final onAssistant?)
            _RailButton(
              tooltip: switch (assistantShortcutLabel) {
                final shortcut? => l10n.shellAskMorkvaShortcut(shortcut),
                null => l10n.shellAskMorkva,
              },
              toggled: assistantOpen,
              onTap: onAssistant,
              child: SparkleIcon(
                size: 22,
                color: assistantOpen
                    ? Theme.of(
                        context,
                      ).extension<MorkvaSemanticColors>()!.primaryText
                    : scheme.onSurfaceVariant,
              ),
            ),
          if (onInbox case final onInbox?)
            _RailButton(
              tooltip: context.l10n.inboxTitle,
              selected: place == ShellPlace.inbox,
              onTap: onInbox,
              child: InboxBadgeIcon(
                icon: Icon(
                  Icons.inbox_rounded,
                  color: place == ShellPlace.inbox
                      ? scheme.onPrimaryContainer
                      : scheme.onSurfaceVariant,
                ),
              ),
            ),
          _RailButton(
            tooltip: l10n.shellAllCollections,
            selected: _allSelected,
            onTap: onAllCollections,
            child: _AllTile(size: 36, selected: _allSelected),
          ),
          if (onAutomations case final onAutomations?)
            _RailButton(
              tooltip: l10n.commonAutomations,
              selected: place == ShellPlace.automations,
              onTap: onAutomations,
              child: RunIndicatorRailIcon(
                color: place == ShellPlace.automations
                    ? scheme.onPrimaryContainer
                    : scheme.onSurfaceVariant,
              ),
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
            tooltip: l10n.commonSettings,
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
    items: [
      PopupMenuItem(
        value: true,
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.push_pin_outlined),
          title: Text(context.l10n.shellUnpin),
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

/// The Inbox and Automations rows' [icon] tile.
class _ToolTile extends StatelessWidget {
  const _ToolTile(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28 * 0.3),
      ),
      child: Icon(icon, size: 18, color: scheme.onPrimaryContainer),
    );
  }
}

/// The Inbox row's count pill; none at 0.
class _InboxPill extends StatelessWidget {
  const _InboxPill();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InboxCountBuilder(
      builder: (context, count) => count == 0
          ? const SizedBox.shrink()
          : Container(
              height: 24,
              constraints: const BoxConstraints(minWidth: 24),
              padding: const EdgeInsets.symmetric(horizontal: Spacing.xs),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: Radii.fullAll,
              ),
              child: Text(
                '$count',
                semanticsLabel: context.l10n.inboxDueCount(count),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
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
                Expanded(child: Text(context.l10n.shellJumpTo, style: muted)),
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

/// The Ask Morkva toggle under "Jump to…": carrot-tinted while the panel is
/// [open], with its shortcut hint.
class _AskButton extends StatelessWidget {
  const _AskButton({required this.open, required this.onTap});

  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final semantic = theme.extension<MorkvaSemanticColors>()!;
    final ink = open ? scheme.onPrimaryContainer : scheme.onSurface;
    return Semantics(
      container: true,
      button: true,
      toggled: open,
      child: Material(
        color: open ? scheme.primaryContainer : Colors.transparent,
        borderRadius: Radii.mdAll,
        child: InkWell(
          onTap: onTap,
          borderRadius: Radii.mdAll,
          hoverColor: open
              ? null
              : scheme.surfaceContainerLowest.withValues(alpha: 0.55),
          child: SizedBox(
            height: 44,
            child: Padding(
              padding: const EdgeInsets.only(
                left: Spacing.sm,
                right: Spacing.xs,
              ),
              child: Row(
                children: [
                  SparkleIcon(size: 18, color: semantic.primaryText),
                  const SizedBox(width: Spacing.xs),
                  Expanded(
                    child: Text(
                      context.l10n.shellAskMorkva,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (assistantShortcutLabel case final shortcut?)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: open
                              ? scheme.primary.withValues(alpha: 0.45)
                              : scheme.outlineVariant,
                        ),
                      ),
                      child: Text(
                        shortcut,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: open ? ink : scheme.onSurfaceVariant,
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
    this.trailing,
    this.dragIndex,
    this.onUnpin,
  });

  final String label;
  final bool selected;
  final Widget leading;
  final Widget? trailing;
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
                        ?widget.trailing,
                        if (index != null && _hovered)
                          ReorderableDragStartListener(
                            index: index,
                            child: MouseRegion(
                              cursor: SystemMouseCursors.grab,
                              child: Tooltip(
                                message: context.l10n.shellDragToReorder,
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
    this.toggled,
    this.onSecondaryTap,
  });

  final String tooltip;
  final VoidCallback onTap;
  final Widget child;
  final bool selected;
  final bool marker;

  /// A toggle's state (Ask Morkva): on = the carrot tint.
  final bool? toggled;
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
                color: toggled ?? false
                    ? scheme.primaryContainer
                    : selected
                    ? scheme.surfaceContainerLowest
                    : null,
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
                    toggled: toggled,
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
            tooltip: context.l10n.commonSettings,
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
String? get jumpShortcutLabel => _shortcutLabel('K');

/// The Ask Morkva toggle's shortcut, like [jumpShortcutLabel].
String? get assistantShortcutLabel => _shortcutLabel('J');

String? _shortcutLabel(String key) => switch (defaultTargetPlatform) {
  TargetPlatform.macOS => '⌘ $key',
  TargetPlatform.android || TargetPlatform.iOS => null,
  _ => 'Ctrl $key',
};
