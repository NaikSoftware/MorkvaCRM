import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../api/auth/auth_cubit.dart';
import '../../design/design.dart';
import '../automation/widgets/run_indicator.dart';
import 'import/trello_import_sheet.dart';

/// Settings: the workspace's Automations entry (the phone's way in; wide
/// layouts also have it in the sidebar), imports from other apps and
/// sign-out, in a 720 px column.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sky = (theme.brightness == Brightness.light
        ? CollectionTints.light
        : CollectionTints.dark)[2];
    return Padding(
      padding: const EdgeInsets.all(Spacing.lg),
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _SectionLabel('Workspace'),
              ListTileCard(
                title: 'Automations',
                subtitle: 'Modules, buttons and runs',
                leading: _Tile(
                  icon: Icons.bolt_rounded,
                  background: scheme.primaryContainer,
                  foreground: scheme.onPrimaryContainer,
                ),
                trailing: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RunIndicatorPill(),
                    Icon(Icons.chevron_right_rounded),
                  ],
                ),
                onTap: () => context.go('/automations'),
              ),
              const SizedBox(height: Spacing.lg),
              const _SectionLabel('Import from other apps'),
              ListTileCard(
                title: 'Trello',
                subtitle:
                    'Boards become collections — lists, cards, labels, '
                    'checklists and comments',
                leading: _Tile(
                  icon: Icons.view_kanban_outlined,
                  background: sky.background,
                  foreground: sky.foreground,
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () async {
                  final to = await showTrelloImportSheet(context);
                  if (to != null && context.mounted) context.go(to);
                },
              ),
              const Spacer(),
              Center(
                child: SecondaryButton(
                  label: 'Sign out',
                  icon: Icons.logout_rounded,
                  onPressed: () => context.read<AuthCubit>().signOut(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.xxs, 0, 0, Spacing.xs),
      child: Semantics(
        header: true,
        child: Text(
          text.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.9,
          ),
        ),
      ),
    );
  }
}

/// A row's 40 px icon tile.
class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Container(
    width: 40,
    height: 40,
    decoration: BoxDecoration(color: background, borderRadius: Radii.mdAll),
    child: Icon(icon, size: 20, color: foreground),
  );
}
