import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../design/design.dart';
import 'navigation/navigation_cubit.dart';
import 'router/app_router.dart';

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
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => NavigationCubit(),
      child: MaterialApp.router(
        title: 'MorkvaCRM',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.system,
        routerConfig: _router,
      ),
    );
  }
}
