import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../api/data/data_repository.dart';
import '../../../core/domain/automation/automation.dart';
import '../../../core/domain/domain.dart';
import '../../../design/design.dart';
import '../bloc/module_details_cubit.dart';
import '../bloc/modules_cubit.dart';
import '../bloc/run_log_cubit.dart';
import '../widgets/reason_copy.dart';
import '../widgets/status_chip.dart';
import 'automations_page.dart';
import 'code_viewer.dart';
import 'consent_sheet.dart';
import 'test_run_sheet.dart';

/// `/automations/modules/:id` (UX §2): what the module can do, consent,
/// auto-apply, its actions, automations, code and recent runs.
///
/// Reads [ModuleDetailsCubit], [ModulesCubit] (the automation switches),
/// [RunLogCubit] (the recent run rows), [CollectionsListCubit] and the
/// [AutomationsHost]; [DataRepository] only for the test-run card picker.
class ModuleDetailsPage extends StatelessWidget {
  const ModuleDetailsPage({super.key, this.now = DateTime.now});

  final DateTime Function() now;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ModuleDetailsCubit>().state;
    final host = context.read<AutomationsHost>();
    final pad = automationsExpanded(context) ? Spacing.xxl : Spacing.md;
    final back = Align(
      alignment: Alignment.centerLeft,
      child: TextActionButton(
        label: 'Automations',
        icon: Icons.arrow_back,
        onPressed: host.openAutomations,
      ),
    );
    final entry = state.entry;
    final Widget content;
    if (state.loading) {
      content = const Center(child: LoadingIndicator());
    } else if (entry == null) {
      content = const EmptyState(
        icon: Icons.extension_off_outlined,
        title: 'This module isn\'t installed',
        message: 'It was uninstalled, or the link is out of date.',
      );
    } else {
      content = _Details(state: state, entry: entry, now: now);
    }
    return BlocListener<ModuleDetailsCubit, ModuleDetailsState>(
      listenWhen: (a, b) => b.error != null && a.error != b.error,
      listener: (context, s) {
        showAutomationSnack(context, s.error!);
        context.read<ModuleDetailsCubit>().clearError();
      },
      child: Material(
        type: MaterialType.transparency,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 1040 + 2 * pad),
            child: Padding(
              padding: EdgeInsets.fromLTRB(pad, Spacing.sm, pad, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  back,
                  Expanded(child: content),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.state, required this.entry, required this.now});

  final ModuleDetailsState state;
  final ModuleEntry entry;
  final DateTime Function() now;

  @override
  Widget build(BuildContext context) {
    final collections = automationCollections(context);
    final cubit = context.read<ModuleDetailsCubit>();
    final module = entry.module;
    final manifest = module.manifest;
    const gap = SizedBox(height: Spacing.lg);
    final banner = _banner(context, cubit, collections);

    final about = _About(module: module);
    final can = _WhatItCanDo(
      state: state,
      entry: entry,
      collections: collections,
    );
    final auto = _AutoApply(state: state);
    final actions = manifest == null
        ? null
        : _Actions(state: state, manifest: manifest, collections: collections);
    final automations = _AutomationsUsing(
      state: state,
      collections: collections,
    );
    final code = _Code(module: module);
    final runs = _RecentRuns(state: state, now: now());

    final header = _Header(state: state, entry: entry);
    if (automationsWide(context)) {
      return ListView(
        padding: const EdgeInsets.only(bottom: Spacing.xl),
        children: [
          if (banner != null) ...[banner, const SizedBox(height: Spacing.md)],
          header,
          const SizedBox(height: Spacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [can, gap, ?actions, gap, runs],
                ),
              ),
              const SizedBox(width: Spacing.lg),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [about, gap, auto, gap, automations, gap, code],
                ),
              ),
            ],
          ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: Spacing.xl),
      children: [
        if (banner != null) ...[banner, const SizedBox(height: Spacing.md)],
        header,
        const SizedBox(height: Spacing.md),
        about,
        gap,
        can,
        gap,
        auto,
        if (actions != null) ...[gap, actions],
        gap,
        automations,
        gap,
        code,
        gap,
        runs,
      ],
    );
  }

  Widget? _banner(
    BuildContext context,
    ModuleDetailsCubit cubit,
    List<Collection> collections,
  ) {
    final engine = state.engineUnavailable
        ? const AutomationBanner(
            tone: CopyTone.warning,
            icon: Icons.warning_amber_rounded,
            title: "Automations can't run on this device right now.",
            body: 'Runs are skipped and logged.',
          )
        : null;
    final banner = switch (state.banner) {
      ModuleBanner.none => null,
      ModuleBanner.allow => AutomationBanner(
        tone: CopyTone.warning,
        icon: Icons.warning_amber_rounded,
        title: 'Allow this module to run.',
        body: 'Review what it can do before its actions can run.',
        action: PrimaryButton(
          label: 'Review permissions',
          onPressed: state.busy
              ? null
              : () => openConsent(context, cubit, collections),
        ),
      ),
      ModuleBanner.changed => AutomationBanner(
        tone: CopyTone.warning,
        icon: Icons.warning_amber_rounded,
        title:
            'This module changed (v${state.consent?.version} → '
            'v${entry.module.version}).',
        body: 'Its automations are paused until you allow the new version.',
        action: PrimaryButton(
          label: 'Review changes',
          onPressed: state.busy
              ? null
              : () => openConsent(context, cubit, collections),
        ),
      ),
      ModuleBanner.broken => AutomationBanner(
        tone: CopyTone.error,
        icon: Icons.error_outline,
        title: "This module's file is no longer valid.",
        body: 'Import it again.',
        details: [for (final p in entry.module.manifestProblems) '$p'],
      ),
    };
    if (engine == null) return banner;
    if (banner == null) return engine;
    return Column(
      children: [
        banner,
        const SizedBox(height: Spacing.sm),
        engine,
      ],
    );
  }
}

/// The consent sheet for the module as it is now; allows on accept.
Future<void> openConsent(
  BuildContext context,
  ModuleDetailsCubit cubit,
  List<Collection> collections,
) async {
  final view = cubit.consentView();
  final module = cubit.state.module;
  if (view == null || module == null) return;
  final consent = cubit.state.consent;
  final scope = await showConsentSheet(
    context,
    view: view,
    collections: collections,
    initial: consent == null
        ? const ConsentScope.only({})
        : ConsentScope.of(consent),
    mode: ConsentMode.allow,
    source: sourceLabel(module),
  );
  if (scope != null) await cubit.allow(view, scope);
}

String sourceLabel(ModuleRecord module) =>
    module.source == ModuleSource.assistant ? 'Made by Ask Morkva' : 'Imported';

enum _Menu { export, uninstall }

class _Header extends StatelessWidget {
  const _Header({required this.state, required this.entry});

  final ModuleDetailsState state;
  final ModuleEntry entry;

  Future<void> _menu(BuildContext context, _Menu item) async {
    final cubit = context.read<ModuleDetailsCubit>();
    final host = context.read<AutomationsHost>();
    final name = entry.module.name;
    switch (item) {
      case _Menu.export:
        final file = cubit.exportFile();
        if (file == null) return;
        if (await host.saveFile(file.name, file.text) && context.mounted) {
          showAutomationSnack(context, 'Exported ${file.name}');
        }
      case _Menu.uninstall:
        final n = state.automations.length;
        final ok = await MorkvaConfirmDialog.show(
          context,
          title: 'Uninstall "$name"?',
          message:
              'Its ${n == 1 ? 'automation' : '$n automations'} and their '
              'buttons are deleted, its pending reviews are dropped and its '
              'permissions are removed. The run history stays.',
          confirmLabel: 'Uninstall',
          destructive: true,
        );
        if (ok != true || !context.mounted) return;
        if (await cubit.uninstall() && context.mounted) {
          showAutomationSnack(context, 'Uninstalled $name');
          host.openAutomations();
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final module = entry.module;
    final author = module.manifest?.author;
    final meta = [
      sourceLabel(module),
      if (author != null) 'Author: $author (from the file)',
      dayMonth(module.updatedAt),
      kbLabel(module.codeBytes),
    ].join(' · ');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ModuleGlyph(module: module, size: 44),
        const SizedBox(width: Spacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: Spacing.xs,
                runSpacing: Spacing.xxs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(module.name, style: theme.textTheme.headlineSmall),
                  StatusChip(
                    label: 'v${module.version}',
                    tone: CopyTone.neutral,
                  ),
                  StatusChip.of(moduleChip(entry.status)),
                ],
              ),
              const SizedBox(height: Spacing.xxs),
              Text(
                meta,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        PopupMenuButton<_Menu>(
          tooltip: 'More',
          icon: const Icon(Icons.more_horiz),
          onSelected: (item) => _menu(context, item),
          itemBuilder: (_) => [
            if (module.manifest != null)
              const PopupMenuItem(value: _Menu.export, child: Text('Export')),
            const PopupMenuItem(
              value: _Menu.uninstall,
              child: Text('Uninstall'),
            ),
          ],
        ),
      ],
    );
  }
}

class _About extends StatelessWidget {
  const _About({required this.module});

  final ModuleRecord module;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final author = module.manifest?.author;
    return AutomationSection(
      title: 'About',
      children: [
        Padding(
          padding: const EdgeInsets.all(Spacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (module.manifest?.description case final d?) ...[
                Text(d, style: theme.textTheme.bodyMedium),
                const SizedBox(height: Spacing.sm),
              ],
              if (author != null)
                MetaLine(
                  icon: Icons.person_outline,
                  text: 'Author: $author (from the file)',
                ),
              MetaLine(
                icon: module.source == ModuleSource.assistant
                    ? Icons.auto_awesome_outlined
                    : Icons.download_outlined,
                text: sourceLabel(module),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WhatItCanDo extends StatelessWidget {
  const _WhatItCanDo({
    required this.state,
    required this.entry,
    required this.collections,
  });

  final ModuleDetailsState state;
  final ModuleEntry entry;
  final List<Collection> collections;

  Future<void> _changeAccess(BuildContext context) async {
    final cubit = context.read<ModuleDetailsCubit>();
    final view = cubit.consentView();
    final consent = state.consent;
    if (view == null || consent == null) return;
    final scope = await showConsentSheet(
      context,
      view: view,
      collections: collections,
      initial: ConsentScope.of(consent),
      mode: ConsentMode.edit,
      source: sourceLabel(entry.module),
    );
    if (scope != null) await cubit.changeAccess(scope);
  }

  Future<void> _revoke(BuildContext context) async {
    final ok = await MorkvaConfirmDialog.show(
      context,
      title: 'Revoke access for "${entry.module.name}"?',
      message:
          'Its automations stop running and pending reviews are dropped until '
          'you allow it again.',
      confirmLabel: 'Revoke',
      destructive: true,
    );
    if (ok == true && context.mounted) {
      await context.read<ModuleDetailsCubit>().revoke();
    }
  }

  @override
  Widget build(BuildContext context) {
    final consent = state.consent;
    final allowed = consent != null && state.status == ModuleStatus.ok;
    final where = consent == null
        ? 'Will ask for: where you allow'
        : scopeLine(consent.collections, collections);
    return AutomationSection(
      title: 'What it can do',
      trailing: consent == null
          ? null
          : Wrap(
              spacing: Spacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _ErrorTextButton(
                  label: 'Revoke',
                  onPressed: state.busy ? null : () => _revoke(context),
                ),
                if (allowed)
                  SecondaryButton(
                    label: 'Change access',
                    onPressed: state.busy ? null : () => _changeAccess(context),
                  ),
              ],
            ),
      footer: const Padding(
        padding: EdgeInsets.all(Spacing.md),
        child: MetaLine(
          icon: Icons.shield_outlined,
          text:
              "Modules can't reach the internet, your account or other apps. "
              'Every change goes through a preview unless you turn on '
              'auto-apply below.',
        ),
      ),
      children: [
        for (final cap in entry.caps) CapabilityRow(cap: cap, extra: where),
      ],
    );
  }
}

/// A [TextActionButton]-shaped action in the error tone (Revoke).
class _ErrorTextButton extends StatelessWidget {
  const _ErrorTextButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    return Theme(
      data: Theme.of(context).copyWith(
        extensions: [
          Theme.of(
            context,
          ).extension<MorkvaSemanticColors>()!.copyWith(primaryText: error),
        ],
      ),
      child: TextActionButton(label: label, onPressed: onPressed),
    );
  }
}

class _AutoApply extends StatelessWidget {
  const _AutoApply({required this.state});

  final ModuleDetailsState state;

  Future<void> _toggle(BuildContext context, bool on) async {
    final cubit = context.read<ModuleDetailsCubit>();
    final confirm = cubit.autoApplyConfirm(on);
    if (confirm != null) {
      final ok = await MorkvaConfirmDialog.show(
        context,
        title: confirm.title,
        message: confirm.body ?? '',
        confirmLabel: confirm.confirm,
      );
      if (ok != true) return;
    }
    await cubit.setAutoApply(on);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    if (!state.autoApplyOffered) {
      return AutomationSection(
        title: 'Apply changes automatically',
        children: [
          Padding(
            padding: const EdgeInsets.all(Spacing.md),
            child: Text(
              'This module can delete or change structure, so its changes '
              'always wait for your review.',
              style: muted,
            ),
          ),
        ],
      );
    }
    final enabled = state.autoApplyEnabled && !state.busy;
    return AutomationSection(
      title: 'Apply changes automatically',
      trailing: Semantics(
        label: 'Apply changes automatically',
        hint: state.autoApplyEnabled ? null : 'Allow this module first',
        child: Switch(
          value: state.autoApplyOn,
          onChanged: enabled ? (on) => _toggle(context, on) : null,
        ),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.all(Spacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Small card creates and edits from this module — up to 20 '
                'cards, nothing cleared — are applied without asking. Bigger '
                'changes, deletes and structure changes always wait for you. '
                'You can undo an applied run until you reload Morkva.',
                style: muted,
              ),
              if (!state.autoApplyEnabled) ...[
                const SizedBox(height: Spacing.xs),
                Text(
                  'Allow this module first',
                  style: theme.textTheme.labelMedium,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// "Date field — a field picker".
String inputLine(InputSpec? input) {
  if (input == null || input.properties.isEmpty) return '';
  return [
    for (final MapEntry(:key, :value) in input.properties.entries)
      '${value.title ?? key} — ${switch (value) {
        InputProperty(format: InputFormat.field) => 'a field picker',
        InputProperty(format: InputFormat.collection) => 'a collection picker',
        InputProperty(enumValues: _?) => 'a choice',
        InputProperty(type: InputType.boolean) => 'on or off',
        InputProperty(type: InputType.number || InputType.integer) => 'a number',
        _ => 'text',
      }}',
  ].join(' · ');
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.state,
    required this.manifest,
    required this.collections,
  });

  final ModuleDetailsState state;
  final ModuleManifest manifest;
  final List<Collection> collections;

  Future<void> _test(BuildContext context, ActionSpec action) {
    final allowed = state.consent?.collections;
    return showTestRunSheet(
      context,
      cubit: context.read<ModuleDetailsCubit>(),
      action: action,
      collections: [
        for (final c in collections)
          if (allowed == null || allowed.contains(c.id)) c,
      ],
      loadCards: (collection) async {
        final objects = await context.read<DataRepository>().getObjects(
          collection.id,
          schema: collection,
        );
        return [
          for (final MapEntry(:key, :value) in objectLabels(
            collection,
            objects,
          ).entries)
            (id: key, label: value),
        ];
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final host = context.read<AutomationsHost>();
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return AutomationSection(
      title: 'Actions',
      children: [
        for (final a in manifest.actions)
          Padding(
            padding: const EdgeInsets.all(Spacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CollectionGlyph(
                  iconKey: a.icon,
                  tintSeed: state.module!.id,
                  size: 28,
                  iconSize: 16,
                ),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: Spacing.xs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(a.label, style: theme.textTheme.titleSmall),
                          StatusChip(
                            label: scopeTag(a.scope),
                            tone: CopyTone.neutral,
                          ),
                        ],
                      ),
                      if (a.description != null)
                        Text(a.description!, style: theme.textTheme.bodyMedium),
                      if (inputLine(a.input) case final line
                          when line.isNotEmpty)
                        Text(line, style: muted),
                      Wrap(
                        spacing: Spacing.xs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Semantics(
                            hint: state.canTestRun
                                ? null
                                : 'Allow this module first',
                            child: TextActionButton(
                              label: 'Test run',
                              icon: Icons.play_arrow_outlined,
                              onPressed: state.canTestRun
                                  ? () => _test(context, a)
                                  : null,
                            ),
                          ),
                          TextActionButton(
                            label: 'Add to a button',
                            icon: Icons.smart_button_outlined,
                            onPressed: () => host.newAutomation(
                              moduleId: manifest.id,
                              actionId: a.id,
                            ),
                          ),
                          if (!state.canTestRun)
                            Text('Allow this module first', style: muted),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _AutomationsUsing extends StatelessWidget {
  const _AutomationsUsing({required this.state, required this.collections});

  final ModuleDetailsState state;
  final List<Collection> collections;

  @override
  Widget build(BuildContext context) {
    final host = context.read<AutomationsHost>();
    final theme = Theme.of(context);
    return AutomationSection(
      title: 'Automations using it',
      trailing: TextActionButton(
        label: 'New automation',
        icon: Icons.add,
        onPressed: () => host.newAutomation(moduleId: state.module!.id),
      ),
      children: [
        if (state.automations.isEmpty)
          Padding(
            padding: const EdgeInsets.all(Spacing.md),
            child: Text(
              'No automations use it yet.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        for (final a in state.automations)
          AutomationRowTile(
            entry: a,
            collection: collectionOf(
              collections,
              a.automation.trigger.collectionId,
            ),
            compact: true,
          ),
      ],
    );
  }
}

class _Code extends StatelessWidget {
  const _Code({required this.module});

  final ModuleRecord module;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AutomationSection(
      title: 'Code',
      trailing: SecondaryButton(
        label: 'View code',
        icon: Icons.code,
        onPressed: () =>
            showCodeViewer(context, code: module.code, hash: module.bundleHash),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.all(Spacing.md),
          child: Text(
            'module.js · ${kbLabel(module.codeBytes)} · '
            '${shortHash(module.bundleHash)}',
            style: MorkvaTypography.mono(
              theme.textTheme.bodySmall!,
            ).copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

class _RecentRuns extends StatelessWidget {
  const _RecentRuns({required this.state, required this.now});

  final ModuleDetailsState state;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final host = context.read<AutomationsHost>();
    final runLog = context.watch<RunLogCubit>().state;
    final theme = Theme.of(context);
    final rows = [for (final r in state.recentRuns) ?runLog.row(r.id)];
    return AutomationSection(
      title: 'Recent runs',
      trailing: TextActionButton(
        label: 'All runs',
        onPressed: () => host.openAutomations(
          tab: AutomationsTab.runs,
          moduleId: state.module!.id,
        ),
      ),
      children: [
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.all(Spacing.md),
            child: Text(
              'No runs yet.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        for (final r in rows) RunRowTile(row: r, now: now),
      ],
    );
  }
}
