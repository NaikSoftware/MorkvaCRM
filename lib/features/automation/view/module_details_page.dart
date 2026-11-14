import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../api/data/data_repository.dart';
import '../../../core/domain/automation/automation.dart';
import '../../../core/domain/domain.dart';
import '../../../design/design.dart';
import '../../../l10n/l10n.dart';
import '../../views/widgets/option_pill.dart';
import '../bloc/module_details_cubit.dart';
import '../bloc/modules_cubit.dart';
import '../bloc/run_log_cubit.dart';
import '../widgets/reason_copy.dart';
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
    final l10n = context.l10n;
    final back = Align(
      alignment: Alignment.centerLeft,
      child: TextActionButton(
        label: l10n.commonAutomations,
        icon: MorkvaIcons.arrowBack,
        onPressed: host.openAutomations,
      ),
    );
    final entry = state.entry;
    final Widget content;
    if (state.loading) {
      content = const Center(child: LoadingIndicator());
    } else if (state.loadFailed) {
      content = AutomationLoadError(
        title: l10n.automationLoadModuleFailed,
        onRetry: context.read<ModuleDetailsCubit>().retry,
      );
    } else if (entry == null) {
      content = EmptyState(
        icon: MorkvaIcons.extensionOff,
        title: l10n.automationModuleNotInstalledTitle,
        message: l10n.automationModuleNotInstalledMessage,
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
    return LayoutBuilder(
      builder: (context, box) => box.maxWidth >= kTwoColumnWidth
          ? _twoColumns(
              banner,
              header,
              [can, ?actions, runs],
              [about, auto, automations, code],
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: Spacing.xl),
              children: [
                if (banner != null) ...[
                  banner,
                  const SizedBox(height: Spacing.md),
                ],
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
            ),
    );
  }

  Widget _twoColumns(
    Widget? banner,
    Widget header,
    List<Widget> left,
    List<Widget> right,
  ) {
    const gap = SizedBox(height: Spacing.lg);
    List<Widget> spaced(List<Widget> ws) => [
      for (final (i, w) in ws.indexed) ...[if (i > 0) gap, w],
    ];
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
                children: spaced(left),
              ),
            ),
            const SizedBox(width: Spacing.lg),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: spaced(right),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget? _banner(
    BuildContext context,
    ModuleDetailsCubit cubit,
    List<Collection> collections,
  ) {
    final l10n = context.l10n;
    final engine = state.engineUnavailable
        ? AutomationBanner(
            tone: CopyTone.warning,
            icon: MorkvaIcons.warning,
            title: l10n.automationEngineDownTitle,
            body: l10n.automationEngineDownBody,
          )
        : null;
    final banner = switch (state.banner) {
      ModuleBanner.none => null,
      ModuleBanner.allow => AutomationBanner(
        tone: CopyTone.warning,
        icon: MorkvaIcons.warning,
        title: l10n.automationModuleAllowTitle,
        body: l10n.automationModuleAllowBody,
        action: PrimaryButton(
          label: l10n.automationReviewPermissions,
          onPressed: state.busy
              ? null
              : () => openConsent(context, cubit, collections),
        ),
      ),
      ModuleBanner.changed => AutomationBanner(
        tone: CopyTone.warning,
        icon: MorkvaIcons.warning,
        title: l10n.automationModuleChangedTitle(
          '${state.consent?.version}',
          entry.module.version,
        ),
        body: l10n.automationModuleChangedBody,
        action: PrimaryButton(
          label: l10n.automationReviewChanges,
          onPressed: state.busy
              ? null
              : () => openConsent(context, cubit, collections),
        ),
      ),
      ModuleBanner.broken => AutomationBanner(
        tone: CopyTone.error,
        icon: MorkvaIcons.error,
        title: l10n.automationModuleBrokenTitle,
        body: l10n.automationModuleBrokenBody,
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
    source: sourceLabel(context.l10n, module),
  );
  if (scope != null) await cubit.allow(view, scope);
}

String sourceLabel(AppLocalizations l10n, ModuleRecord module) =>
    module.source == ModuleSource.assistant
    ? l10n.automationSourceAssistant
    : l10n.automationSourceImported;

enum _Menu { export, uninstall }

class _Header extends StatelessWidget {
  const _Header({required this.state, required this.entry});

  final ModuleDetailsState state;
  final ModuleEntry entry;

  Future<void> _menu(BuildContext context, _Menu item) async {
    final cubit = context.read<ModuleDetailsCubit>();
    final host = context.read<AutomationsHost>();
    final name = entry.module.name;
    final l10n = context.l10n;
    switch (item) {
      case _Menu.export:
        final file = cubit.exportFile();
        if (file == null) return;
        if (await host.saveFile(file.name, file.text) && context.mounted) {
          showAutomationSnack(context, l10n.automationExportedSnack(file.name));
        }
      case _Menu.uninstall:
        final n = state.automations.length;
        final ok = await MorkvaConfirmDialog.show(
          context,
          title: l10n.automationUninstallTitle(name),
          message: switch (n) {
            0 => l10n.automationUninstallMessageNone,
            1 => l10n.automationUninstallMessageOne,
            _ => l10n.automationUninstallMessageMany(n),
          },
          confirmLabel: l10n.automationUninstall,
          destructive: true,
        );
        if (ok != true || !context.mounted) return;
        if (await cubit.uninstall() && context.mounted) {
          showAutomationSnack(context, l10n.automationUninstalledSnack(name));
          host.openAutomations();
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final module = entry.module;
    final author = module.manifest?.author;
    final l10n = context.l10n;
    final meta = [
      sourceLabel(l10n, module),
      if (author != null) l10n.automationModuleAuthor(author),
      dayMonth(module.updatedAt),
      kbLabel(l10n, module.codeBytes),
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
                  OptionPill(label: 'v${module.version}'),
                  HugChip.of(moduleChip(entry.status)),
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
          tooltip: l10n.commonMore,
          icon: const Icon(MorkvaIcons.moreHoriz),
          // 44 px, like every other target here (the default is 40).
          style: IconButton.styleFrom(minimumSize: const Size.square(44)),
          onSelected: (item) => _menu(context, item),
          itemBuilder: (_) => [
            if (module.manifest != null)
              PopupMenuItem(
                value: _Menu.export,
                child: Text(l10n.automationExport),
              ),
            PopupMenuItem(
              value: _Menu.uninstall,
              child: Text(l10n.automationUninstall),
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
    final l10n = context.l10n;
    return AutomationSection(
      divided: false,
      title: l10n.automationModuleAbout,
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
                  icon: MorkvaIcons.person,
                  text: l10n.automationModuleAuthor(author),
                ),
              MetaLine(
                icon: module.source == ModuleSource.assistant
                    ? MorkvaIcons.sparkle
                    : MorkvaIcons.download,
                text: sourceLabel(l10n, module),
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
      source: sourceLabel(context.l10n, entry.module),
    );
    if (scope != null) await cubit.changeAccess(scope);
  }

  Future<void> _revoke(BuildContext context) async {
    final l10n = context.l10n;
    final ok = await MorkvaConfirmDialog.show(
      context,
      title: l10n.automationRevokeTitle(entry.module.name),
      message: l10n.automationRevokeMessage,
      confirmLabel: l10n.automationRevoke,
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
    final l10n = context.l10n;
    final where = consent == null
        ? null
        : scopeLine(l10n, consent.collections, collections);
    return AutomationSection(
      title: l10n.automationWhatItCanDo,
      trailing: consent == null
          ? null
          : Wrap(
              spacing: Spacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _ErrorTextButton(
                  label: l10n.automationRevoke,
                  onPressed: state.busy ? null : () => _revoke(context),
                ),
                if (allowed)
                  SecondaryButton(
                    label: l10n.automationChangeAccess,
                    onPressed: state.busy ? null : () => _changeAccess(context),
                  ),
              ],
            ),
      footer: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: MetaLine(
          icon: MorkvaIcons.shield,
          text: l10n.automationModuleSandboxNote,
        ),
      ),
      children: [
        if (consent == null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.md,
              Spacing.sm,
              Spacing.md,
              0,
            ),
            child: Text(
              l10n.automationWillAskForLabel,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
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
    final l10n = context.l10n;
    if (!state.autoApplyOffered) {
      return AutomationSection(
        divided: false,
        title: l10n.automationAutoApplyTitle,
        children: [
          Padding(
            padding: const EdgeInsets.all(Spacing.md),
            child: Text(
              l10n.automationAutoApplyNotOffered,
              style: muted,
            ),
          ),
        ],
      );
    }
    final enabled = state.autoApplyEnabled && !state.busy;
    return AutomationSection(
      divided: false,
      title: l10n.automationAutoApplyTitle,
      trailing: Semantics(
        label: l10n.automationAutoApplyTitle,
        hint: state.autoApplyEnabled ? null : l10n.automationAllowModuleFirst,
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
              Text(l10n.automationAutoApplyExplanation, style: muted),
              if (!state.autoApplyEnabled) ...[
                const SizedBox(height: Spacing.xs),
                Text(
                  l10n.automationAllowModuleFirst,
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
String inputLine(AppLocalizations l10n, InputSpec? input) {
  if (input == null || input.properties.isEmpty) return '';
  return [
    for (final MapEntry(:key, :value) in input.properties.entries)
      '${value.title ?? key} — ${switch (value) {
        InputProperty(format: InputFormat.field) => l10n.automationInputField,
        InputProperty(format: InputFormat.collection) => l10n.automationInputCollection,
        InputProperty(enumValues: _?) => l10n.automationInputChoice,
        InputProperty(type: InputType.boolean) => l10n.automationInputOnOff,
        InputProperty(type: InputType.number || InputType.integer) => l10n.automationInputNumber,
        _ => l10n.automationInputText,
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
    // First the collections this action already runs on, then the consent's
    // own order (the module's main collection is usually named first).
    final used = [
      for (final e in state.automations)
        if (e.automation.actionId == action.id)
          e.automation.trigger.collectionId,
    ];
    int rank(Collection c) {
      final u = used.indexOf(c.id);
      if (u >= 0) return u;
      final a = allowed?.indexOf(c.id) ?? -1;
      return a >= 0 ? used.length + a : 1 << 20;
    }

    return showTestRunSheet(
      context,
      cubit: context.read<ModuleDetailsCubit>(),
      action: action,
      collections:
          [
            for (final c in collections)
              if (allowed == null || allowed.contains(c.id)) c,
          ]..sort(
            // List.sort isn't stable: ties keep the workspace order.
            (a, b) => rank(a) != rank(b)
                ? rank(a).compareTo(rank(b))
                : collections.indexOf(a).compareTo(collections.indexOf(b)),
          ),
      // shortcut: loads the whole collection for the picker; upgrade to a
      // search-backed query once collections run to thousands of cards.
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
    final l10n = context.l10n;
    return AutomationSection(
      title: l10n.automationActions,
      children: [
        for (final a in manifest.actions)
          LayoutBuilder(
            builder: (context, box) {
              final buttons = Wrap(
                spacing: Spacing.xs,
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Semantics(
                    hint: state.canTestRun
                        ? null
                        : l10n.automationAllowModuleFirst,
                    child: TextActionButton(
                      label: l10n.automationTestRun,
                      icon: MorkvaIcons.play,
                      onPressed: state.canTestRun
                          ? () => _test(context, a)
                          : null,
                    ),
                  ),
                  TextActionButton(
                    label: l10n.automationAddToButton,
                    icon: MorkvaIcons.smartButton,
                    onPressed: () => host.newAutomation(
                      moduleId: manifest.id,
                      actionId: a.id,
                    ),
                  ),
                  if (!state.canTestRun)
                    Text(l10n.automationAllowModuleFirst, style: muted),
                ],
              );
              // Wide: the buttons at the row's end, as the mockup; narrow
              // cards stack them under the text.
              final wide = box.maxWidth >= 520;
              return Padding(
                padding: const EdgeInsets.all(Spacing.md),
                child: Row(
                  crossAxisAlignment: wide
                      ? CrossAxisAlignment.center
                      : CrossAxisAlignment.start,
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
                              HugChip(
                                label: scopeTag(l10n, a.scope),
                                tone: CopyTone.neutral,
                              ),
                            ],
                          ),
                          if (a.description != null)
                            Text(
                              a.description!,
                              style: theme.textTheme.bodyMedium,
                            ),
                          if (inputLine(l10n, a.input) case final line
                              when line.isNotEmpty)
                            Text(line, style: muted),
                          if (!wide) buttons,
                        ],
                      ),
                    ),
                    if (wide) ...[
                      const SizedBox(width: Spacing.sm),
                      Flexible(child: buttons),
                    ],
                  ],
                ),
              );
            },
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
    final l10n = context.l10n;
    return AutomationSection(
      title: l10n.automationUsingIt,
      trailing: TextActionButton(
        label: l10n.automationNewAutomation,
        icon: MorkvaIcons.add,
        onPressed: () => host.newAutomation(moduleId: state.module!.id),
      ),
      children: [
        if (state.automations.isEmpty)
          Padding(
            padding: const EdgeInsets.all(Spacing.md),
            child: Text(
              l10n.automationUsingItNone,
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
    final l10n = context.l10n;
    return AutomationSection(
      divided: false,
      title: l10n.automationCode,
      trailing: SecondaryButton(
        label: l10n.automationViewCode,
        icon: MorkvaIcons.code,
        onPressed: () =>
            showCodeViewer(context, code: module.code, hash: module.bundleHash),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.all(Spacing.md),
          child: Row(
            children: [
              Icon(
                MorkvaIcons.file,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: Spacing.xs),
              Flexible(
                child: Text(
                  'module.js · ${kbLabel(l10n, module.codeBytes)} · '
                  '${shortHash(module.bundleHash)}',
                  style: MorkvaTypography.mono(
                    theme.textTheme.bodySmall!,
                  ).copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ],
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
    final l10n = context.l10n;
    return AutomationSection(
      title: l10n.automationRecentRuns,
      trailing: TextActionButton(
        label: l10n.automationAllRuns,
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
              l10n.automationNoRunsShort,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        for (final r in rows) RunRowTile(row: r, now: now, compact: true),
      ],
    );
  }
}
