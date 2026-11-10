import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../api/api.dart';
import '../../features/assistant/bloc/assistant_session.dart';
import '../../features/assistant/host/router_ui_port.dart';
import '../../features/assistant/view/assistant_page.dart';
import '../../features/auth/session_loading_page.dart';
import '../../features/auth/sign_in_page.dart';
import '../../features/collections/collections.dart';
import '../../features/home/home_page.dart';
import '../../features/settings/settings_page.dart';
import '../../features/views/views.dart';
import '../shell/app_shell.dart';
import '../shell/app_shell_scaffold.dart';

/// The app's route table.
///
/// Three top-level routes: the auth-gated app shell (a [ShellRoute] holding
/// All collections at `/`, `/settings` and a collection's Work page
/// `/collections/:id` in its main panel; the editor `/collections/:id/edit` covers it full-screen), the
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
          collectionId: state.pathParameters['id'],
          inSettings: state.matchedLocation == '/settings',
          child: child,
        ),
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const HomePage(),
            routes: [
              GoRoute(
                path: 'settings',
                pageBuilder: (context, state) => collectionPage(
                  context,
                  key: state.pageKey,
                  child: const SettingsPage(),
                ),
              ),
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
                    // Per id: go_router's pageKey is the route pattern, so
                    // one collection → another (sidebar) would keep the old
                    // page and its cubit.
                    key: ValueKey('/collections/$id'),
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
      // Phone: Ask Morkva full screen over the shell (the wide layouts use
      // the shell's side panel). Chips pop it before navigating.
      GoRoute(
        path: '/assistant',
        parentNavigatorKey: rootKey,
        builder: (context, state) => const _AssistantRoute(),
        routes: [
          GoRoute(
            path: 'history',
            parentNavigatorKey: rootKey,
            builder: (context, state) =>
                AssistantHistory(onPicked: context.pop, onBack: context.pop),
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

/// The `/assistant` page over the session. While it is up the panel cubit
/// says open, so the collections the chat leased stay warm.
class _AssistantRoute extends StatefulWidget {
  const _AssistantRoute();

  @override
  State<_AssistantRoute> createState() => _AssistantRouteState();
}

class _AssistantRouteState extends State<_AssistantRoute> {
  late final AssistantSession _session = context.read<AssistantSession>();
  late final _actions = SessionAssistantActions(
    _session.bloc,
    RouterUiPort(() => GoRouter.of(context)),
  );

  @override
  void initState() {
    super.initState();
    // Not while the tree builds or unmounts: the shell listens to the cubit.
    scheduleMicrotask(_session.panel.show);
  }

  @override
  void dispose() {
    final panel = _session.panel;
    scheduleMicrotask(() {
      if (!panel.isClosed) panel.hide();
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AssistantPage(
        bloc: _session.bloc,
        actions: _actions,
        onBack: () => context.canPop() ? context.pop() : context.go('/'),
        onOpenHistory: () => context.push('/assistant/history'),
      ),
    );
  }
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

/// A page inside the shell (a collection, settings). Wide, only the main panel changes,
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
        MediaQuery.sizeOf(context).width >= AppShell.expandedBreakpoint ||
            ShellTab.of(context)
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
