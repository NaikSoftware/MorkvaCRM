import 'package:flutter/material.dart' show IconData, Icons;
import 'package:flutter_bloc/flutter_bloc.dart';

/// A top-level destination in the app shell.
///
/// Each section carries its own [label] and [icon] so the navigation UI stays
/// dumb — it just renders what the section describes.
enum AppSection {
  home(label: 'Home', icon: Icons.dashboard_outlined),
  settings(label: 'Settings', icon: Icons.settings_outlined);

  const AppSection({required this.label, required this.icon});

  /// Human-readable label shown in the rail / bar destination.
  final String label;

  /// Material icon shown in the rail / bar destination.
  final IconData icon;
}

/// The ordered list of sections the shell renders, in display order.
const List<AppSection> kAppSections = [AppSection.home, AppSection.settings];

/// Holds the currently selected [AppSection].
///
/// Pure navigation state — no routing or widget concerns live here. The shell
/// reads [state] and reports user taps back via [select].
class NavigationCubit extends Cubit<AppSection> {
  NavigationCubit() : super(AppSection.home);

  /// Selects [section] as the active destination.
  void select(AppSection section) => emit(section);
}
