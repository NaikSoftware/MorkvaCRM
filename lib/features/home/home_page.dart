import 'package:flutter/material.dart';

import '../../design/design.dart';

/// The home surface — where collections will be listed (Epic 3+). For now it
/// shows the empty workspace state so the themed shell has real content.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.dashboard_customize_outlined,
      title: 'No collections yet',
      message:
          'Collections hold your cards — orders, clients, inventory, anything. '
          'Create your first one to start organizing your work.',
      actionLabel: 'New collection',
      onAction: () {
        // Collection creation arrives in Epic 3.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Creating collections comes in a later update')),
        );
      },
    );
  }
}
