import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
// flutter_bloc's providers reject a Listenable (the focus notifier).
import 'package:provider/provider.dart' show ChangeNotifierProvider;

import '../api/api.dart';
import '../api/assistant/assistant_config_repository.dart';
import '../api/assistant/firestore_thread_repository.dart';
import '../api/assistant/thread_repository.dart';
// Concrete Firebase-backed implementations are not exported from the api
// barrel (it exposes only the contracts), so import them directly for the
// production defaults.
import '../api/auth/firestore_auth_repository.dart';
import '../api/automation/firestore_automation_store.dart';
import '../api/automation/firestore_docs.dart';
import '../api/automation/firestore_grant_store.dart';
import '../api/automation/firestore_module_store.dart';
import '../api/automation/firestore_run_store.dart';
import '../api/automation/engine/script_engine_factory.dart';
import '../api/automation/session_key.dart';
import '../api/data/firestore_data_repository.dart';
import '../api/files/firebase_attachment_store.dart';
import '../api/inbox/firestore_inbox_repository.dart';
import '../api/inbox/inbox_repository.dart';
import '../core/automation/automation_runner.dart';
import '../core/automation/engine/script_engine.dart';
import '../core/automation/runner_api.dart';
import '../core/automation/store_catalog.dart';
import '../core/domain/automation/automation.dart';
import '../core/domain/inbox/inbox.dart';
import '../core/domain/core_words.dart';
import '../core/harness/session/harness_session.dart';
import '../design/design.dart';
import '../features/assistant/bloc/assistant_bloc.dart';
import '../features/assistant/bloc/assistant_focus.dart';
import '../features/assistant/bloc/assistant_panel_cubit.dart';
import '../features/assistant/bloc/assistant_session.dart';
import '../features/automation/bloc/automation_runs_cubit.dart';
import '../features/automation/bloc/modules_cubit.dart';
import '../features/automation/bloc/run_log_cubit.dart';
import '../features/inbox/bloc/inbox_cubit.dart';
import '../features/inbox/reminders/reminder_platform.dart';
import '../features/inbox/reminders/reminder_scheduler.dart';
import '../features/inbox/view/inbox_format.dart';
import '../features/settings/theme_mode_cubit.dart';
import '../l10n/l10n.dart';
import 'router/app_router.dart';

/// App-wide scroll behavior: no colored overscroll glow (it clashed with the
/// warm theme and read as an artifact). Touch, stylus and trackpad gestures
/// drag-scroll; a mouse never does (owner, 2026-11-12): on desktop and web
/// the wheel, the trackpad and scrollbars scroll, and a mouse drag selects
/// text or moves cards instead.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
}

/// Root of the MorkvaCRM app.
///
/// Owns the dependency-injection tree: the auth and data repositories, the
/// shared [SyncStatusCubit] and the [AuthCubit] that gates routing. Applies
/// the "Warm Carrot" theme and drives auth-guarded routing through go_router. Runs unchanged on web and mobile.
///
/// Repositories and the [WorkspaceResolver] can be injected for tests; in
/// production they default to the Firebase-backed implementations built against
/// `FirebaseFirestore.instance` (Firebase must be initialized first — see
/// `main.dart`).
class MorkvaApp extends StatefulWidget {
  const MorkvaApp({
    super.key,
    required this.themeModeCubit,
    this.authRepository,
    this.dataRepository,
    this.syncStatusCubit,
    this.workspaceResolver,
    this.attachmentStore,
    this.threadRepository,
    this.assistantConfigRepository,
    this.automationStores,
    this.scriptEngine,
    this.inboxRepository,
  });

  /// The theme choice saved on this device; closed with the app.
  final ThemeModeCubit themeModeCubit;

  /// Auth backend; defaults to [FirestoreAuthRepository].
  final AuthRepository? authRepository;

  /// Data backend; defaults to a [FirestoreDataRepository] bound to
  /// `FirebaseFirestore.instance` and the shared [SyncStatusCubit].
  final DataRepository? dataRepository;

  /// Shared sync-status holder; defaults to a fresh [SyncStatusCubit]. Must be
  /// the same instance the [dataRepository] reports into.
  final SyncStatusCubit? syncStatusCubit;

  /// Maps a uid to its workspace id; defaults to [UidWorkspaceResolver].
  final WorkspaceResolver? workspaceResolver;

  /// File-field blob store; defaults to [FirebaseAttachmentStore].
  final AttachmentStore? attachmentStore;

  /// Ask Morkva's conversations; defaults to [FirestoreThreadRepository].
  final ThreadRepository? threadRepository;

  /// Ask Morkva's config, feature flag and consent; defaults to one over
  /// `FirebaseFirestore.instance`.
  final AssistantConfigRepository? assistantConfigRepository;

  /// Modules, automations, runs and consents; defaults to the Firestore
  /// stores over `FirebaseFirestore.instance`.
  final AutomationStores? automationStores;

  /// The automation sandbox; defaults to this platform's engine (web: the
  /// iframe sandbox, Android/iOS: QuickJS).
  final ScriptEngine? scriptEngine;

  /// The member's Inbox; defaults to [FirestoreInboxRepository] over
  /// `FirebaseFirestore.instance`.
  final InboxRepository? inboxRepository;

  @override
  State<MorkvaApp> createState() => _MorkvaAppState();
}

class _MorkvaAppState extends State<MorkvaApp> {
  // The SyncStatusCubit is the one shared instance threaded into BOTH the
  // DataRepository (so it can report pending/snapshot/conflict signals) and the
  // BlocProvider below (so the sync UI observes the same status).
  late final SyncStatusCubit _syncStatusCubit =
      widget.syncStatusCubit ?? SyncStatusCubit();
  late final AuthRepository _authRepository =
      widget.authRepository ?? FirestoreAuthRepository();
  late final DataRepository _dataRepository =
      widget.dataRepository ??
      FirestoreDataRepository(
        firestore: FirebaseFirestore.instance,
        syncStatus: _syncStatusCubit,
      );
  late final AttachmentStore _attachmentStore =
      widget.attachmentStore ?? FirebaseAttachmentStore();
  late final WorkspaceResolver _workspaceResolver =
      widget.workspaceResolver ?? const UidWorkspaceResolver();

  late final ThreadRepository _threads =
      widget.threadRepository ??
      FirestoreThreadRepository(firestore: FirebaseFirestore.instance);

  late final InboxRepository _inbox =
      widget.inboxRepository ??
      FirestoreInboxRepository(firestore: FirebaseFirestore.instance);

  /// Shared by the default stores; null when they are injected.
  late final AutomationWorkspace? _automationWorkspace =
      widget.automationStores == null
      ? AutomationWorkspace(firestore: FirebaseFirestore.instance)
      : null;

  late final AutomationStores _automationStores =
      widget.automationStores ?? _firestoreStores(_automationWorkspace!);

  static AutomationStores _firestoreStores(AutomationWorkspace workspace) =>
      AutomationStores(
        modules: FirestoreModuleStore(workspace),
        automations: FirestoreAutomationStore(workspace),
        runs: FirestoreRunStore(workspace),
        grants: FirestoreGrantStore(workspace),
      );

  // Consents belong to the signed-in member.
  late final StoreAutomationCatalog _catalog = StoreAutomationCatalog(
    _automationStores,
    uid: () => switch (_authCubit.state) {
      AuthAuthenticated(:final user) => user.uid,
      _ => null,
    },
  );

  /// The one harness the assistant and the automation runner share.
  late final HarnessSession _harness = HarnessSession(
    repository: _dataRepository,
    catalog: _catalog,
    isOnline: () => _syncStatusCubit.state is! SyncOffline,
  );

  late final PlatformEngine _engine = switch (widget.scriptEngine) {
    final engine? => (engine: engine, crashMarker: null, device: 'web'),
    null => platformScriptEngine(),
  };

  /// Buttons and card events over the shared harness.
  late final AutomationRunner _runner = AutomationRunner(
    session: _harness,
    repository: _dataRepository,
    stores: _automationStores,
    engine: _engine.engine,
    crashMarker: _engine.crashMarker,
    device: _engine.device,
    sessionId: sessionKey,
    timeZoneName: DateTime.now().timeZoneName,
  );

  /// The signed-in member's automation and Inbox cubits (they watch the
  /// bound stores from construction); null until the first sign-in, closed
  /// after a sign-out.
  _SessionCubits? _cubits;

  /// Keeps the router's state while the automation providers come and go
  /// around it.
  final _routerKey = GlobalKey();

  /// Ask Morkva for the signed-in member: always provided, bound per
  /// workspace in [_onAuthChanged].
  late final AssistantSession _assistant = AssistantSession(
    harnessSession: _harness,
    threads: _threads,
    config:
        widget.assistantConfigRepository ??
        AssistantConfigRepository(firestore: FirebaseFirestore.instance),
    syncStatus: _syncStatusCubit,
    runsStarted: _runner.runsStarted,
  );

  late final AuthCubit _authCubit = AuthCubit(_authRepository)..initialize();

  /// Whether the workspace [DataRepository] has finished `initialize()` and the
  /// session is ready for feature pages to mount. Merged into the router's
  /// refresh listenable so the route gate re-evaluates when it flips.
  final ValueNotifier<bool> _sessionReady = ValueNotifier(false);

  late final GoRouter _router = createAppRouter(
    _authCubit,
    sessionReady: _sessionReady,
  );

  /// The workspace the [DataRepository] is currently bound to, so we don't
  /// re-initialize on every repeated [AuthAuthenticated] emission.
  String? _initializedWorkspaceId;

  @override
  void initState() {
    super.initState();
    // modules.testRun (the assistant) runs through the runner.
    _catalog.hooks = _runner;
  }

  Future<void> _onAuthChanged(BuildContext context, AuthState state) async {
    try {
      switch (state) {
        case AuthAuthenticated(:final user):
          final workspaceId = await _workspaceResolver.resolveWorkspaceId(
            user.uid,
          );
          // The widget may have been disposed while resolving the workspace, or
          // the auth state may have changed again — bail if either happened.
          if (!mounted || _initializedWorkspaceId == workspaceId) return;
          _initializedWorkspaceId = workspaceId;
          _attachmentStore.initialize(workspaceId);
          await _dataRepository.initialize(workspaceId);

          // Re-check after the async gap: a sign-out (or a switch to a
          // different workspace) may have raced in while `initialize` ran. If
          // so, tear the repo back down and leave the session not-ready.
          if (!mounted || _initializedWorkspaceId != workspaceId) {
            await _dataRepository.dispose();
            return;
          }
          _automationWorkspace?.initialize(workspaceId: workspaceId);
          // Binds the shared harness; the runner subscribes after its cache.
          await _assistant.initialize(workspaceId, user: user);
          if (!mounted || _initializedWorkspaceId != workspaceId) return;
          final since = DateTime.now();
          _runner.initialize(workspaceId: workspaceId, uid: user.uid);
          _inbox.initialize(workspaceId: workspaceId, uid: user.uid);
          final stores = _automationStores;
          final inbox = InboxCubit(_inbox);
          setState(
            () => _cubits = (
              modules: ModulesCubit(_runner, stores, uid: user.uid),
              runs: AutomationRunsCubit(_runner, stores, since: since),
              runLog: RunLogCubit(_runner, stores, uid: user.uid),
              inbox: inbox,
              reminders: _startReminders(inbox),
            ),
          );
          _sessionReady.value = true;

        case AuthUnauthenticated() || AuthError():
          if (_initializedWorkspaceId == null) return;
          _initializedWorkspaceId = null;
          _sessionReady.value = false;
          // Stay provided (closed) until the next sign-in replaces them: the
          // pages under them unmount only on the redirect's frame.
          final cubits = _cubits;
          _stopReminders(cubits);
          // The runner first: no bridge call is cut with a stale uid. Both
          // unbind at once, so the cache cancels its listeners before the
          // repository goes; their cancels need not hold it up.
          final runnerReset = _runner.reset();
          final reset = _assistant.reset();
          await _dataRepository.dispose();
          await runnerReset;
          await reset;
          await _close(cubits);

        case AuthInitial() || AuthLoading():
          break;
      }
    } catch (error) {
      // Surface init failures via the sync indicator instead of a silent hang;
      // leave the session not-ready so the router holds on `/loading`.
      _initializedWorkspaceId = null;
      _sessionReady.value = false;
      _syncStatusCubit.reportError(
        'Could not load your workspace',
        cause: error,
      );
    }
  }

  /// Tears down everything this State owns. Cancels/disposes the data
  /// repository first (so its Firestore listeners stop reporting into the sync
  /// cubit), then closes the cubits. Idempotent at the repository/cubit level.
  Future<void> _cleanup() async {
    await _runner.dispose();
    await _assistant.dispose();
    await _close(_cubits);
    await _dataRepository.dispose();
    await _authCubit.close();
    await _syncStatusCubit.close();
    await widget.themeModeCubit.close();
    _sessionReady.dispose();
  }

  /// Fires the member's reminders from the Inbox as it loads and changes.
  ({ReminderScheduler scheduler, StreamSubscription<InboxState> feed})
  _startReminders(InboxCubit inbox) {
    final platform = createReminderPlatform();
    final scheduler = ReminderScheduler(
      now: DateTime.now,
      attention: platform.attention,
      store: platform.store,
      notifier: platform.notifier,
      bodyOf: _reminderBody,
      onOpen: (id) => _router.go(
        Uri(path: '/inbox', queryParameters: {'item': id}).toString(),
      ),
    );
    // Only loaded lists: an empty "loading" list would advance the shared
    // mark and skip the catch-up.
    final feed = inbox.stream.listen((s) {
      if (s is InboxReady) scheduler.updateItems(s.items);
    });
    if (inbox.state case InboxReady(:final items)) {
      scheduler.updateItems(items);
    }
    scheduler.start();
    return (scheduler: scheduler, feed: feed);
  }

  /// Synchronous, so no tick timer outlives the session.
  static void _stopReminders(_SessionCubits? cubits) {
    if (cubits == null) return;
    unawaited(cubits.reminders.feed.cancel());
    cubits.reminders.scheduler.dispose();
  }

  /// "10:00 · #1042": the time (timed items) and the linked card.
  // shortcut: the collection name isn't in the link snapshot and there is no
  // sync lookup here; add it when the link stores it.
  static String _reminderBody(InboxItem item) => [
    if (itemMinutes(item) case final m?) timeLabel(m),
    if (item.link case final link? when link.label.isNotEmpty) link.label,
  ].join(' · ');

  @override
  void dispose() {
    _stopReminders(_cubits);
    _router.dispose();
    // `State.dispose` cannot be async, so fire-and-forget the teardown. The
    // futures involved are local cancellations/closes that complete promptly
    // and don't touch the widget tree, so there's nothing to await on.
    // Everything below is provided via `.value`, so this State owns disposal
    // (BlocProvider.value never closes the value it is given).
    unawaited(_cleanup());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AuthRepository>.value(value: _authRepository),
        RepositoryProvider<DataRepository>.value(value: _dataRepository),
        RepositoryProvider<AttachmentStore>.value(value: _attachmentStore),
        RepositoryProvider<ThreadRepository>.value(value: _threads),
        RepositoryProvider<AssistantSession>.value(value: _assistant),
        RepositoryProvider<AutomationRunnerApi>.value(value: _runner),
        RepositoryProvider<AutomationStores>.value(value: _automationStores),
        RepositoryProvider<InboxRepository>.value(value: _inbox),
        ChangeNotifierProvider<AssistantFocusNotifier>.value(
          value: _assistant.focus,
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthCubit>.value(value: _authCubit),
          BlocProvider<ThemeModeCubit>.value(value: widget.themeModeCubit),
          BlocProvider<SyncStatusCubit>.value(value: _syncStatusCubit),
          BlocProvider<AssistantBloc>.value(value: _assistant.bloc),
          BlocProvider<AssistantPanelCubit>.value(value: _assistant.panel),
        ],
        child: BlocListener<AuthCubit, AuthState>(
          listener: _onAuthChanged,
          child: BlocBuilder<ThemeModeCubit, ThemeMode>(
            builder: (context, themeMode) => MaterialApp.router(
              onGenerateTitle: (context) => context.l10n.appTitle,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode: themeMode,
              scrollBehavior: const AppScrollBehavior(),
              routerConfig: _router,
              builder: (context, child) {
                // DateFormat in lib/core (no BuildContext) reads this.
                Intl.defaultLocale = Localizations.localeOf(context).toString();
                // So do core's fallback words ("Untitled", "Yes"…).
                CoreWords.current = context.l10n.coreWords;
                final router = KeyedSubtree(key: _routerKey, child: child!);
                final cubits = _cubits;
                if (cubits == null) return router;
                return MultiBlocProvider(
                  providers: [
                    BlocProvider<ModulesCubit>.value(value: cubits.modules),
                    BlocProvider<AutomationRunsCubit>.value(value: cubits.runs),
                    BlocProvider<RunLogCubit>.value(value: cubits.runLog),
                    BlocProvider<InboxCubit>.value(value: cubits.inbox),
                    RepositoryProvider<ReminderScheduler>.value(
                      value: cubits.reminders.scheduler,
                    ),
                  ],
                  child: router,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

typedef _SessionCubits = ({
  ModulesCubit modules,
  AutomationRunsCubit runs,
  RunLogCubit runLog,
  InboxCubit inbox,
  ({ReminderScheduler scheduler, StreamSubscription<InboxState> feed})
  reminders,
});

Future<void> _close(_SessionCubits? cubits) async {
  if (cubits == null) return;
  await Future.wait([
    cubits.modules.close(),
    cubits.runs.close(),
    cubits.runLog.close(),
    cubits.inbox.close(),
  ]);
}
