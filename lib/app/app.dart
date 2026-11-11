import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
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
import '../api/data/firestore_data_repository.dart';
import '../api/files/firebase_attachment_store.dart';
import '../design/design.dart';
import '../features/assistant/bloc/assistant_bloc.dart';
import '../features/assistant/bloc/assistant_focus.dart';
import '../features/assistant/bloc/assistant_panel_cubit.dart';
import '../features/assistant/bloc/assistant_session.dart';
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
    this.authRepository,
    this.dataRepository,
    this.syncStatusCubit,
    this.workspaceResolver,
    this.attachmentStore,
    this.threadRepository,
    this.assistantConfigRepository,
  });

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

  /// Ask Morkva for the signed-in member: always provided, bound per
  /// workspace in [_onAuthChanged].
  late final AssistantSession _assistant = AssistantSession(
    dataRepository: _dataRepository,
    threads: _threads,
    config:
        widget.assistantConfigRepository ??
        AssistantConfigRepository(firestore: FirebaseFirestore.instance),
    syncStatus: _syncStatusCubit,
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
          await _assistant.initialize(workspaceId, user: user);
          _sessionReady.value = true;

        case AuthUnauthenticated() || AuthError():
          if (_initializedWorkspaceId == null) return;
          _initializedWorkspaceId = null;
          _sessionReady.value = false;
          // Unbinds at once, so the assistant's cache cancels its listeners
          // before the repository goes; their cancels need not hold it up.
          final reset = _assistant.reset();
          await _dataRepository.dispose();
          await reset;

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
    await _assistant.dispose();
    await _dataRepository.dispose();
    await _authCubit.close();
    await _syncStatusCubit.close();
    _sessionReady.dispose();
  }

  @override
  void dispose() {
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
        ChangeNotifierProvider<AssistantFocusNotifier>.value(
          value: _assistant.focus,
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthCubit>.value(value: _authCubit),
          BlocProvider<SyncStatusCubit>.value(value: _syncStatusCubit),
          BlocProvider<AssistantBloc>.value(value: _assistant.bloc),
          BlocProvider<AssistantPanelCubit>.value(value: _assistant.panel),
        ],
        child: BlocListener<AuthCubit, AuthState>(
          listener: _onAuthChanged,
          child: MaterialApp.router(
            title: 'Morkva CRM',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: ThemeMode.system,
            scrollBehavior: const AppScrollBehavior(),
            routerConfig: _router,
          ),
        ),
      ),
    );
  }
}
