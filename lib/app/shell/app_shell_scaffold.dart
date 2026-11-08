import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../api/api.dart';
import '../../core/domain/domain.dart';
import '../../design/design.dart';
import '../../features/auth/conflict_warning_banner.dart';
import '../../features/collections/collections.dart';
import 'app_shell.dart';
import 'brand_wordmark.dart';
import 'jump_to_dialog.dart';
import 'shell_sidebar.dart';

/// The persistent shell around every page of the app's [ShellRoute].
///
/// Owns the workspace's [CollectionsListCubit] and [PinnedCollectionsCubit]
/// (shared by the sidebar and the All collections page) and wires the dumb
/// [AppShell] / [ShellSidebar] to the router: what's selected comes from the
/// location, taps navigate. Built once, so the sidebar never rebuilds
/// between pages.
class AppShellScaffold extends StatelessWidget {
  const AppShellScaffold({
    super.key,
    required this.child,
    this.collectionId,
    this.inSettings = false,
  });

  /// The routed page (the shell's navigator).
  final Widget child;

  /// The open collection, when a collection page is shown. It draws its own
  /// header and banner (wide) or its own full-screen app bar (phone).
  final String? collectionId;

  /// The settings page is shown.
  final bool inSettings;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) =>
              CollectionsListCubit(context.read<DataRepository>())
                ..initialize(),
        ),
        BlocProvider(create: (_) => SidebarExtendedCubit()),
        BlocProvider(
          create: (context) =>
              PinnedCollectionsCubit(context.read<DataRepository>())
                ..initialize(),
        ),
      ],
      child: _ShellView(
        collectionId: collectionId,
        inSettings: inSettings,
        child: child,
      ),
    );
  }
}

class _ShellView extends StatelessWidget {
  const _ShellView({
    required this.child,
    required this.collectionId,
    required this.inSettings,
  });

  final Widget child;
  final String? collectionId;
  final bool inSettings;

  ShellPlace get _place => collectionId != null
      ? ShellPlace.collection
      : inSettings
      ? ShellPlace.settings
      : ShellPlace.allCollections;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CollectionsListCubit>().state;
    final collections = state is CollectionsListReady
        ? state.collections
        : const <Collection>[];
    final pins = context.watch<PinnedCollectionsCubit>();
    final pinned = pinnedCollections(pins.state, collections);
    final authState = context.watch<AuthCubit>().state;
    final user = authState is AuthAuthenticated ? authState.user : null;
    final router = GoRouter.of(context);

    void openAll() => router.go('/');
    void openSettings() => router.go('/settings');
    void openCollection(String id) => router.go('/collections/$id');
    Future<void> jumpTo() async {
      final rest = [
        for (final c in collections)
          if (!pinned.contains(c)) c,
      ];
      final id = await showJumpToDialog(context, [...pinned, ...rest]);
      if (id != null) openCollection(id);
    }

    final place = _place;
    final wide =
        MediaQuery.sizeOf(context).width >= AppShell.expandedBreakpoint;
    final inCollection = place == ShellPlace.collection;
    return _JumpShortcut(
      onJump: jumpTo,
      child: AppShell(
        extended: context.watch<SidebarExtendedCubit>().state,
        sidebarBuilder: (context, extended) => ShellSidebar(
          extended: extended,
          place: place,
          collectionId: collectionId,
          pinned: pinned,
          user: user,
          onAllCollections: openAll,
          onToggleExtended: () =>
              context.read<SidebarExtendedCubit>().set(!extended),
          onCollection: openCollection,
          onSettings: openSettings,
          onJumpTo: jumpTo,
          onUnpin: pins.unpin,
          onReorder: (from, to) =>
              pins.reorder([for (final c in pinned) c.id], from, to),
        ),
        title: inSettings ? 'Settings' : 'Collections',
        // Wide, All collections draws its own header; a collection always
        // does.
        header: inCollection || (wide && place == ShellPlace.allCollections)
            ? const SizedBox.shrink()
            : null,
        // Wide, the sidebar is the way back and carries the brand.
        headerLeading: wide
            ? null
            : inSettings
            ? BackButton(onPressed: openAll)
            : const BrandLogomark(size: 34),
        headerTrailing: inSettings
            ? null
            : Tooltip(
                message: 'Account and settings',
                child: InkResponse(
                  onTap: openSettings,
                  radius: 22,
                  child: Padding(
                    padding: const EdgeInsets.all(5),
                    child: UserAvatar(
                      user: user,
                      showSync: true,
                      dotRing: Theme.of(context).colorScheme.surface,
                    ),
                  ),
                ),
              ),
        bottomBar: place == ShellPlace.allCollections && pinned.isNotEmpty
            ? _PinsBar(pinned: pinned, onCollection: openCollection)
            : null,
        banner: inCollection ? null : const ConflictWarningBanner(),
        showCompactChrome: !inCollection,
        child: child,
      ),
    );
  }
}

/// Ctrl/Cmd K anywhere in the shell runs [onJump]. A global key handler, not
/// [Shortcuts], so it works when nothing has focus (e.g. after a click).
class _JumpShortcut extends StatefulWidget {
  const _JumpShortcut({required this.onJump, required this.child});

  final Future<void> Function() onJump;
  final Widget child;

  @override
  State<_JumpShortcut> createState() => _JumpShortcutState();
}

class _JumpShortcutState extends State<_JumpShortcut> {
  bool _open = false;

  bool _onKey(KeyEvent event) {
    final keys = HardwareKeyboard.instance;
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.keyK ||
        !(keys.isControlPressed || keys.isMetaPressed)) {
      return false;
    }
    // Only from the shell itself: not over a dialog or a full-screen route.
    if (_open || !(ModalRoute.of(context)?.isCurrent ?? true)) return false;
    _open = true;
    widget.onJump().whenComplete(() => _open = false);
    return true;
  }

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Phone: the first three pins plus All collections (the current page).
class _PinsBar extends StatelessWidget {
  const _PinsBar({required this.pinned, required this.onCollection});

  final List<Collection> pinned;
  final ValueChanged<String> onCollection;

  @override
  Widget build(BuildContext context) {
    final shown = pinned.take(3).toList();
    return NavigationBar(
      selectedIndex: shown.length,
      onDestinationSelected: (i) {
        if (i < shown.length) onCollection(shown[i].id);
      },
      destinations: [
        for (final c in shown)
          NavigationDestination(
            icon: Icon(CollectionIcons.byKey(c.icon)),
            label: c.name,
          ),
        const NavigationDestination(
          icon: Icon(Icons.grid_view_rounded),
          label: 'All',
        ),
      ],
    );
  }
}

/// The user's sidebar choice from the logo: true = full sidebar, false =
/// rail, null = by window width.
// shortcut: kept for the session only; persist it if people ask.
class SidebarExtendedCubit extends Cubit<bool?> {
  SidebarExtendedCubit() : super(null);

  void set(bool extended) => emit(extended);
}
