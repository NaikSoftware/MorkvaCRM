import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../api/auth/auth_cubit.dart';
import '../../app/shell/app_shell.dart';
import '../../design/design.dart';
import '../../l10n/l10n.dart';
import '../automation/view/consent_sheet.dart' show sheetSegmentedStyle;
import '../automation/widgets/run_indicator.dart';
import 'import/trello_import_sheet.dart';
import 'theme_mode_cubit.dart';

/// Settings, ordered by scope: what the workspace shares (its Automations
/// entry — the phone's way in; wide layouts also have it in the sidebar —
/// and imports from other apps), then what is yours on this device (theme,
/// sign-out). Wide, laid out like the Automations page: a centred 1040 px
/// column on a 48 px gutter carrying its own title (the shell draws no
/// header); on a phone, full width on the shell header's 16 px gutter.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.l10n;
    final sky = (theme.brightness == Brightness.light
        ? CollectionTints.light
        : CollectionTints.dark)[2];
    final wide =
        MediaQuery.sizeOf(context).width >= AppShell.expandedBreakpoint;
    final gutter = wide ? Spacing.xxl : Spacing.md;
    // The scroll view spans the page, so the wheel works beside the column.
    return SingleChildScrollView(
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1040 + 2 * Spacing.xxl),
          // Phone: with the shell header's sm bottom padding, a lg gap under
          // its title.
          padding: EdgeInsets.fromLTRB(
            gutter,
            wide ? Spacing.lg : Spacing.sm,
            gutter,
            Spacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (wide) ...[
                ConstrainedBox(
                  // The Automations header's title row height.
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      l10n.commonSettings,
                      style: theme.textTheme.headlineSmall,
                    ),
                  ),
                ),
                const SizedBox(height: Spacing.md),
              ],
              _SectionLabel(l10n.settingsWorkspaceSection),
              ListTileCard(
                title: l10n.commonAutomations,
                subtitle: l10n.settingsAutomationsSubtitle,
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
              _SectionLabel(l10n.settingsImportSection),
              ListTileCard(
                title: 'Trello',
                subtitle: l10n.settingsTrelloSubtitle,
                leading: _Tile(
                  icon: Icons.view_kanban_outlined,
                  background: sky.background,
                  foreground: sky.foreground,
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () async {
                  // Browser Back mid-import leaves Settings while the
                  // sheet stays up; the router outlives this page.
                  final router = GoRouter.of(context);
                  final to = await showTrelloImportSheet(context);
                  if (to != null) router.go(to);
                },
              ),
              const SizedBox(height: Spacing.lg),
              _SectionLabel(l10n.settingsAppearanceSection),
              const _ThemeCard(),
              const SizedBox(height: Spacing.lg),
              _SectionLabel(l10n.settingsAccountSection),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: SecondaryButton(
                  label: l10n.settingsSignOut,
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
      padding: const EdgeInsets.only(bottom: Spacing.xs),
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

/// Theme: Light · Dark · System. The control sits at the row's end, or drops
/// under the title, full width, when the card is narrow (a phone).
class _ThemeCard extends StatelessWidget {
  const _ThemeCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final plum = (theme.brightness == Brightness.light
        ? CollectionTints.light
        : CollectionTints.dark)[3];
    final l10n = context.l10n;
    final mode = context.watch<ThemeModeCubit>().state;
    final picker = SegmentedButton<ThemeMode>(
      segments: [
        ButtonSegment(
          value: ThemeMode.light,
          icon: const Icon(Icons.light_mode_outlined),
          label: Text(l10n.settingsThemeLight),
        ),
        ButtonSegment(
          value: ThemeMode.dark,
          icon: const Icon(Icons.dark_mode_outlined),
          label: Text(l10n.settingsThemeDark),
        ),
        ButtonSegment(
          value: ThemeMode.system,
          icon: const Icon(Icons.contrast_rounded),
          label: Text(l10n.settingsThemeSystem),
        ),
      ],
      selected: {mode},
      // The default check mark stands in for the picked segment's icon: a
      // cue beyond the fill colour (WCAG 1.4.11).
      style: sheetSegmentedStyle,
      onSelectionChanged: (s) =>
          context.read<ThemeModeCubit>().select(s.single),
    );
    final title = Row(
      children: [
        _Tile(
          icon: Icons.palette_outlined,
          background: plum.background,
          foreground: plum.foreground,
        ),
        const SizedBox(width: Spacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.settingsTheme, style: theme.textTheme.titleMedium),
              const SizedBox(height: Spacing.xxs),
              Text(
                l10n.settingsThemeSubtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.md,
        vertical: Spacing.sm,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth >= 560
            ? Row(
                children: [
                  Expanded(child: title),
                  const SizedBox(width: Spacing.sm),
                  picker,
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  title,
                  const SizedBox(height: Spacing.sm),
                  picker,
                ],
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
