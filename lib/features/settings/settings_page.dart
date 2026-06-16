import 'package:flutter/material.dart';

import '../../design/design.dart';

/// Placeholder settings surface — proves the second navigation destination.
/// Real preferences land in a later epic.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.tune_outlined,
      title: 'Settings',
      message: 'Workspace and account settings will live here.',
    );
  }
}
