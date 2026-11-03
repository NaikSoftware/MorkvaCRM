import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/conflict_warning_banner.dart';
import '../../features/home/home_page.dart';
import '../../features/settings/settings_page.dart';
import '../navigation/navigation_cubit.dart';
import 'app_shell.dart';
import 'brand_wordmark.dart';
import 'sync_status_indicator.dart';

/// The persistent shell around every page of the app's [ShellRoute]: connects
/// [NavigationCubit] (the selection source of truth) to the dumb [AppShell].
/// The cubit drives which destination is active; tapping a destination
/// reports back through [NavigationCubit.select] (and leaves a collection
/// for `/`). Built once, so the rail never rebuilds between pages.
class AppShellScaffold extends StatelessWidget {
  const AppShellScaffold({
    super.key,
    required this.child,
    this.inCollection = false,
  });

  /// The routed page (the shell's navigator).
  final Widget child;

  /// A collection page is shown: it draws its own header and banner (wide)
  /// or its own full-screen app bar (phone), so the shell's are hidden.
  final bool inCollection;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NavigationCubit, AppSection>(
      builder: (context, section) {
        return AppShell(
          // A collection lives under Home.
          selectedIndex: kAppSections.indexOf(
            inCollection ? AppSection.home : section,
          ),
          destinations: kAppSections,
          // App bar shows the current page; the brand lives in the rail header.
          title: section.label,
          railHeaderBuilder: (context, extended) =>
              BrandWordmark(extended: extended),
          // Sync status sits quietly in the header so it's visible on every
          // main screen; the conflict banner self-hides until there's a
          // conflict to surface.
          headerTrailing: const SyncStatusIndicator(),
          header: inCollection ? const SizedBox.shrink() : null,
          banner: inCollection ? null : const ConflictWarningBanner(),
          showCompactChrome: !inCollection,
          onDestinationSelected: (i) {
            context.read<NavigationCubit>().select(kAppSections[i]);
            if (inCollection) context.go('/');
          },
          child: child,
        );
      },
    );
  }
}

/// The `/` page: the selected section's page, via an [IndexedStack] so each
/// keeps its state.
class HomeSections extends StatelessWidget {
  const HomeSections({super.key});

  @override
  Widget build(BuildContext context) {
    final section = context.watch<NavigationCubit>().state;
    return Material(
      type: MaterialType.transparency,
      child: IndexedStack(
        index: kAppSections.indexOf(section),
        children: const [HomePage(), SettingsPage()],
      ),
    );
  }
}
