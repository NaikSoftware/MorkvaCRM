import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

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
  ) =>
      child;

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

/// Root of the MorkvaCRM app: provides the [NavigationCubit], applies the
/// "Warm Carrot" theme (light/dark by system), and drives routing through
/// go_router. Runs unchanged on web and mobile.
class MorkvaApp extends StatefulWidget {
  const MorkvaApp({super.key});

  @override
  State<MorkvaApp> createState() => _MorkvaAppState();
}

class _MorkvaAppState extends State<MorkvaApp> {
  late final GoRouter _router = createAppRouter();

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => NavigationCubit(),
      child: MaterialApp.router(
        title: 'Morkva CRM',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.system,
        scrollBehavior: const _AppScrollBehavior(),
        routerConfig: _router,
      ),
    );
  }
}
