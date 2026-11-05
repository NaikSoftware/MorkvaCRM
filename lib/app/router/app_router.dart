import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../api/api.dart';
import '../../features/auth/session_loading_page.dart';
import '../../features/auth/sign_in_page.dart';
import '../../features/collections/collections.dart';
import '../../features/views/views.dart';
import '../shell/app_shell.dart';
import '../shell/app_shell_scaffold.dart';

/// The app's route table.
///
/// Three top-level routes: the auth-gated app shell (a [ShellRoute] holding
/// Home at `/` and a collection's Work page `/collections/:id` in its main
/// panel; the editor `/collections/:id/edit` covers it full-screen), the
/// public sign-in
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
  // One UI-side field-editor registry for the app's lifetime. Stateless and
  // open-for-extension (mirrors the domain FieldTypeRegistry); shared by the
  // schema editor page and its cubit.
  final fieldEditorRegistry = defaultFieldEditorRegistry();
  final viewModes = defaultViewModeRegistry();

  final rootKey = GlobalKey<NavigatorState>();

  return GoRouter(
    navigatorKey: rootKey,
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
        // First auth state not yet resolved — hold on the neutral interstitial
        // while the repository replays the persisted session.
        case AuthInitial():
          return isOnLoading ? null : '/loading';

        // A sign-in is in flight — keep the user on the sign-in screen so its
        // inline spinner *and* the Cancel affordance stay visible. Bouncing to
        // the full-screen interstitial here is exactly what made a dismissed
        // Google popup look like an unrecoverable infinite-progress hang.
        case AuthLoading():
          return isOnSignIn ? null : '/sign-in';

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
      // The persistent shell: the rail (wide) is built once and only the
      // main panel's page changes between Home and a collection.
      ShellRoute(
        builder: (context, state, child) => AppShellScaffold(
          inCollection: state.pathParameters.containsKey('id'),
          child: child,
        ),
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const HomeSections(),
            routes: [
              // A collection's Work surface. Nested under `/` so back returns
              // Home. Same auth+session gate as `/` (the redirect above holds
              // any protected location on `/loading` until the workspace is
              // ready), so the repository is initialized before the cubit
              // subscribes.
              GoRoute(
                path: 'collections/:id',
                pageBuilder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return collectionPage(
                    context,
                    key: state.pageKey,
                    child: BlocProvider(
                      create: (context) => CollectionViewsCubit(
                        context.read<DataRepository>(),
                        id,
                      )..initialize(),
                      child: CollectionViewsPage(modes: viewModes),
                    ),
                  );
                },
                routes: [
                  // Build: the full-screen schema editor, a focused mode
                  // outside the shell. Its cubit loads a one-shot snapshot of
                  // the workspace collections itself (for the reference
                  // picker).
                  GoRoute(
                    path: 'edit',
                    parentNavigatorKey: rootKey,
                    builder: (context, state) {
                      final id = state.pathParameters['id']!;
                      final repository = context.read<DataRepository>();
                      final fieldId = state.uri.queryParameters['field'];
                      return BlocProvider(
                        create: (_) => CollectionEditorCubit(
                          repository,
                          fieldEditorRegistry,
                        )..load(id, selectFieldId: fieldId),
                        child: CollectionEditorPage(
                          registry: fieldEditorRegistry,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
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

/// The collection page inside the shell. Wide, only the main panel changes,
/// at once, so the rail stays put; phone, the platform's push transition, as
/// a full-screen page with back. One page type for both, so resizing across
/// the breakpoint keeps the page (and its state).
Page<void> collectionPage(
  BuildContext context, {
  required LocalKey key,
  required Widget child,
}) {
  final wide = MediaQuery.sizeOf(context).width >= AppShell.expandedBreakpoint;
  const phone = Duration(milliseconds: 300);
  return CustomTransitionPage(
    key: key,
    child: child,
    transitionDuration: wide ? Duration.zero : phone,
    reverseTransitionDuration: wide ? Duration.zero : phone,
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        MediaQuery.sizeOf(context).width >= AppShell.expandedBreakpoint
        ? child
        : Theme.of(context).pageTransitionsTheme.buildTransitions(
            ModalRoute.of(context)! as PageRoute<void>,
            context,
            animation,
            secondaryAnimation,
            child,
          ),
  );
}
