import 'package:flutter/material.dart';

import '../navigation/navigation_cubit.dart';

/// Responsive scaffold that frames every routed page.
///
/// Dumb by design: it owns no navigation state. The parent supplies the
/// [destinations], the [selectedIndex], and an [onDestinationSelected] callback,
/// and the shell decides only how to *present* them based on available width.
///
/// Layout (single breakpoint per `DESIGN.md` §8):
/// - `>= 840`: [NavigationRail] (extended at `>= 1240`) beside the body.
/// - `< 840`: bottom [NavigationBar].
///
/// The themed [AppBar], rail, and bar style themselves from [AppTheme] — this
/// widget intentionally does no restyling.
class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    required this.title,
    required this.child,
  });

  /// Index into [destinations] of the active section.
  final int selectedIndex;

  /// Called with the tapped destination's index.
  final ValueChanged<int> onDestinationSelected;

  /// Sections to render, in display order.
  final List<AppSection> destinations;

  /// Title shown in the [AppBar].
  final String title;

  /// The routed page body.
  final Widget child;

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
    // A single Scaffold (no nesting) so safe-area insets are consumed once and
    // the AppBar respects them correctly. The rail sits inside the body Row.
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Row(
        children: [
          NavigationRail(
            extended: extended,
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
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
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _buildCompact(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: child,
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
