import 'package:flutter/material.dart';

import '../../design/design.dart';

/// Responsive scaffold that frames every routed page.
///
/// Dumb by design: the parent supplies the navigation as widgets and the shell
/// only decides how to *present* them based on available width.
///
/// Layout (single breakpoint per `DESIGN.md` §8):
/// - `>= 840`: a full-height sidebar ([sidebarBuilder]; a slim rail below
///   `1240`, the full sidebar at/above) beside the content. The page title
///   lives in a slim header **over the content**. A side panel (Ask Morkva)
///   pushes the page from the right at `>= 1280` beside the full sidebar,
///   else it is a sheet over the page behind a scrim.
/// - `< 840`: the same content header on top of the body, with [bottomBar]
///   (if any) under it; no side panel (the phone has its own route).
class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.sidebarBuilder,
    required this.title,
    required this.child,
    this.bottomBar,
    this.headerLeading,
    this.headerTrailing,
    this.banner,
    this.header,
    this.showCompactChrome = true,
    this.extended,
    this.sidePanelBuilder,
    this.onDismissSidePanel,
  });

  /// Builds the sidebar for the expanded layout; `extended` is false for the
  /// slim rail.
  final Widget Function(BuildContext context, bool extended) sidebarBuilder;

  /// Current page title, shown in the content header.
  final String title;

  /// The routed page body.
  final Widget child;

  /// Compact layout only: the bottom navigation, or null for none.
  final Widget? bottomBar;

  /// Optional widget before the title in the content header (a back button,
  /// the brand mark).
  final Widget? headerLeading;

  /// Optional trailing widget at the right of the content header.
  final Widget? headerTrailing;

  /// Optional full-width banner mounted directly above the content body, below
  /// the header (e.g. a conflict warning). Self-hiding widgets are safe to pass
  /// permanently — they render nothing when there is nothing to show.
  final Widget? banner;

  /// Replaces the slim title header (and [title] / [headerLeading] /
  /// [headerTrailing]) with a page's own header.
  final Widget? header;

  /// Compact layout only: false drops the shell (header, banner, bottom bar
  /// and its Scaffold), so a page with its own full-screen Scaffold (a
  /// collection) owns the screen.
  final bool showCompactChrome;

  /// Wide layouts only: forces the full sidebar (true) or the rail (false);
  /// null picks by width ([extendedRailBreakpoint]).
  final bool? extended;

  /// Wide layouts only: the open side panel; `overlay` is true when it is a
  /// sheet over the page ([pushesSidePanel] false). Null = closed.
  final Widget Function(BuildContext context, bool overlay)? sidePanelBuilder;

  /// A tap on the overlay's scrim.
  final VoidCallback? onDismissSidePanel;

  /// Width at/above which the expanded sidebar layout is used (`DESIGN.md` §8).
  static const double expandedBreakpoint = 840;

  /// Width at/above which the full sidebar replaces the slim rail.
  static const double extendedRailBreakpoint = 1240;

  /// Window width at/above which the side panel sits beside the page.
  static const double sidePanelPushBreakpoint = 1280;

  /// Whether a side panel pushes the page at [width] (beside the full
  /// sidebar only; [extended] null = by width) rather than covering it.
  static bool pushesSidePanel(double width, {bool? extended}) =>
      width >= sidePanelPushBreakpoint &&
      (extended ?? width >= extendedRailBreakpoint);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isExpanded = constraints.maxWidth >= expandedBreakpoint;
        return isExpanded
            ? _buildExpanded(
                context,
                extended:
                    extended ?? constraints.maxWidth >= extendedRailBreakpoint,
                push: pushesSidePanel(constraints.maxWidth, extended: extended),
              )
            : _buildCompact(context);
      },
    );
  }

  Widget _pageHeader() =>
      header ??
      _PageHeader(
        title: title,
        leading: headerLeading,
        trailing: headerTrailing,
      );

  Widget _buildExpanded(
    BuildContext context, {
    required bool extended,
    required bool push,
  }) {
    final panel = sidePanelBuilder?.call(context, !push);
    final sheet = push ? null : panel;
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            sidebarBuilder(context, extended),
            Expanded(
              // Always a Stack, so opening the panel never remounts the page.
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // The main panel: doodles behind its header and content.
                  // Under the sheet's scrim Tab must not reach it (the
                  // barrier only blocks the pointer); the sidebar stays.
                  ExcludeFocus(
                    excluding: sheet != null,
                    child: DoodleBackground(
                      child: Column(
                        children: [
                          _pageHeader(),
                          ?banner,
                          Expanded(child: child),
                        ],
                      ),
                    ),
                  ),
                  // A sheet over the page only; the navigation stays usable.
                  if (sheet != null) ...[
                    ModalBarrier(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.32),
                      // Without a handler it would pop the route.
                      dismissible: onDismissSidePanel != null,
                      onDismiss: onDismissSidePanel,
                    ),
                    Positioned(top: 0, right: 0, bottom: 0, child: sheet),
                  ],
                ],
              ),
            ),
            if (push) ?panel,
          ],
        ),
      ),
    );
  }

  Widget _buildCompact(BuildContext context) {
    // No shell Scaffold under a full-screen page: its own Scaffold must be the
    // root one, so snackbars clear its FAB.
    // A bottom-bar tab (a pinned collection) keeps the bar under its page.
    if (!showCompactChrome) {
      return ColoredBox(
        color: Theme.of(context).colorScheme.surface,
        child: Column(
          children: [
            Expanded(child: child),
            ?bottomBar,
          ],
        ),
      );
    }
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _pageHeader(),
            ?banner,
            Expanded(child: DoodleBackground(child: child)),
          ],
        ),
      ),
      bottomNavigationBar: bottomBar,
    );
  }
}

/// A slim header over the content area: an optional [leading], the page
/// [title], and an optional [trailing] control, on the `lg` content gutter.
class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.title, this.leading, this.trailing});

  final String title;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.md,
        vertical: Spacing.sm,
      ),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: Spacing.sm)],
          Expanded(child: Text(title, style: theme.textTheme.headlineSmall)),
          if (trailing != null) ...[
            const SizedBox(width: Spacing.md),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// Tells the routed page whether it is a phone bottom-bar tab: such a page
/// shows no back button and appears without a push transition. [onAsk]
/// opens Ask Morkva from a page that draws its own phone header (null: no
/// entry there).
class ShellTab extends InheritedWidget {
  const ShellTab({
    super.key,
    required this.isTab,
    this.onAsk,
    required super.child,
  });

  final bool isTab;
  final VoidCallback? onAsk;

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellTab>()?.isTab ?? false;

  static VoidCallback? askOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellTab>()?.onAsk;

  @override
  bool updateShouldNotify(ShellTab oldWidget) =>
      oldWidget.isTab != isTab || oldWidget.onAsk != onAsk;
}
