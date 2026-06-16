import 'dart:async';

import 'package:flutter/foundation.dart'
    show ChangeNotifier, Listenable, ValueListenable;
import 'package:go_router/go_router.dart';

import '../../api/api.dart';
import '../../features/auth/session_loading_page.dart';
import '../../features/auth/sign_in_page.dart';
import '../shell/app_shell_scaffold.dart';

/// The app's route table.
///
/// Three top-level routes: the auth-gated app shell at `/`, the public sign-in
/// screen at `/sign-in`, and a neutral `/loading` interstitial. Routing is
/// gated on two signals merged into [GoRouter.refreshListenable]: the
/// [authCubit] auth state and [sessionReady] (the [DataRepository] has been
/// initialized for the workspace). Feature pages under `/` therefore never
/// mount before the repository is ready — their `watch*` calls require it.
///
/// Kept as a factory so each app instance owns one router.
GoRouter createAppRouter(
  AuthCubit authCubit, {
  required ValueListenable<bool> sessionReady,
}) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: Listenable.merge([
      GoRouterRefreshStream(authCubit.stream),
      sessionReady,
    ]),
    redirect: (context, state) {
      final authState = authCubit.state;
      final location = state.matchedLocation;
      final isOnSignIn = location == '/sign-in';
      final isOnLoading = location == '/loading';

      switch (authState) {
        // First auth state not yet resolved, or a sign-in is in flight — hold
        // on the neutral interstitial.
        case AuthInitial() || AuthLoading():
          return isOnLoading ? null : '/loading';

        case AuthAuthenticated():
          // Signed in but the workspace data layer isn't ready yet — wait on
          // the interstitial so feature pages don't mount too early.
          if (!sessionReady.value) {
            return isOnLoading ? null : '/loading';
          }
          // Ready: leave the gate screens for the shell.
          if (isOnSignIn || isOnLoading) return '/';
          return null;

        case AuthUnauthenticated() || AuthError():
          return isOnSignIn ? null : '/sign-in';
      }
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const AppShellScaffold()),
      GoRoute(
        path: '/sign-in',
        builder: (context, state) => const SignInPage(),
      ),
      GoRoute(
        path: '/loading',
        builder: (context, state) => const SessionLoadingPage(),
      ),
    ],
  );
}

/// Adapts a [Stream] into a [Listenable] so go_router can re-run its redirect
/// whenever the stream emits — the standard pattern for wiring a bloc/cubit
/// stream into `refreshListenable`. Notifies once on creation so the initial
/// state is evaluated, then on every subsequent emission.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
