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
///   lives in a slim header **over the content**.
/// - `< 840`: the same content header on top of the body, with [bottomBar]
///   (if any) under it.
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

  /// Width at/above which the expanded sidebar layout is used (`DESIGN.md` §8).
  static const double expandedBreakpoint = 840;

  /// Width at/above which the full sidebar replaces the slim rail.
  static const double extendedRailBreakpoint = 1240;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isExpanded = constraints.maxWidth >= expandedBreakpoint;
        return isExpanded
            ? _buildExpanded(
                context,
                extended: constraints.maxWidth >= extendedRailBreakpoint,
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

  Widget _buildExpanded(BuildContext context, {required bool extended}) {
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            sidebarBuilder(context, extended),
            // The main panel: doodles behind its header and content.
            Expanded(
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
          ],
        ),
      ),
    );
  }

  Widget _buildCompact(BuildContext context) {
    // No shell Scaffold under a full-screen page: its own Scaffold must be the
    // root one, so snackbars clear its FAB.
    if (!showCompactChrome) {
      return ColoredBox(
        color: Theme.of(context).colorScheme.surface,
        child: child,
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
