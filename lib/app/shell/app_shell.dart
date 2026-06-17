import 'package:flutter/material.dart';

import '../../design/design.dart';
import '../navigation/navigation_cubit.dart';

/// Responsive scaffold that frames every routed page.
///
/// Dumb by design: it owns no navigation state. The parent supplies the
/// [destinations], the [selectedIndex], and an [onDestinationSelected] callback,
/// and the shell decides only how to *present* them based on available width.
///
/// Layout (single breakpoint per `DESIGN.md` §8):
/// - `>= 840`: a **full-height** [NavigationRail] (extended at `>= 1240`) beside
///   the content. The page title lives in a slim header **over the content**,
///   never as a full-width band above the rail.
/// - `< 840`: the same content header on top of the body, with a bottom
///   [NavigationBar].
///
/// The themed rail, bar, and surfaces style themselves from [AppTheme].
class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    required this.title,
    required this.child,
    this.railHeaderBuilder,
    this.headerTrailing,
    this.banner,
  });

  /// Index into [destinations] of the active section.
  final int selectedIndex;

  /// Called with the tapped destination's index.
  final ValueChanged<int> onDestinationSelected;

  /// Sections to render, in display order.
  final List<AppSection> destinations;

  /// Current page title, shown in the content header.
  final String title;

  /// The routed page body.
  final Widget child;

  /// Optional header for the [NavigationRail] (e.g. a brand wordmark). Receives
  /// whether the rail is currently `extended` so it can adapt (full wordmark vs.
  /// compact mark). Only used in the expanded layout — the compact layout has no
  /// rail.
  final Widget Function(BuildContext context, bool extended)? railHeaderBuilder;

  /// Optional trailing widget pinned to the right of the content header (e.g. a
  /// sync-status indicator). Shown in both layouts so it stays visible on every
  /// main screen.
  final Widget? headerTrailing;

  /// Optional full-width banner mounted directly above the content body, below
  /// the header (e.g. a conflict warning). Self-hiding widgets are safe to pass
  /// permanently — they render nothing when there is nothing to show.
  final Widget? banner;

  /// Width at/above which the expanded rail layout is used (`DESIGN.md` §8).
  static const double expandedBreakpoint = 840;

  /// Width at/above which the rail is shown extended (labels beside icons).
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

  Widget _buildExpanded(BuildContext context, {required bool extended}) {
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            NavigationRail(
              extended: extended,
              selectedIndex: selectedIndex,
              onDestinationSelected: onDestinationSelected,
              leading: railHeaderBuilder == null
                  ? null
                  : Padding(
                      // Generous top breathing room so the brand isn't cramped
                      // against the rail's top edge, an equal gap (lg) down to
                      // the first destination, and a left inset that lines the
                      // wordmark up with the destination icons when extended.
                      padding: EdgeInsets.only(
                        top: Spacing.lg,
                        bottom: Spacing.lg,
                        left: extended ? Spacing.md : Spacing.xs,
                        right: Spacing.xs,
                      ),
                      child: Align(
                        alignment: extended
                            ? Alignment.centerLeft
                            : Alignment.center,
                        child: railHeaderBuilder!(context, extended),
                      ),
                    ),
              labelType: extended
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.all,
              destinations: [
                for (final section in destinations)
                  NavigationRailDestination(
                    icon: Icon(section.icon),
                    label: Text(section.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: Column(
                children: [
                  _PageHeader(title: title, trailing: headerTrailing),
                  ?banner,
                  Expanded(child: child),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompact(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _PageHeader(title: title, trailing: headerTrailing),
            ?banner,
            Expanded(child: child),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected,
        destinations: [
          for (final section in destinations)
            NavigationDestination(
              icon: Icon(section.icon),
              label: section.label,
            ),
        ],
      ),
    );
  }
}

/// A slim header that sits over the content area: the page [title] on the left
/// and room for page-level actions on the right (added by feature pages later).
///
/// The title is vertically centered by symmetric token padding (`md`) rather
/// than a fixed pixel height, so the band keeps the spacing rhythm and grows
/// gracefully once an action control is added. Horizontal padding is the `lg`
/// content gutter so the title aligns with page content. A single hairline
/// bottom border in `outlineVariant` separates it from the content — matching
/// the rail/content [VerticalDivider] in weight and color — no shadow, no band.
class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.title, this.trailing});

  final String title;

  /// Optional control pinned to the right edge of the header (e.g. the sync
  /// status indicator).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.lg,
        vertical: Spacing.md,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          Expanded(child: Text(title, style: theme.textTheme.titleLarge)),
          if (trailing != null) ...[
            const SizedBox(width: Spacing.md),
            trailing!,
          ],
        ],
      ),
    );
  }
}
