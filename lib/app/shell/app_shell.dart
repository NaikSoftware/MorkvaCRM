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
                      padding: const EdgeInsets.only(
                        top: Spacing.sm,
                        bottom: Spacing.lg,
                        left: Spacing.xs,
                        right: Spacing.xs,
                      ),
                      child: Align(
                        alignment:
                            extended ? Alignment.centerLeft : Alignment.center,
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
                  _PageHeader(title: title),
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
            _PageHeader(title: title),
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
/// A hairline bottom border separates it from the content — no shadow, no band.
class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Text(title, style: theme.textTheme.titleLarge),
    );
  }
}
