import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../api/api.dart';
// Concrete Firebase-backed implementations are not exported from the api
// barrel (it exposes only the contracts), so import them directly for the
// production defaults.
import '../api/auth/firestore_auth_repository.dart';
import '../api/data/firestore_data_repository.dart';
import '../design/design.dart';
import 'navigation/navigation_cubit.dart';
import 'router/app_router.dart';

/// App-wide scroll behavior: no colored overscroll glow (it clashed with the
/// warm theme and read as an artifact), and trackpad/mouse drag-to-scroll
/// enabled so the web build feels native.
class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
}

/// Root of the MorkvaCRM app.
///
/// Owns the dependency-injection tree: the auth and data repositories, the
/// shared [SyncStatusCubit], the [AuthCubit] that gates routing, and the
/// [NavigationCubit] for the shell. Applies the "Warm Carrot" theme and drives
/// auth-guarded routing through go_router. Runs unchanged on web and mobile.
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
  late final WorkspaceResolver _workspaceResolver =
      widget.workspaceResolver ?? const UidWorkspaceResolver();

  late final AuthCubit _authCubit = AuthCubit(_authRepository)..initialize();
  late final GoRouter _router = createAppRouter(_authCubit);

  /// The workspace the [DataRepository] is currently bound to, so we don't
  /// re-initialize on every repeated [AuthAuthenticated] emission.
  String? _initializedWorkspaceId;

  Future<void> _onAuthChanged(BuildContext context, AuthState state) async {
    switch (state) {
      case AuthAuthenticated(:final user):
        final workspaceId = await _workspaceResolver.resolveWorkspaceId(
          user.uid,
        );
        // The widget may have been disposed while resolving the workspace, or
        // the auth state may have changed again — bail if either happened.
        if (!mounted || _initializedWorkspaceId == workspaceId) return;
        _initializedWorkspaceId = workspaceId;
        await _dataRepository.initialize(workspaceId);
      case AuthUnauthenticated() || AuthError():
        if (_initializedWorkspaceId == null) return;
        _initializedWorkspaceId = null;
        await _dataRepository.dispose();
      case AuthInitial() || AuthLoading():
        break;
    }
  }

  @override
  void dispose() {
    _router.dispose();
    // Everything in the DI tree is provided via `.value`, so this State owns
    // disposal of what it constructed (BlocProvider.value never closes the
    // value it is given).
    _authCubit.close();
    _syncStatusCubit.close();
    _dataRepository.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AuthRepository>.value(value: _authRepository),
        RepositoryProvider<DataRepository>.value(value: _dataRepository),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthCubit>.value(value: _authCubit),
          BlocProvider<SyncStatusCubit>.value(value: _syncStatusCubit),
          BlocProvider<NavigationCubit>(create: (_) => NavigationCubit()),
        ],
        child: BlocListener<AuthCubit, AuthState>(
          listener: _onAuthChanged,
          child: MaterialApp.router(
            title: 'Morkva CRM',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: ThemeMode.system,
            scrollBehavior: const _AppScrollBehavior(),
            routerConfig: _router,
          ),
        ),
      ),
    );
  }
}
