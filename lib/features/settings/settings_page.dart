import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../api/auth/auth_cubit.dart';
import '../../design/design.dart';
import '../automation/widgets/run_indicator.dart';

/// Placeholder settings surface — hosts the Automations entry (the phone's
/// way in; wide layouts also have it in the sidebar) and the sign-out
/// affordance. Real preferences land in a later epic.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(Spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTileCard(
            title: 'Automations',
            subtitle: 'Modules, buttons and runs',
            leading: Icon(Icons.bolt_rounded, color: scheme.onPrimaryContainer),
            trailing: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [RunIndicatorPill(), Icon(Icons.chevron_right_rounded)],
            ),
            onTap: () => context.go('/automations'),
          ),
          const Expanded(
            child: EmptyState(
              icon: Icons.tune_outlined,
              title: 'Settings',
              message: 'Workspace and account settings will live here.',
            ),
          ),
          Center(
            child: SecondaryButton(
              label: 'Sign out',
              icon: Icons.logout_rounded,
              onPressed: () => context.read<AuthCubit>().signOut(),
            ),
          ),
        ],
      ),
    );
  }
}
