import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/home/home_page.dart';
import '../../features/settings/settings_page.dart';
import '../navigation/navigation_cubit.dart';
import 'app_shell.dart';
import 'brand_wordmark.dart';

/// Connects [NavigationCubit] (the selection source of truth) to the dumb
/// [AppShell]. The cubit drives which destination is active; tapping a
/// destination reports back through [NavigationCubit.select]. The selected
/// section's page is shown via an [IndexedStack] so each page keeps its state.
///
/// Per-section deep-link URLs arrive in Epic 3 alongside real collection routes;
/// here go_router hosts the shell at `/`.
class AppShellScaffold extends StatelessWidget {
  const AppShellScaffold({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NavigationCubit, AppSection>(
      builder: (context, section) {
        final index = kAppSections.indexOf(section);
        return AppShell(
          selectedIndex: index,
          destinations: kAppSections,
          // App bar shows the current page; the brand lives in the rail header.
          title: section.label,
          railHeaderBuilder: (context, extended) =>
              BrandWordmark(extended: extended),
          onDestinationSelected: (i) =>
              context.read<NavigationCubit>().select(kAppSections[i]),
          child: IndexedStack(
            index: index,
            children: const [HomePage(), SettingsPage()],
          ),
        );
      },
    );
  }
}
