import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../api/api.dart';
import '../../api/assistant/thread_repository.dart';
import '../../core/domain/automation/automation.dart';
import '../../core/domain/domain.dart';
import '../../design/design.dart';
import '../../features/assistant/bloc/assistant_bloc.dart';
import '../../features/assistant/bloc/assistant_panel_cubit.dart';
import '../../features/assistant/bloc/assistant_session.dart';
import '../../features/assistant/bloc/assistant_state.dart';
import '../../features/assistant/bloc/chat_item.dart';
import '../../features/assistant/bloc/thread_list_cubit.dart';
import '../../features/assistant/host/router_ui_port.dart';
import '../../features/assistant/view/assistant_actions.dart';
import '../../features/assistant/view/assistant_panel.dart';
import '../../features/assistant/view/thread_list_page.dart';
import '../../features/assistant/view/widgets/sparkle_icon.dart';
import '../../features/auth/conflict_warning_banner.dart';
import '../../features/automation/bloc/automation_runs_cubit.dart';
import '../../features/automation/bloc/modules_cubit.dart';
import '../../features/automation/bloc/run_log_cubit.dart';
import '../../features/automation/view/automation_editor_sheet.dart';
import '../../features/automation/view/automations_page.dart';
import '../../features/automation/view/code_viewer.dart';
import '../../features/automation/view/review_sheet.dart';
import '../../features/automation/widgets/action_buttons.dart';
import '../../features/automation/widgets/collection_actions_menu.dart';
import '../../features/automation/widgets/run_indicator.dart';
import '../../features/collections/collections.dart';
import '../../features/views/view_link.dart';
import '../../l10n/l10n.dart';
import 'app_shell.dart';
import 'brand_wordmark.dart';
import 'jump_to_dialog.dart';
import 'shell_sidebar.dart';

/// The persistent shell around every page of the app's [ShellRoute].
///
/// Owns the workspace's [CollectionsListCubit] and [PinnedCollectionsCubit]
/// (shared by the sidebar and the All collections page) and wires the dumb
/// [AppShell] / [ShellSidebar] to the router: what's selected comes from the
/// location, taps navigate. Built once, so the sidebar never rebuilds
/// between pages.
class AppShellScaffold extends StatelessWidget {
  const AppShellScaffold({
    super.key,
    required this.child,
    this.collectionId,
    this.inSettings = false,
    this.inAutomations = false,
    this.automationsDetail = false,
  });

  /// The routed page (the shell's navigator).
  final Widget child;

  /// The open collection, when a collection page is shown. It draws its own
  /// header and banner (wide) or its own full-screen app bar (phone).
  final String? collectionId;

  /// The settings page is shown.
  final bool inSettings;

  /// An `/automations` page is shown.
  final bool inAutomations;

  /// Module details or run detail: they draw their own back link.
  final bool automationsDetail;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) =>
              CollectionsListCubit(context.read<DataRepository>())
                ..initialize(),
        ),
        BlocProvider(create: (_) => SidebarExtendedCubit()),
        BlocProvider(
          create: (context) =>
              PinnedCollectionsCubit(context.read<DataRepository>())
                ..initialize(),
        ),
      ],
      child: _ShellView(
        collectionId: collectionId,
        inSettings: inSettings,
        inAutomations: inAutomations,
        automationsDetail: automationsDetail,
        child: child,
      ),
    );
  }
}

class _ShellView extends StatefulWidget {
  const _ShellView({
    required this.child,
    required this.collectionId,
    required this.inSettings,
    required this.inAutomations,
    required this.automationsDetail,
  });

  final Widget child;
  final String? collectionId;
  final bool inSettings;
  final bool inAutomations;
  final bool automationsDetail;

  @override
  State<_ShellView> createState() => _ShellViewState();
}

class _ShellViewState extends State<_ShellView> {
  /// Keeps the panel (scroll, history pane) when a resize moves it between
  /// beside the page and over it.
  final _panelKey = GlobalKey();

  /// What had focus before the panel opened; it gets focus back on close.
  FocusNode? _opener;

  /// Focused on open: `autofocus` alone loses to the page's route, which
  /// already holds the shell's focus scope.
  final _composerFocus = FocusNode(debugLabel: 'Ask Morkva composer');

  /// One instance, so a shell rebuild does not rebuild the whole chat
  /// (the assistant scope compares its actions).
  SessionAssistantActions? _actions;

  /// The panel is a sheet over the page, as last laid out.
  bool _sheet = false;

  /// The automation pages' way into the app.
  late final _automationsHost = _ShellAutomationsHost(this);

  /// Opens Ask Morkva with the composer prefilled; null while it is flagged
  /// off.
  void Function(String draft)? _openAssistant;

  SessionAssistantActions _actionsFor(
    AssistantSession assistant, {
    required bool sheet,
  }) {
    _sheet = sheet;
    return _actions ??= SessionAssistantActions(
      assistant.bloc,
      RouterUiPort(() => GoRouter.of(context)),
      // A sheet over the page would hide what was just opened.
      onNavigated: () {
        if (_sheet) assistant.panel.hide();
      },
      onViewCode: (code) => showCodeViewer(context, code: code),
    );
  }

  @override
  void dispose() {
    _composerFocus.dispose();
    super.dispose();
  }

  ShellPlace get _place => widget.collectionId != null
      ? ShellPlace.collection
      : widget.inSettings
      ? ShellPlace.settings
      : widget.inAutomations
      ? ShellPlace.automations
      : ShellPlace.allCollections;

  void _onPanelChanged(bool open) {
    if (open) {
      _opener = FocusManager.instance.primaryFocus;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_composerFocus.context != null) _composerFocus.requestFocus();
      });
      return;
    }
    final opener = _opener;
    _opener = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (opener != null && opener.context != null && opener.canRequestFocus) {
        opener.requestFocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = _assistantSessionOf(context);
    if (session == null) return _shell(context, null, false);
    return MultiBlocListener(
      listeners: [
        BlocListener<AssistantPanelCubit, bool>(
          bloc: session.panel,
          listener: (_, open) => _onPanelChanged(open),
        ),
        // The flag went off with the panel open.
        BlocListener<AssistantBloc, AssistantState>(
          bloc: session.bloc,
          listenWhen: (a, b) => _flagOff(b) && !_flagOff(a),
          listener: (_, _) => session.panel.hide(),
        ),
      ],
      child: BlocSelector<AssistantBloc, AssistantState, bool>(
        bloc: session.bloc,
        selector: (s) => !_flagOff(s),
        builder: (context, enabled) => BlocBuilder<AssistantPanelCubit, bool>(
          bloc: session.panel,
          builder: (context, open) =>
              _shell(context, enabled ? session : null, open && enabled),
        ),
      ),
    );
  }

  /// The shell; [assistant] null hides every Ask Morkva entry.
  Widget _shell(
    BuildContext context,
    AssistantSession? assistant,
    bool assistantOpen,
  ) {
    final collectionId = widget.collectionId;
    final inSettings = widget.inSettings;
    final state = context.watch<CollectionsListCubit>().state;
    final collections = state is CollectionsListReady
        ? state.collections
        : const <Collection>[];
    final pins = context.watch<PinnedCollectionsCubit>();
    final pinned = pinnedCollections(pins.state, collections);
    final authState = context.watch<AuthCubit>().state;
    final user = authState is AuthAuthenticated ? authState.user : null;
    final router = GoRouter.of(context);

    void openAll() => router.go('/');
    void openSettings() => router.go('/settings');
    void openCollection(String id) => router.go('/collections/$id');
    // Idle: the page itself; else the Runs tab filtered to what needs a look.
    void openAutomations() {
      final runs = maybeRead<AutomationRunsCubit>(context);
      router.go(
        runs == null || runs.primary == IndicatorState.idle
            ? '/automations'
            : runIndicatorPathOf(context),
      );
    }

    Future<void> jumpTo() async {
      final rest = [
        for (final c in collections)
          if (!pinned.contains(c)) c,
      ];
      final id = await showJumpToDialog(context, [...pinned, ...rest]);
      if (id != null) openCollection(id);
    }

    final place = _place;
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= AppShell.expandedBreakpoint;
    final extended = context.watch<SidebarExtendedCubit>().state;
    final inCollection = place == ShellPlace.collection;
    // Phone: the first three pins and All are bottom-bar tabs.
    final tabs = pinned.take(3).toList();
    final isTab =
        !wide && inCollection && tabs.any((c) => c.id == collectionId);

    // Phone: the chat is its own full-screen route.
    final VoidCallback? toggleAssistant = assistant == null
        ? null
        : wide
        ? assistant.panel.toggle
        : () => router.push('/assistant');
    final ask = !wide && toggleAssistant != null
        ? AskMorkvaAction(onTap: toggleAssistant)
        : null;
    _openAssistant = assistant == null
        ? null
        : (draft) {
            assistant.draft.value = draft;
            wide ? assistant.panel.show() : router.push('/assistant');
          };
    final inAutomations = place == ShellPlace.automations;
    final avatar = Tooltip(
      message: context.l10n.shellAccountAndSettings,
      child: InkResponse(
        onTap: openSettings,
        radius: 22,
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: UserAvatar(
            user: user,
            showSync: true,
            dotRing: Theme.of(context).colorScheme.surface,
          ),
        ),
      ),
    );

    final shell = _KeyShortcut(
      keyboardKey: LogicalKeyboardKey.keyK,
      onKey: jumpTo,
      child: _KeyShortcut(
        keyboardKey: LogicalKeyboardKey.keyJ,
        onKey: toggleAssistant,
        child: AppShell(
          extended: extended,
          sidebarBuilder: (context, extended) => ShellSidebar(
            extended: extended,
            place: place,
            collectionId: collectionId,
            pinned: pinned,
            user: user,
            onAllCollections: openAll,
            onToggleExtended: () =>
                context.read<SidebarExtendedCubit>().set(!extended),
            onCollection: openCollection,
            onSettings: openSettings,
            onJumpTo: jumpTo,
            onAssistant: toggleAssistant,
            assistantOpen: assistantOpen,
            onAutomations: openAutomations,
            onUnpin: pins.unpin,
            onReorder: (from, to) =>
                pins.reorder([for (final c in pinned) c.id], from, to),
          ),
          sidePanelBuilder: assistant == null || !assistantOpen
              ? null
              : (context, overlay) => AssistantPanel(
                  key: _panelKey,
                  composerFocus: _composerFocus,
                  bloc: assistant.bloc,
                  draft: assistant.draft,
                  actions: _actionsFor(assistant, sheet: overlay),
                  overlay: overlay,
                  onClose: assistant.panel.hide,
                  historyBuilder: (context, back) =>
                      AssistantHistory(onPicked: back),
                ),
          onDismissSidePanel: assistant?.panel.hide,
          title: inSettings
              ? context.l10n.commonSettings
              : inAutomations
              ? context.l10n.commonAutomations
              : context.l10n.commonCollections,
          // Wide, All collections, Automations and Settings draw their own
          // header; a collection and the automation detail pages always do.
          header:
              inCollection ||
                  widget.automationsDetail ||
                  (wide &&
                      (place == ShellPlace.allCollections ||
                          inAutomations ||
                          inSettings))
              ? const SizedBox.shrink()
              : null,
          // Wide, the sidebar is the way back and carries the brand.
          headerLeading: wide
              ? null
              : inSettings || inAutomations
              ? BackButton(onPressed: openAll)
              : const BrandLogomark(size: 34),
          headerTrailing: Row(
            mainAxisSize: MainAxisSize.min,
            // Phone header buttons need air between them (owner, 2026-11-14).
            spacing: Spacing.xs,
            children: [
              // Phone: hidden while idle.
              if (!wide) const RunIndicatorButton(),
              // Phone: no sidebar, so All collections carries Jump to.
              if (!wide &&
                  place == ShellPlace.allCollections &&
                  collections.isNotEmpty)
                IconButton(
                  tooltip: context.l10n.shellJumpTo,
                  icon: const Icon(MorkvaIcons.search),
                  onPressed: jumpTo,
                ),
              ?ask,
              if (!inSettings && !inAutomations) avatar,
            ],
          ),
          bottomBar:
              tabs.isNotEmpty && (place == ShellPlace.allCollections || isTab)
              ? _PinsBar(
                  tabs: tabs,
                  selectedId: collectionId,
                  onCollection: openCollection,
                  onAll: openAll,
                )
              : null,
          banner: inCollection ? null : const ConflictWarningBanner(),
          showCompactChrome: !inCollection,
          child: ShellTab(
            isTab: isTab,
            onAsk: ask == null ? null : toggleAssistant,
            child: widget.child,
          ),
        ),
      ),
    );
    // The app's one notice host: finish snackbars and collection-button
    // reviews on any page.
    return RepositoryProvider<AutomationsHost>.value(
      value: _automationsHost,
      child: RunNoticeHost(collectionId: collectionId, child: shell),
    );
  }
}

/// [AutomationsHost] over the router and the shell's context.
final class _ShellAutomationsHost implements AutomationsHost {
  _ShellAutomationsHost(this._shell);

  final _ShellViewState _shell;

  BuildContext get _context => _shell.context;

  GoRouter get _router => GoRouter.of(_context);

  @override
  void openAutomations({
    AutomationsTab tab = AutomationsTab.modules,
    String? collectionId,
    String? cardId,
    RunFilterKind? filter,
    String? moduleId,
  }) => _router.go(
    Uri(
      path: '/automations',
      queryParameters: {
        if (tab != AutomationsTab.modules) 'tab': tab.name,
        'collection': ?collectionId,
        'card': ?cardId,
        if (filter != null && filter != RunFilterKind.all)
          'filter': filter.name,
        'module': ?moduleId,
      },
    ).toString(),
  );

  @override
  void openModule(String moduleId) =>
      _router.go(AutomationPaths.module(moduleId));

  @override
  void openRun(String runId) => _router.go(AutomationPaths.run(runId));

  @override
  void openCard(String collectionId, String cardId) =>
      _router.go(collectionLink(collectionId, card: cardId));

  /// Refs per kind: `card` `<cid>/<cardId>`, `view` `<cid>/<viewId>`,
  /// `collection` `<cid>`.
  @override
  void openLink(UiLink link) {
    final slash = link.ref.indexOf('/');
    final collectionId = slash < 0 ? link.ref : link.ref.substring(0, slash);
    final id = slash < 0 ? null : link.ref.substring(slash + 1);
    _router.go(
      collectionLink(
        collectionId,
        card: link.kind == 'card' ? id : null,
        view: link.kind == 'view' ? id : null,
      ),
    );
  }

  @override
  void newAutomation({
    String? moduleId,
    String? actionId,
    String? collectionId,
  }) => unawaited(
    showAutomationEditor(
      _context,
      moduleId: moduleId,
      actionId: actionId,
      collectionId: collectionId,
    ),
  );

  @override
  void editAutomation(String automationId) {
    final existing = maybeRead<ModulesCubit>(_context)?.state.automations
        .where((a) => a.automation.id == automationId)
        .firstOrNull
        ?.automation;
    if (existing == null) return;
    unawaited(showAutomationEditor(_context, existing: existing));
  }

  @override
  void review(String runId) =>
      unawaited(showReviewSheet(_context, runId: runId));

  @override
  void Function(String prefill)? get askMorkva => _shell._openAssistant;

  @override
  Future<({String name, String text})?> pickModuleFile() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    // Malformed text still reaches the parser, which says what is wrong.
    return (name: file.name, text: utf8.decode(bytes, allowMalformed: true));
  }

  @override
  Future<bool> saveFile(String name, String text) async {
    final uri = await FilePicker.saveFile(
      fileName: name,
      bytes: utf8.encode(text),
      mimeType: 'application/json',
    );
    // The web downloads the file; there is no dialog to cancel.
    return kIsWeb || uri != null;
  }
}

bool _flagOff(AssistantState s) => s.availability is AvailabilityDisabledByFlag;

/// The app's [AssistantSession], or null where none is provided (shell
/// tests): no Ask Morkva entries then.
AssistantSession? _assistantSessionOf(BuildContext context) {
  try {
    return context.read<AssistantSession>();
  } on ProviderNotFoundException {
    return null;
  }
}

/// Ctrl/Cmd + [keyboardKey] anywhere in the shell runs [onKey] (null: the
/// key is left alone). A global key handler, not [Shortcuts], so it works
/// when nothing has focus (e.g. after a click).
class _KeyShortcut extends StatefulWidget {
  const _KeyShortcut({
    required this.keyboardKey,
    required this.onKey,
    required this.child,
  });

  final LogicalKeyboardKey keyboardKey;
  final FutureOr<void> Function()? onKey;
  final Widget child;

  @override
  State<_KeyShortcut> createState() => _KeyShortcutState();
}

class _KeyShortcutState extends State<_KeyShortcut> {
  bool _running = false;

  bool _onKey(KeyEvent event) {
    final keys = HardwareKeyboard.instance;
    final onKey = widget.onKey;
    if (onKey == null ||
        event is! KeyDownEvent ||
        event.logicalKey != widget.keyboardKey ||
        !(keys.isControlPressed || keys.isMetaPressed)) {
      return false;
    }
    // Only from the shell itself: not over a dialog or a full-screen route.
    if (_running || !(ModalRoute.of(context)?.isCurrent ?? true)) return false;
    _running = true;
    Future.sync(onKey).whenComplete(() => _running = false);
    return true;
  }

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Phone: the tinted sparkle in a page's header; opens `/assistant`.
class AskMorkvaAction extends StatelessWidget {
  const AskMorkvaAction({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const radius = BorderRadius.all(Radius.circular(14));
    return Tooltip(
      message: context.l10n.shellAskMorkva,
      child: PressableScale(
        onPressed: onTap,
        semanticLabel: context.l10n.shellAskMorkva,
        borderRadius: radius,
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: radius,
          ),
          child: SparkleIcon(
            size: 22,
            color: theme.extension<MorkvaSemanticColors>()!.primaryText,
          ),
        ),
      ),
    );
  }
}

/// [AssistantActions] over the session's bloc: each intent is the named
/// event; chips and "Open as filtered view" navigate through [RouterUiPort]
/// (which pops the phone chat first), then [onNavigated] runs.
final class SessionAssistantActions implements AssistantActions {
  SessionAssistantActions(
    this._bloc,
    this._ui, {
    this.onNavigated,
    this.onViewCode,
  });

  final AssistantBloc _bloc;
  final RouterUiPort _ui;
  final VoidCallback? onNavigated;

  /// Opens the read-only code viewer over a module's script.
  final void Function(String code)? onViewCode;

  @override
  void submit(String text) => _bloc.add(PromptSubmitted(text));

  @override
  void suggest(String text) => _bloc.add(SuggestionTapped(text));

  @override
  void stop() => _bloc.add(const StopRequested());

  @override
  void changePlanSelection(String planId, Set<String> itemIds) =>
      _bloc.add(PlanSelectionChanged(planId, itemIds));

  @override
  void approvePlan(String planId) => _bloc.add(PlanApproved(planId));

  @override
  void rejectPlan(String planId) => _bloc.add(PlanRejected(planId));

  @override
  void undo(String journalId) => _bloc.add(UndoRequested(journalId));

  @override
  void retryFailed(String planId) => _bloc.add(RetryFailedRequested(planId));

  @override
  void retry() => _bloc.add(const RetryRequested());

  @override
  void retryNow() => _bloc.add(const RetryNowRequested());

  @override
  void clearFocus() => _bloc.add(const FocusCleared());

  @override
  void newThread() => _bloc.add(const NewThreadRequested());

  @override
  @override
  void openObject({
    required String collectionId,
    String? cardId,
    String? viewId,
  }) {
    _ui.open(collectionId: collectionId, viewId: viewId, cardId: cardId);
    onNavigated?.call();
  }

  @override
  void openTable(TableItem item) {
    final spec = item.spec;
    if (spec != null && _ui.openQuery(spec)) onNavigated?.call();
  }

  @override
  void viewCode(PlanRow row) {
    if (row.code case final code?) onViewCode?.call(code);
  }
}

/// The member's conversations: the panel's history pane, or with [onBack]
/// the phone's `/assistant/history` page. Picking one opens it in the chat,
/// then [onPicked] runs.
class AssistantHistory extends StatelessWidget {
  const AssistantHistory({super.key, required this.onPicked, this.onBack});

  final VoidCallback onPicked;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<AssistantSession>().bloc;
    return BlocProvider(
      create: (context) => ThreadListCubit(context.read<ThreadRepository>()),
      child: BlocBuilder<ThreadListCubit, ThreadListState>(
        builder: (context, list) => BlocBuilder<AssistantBloc, AssistantState>(
          bloc: bloc,
          buildWhen: (a, b) =>
              a.threadId != b.threadId ||
              (a.phase is ApplyingPhase) != (b.phase is ApplyingPhase),
          builder: (context, chat) {
            final threads = [for (final r in list.threads) ?_summaryOf(r)];
            void select(String id) {
              bloc.add(ThreadSelected(id));
              onPicked();
            }

            void delete(String id) => bloc.add(ThreadDeleted(id));
            final applying = chat.phase is ApplyingPhase;
            final back = onBack;
            return back == null
                ? ThreadListView(
                    threads: threads,
                    onSelect: select,
                    onDelete: delete,
                    currentId: chat.threadId,
                    loading: list.loading,
                    disabled: applying,
                  )
                : ThreadListPage(
                    threads: threads,
                    onSelect: select,
                    onDelete: delete,
                    onBack: back,
                    currentId: chat.threadId,
                    loading: list.loading,
                    disabled: applying,
                  );
          },
        ),
      ),
    );
  }

  /// A malformed record is left out rather than breaking the list.
  static ThreadSummary? _summaryOf(AssistantRecord record) {
    try {
      return ThreadSummary.fromRecord(record);
    } on FormatException {
      return null;
    }
  }
}

/// Phone: the first three pins plus All collections.
class _PinsBar extends StatelessWidget {
  const _PinsBar({
    required this.tabs,
    required this.selectedId,
    required this.onCollection,
    required this.onAll,
  });

  final List<Collection> tabs;

  /// The open tab's collection; null = All.
  final String? selectedId;
  final ValueChanged<String> onCollection;
  final VoidCallback onAll;

  @override
  Widget build(BuildContext context) {
    final shown = tabs;
    final selected = shown.indexWhere((c) => c.id == selectedId);
    return NavigationBar(
      selectedIndex: selected < 0 ? shown.length : selected,
      onDestinationSelected: (i) =>
          i < shown.length ? onCollection(shown[i].id) : onAll(),
      destinations: [
        for (final c in shown)
          NavigationDestination(
            icon: Icon(CollectionIcons.byKey(c.icon)),
            label: c.name,
          ),
        NavigationDestination(
          icon: const Icon(MorkvaIcons.gridView),
          label: context.l10n.shellNavAll,
        ),
      ],
    );
  }
}

/// The user's sidebar choice from the logo: true = full sidebar, false =
/// rail, null = by window width.
// shortcut: kept for the session only; persist it if people ask.
class SidebarExtendedCubit extends Cubit<bool?> {
  SidebarExtendedCubit() : super(null);

  void set(bool extended) => emit(extended);
}
