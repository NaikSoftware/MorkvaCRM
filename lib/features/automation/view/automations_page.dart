import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../api/sync/sync_status.dart';
import '../../../api/sync/sync_status_cubit.dart';
import '../../../app/shell/app_shell.dart';
import '../../../core/automation/runner_api.dart';
import '../../../core/domain/automation/automation.dart';
import '../../../core/domain/domain.dart';
import '../../../design/design.dart';
import '../../collections/collections.dart';
import '../../views/widgets/option_pill.dart';
import '../../views/widgets/view_labels.dart';
import '../bloc/automation_editor_cubit.dart' show filterOf;
import '../bloc/automation_runs_cubit.dart';
import '../bloc/modules_cubit.dart';
import '../bloc/run_log_cubit.dart';
import '../widgets/action_buttons.dart' show buttonTintOf;
import '../widgets/reason_copy.dart';
import '../widgets/status_chip.dart';
import 'consent_sheet.dart';
import 'import_sheet.dart';

/// The Automations page's tabs (`?tab=`).
enum AutomationsTab {
  modules,
  automations,
  runs;

  static AutomationsTab fromQuery(String? tab) =>
      values.asNameMap()[tab] ?? modules;
}

/// What the automation pages ask of the app: navigation (the router), the
/// editor and review sheets (T13), Ask Morkva and file pick/save. The app
/// provides one (`RepositoryProvider<AutomationsHost>`), so the pages stay
/// free of the router and the platform.
abstract interface class AutomationsHost {
  /// `/automations?tab=…&collection=…&card=…&filter=…` ([moduleId]: the
  /// Runs tab filtered to one module, module details' "All runs").
  void openAutomations({
    AutomationsTab tab = AutomationsTab.modules,
    String? collectionId,
    String? cardId,
    RunFilterKind? filter,
    String? moduleId,
  });

  void openModule(String moduleId);

  void openRun(String runId);

  /// A run's card ("Open card").
  void openCard(String collectionId, String cardId);

  /// A module's `ui.open` chip (an in-app ref only; navigates on tap).
  void openLink(UiLink link);

  /// The automation editor (T13) for a new automation, preset as given.
  void newAutomation({
    String? moduleId,
    String? actionId,
    String? collectionId,
  });

  void editAutomation(String automationId);

  /// The review sheet (T13) of a run waiting for review in this session.
  void review(String runId);

  /// Opens Ask Morkva with the composer prefilled; null while Ask Morkva is
  /// flagged off (its entries are hidden then).
  void Function(String prefill)? get askMorkva;

  /// The system file picker for a `.morkva.json`; null when cancelled.
  Future<({String name, String text})?> pickModuleFile();

  /// The system save dialog (a download on web); false when cancelled.
  Future<bool> saveFile(String name, String text);
}

/// The page's own width for two columns (module cards, module details):
/// the full sidebar's 1040 content, not the rail's or a page narrowed by the
/// Ask panel. Measured with a LayoutBuilder, not the window.
const double kTwoColumnWidth = 880;

/// Not a phone.
bool automationsExpanded(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= AppShell.expandedBreakpoint;

/// Whether the device is offline ("Needs a connection"); false where no
/// sync status is provided.
bool automationsOffline(BuildContext context) =>
    context.watch<SyncStatusCubit?>()?.state is SyncOffline;

/// The workspace collections (names, glyphs, pickers).
List<Collection> automationCollections(
  BuildContext context, {
  bool listen = true,
}) => switch ((listen
        ? context.watch<CollectionsListCubit>()
        : context.read<CollectionsListCubit>())
    .state) {
  CollectionsListReady(:final collections) => collections,
  _ => const [],
};

/// "just now", "2 min ago", "3 h ago", "Yesterday", else "12 Nov".
String agoLabel(DateTime t, DateTime now) {
  final d = now.difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inHours < 1) return '${d.inMinutes} min ago';
  if (d.inDays < 1) return '${d.inHours} h ago';
  if (d.inDays < 2) return 'Yesterday';
  return dayMonth(t);
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// "12 Nov" (local).
String dayMonth(DateTime t) {
  final l = t.toLocal();
  return '${l.day} ${_months[l.month - 1]}';
}

/// "12:04" (local).
String clock(DateTime t) {
  final l = t.toLocal();
  return '${l.hour.toString().padLeft(2, '0')}:'
      '${l.minute.toString().padLeft(2, '0')}';
}

/// "2.1 KB".
String kbLabel(int bytes) =>
    bytes < 1024 ? '$bytes B' : '${(bytes / 1024).toStringAsFixed(1)} KB';

/// "sha256:3fa2…c91".
String shortHash(String hash) {
  final hex = hash.startsWith('sha256:') ? hash.substring(7) : hash;
  return hex.length <= 8
      ? 'sha256:$hex'
      : 'sha256:${hex.substring(0, 4)}…${hex.substring(hex.length - 3)}';
}

/// "412 ms" / "20 s"; "—" when unknown.
String durationLabel(int? ms) => ms == null
    ? '—'
    : ms < 1000
    ? '$ms ms'
    : '${(ms / 1000).round()} s';

Collection? collectionOf(List<Collection> all, String id) =>
    all.where((c) => c.id == id).firstOrNull;

/// "In Orders, Clients" / "In all collections".
String scopeLine(List<String>? collections, List<Collection> all) =>
    collections == null
    ? 'In all collections'
    : 'In ${[for (final id in collections) collectionOf(all, id)?.name ?? 'a removed collection'].join(', ')}';

/// The module card's permission line: titles, then where.
String permissionSummary(ModuleEntry entry, List<Collection> all) {
  final titles = [
    for (final cap in entry.caps) kCapabilityCopy[cap]?.title ?? cap,
  ].join(' · ');
  final consent = entry.consent;
  return consent == null
      ? 'Will ask for: $titles'
      : '$titles · ${scopeLine(consent.collections, all)}';
}

/// "Button on a card", "When a card is updated · Status is Shipped", …
String whenLine(TriggerSpec trigger, Collection? collection) {
  switch (trigger) {
    case ButtonTrigger(:final scope):
      return scope == ButtonScope.card
          ? 'Button on a card'
          : 'Button on ${collection?.name ?? 'a collection'}';
    case EventTrigger(:final kind, :final where, :final mode, :final fields):
      final head = switch (kind) {
        TriggerKind.cardCreated => 'When a card is created',
        TriggerKind.cardDeleted => 'When a card is deleted',
        _ => 'When a card is updated',
      };
      final conditions = [
        for (final c in where)
          switch ((filterOf(c), collection)) {
            (final f?, final col?) => filterLabel(f, col),
            _ => '${c['field']} ${c['op']} ${c['relative'] ?? c['value']}',
          },
      ].join(' and ');
      final watched = fields == null || fields.isEmpty
          ? null
          : 'when ${[for (final id in fields) collection?.fieldById(id)?.name ?? id].join(' or ')} changes';
      // One condition reads 'Status starts matching "is Shipped"'.
      final field = where.length == 1
          ? collection?.fieldById('${where.single['field']}')?.name
          : null;
      return [
        head,
        if (conditions.isNotEmpty)
          switch (kind == TriggerKind.cardUpdated &&
              mode == TriggerMode.enters) {
            false => conditions,
            true when field != null && conditions.startsWith('$field ') =>
              '$field starts matching "${conditions.substring(field.length + 1)}"',
            true => 'starts matching "$conditions"',
          },
        ?watched,
      ].join(' · ');
  }
}

/// "Do: Stamp shipped date › Stamp".
String doLine(AutomationEntry entry) =>
    'Do: ${entry.module?.module.name ?? 'a removed module'} › '
    '${entry.action?.label ?? entry.automation.actionId}';

/// The `/automations` page: Modules · Automations · Runs. The query
/// parameters are its state: a tab tap or a chip clear asks the host to
/// change them, and [didUpdateWidget] applies them, so the run indicator can
/// switch tabs while the page is up.
///
/// Reads [ModulesCubit], [RunLogCubit], [AutomationRunsCubit],
/// [CollectionsListCubit] and the [AutomationsHost] from the context.
class AutomationsPage extends StatefulWidget {
  const AutomationsPage({
    super.key,
    this.tab = AutomationsTab.modules,
    this.collectionId,
    this.cardId,
    this.filter,
    this.moduleId,
    this.now = DateTime.now,
  });

  final AutomationsTab tab;

  /// Automations tab: one collection's group ("Orders ✕"); also the
  /// collection an import came from.
  final String? collectionId;

  /// Runs tab: one card's runs ("#1042 ✕").
  final String? cardId;
  final RunFilterKind? filter;
  final String? moduleId;
  final DateTime Function() now;

  @override
  State<AutomationsPage> createState() => _AutomationsPageState();
}

class _AutomationsPageState extends State<AutomationsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: AutomationsTab.values.length,
    initialIndex: widget.tab.index,
    vsync: this,
  );

  @override
  void initState() {
    super.initState();
    _applyQuery();
  }

  @override
  void didUpdateWidget(AutomationsPage old) {
    super.didUpdateWidget(old);
    if (old.tab != widget.tab && _tabs.index != widget.tab.index) {
      // Coming back from a detail route the page was offstage: its tab bar
      // and view have no viewport until this frame's layout.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _tabs.animateTo(widget.tab.index);
      });
    }
    if (old.tab != widget.tab ||
        old.cardId != widget.cardId ||
        old.filter != widget.filter ||
        old.moduleId != widget.moduleId) {
      _applyQuery();
    }
  }

  void _applyQuery() {
    context.read<RunLogCubit>().setFilter(
      RunFilter(
        kind: widget.filter ?? RunFilterKind.all,
        cardId: widget.cardId,
        moduleId: widget.moduleId,
        automationId: context.read<RunLogCubit>().state.filter.automationId,
      ),
    );
    if (widget.tab == AutomationsTab.runs) {
      context.read<AutomationRunsCubit>().markRunsSeen();
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  AutomationsHost get _host => context.read<AutomationsHost>();

  void _select(AutomationsTab tab) => _host.openAutomations(
    tab: tab,
    collectionId: widget.collectionId,
    cardId: widget.cardId,
    filter: widget.filter,
    moduleId: widget.moduleId,
  );

  Future<void> _import() async {
    final modules = context.read<ModulesCubit>();
    final collections = automationCollections(context, listen: false);
    final preview = await showImportSheet(
      context,
      preview: modules.previewImport,
      pickFile: _host.pickModuleFile,
    );
    final bundle = preview?.bundle;
    if (bundle == null || !mounted) return;
    final view = consentViewOf(bundle, preview!.replacing?.consent);
    final scope = await showConsentSheet(
      context,
      view: view,
      collections: collections,
      initial: ConsentScope.forImport(
        fromCollection: widget.collectionId,
        replacing: preview.replacing?.consent,
      ),
      mode: ConsentMode.install,
      source: 'Imported',
    );
    if (scope == null || !mounted) return;
    if (await modules.install(bundle, scope) && mounted) {
      showAutomationSnack(context, 'Installed ${bundle.manifest.name}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final modules = context.watch<ModulesCubit>().state;
    final runs = context.watch<RunLogCubit>().state;
    final engineDown = context.select<AutomationRunsCubit, bool>(
      (c) => c.state.activity.engineUnavailable,
    );
    final expanded = automationsExpanded(context);
    final host = _host;
    final ask = host.askMorkva;

    // Wide: in the header. Phone: the first row of the tab's list, so the
    // tab bar sits under the app bar on every tab.
    Widget? actionFor(AutomationsTab tab) => switch (tab) {
      AutomationsTab.modules => Wrap(
        alignment: WrapAlignment.end,
        spacing: Spacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (ask != null)
            TextActionButton(
              label: expanded ? 'Ask Morkva to write one' : 'Ask Morkva',
              icon: Icons.auto_awesome_outlined,
              onPressed: () => ask('Write a module that '),
            ),
          SecondaryButton(
            label: 'Import module',
            icon: Icons.upload_outlined,
            onPressed: _import,
          ),
        ],
      ),
      // Not "Install a module first" while the list failed to load.
      AutomationsTab.automations when modules.loadFailed => null,
      AutomationsTab.automations => _NewAutomationAction(
        enabled: modules.modules.isNotEmpty,
        onPressed: () => host.newAutomation(collectionId: widget.collectionId),
      ),
      AutomationsTab.runs => null,
    };

    return BlocListener<ModulesCubit, ModulesState>(
      listenWhen: (a, b) => b.error != null && a.error != b.error,
      listener: (context, s) {
        showAutomationSnack(context, s.error!);
        context.read<ModulesCubit>().clearError();
      },
      child: BlocListener<RunLogCubit, RunLogState>(
        listenWhen: (a, b) => b.error != null && a.error != b.error,
        listener: (context, s) {
          showAutomationSnack(context, s.error!);
          context.read<RunLogCubit>().clearError();
        },
        child: Material(
          type: MaterialType.transparency,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1040 + 2 * 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (expanded) _Header(action: actionFor(widget.tab)),
                  _Tabs(
                    controller: _tabs,
                    // No "0" for lists that failed to load.
                    modules: modules.loadFailed ? null : modules.modules.length,
                    automations: modules.loadFailed
                        ? null
                        : modules.automations.length,
                    reviews: runs.loadFailed ? null : runs.needsReview,
                    onSelect: _select,
                    padding: expanded ? Spacing.xxl : Spacing.md,
                  ),
                  if (engineDown)
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        expanded ? Spacing.xxl : Spacing.md,
                        Spacing.md,
                        expanded ? Spacing.xxl : Spacing.md,
                        0,
                      ),
                      child: const AutomationBanner(
                        tone: CopyTone.warning,
                        icon: Icons.warning_amber_rounded,
                        title:
                            "Automations can't run on this device right now.",
                        body: 'Runs are skipped and logged.',
                      ),
                    ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabs,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _ModulesTab(
                          state: modules,
                          onImport: _import,
                          lead: expanded
                              ? null
                              : actionFor(AutomationsTab.modules),
                        ),
                        _AutomationsTab(
                          state: modules,
                          collectionId: widget.collectionId,
                          lead: expanded
                              ? null
                              : actionFor(AutomationsTab.automations),
                        ),
                        _RunsTab(
                          state: runs,
                          automations: modules.automations,
                          now: widget.now,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A floating snackbar that times out (`persist: false`; a SnackBar with
/// an action never times out on web otherwise).
void showAutomationSnack(BuildContext context, String text) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  messenger?.hideCurrentSnackBar();
  messenger?.showSnackBar(
    SnackBar(
      content: Text(text),
      behavior: SnackBarBehavior.floating,
      persist: false,
      duration: const Duration(seconds: 5),
      width: automationsExpanded(context) ? 480 : null,
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header({this.action});

  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = Text('Automations', style: theme.textTheme.headlineSmall);
    final subtitle = Text(
      'Modules add actions. Automations put them on buttons or '
      'run them when cards change.',
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
    const padding = EdgeInsets.fromLTRB(
      Spacing.xxl,
      Spacing.lg,
      Spacing.xxl,
      Spacing.md,
    );
    // Under 1240 the subtitle would wrap beside the Modules actions: it goes
    // full width under a title row of one height on every tab, so it stays
    // one line and the tabs stay put when switching.
    if (MediaQuery.sizeOf(context).width < 1240) {
      return Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Row(
                children: [
                  Expanded(child: title),
                  if (action != null) ...[
                    const SizedBox(width: Spacing.md),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: action,
                    ),
                  ],
                ],
              ),
            ),
            subtitle,
          ],
        ),
      );
    }
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                title,
                const SizedBox(height: Spacing.xxs),
                subtitle,
              ],
            ),
          ),
          if (action != null) ...[
            const SizedBox(width: Spacing.md),
            // Not Flexible: an even flex split wrapped the subtitle on the
            // Modules / Automations tabs (not on Runs), so the tabs jumped.
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: action,
            ),
          ],
        ],
      ),
    );
  }
}

class _NewAutomationAction extends StatelessWidget {
  const _NewAutomationAction({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final button = PrimaryButton(
      label: 'New automation',
      icon: Icons.add,
      onPressed: enabled ? onPressed : null,
    );
    if (enabled) return button;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Flexible: the header gives the action ≤ 480 px (less on a phone).
        Flexible(
          child: Text(
            'Install a module first',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: Spacing.sm),
        Semantics(hint: 'Install a module first', child: button),
      ],
    );
  }
}

/// The views tab style, with counts: "Modules 3", "Runs 2" (amber when
/// reviews wait).
class _Tabs extends StatelessWidget {
  const _Tabs({
    required this.controller,
    required this.modules,
    required this.automations,
    required this.reviews,
    required this.onSelect,
    required this.padding,
  });

  final TabController controller;

  /// Null: unknown (the list failed to load), no badge.
  final int? modules;
  final int? automations;
  final int? reviews;
  final ValueChanged<AutomationsTab> onSelect;
  final double padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    Widget tab(String label, int? count, {bool amber = false}) => SizedBox(
      height: 48,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (count != null && (count > 0 || !amber)) ...[
            const SizedBox(width: Spacing.xs),
            CountBadge(count: count, amber: amber),
          ],
        ],
      ),
    );
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: padding - Spacing.sm),
      child: TabBar(
        controller: controller,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        padding: EdgeInsets.zero,
        labelPadding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: scheme.primary, width: 3),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
        ),
        labelColor: scheme.onSurface,
        unselectedLabelColor: scheme.onSurfaceVariant,
        labelStyle: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: theme.textTheme.labelLarge,
        splashBorderRadius: Radii.smAll,
        onTap: (i) => onSelect(AutomationsTab.values[i]),
        tabs: [
          tab('Modules', modules),
          tab('Automations', automations),
          tab('Runs', reviews, amber: true),
        ],
      ),
    );
  }
}

/// A [StatusChip] in a Wrap or Column (the chip hugs its label itself).
class HugChip extends StatelessWidget {
  const HugChip({
    super.key,
    required this.label,
    required this.tone,
    this.icon,
    this.onTap,
  });

  HugChip.of(ChipCopy copy, {Key? key, VoidCallback? onTap})
    : this(
        key: key,
        label: copy.label,
        tone: copy.tone,
        icon: copy.icon,
        onTap: onTap,
      );

  final String label;
  final CopyTone tone;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) =>
      StatusChip(label: label, tone: tone, icon: icon, onTap: onTap);
}

/// A count pill: neutral, or solid amber (`warning` / `onWarning`) for
/// reviews waiting.
class CountBadge extends StatelessWidget {
  const CountBadge({super.key, required this.count, this.amber = false});

  final int count;
  final bool amber;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<MorkvaSemanticColors>()!;
    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: amber
            ? semantic.warning
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: Radii.fullAll,
      ),
      child: Text(
        '$count',
        style: theme.textTheme.labelSmall?.copyWith(
          color: amber
              ? semantic.onWarning
              : theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// The stores couldn't be read (rules, a dead listener): a calm empty
/// state with Retry instead of a raw exception.
class AutomationLoadError extends StatelessWidget {
  const AutomationLoadError({
    super.key,
    required this.title,
    required this.onRetry,
  });

  final String title;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => EmptyState(
    icon: Icons.cloud_off_outlined,
    title: title,
    message: 'Check your connection and try again.',
    action: SecondaryButton(
      label: 'Retry',
      icon: Icons.refresh,
      onPressed: onRetry,
    ),
  );
}

/// A top-of-page banner (`Radii.md`, live region): amber, error or info.
class AutomationBanner extends StatelessWidget {
  const AutomationBanner({
    super.key,
    required this.tone,
    required this.icon,
    required this.title,
    this.body,
    this.action,
    this.details = const [],
  });

  final CopyTone tone;
  final IconData icon;
  final String title;
  final String? body;
  final Widget? action;
  final List<String> details;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = StatusChip.colorsOf(theme, tone);
    final style = theme.textTheme.bodyMedium?.copyWith(
      color: colors.foreground,
    );
    final text = Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          if (body != null) TextSpan(text: ' $body'),
        ],
      ),
      style: style,
    );
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.md,
          vertical: Spacing.sm,
        ),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: Radii.mdAll,
          border: Border.all(color: colors.foreground.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: colors.foreground),
            const SizedBox(width: Spacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  text,
                  for (final d in details)
                    Padding(
                      padding: const EdgeInsets.only(top: Spacing.xxs),
                      child: Text(
                        d,
                        style: MorkvaTypography.mono(
                          theme.textTheme.bodySmall!,
                        ).copyWith(color: colors.foreground),
                      ),
                    ),
                ],
              ),
            ),
            if (action != null) ...[const SizedBox(width: Spacing.sm), action!],
          ],
        ),
      ),
    );
  }
}

/// A titled [SurfaceCard] section whose rows are split by dividers.
class AutomationSection extends StatelessWidget {
  const AutomationSection({
    super.key,
    required this.title,
    required this.children,
    this.trailing,
    this.footer,
    this.divided = true,
    this.dense = false,
  });

  final String title;
  final Widget? trailing;
  final List<Widget> children;
  final Widget? footer;

  /// A rule between the header and the first child: off for prose sections
  /// (About, Apply changes automatically, Code), whose body reads as the
  /// title's continuation.
  final bool divided;

  /// A 14 px title in a ~40 px band (Running now), not the 44 px row.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final divider = Divider(height: 1, color: theme.colorScheme.outlineVariant);
    return SurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (dense)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Spacing.md,
                Spacing.sm,
                Spacing.md,
                Spacing.xs,
              ),
              child: Text(title, style: theme.textTheme.titleSmall),
            )
          else
            Padding(
              padding: EdgeInsets.fromLTRB(
                Spacing.md,
                Spacing.sm,
                Spacing.md,
                divided ? Spacing.sm : 0,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                // Centred in the 44 px row: a title alone sat at its top and
                // left an empty band under it.
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: SizedBox(
                    width: double.infinity,
                    // A Wrap, so a wide trailing (Revoke + Change access) drops
                    // under the title on a phone instead of overflowing.
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      runSpacing: Spacing.xs,
                      children: [
                        Text(title, style: theme.textTheme.titleMedium),
                        ?trailing,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          for (final (i, child) in children.indexed) ...[
            if (divided || i > 0) divider,
            child,
          ],
          if (footer != null) ...[divider, footer!],
        ],
      ),
    );
  }
}

/// A small icon + muted text line ("Imported · 2 automations").
class MetaLine extends StatelessWidget {
  const MetaLine({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: Spacing.xs),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------ modules

class _ModulesTab extends StatelessWidget {
  const _ModulesTab({required this.state, required this.onImport, this.lead});

  final ModulesState state;
  final VoidCallback onImport;

  /// Phone: the tab's actions, the list's first row.
  final Widget? lead;

  @override
  Widget build(BuildContext context) {
    if (state.loading) return const Center(child: LoadingIndicator());
    if (state.loadFailed) {
      return AutomationLoadError(
        title: "Couldn't load modules",
        onRetry: context.read<ModulesCubit>().retry,
      );
    }
    final host = context.read<AutomationsHost>();
    final ask = host.askMorkva;
    if (state.modules.isEmpty) {
      return EmptyState(
        icon: Icons.extension_outlined,
        title: 'No modules yet',
        message:
            'Modules add actions to Morkva — like stamping a date or flagging '
            'low stock. Ask Morkva to write one, or import a .morkva.json file.',
        action: Wrap(
          spacing: Spacing.sm,
          runSpacing: Spacing.sm,
          alignment: WrapAlignment.center,
          children: [
            if (ask != null)
              PrimaryButton(
                label: 'Ask Morkva',
                icon: Icons.auto_awesome_outlined,
                onPressed: () => ask('Write a module that '),
              ),
            SecondaryButton(
              label: 'Import module',
              icon: Icons.upload_outlined,
              onPressed: onImport,
            ),
          ],
        ),
      );
    }
    final collections = automationCollections(context);
    final cards = [
      for (final m in state.modules)
        _ModuleCard(
          entry: m,
          collections: collections,
          onTap: () => host.openModule(m.module.id),
        ),
    ];
    final pad = automationsExpanded(context) ? Spacing.xxl : Spacing.md;
    return LayoutBuilder(
      builder: (context, box) => box.maxWidth - 2 * pad < kTwoColumnWidth
          ? _oneColumn([
              if (lead != null)
                Align(alignment: Alignment.centerRight, child: lead),
              ...cards,
            ], pad)
          : _twoColumns(cards, pad),
    );
  }

  Widget _oneColumn(List<Widget> cards, double pad) => ListView.separated(
    padding: EdgeInsets.fromLTRB(pad, Spacing.md, pad, Spacing.xl),
    itemCount: cards.length,
    separatorBuilder: (_, _) => const SizedBox(height: Spacing.md),
    itemBuilder: (_, i) => cards[i],
  );

  Widget _twoColumns(List<Widget> cards, double pad) => ListView(
    padding: EdgeInsets.fromLTRB(pad, Spacing.md, pad, Spacing.xl),
    children: [
      for (var i = 0; i < cards.length; i += 2)
        Padding(
          padding: const EdgeInsets.only(bottom: Spacing.md),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: cards[i]),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: i + 1 < cards.length
                      ? cards[i + 1]
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
    ],
  );
}

/// The module's glyph: its first action's icon, tinted by module id.
class ModuleGlyph extends StatelessWidget {
  const ModuleGlyph({super.key, required this.module, this.size = 40});

  final ModuleRecord module;
  final double size;

  @override
  Widget build(BuildContext context) => CollectionGlyph(
    iconKey: module.manifest?.actions.firstOrNull?.icon,
    tintSeed: module.id,
    size: size,
    iconSize: size * 0.5,
  );
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({
    required this.entry,
    required this.collections,
    required this.onTap,
  });

  final ModuleEntry entry;
  final List<Collection> collections;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final module = entry.module;
    final n = entry.automations;
    final description = module.manifest?.description;
    return SurfaceCard(
      onTap: onTap,
      semanticLabel: module.name,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ModuleGlyph(module: module),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              module.name,
                              style: theme.textTheme.titleMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: Spacing.xs),
                          OptionPill(label: 'v${module.version}'),
                        ],
                      ),
                    ),
                    const SizedBox(width: Spacing.xs),
                    HugChip.of(moduleChip(entry.status)),
                  ],
                ),
                if (description != null) ...[
                  const SizedBox(height: Spacing.xxs),
                  Text(description, style: theme.textTheme.bodyMedium),
                ],
                const SizedBox(height: Spacing.sm),
                Divider(height: 1, color: theme.colorScheme.outlineVariant),
                const SizedBox(height: Spacing.sm),
                MetaLine(
                  icon: Icons.shield_outlined,
                  text: permissionSummary(entry, collections),
                ),
                const SizedBox(height: Spacing.xxs),
                MetaLine(
                  icon: module.source == ModuleSource.assistant
                      ? Icons.auto_awesome_outlined
                      : Icons.download_outlined,
                  text:
                      '${module.source == ModuleSource.assistant ? 'Made by Ask Morkva' : 'Imported'}'
                      ' · ${n == 1 ? '1 automation' : '$n automations'}',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------- automations

class _AutomationsTab extends StatelessWidget {
  const _AutomationsTab({required this.state, this.collectionId, this.lead});

  final ModulesState state;
  final String? collectionId;

  /// Phone: the tab's action, the list's first row.
  final Widget? lead;

  @override
  Widget build(BuildContext context) {
    if (state.loading) return const Center(child: LoadingIndicator());
    if (state.loadFailed) {
      return AutomationLoadError(
        title: "Couldn't load automations",
        onRetry: context.read<ModulesCubit>().retry,
      );
    }
    final host = context.read<AutomationsHost>();
    final collections = automationCollections(context);
    final pad = automationsExpanded(context) ? Spacing.xxl : Spacing.md;
    final filtered = collectionId == null
        ? state.automations
        : state.automationsIn(collectionId!);
    final groups = <String, List<AutomationEntry>>{};
    for (final a in filtered) {
      (groups[a.automation.trigger.collectionId] ??= []).add(a);
    }
    final chip = collectionId == null
        ? null
        : Align(
            alignment: Alignment.centerLeft,
            child: FilterChipButton(
              label:
                  collectionOf(collections, collectionId!)?.name ??
                  'This collection',
              selected: true,
              onClear: () =>
                  host.openAutomations(tab: AutomationsTab.automations),
            ),
          );
    final leadRow = lead == null
        ? null
        : Padding(
            padding: const EdgeInsets.only(bottom: Spacing.xs),
            child: Align(alignment: Alignment.centerRight, child: lead),
          );
    if (filtered.isEmpty) {
      final noModules = state.modules.isEmpty;
      return Column(
        children: [
          // The empty state has its own New automation; not the hint.
          if (leadRow != null && noModules)
            Padding(
              padding: EdgeInsets.fromLTRB(pad, Spacing.md, pad, 0),
              child: leadRow,
            ),
          if (chip != null)
            Padding(
              padding: EdgeInsets.fromLTRB(pad, Spacing.md, pad, 0),
              child: chip,
            ),
          Expanded(
            child: EmptyState(
              icon: Icons.bolt_outlined,
              title: 'No automations yet',
              message:
                  "Put a module's action on a button, or run it when cards are "
                  'created, changed or deleted.',
              action: noModules
                  ? null
                  : PrimaryButton(
                      label: 'New automation',
                      icon: Icons.add,
                      onPressed: () =>
                          host.newAutomation(collectionId: collectionId),
                    ),
            ),
          ),
        ],
      );
    }
    final theme = Theme.of(context);
    return ListView(
      padding: EdgeInsets.fromLTRB(pad, Spacing.md, pad, Spacing.xl),
      children: [
        ?leadRow,
        ?chip,
        for (final MapEntry(key: id, value: list) in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.only(top: Spacing.sm, bottom: Spacing.xs),
            child: Row(
              children: [
                CollectionGlyph(
                  iconKey: collectionOf(collections, id)?.icon,
                  tintSeed: id,
                  size: 24,
                  iconSize: 14,
                ),
                const SizedBox(width: Spacing.xs),
                Text(
                  collectionOf(collections, id)?.name ?? 'Removed collection',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(width: Spacing.xs),
                Text(
                  '${list.length}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          for (final a in list)
            Padding(
              padding: const EdgeInsets.only(bottom: Spacing.xs),
              child: AutomationRowTile(
                entry: a,
                collection: collectionOf(collections, id),
              ),
            ),
        ],
      ],
    );
  }
}

/// The icon tile of an automation: its button's icon on its tint, or a bolt.
class AutomationTile extends StatelessWidget {
  const AutomationTile({super.key, required this.automation, this.size = 40});

  final AutomationRecord automation;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final button = automation.button;
    if (button == null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(size * 0.3),
        ),
        child: Icon(
          Icons.bolt_outlined,
          size: size * 0.5,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }
    // The same tint the button itself is drawn with.
    final tint = buttonTintOf(
      button.tint,
      automation.trigger.collectionId,
      theme.brightness,
    );
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tint.background,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(
        CollectionIcons.byKey(button.icon),
        size: size * 0.5,
        color: tint.foreground,
      ),
    );
  }
}

/// One automation (UX §1b): tile, name, when line, "Do:" line, the apply and
/// status chips and the enabled switch. [compact] (module details) puts the
/// chips under the text and drops the "Do:" line.
class AutomationRowTile extends StatelessWidget {
  const AutomationRowTile({
    super.key,
    required this.entry,
    required this.collection,
    this.compact = false,
  });

  final AutomationEntry entry;
  final Collection? collection;
  final bool compact;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) =>
        _build(context, inline: !compact && box.maxWidth >= 600),
  );

  Widget _build(BuildContext context, {required bool inline}) {
    final theme = Theme.of(context);
    final host = context.read<AutomationsHost>();
    final modules = context.read<ModulesCubit>();
    final a = entry.automation;
    final status = automationChip(entry.status);
    final apply = applyChip(entry.apply);
    final applyChipW = HugChip.of(
      apply,
      onTap: entry.apply == EffectiveApply.autoOff
          ? () => host.openModule(a.moduleId)
          : null,
    );
    final statusChipW = status == null
        ? null
        : HugChip.of(
            status,
            onTap: switch (entry.status) {
              AutomationStatus.needsConsent => () => host.openModule(
                a.moduleId,
              ),
              AutomationStatus.broken => () => host.editAutomation(a.id),
              AutomationStatus.crashed ||
              AutomationStatus.loopSuspected => () => modules.resume(a.id),
              _ => null,
            },
          );
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final chips = [
      applyChipW,
      if (statusChipW != null) ...[
        const SizedBox(width: Spacing.xs),
        statusChipW,
      ],
    ];
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          a.name,
          style: compact
              ? theme.textTheme.titleSmall
              : theme.textTheme.titleMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          whenLine(a.trigger, collection),
          style: muted,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (!compact)
          Text(
            doLine(entry),
            style: muted,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        if (!inline) ...[
          const SizedBox(height: Spacing.xxs),
          Wrap(
            spacing: Spacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [applyChipW, ?statusChipW],
          ),
        ],
      ],
    );
    final row = Row(
      children: [
        AutomationTile(automation: a),
        const SizedBox(width: Spacing.sm),
        Expanded(child: text),
        if (inline) ...[const SizedBox(width: Spacing.sm), ...chips],
        const SizedBox(width: Spacing.sm),
        Semantics(
          label: '${a.name} enabled',
          child: Switch(
            value: a.enabled,
            onChanged: (on) => modules.setEnabled(a.id, on),
          ),
        ),
      ],
    );
    void onTap() => host.editAutomation(a.id);
    if (compact) {
      return InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.md,
            vertical: Spacing.sm,
          ),
          child: row,
        ),
      );
    }
    return SurfaceCard(
      onTap: onTap,
      semanticLabel: a.name,
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.md,
        vertical: Spacing.sm,
      ),
      child: row,
    );
  }
}

// --------------------------------------------------------------------- runs

/// A filter chip (Runs tab, the collection chip): 44 px hit area; with
/// [onClear] it shows "✕" and clears.
class FilterChipButton extends StatelessWidget {
  const FilterChipButton({
    super.key,
    required this.label,
    this.selected = false,
    this.count,
    this.onTap,
    this.onClear,
  });

  final String label;
  final bool selected;
  final int? count;
  final VoidCallback? onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final pill = Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
      decoration: BoxDecoration(
        color: selected ? scheme.primaryContainer : scheme.surface,
        borderRadius: Radii.smAll,
        border: Border.all(
          color: selected ? scheme.primaryContainer : scheme.outline,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (selected && onClear == null) ...[
            Icon(Icons.check, size: 16, color: scheme.onPrimaryContainer),
            const SizedBox(width: Spacing.xxs),
          ],
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: selected ? scheme.onPrimaryContainer : scheme.onSurface,
            ),
          ),
          if (count != null && count! > 0) ...[
            const SizedBox(width: Spacing.xs),
            CountBadge(count: count!, amber: true),
          ],
          if (onClear != null) ...[
            const SizedBox(width: Spacing.xxs),
            Icon(Icons.close, size: 16, color: scheme.onPrimaryContainer),
          ],
        ],
      ),
    );
    return PressableScale(
      onPressed: onClear ?? onTap,
      semanticLabel: onClear == null ? label : 'Clear $label',
      borderRadius: Radii.smAll,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Center(widthFactor: 1, child: pill),
      ),
    );
  }
}

class _RunsTab extends StatelessWidget {
  const _RunsTab({
    required this.state,
    required this.automations,
    required this.now,
  });

  final RunLogState state;
  final List<AutomationEntry> automations;
  final DateTime Function() now;

  @override
  Widget build(BuildContext context) {
    if (state.loading) return const Center(child: LoadingIndicator());
    final runLog = context.read<RunLogCubit>();
    if (state.loadFailed) {
      return AutomationLoadError(
        title: "Couldn't load runs",
        onRetry: runLog.retry,
      );
    }
    final host = context.read<AutomationsHost>();
    final filter = state.filter;
    final pad = automationsExpanded(context) ? Spacing.xxl : Spacing.md;
    final picked = automations
        .where((a) => a.automation.id == filter.automationId)
        .firstOrNull;
    void go(RunFilterKind kind) => host.openAutomations(
      tab: AutomationsTab.runs,
      filter: kind == RunFilterKind.all ? null : kind,
      cardId: filter.cardId,
      moduleId: filter.moduleId,
    );
    final cardLabel = filter.cardId == null
        ? null
        : state.rows
                  .where((r) => r.run.trigger.cardId == filter.cardId)
                  .firstOrNull
                  ?.run
                  .trigger
                  .cardLabel ??
              'This card';
    final moduleName = filter.moduleId == null
        ? null
        : state.rows
                  .where((r) => r.run.moduleId == filter.moduleId)
                  .firstOrNull
                  ?.run
                  .moduleName ??
              'This module';
    final chips = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: pad),
      child: Row(
        children: [
          FilterChipButton(
            label: 'All',
            selected: filter.kind == RunFilterKind.all,
            onTap: () => go(RunFilterKind.all),
          ),
          const SizedBox(width: Spacing.xs),
          FilterChipButton(
            label: 'Needs review',
            count: state.needsReview,
            selected: filter.kind == RunFilterKind.review,
            onTap: () => go(RunFilterKind.review),
          ),
          const SizedBox(width: Spacing.xs),
          FilterChipButton(
            label: 'Failed',
            selected: filter.kind == RunFilterKind.failed,
            onTap: () => go(RunFilterKind.failed),
          ),
          const SizedBox(width: Spacing.xs),
          // '' = any: a null value reads as a cancelled menu.
          PopupMenuButton<String>(
            tooltip: 'Filter by automation',
            onSelected: (id) => runLog.setFilter(
              RunFilter(
                kind: filter.kind,
                automationId: id.isEmpty ? null : id,
                moduleId: filter.moduleId,
                cardId: filter.cardId,
              ),
            ),
            itemBuilder: (_) => [
              const PopupMenuItem(value: '', child: Text('Any automation')),
              for (final a in automations)
                PopupMenuItem(
                  value: a.automation.id,
                  child: Text(a.automation.name),
                ),
            ],
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Spacing.xs),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bolt_outlined, size: 18),
                    const SizedBox(width: Spacing.xxs),
                    Text(
                      picked?.automation.name ?? 'Any automation',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const Icon(Icons.expand_more, size: 18),
                  ],
                ),
              ),
            ),
          ),
          if (cardLabel != null) ...[
            const SizedBox(width: Spacing.xs),
            FilterChipButton(
              label: cardLabel,
              selected: true,
              onClear: () => host.openAutomations(
                tab: AutomationsTab.runs,
                filter: filter.kind == RunFilterKind.all ? null : filter.kind,
                moduleId: filter.moduleId,
              ),
            ),
          ],
          if (moduleName != null) ...[
            const SizedBox(width: Spacing.xs),
            FilterChipButton(
              label: moduleName,
              selected: true,
              onClear: () => host.openAutomations(
                tab: AutomationsTab.runs,
                filter: filter.kind == RunFilterKind.all ? null : filter.kind,
                cardId: filter.cardId,
              ),
            ),
          ],
        ],
      ),
    );
    final entries = state.entries;
    final live = state.live;
    return ListView(
      padding: const EdgeInsets.only(top: Spacing.sm, bottom: Spacing.xl),
      children: [
        chips,
        const SizedBox(height: Spacing.sm),
        if (live.isNotEmpty)
          Padding(
            padding: EdgeInsets.fromLTRB(pad, 0, pad, Spacing.md),
            child: AutomationSection(
              title: 'Running now',
              dense: true,
              children: [
                for (final r in live)
                  LiveRunTile(run: r, onStop: () => runLog.stop(r.runId)),
              ],
            ),
          ),
        if (entries.isEmpty && live.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: Spacing.xl),
            child: EmptyState(
              icon: Icons.history,
              title: 'No runs yet',
              message:
                  'When an automation runs, its log shows up here — what '
                  'triggered it, what it read, what it changed.',
            ),
          )
        else if (entries.isNotEmpty)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: pad),
            child: SurfaceCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final (i, e) in entries.indexed) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    switch (e) {
                      RunEntryRow(:final row) => RunRowTile(
                        row: row,
                        now: now(),
                      ),
                      RunEntryGroup() => _GroupRow(
                        group: e,
                        onShow: () => runLog.expand(e.key),
                      ),
                    },
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _GroupRow extends StatelessWidget {
  const _GroupRow({required this.group, required this.onShow});

  final RunEntryGroup group;
  final VoidCallback onShow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
      child: Row(
        children: [
          const RunStatusIcon(status: RunStatus.skipped),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Text(
              '${group.count} skipped · ${group.rows.first.copy.row}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          TextActionButton(label: 'Show', onPressed: onShow),
        ],
      ),
    );
  }
}

/// The status glyph of a run row (UX §1c).
class RunStatusIcon extends StatelessWidget {
  const RunStatusIcon({
    super.key,
    required this.status,
    this.reason,
    this.undone = false,
  });

  final RunStatus status;
  final RunReason? reason;
  final bool undone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final semantic = theme.extension<MorkvaSemanticColors>()!;
    final muted = scheme.onSurfaceVariant;
    Widget icon(IconData data, Color color) =>
        Icon(data, size: 20, color: color);
    final child = switch (status) {
      RunStatus.running ||
      RunStatus.sealing ||
      RunStatus.applying => SizedBox.square(
        dimension: 16,
        child: CircularProgressIndicator(strokeWidth: 2, color: semantic.info),
      ),
      RunStatus.queued => icon(Icons.schedule, muted),
      RunStatus.awaitingReview => Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: semantic.warning,
          shape: BoxShape.circle,
          border: Border.all(color: semantic.warningContainer, width: 3),
        ),
      ),
      RunStatus.succeeded when undone => icon(Icons.undo, muted),
      RunStatus.succeeded => icon(Icons.check_circle_outline, semantic.success),
      RunStatus.failed when reason == RunReason.interrupted => icon(
        Icons.help_outline,
        semantic.warning,
      ),
      RunStatus.failed when reason == RunReason.cancelled => icon(
        Icons.cancel_outlined,
        muted,
      ),
      RunStatus.failed ||
      RunStatus.timedOut => icon(Icons.cancel_outlined, scheme.error),
      RunStatus.skipped => icon(Icons.block, muted),
      RunStatus.expired => icon(Icons.hourglass_disabled_outlined, muted),
      RunStatus.rejected => icon(Icons.close, muted),
    };
    return SizedBox.square(dimension: 24, child: Center(child: child));
  }
}

/// A queued / running run with Stop ("Running now").
class LiveRunTile extends StatelessWidget {
  const LiveRunTile({super.key, required this.run, required this.onStop});

  final RunView run;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = run.progress;
    final where = run.trigger.cardLabel ?? '';
    // "Stamp when shipped · Stamp", as the run rows below read.
    final name = context
        .read<ModulesCubit>()
        .state
        .automations
        .where((a) => a.automation.id == run.automationId)
        .firstOrNull
        ?.automation
        .name;
    final title = name == null || name == run.label
        ? run.label
        : '$name · ${run.label}';
    final second = switch (run.status) {
      RunStatus.queued =>
        'Queued${run.queuedAhead == null ? '' : ' · ${run.queuedAhead} ahead'}',
      RunStatus.applying => 'Applying…',
      _ => 'Running',
    };
    return Padding(
      padding: const EdgeInsets.only(left: Spacing.md, right: Spacing.xs),
      child: Row(
        children: [
          RunStatusIcon(status: run.status),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  [
                    second,
                    if (where.isNotEmpty) where,
                    if (p != null) '${p.done}/${p.total}',
                  ].join(' · '),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (run.status != RunStatus.applying)
            TextActionButton(label: 'Stop', onPressed: onStop),
        ],
      ),
    );
  }
}

/// One run row (UX §1c): status, title, the summary or reason, the card,
/// when, how long, and the trailing action. Tap → run detail.
class RunRowTile extends StatelessWidget {
  const RunRowTile({
    super.key,
    required this.row,
    required this.now,
    this.compact = false,
  });

  final RunRow row;
  final DateTime now;

  /// Module details' recent runs: the card over "when · how long".
  final bool compact;

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, box) => _build(context, box.maxWidth));

  Widget _build(BuildContext context, double width) {
    final theme = Theme.of(context);
    final host = context.read<AutomationsHost>();
    final runLog = context.read<RunLogCubit>();
    final offline = automationsOffline(context);
    final run = row.run;
    final mutedRow =
        row.copy.tone == CopyTone.muted || run.status == RunStatus.skipped;
    final ink = mutedRow
        ? theme.colorScheme.onSurfaceVariant
        : theme.colorScheme.onSurface;
    final card = run.trigger.cardLabel;
    // The card column: the card, or the collection a collection run ran on.
    final where =
        card ??
        collectionOf(
          automationCollections(context),
          run.trigger.collectionId,
        )?.name;
    final title = [
      run.automationName ?? run.moduleName,
      run.actionLabel,
    ].join(' · ');
    final changedAt = run.trigger.changedAt;
    // The table layout has a card column; the narrow one puts the card in
    // the second line instead ("Expired · #1039").
    final table = !compact && width >= 680;
    final cardColumn = table || (compact && width >= 420);
    final notHere = row.display == RunDisplay.reviewNotHere;
    final what = switch (run) {
      _ when run.count > 1 => 'Skipped ${run.count} times · ${row.copy.row}',
      RunRecord(status: RunStatus.succeeded) when run.undoneAt != null => [
        'Undone',
        ?run.summary,
      ].join(' · '),
      RunRecord(status: RunStatus.succeeded, :final summary?) => summary,
      _ when notHere => '${row.copy.row} — ${_clause(row.copy.detail)}',
      // "Needs your review · 1 change" (run detail has the plan title).
      RunRecord(status: RunStatus.awaitingReview, :final log)
          when log.plan.isNotEmpty =>
        '${row.copy.row} · ${changeCount(log)}',
      RunRecord(status: RunStatus.awaitingReview, :final planTitle?) =>
        '${row.copy.row} · $planTitle',
      _ => row.copy.row,
    };
    final second = [
      what,
      if (!cardColumn && where != null && !what.contains(where)) where,
      if (changedAt != null &&
          run.startedAt.difference(changedAt).inMinutes >= 1)
        'Changed offline ${clock(changedAt)} · ran ${clock(run.startedAt)}',
    ].join(' · ');
    final action = switch (row.action) {
      RunRowAction.none => null,
      RunRowAction.review => SecondaryButton(
        label: 'Review',
        onPressed: () => host.review(run.id),
      ),
      RunRowAction.runAgain => _RunAgain(
        // The table shows the card a column away; "Run again on Order
        // #1047" truncated in its 200 px slot.
        label: card == null || notHere || table
            ? 'Run again'
            : 'Run again on $card',
        offline: offline,
        onPressed: () => runLog.runAgain(run.id),
      ),
      RunRowAction.reviewPermissions => TextActionButton(
        label: 'Review permissions',
        icon: Icons.shield_outlined,
        onPressed: () => host.openModule(run.moduleId),
      ),
      RunRowAction.editAutomation => TextActionButton(
        label: 'Edit automation',
        icon: Icons.edit_outlined,
        onPressed: () => host.editAutomation(run.automationId!),
      ),
    };
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final status = notHere
        ? const _ReviewNotHereIcon()
        : RunStatusIcon(
            status: row.display == RunDisplay.outcomeUnknown
                ? RunStatus.failed
                : run.status,
            reason: row.display == RunDisplay.outcomeUnknown
                ? RunReason.interrupted
                : run.reason,
            undone: run.undoneAt != null,
          );
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(color: ink),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          second,
          style: muted,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
    final Widget body;
    final cardText = Text(
      where ?? '',
      style: theme.textTheme.bodyMedium?.copyWith(color: ink),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    if (compact && width >= 420) {
      body = Row(
        children: [
          status,
          const SizedBox(width: Spacing.sm),
          Expanded(child: text),
          const SizedBox(width: Spacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              cardText,
              Text(
                '${agoLabel(run.startedAt, now)} · '
                '${durationLabel(run.durationMs)}',
                style: muted,
              ),
            ],
          ),
          if (action != null) ...[const SizedBox(width: Spacing.sm), action],
        ],
      );
    } else if (table) {
      body = Row(
        children: [
          status,
          const SizedBox(width: Spacing.sm),
          Expanded(child: text),
          const SizedBox(width: Spacing.sm),
          SizedBox(width: 104, child: cardText),
          SizedBox(
            width: 96,
            child: Text(agoLabel(run.startedAt, now), style: muted),
          ),
          SizedBox(
            width: 64,
            child: Text(durationLabel(run.durationMs), style: muted),
          ),
          SizedBox(
            width: 200,
            child: Align(alignment: Alignment.centerRight, child: action),
          ),
        ],
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              status,
              const SizedBox(width: Spacing.sm),
              Expanded(child: text),
              const SizedBox(width: Spacing.xs),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(agoLabel(run.startedAt, now), style: muted),
                  Text(durationLabel(run.durationMs), style: muted),
                ],
              ),
            ],
          ),
          if (action != null)
            // The status glyph's 24 + its gap, less the button's own start
            // padding (both Spacing.sm): the icon lines up with the title.
            Padding(padding: const EdgeInsets.only(left: 24), child: action),
        ],
      );
    }
    return InkWell(
      onTap: () => host.openRun(run.id),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.md,
            vertical: Spacing.xs,
          ),
          child: body,
        ),
      ),
    );
  }
}

/// "1 change", "200 changes": the plan's rows, those past the log's row cap
/// too.
String changeCount(RunLog log) {
  final n = log.plan.length + log.dropped.plan;
  return '$n ${n == 1 ? 'change' : 'changes'}';
}

/// "It was opened in another window." → "it was opened in another window".
String _clause(String sentence) {
  final s = sentence.endsWith('.')
      ? sentence.substring(0, sentence.length - 1)
      : sentence;
  return s.isEmpty ? s : s[0].toLowerCase() + s.substring(1);
}

/// A review another window holds: a muted ring, not the amber dot of a
/// review this tab can open.
class _ReviewNotHereIcon extends StatelessWidget {
  const _ReviewNotHereIcon();

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 24,
    child: Center(
      child: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            width: 1.5,
          ),
        ),
      ),
    ),
  );
}

/// "Run again", or disabled offline with the visible reason.
class _RunAgain extends StatelessWidget {
  const _RunAgain({
    required this.label,
    required this.offline,
    required this.onPressed,
  });

  final String label;
  final bool offline;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final button = TextActionButton(
      label: label,
      icon: Icons.refresh,
      onPressed: offline ? null : onPressed,
    );
    if (!offline) return button;
    final theme = Theme.of(context);
    return Semantics(
      hint: 'Needs a connection',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          button,
          Text(
            'Needs a connection',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Stops a timer-driven widget from leaking past its state.
mixin TickerRefresh<T extends StatefulWidget> on State<T> {
  Timer? _ticker;

  /// Rebuilds every [period] while [active]; [onTick] runs first.
  void tickWhile(
    bool active, {
    Duration period = const Duration(seconds: 1),
    VoidCallback? onTick,
  }) {
    if (!active) {
      _ticker?.cancel();
      _ticker = null;
      return;
    }
    _ticker ??= Timer.periodic(period, (_) {
      if (!mounted) return;
      onTick?.call();
      setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
