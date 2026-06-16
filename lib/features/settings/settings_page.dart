import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../api/auth/auth_cubit.dart';
import '../../design/design.dart';

/// Placeholder settings surface — proves the second navigation destination and
/// hosts the sign-out affordance. Real preferences land in a later epic.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Spacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Expanded(
            child: EmptyState(
              icon: Icons.tune_outlined,
              title: 'Settings',
              message: 'Workspace and account settings will live here.',
            ),
          ),
          SecondaryButton(
            label: 'Sign out',
            icon: Icons.logout_rounded,
            onPressed: () => context.read<AuthCubit>().signOut(),
          ),
        ],
      ),
    );
  }
}
