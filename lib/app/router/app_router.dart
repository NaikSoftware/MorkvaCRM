import 'package:go_router/go_router.dart';

import '../shell/app_shell_scaffold.dart';

/// The app's route table. For Epic 0 there is a single shell route at `/`;
/// real entity routes (collection detail, object detail) extend this in
/// later epics. Kept as a factory so each app instance owns one router.
GoRouter createAppRouter() {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const AppShellScaffold(),
      ),
    ],
  );
}
