import 'dart:async';

import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:go_router/go_router.dart';

import '../../api/api.dart';
import '../../features/auth/sign_in_page.dart';
import '../shell/app_shell_scaffold.dart';

/// The app's route table.
///
/// Two top-level routes: the auth-gated app shell at `/` and the public
/// sign-in screen at `/sign-in`. The [authCubit] drives an auth redirect so an
/// unauthenticated user can only reach `/sign-in`, and an authenticated user is
/// bounced away from it. Real entity routes (collection / object detail) extend
/// the `/` subtree in later epics.
///
/// Kept as a factory so each app instance owns one router.
GoRouter createAppRouter(AuthCubit authCubit) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: GoRouterRefreshStream(authCubit.stream),
    redirect: (context, state) {
      final authState = authCubit.state;

      // Until the first auth state resolves (or while a sign-in is in flight)
      // we don't know where to send the user — stay put and let the stream
      // refresh trigger a redirect once the state settles.
      if (authState is AuthInitial || authState is AuthLoading) {
        return null;
      }

      final isAuthenticated = authState is AuthAuthenticated;
      final isOnSignIn = state.matchedLocation == '/sign-in';

      if (!isAuthenticated && !isOnSignIn) return '/sign-in';
      if (isAuthenticated && isOnSignIn) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const AppShellScaffold()),
      GoRoute(
        path: '/sign-in',
        builder: (context, state) => const SignInPage(),
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
