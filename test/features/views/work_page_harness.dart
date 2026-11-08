import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:go_router/go_router.dart';
import 'package:morkva_crm/api/api.dart';
import 'package:morkva_crm/app/app.dart';
import 'package:morkva_crm/app/shell/app_shell_scaffold.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/design/design.dart';
import 'package:morkva_crm/features/views/views.dart';

import '../collections/fake_data_repository.dart';
import 'views_fixtures.dart';

/// A repository with [deals] (+ [companies]) and their objects.
FakeDataRepository workRepository({
  Collection collection = deals,
  List<MorkvaObject>? objects,
}) {
  final repo = FakeDataRepository([collection, companies]);
  repo.seedObjects('deals', objects ?? sampleDeals());
  repo.seedObjects('companies', [
    company('k1', 'Zeta Corp', 0),
    company('k2', 'Alpha Ltd', 1),
  ]);
  return repo;
}

class _MockAuthRepository extends Mock implements AuthRepository {}

/// Pumps the Work page for `deals` at [size] inside a minimal router (Home
/// at `/`, the editor at `/collections/:id/edit` as a marker text). With
/// [initialize] false the cubit stays in [ViewsLoading].
Future<CollectionViewsCubit> pumpWorkPage(
  WidgetTester tester, {
  FakeDataRepository? repository,
  Size size = const Size(1280, 800),
  bool initialize = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final repo = repository ?? workRepository();
  final cubit = CollectionViewsCubit(repo, 'deals');
  if (initialize) cubit.initialize();
  addTearDown(cubit.close);
  final sync = SyncStatusCubit();
  addTearDown(sync.close);
  final auth = _MockAuthRepository();
  when(
    () => auth.authStateChanges,
  ).thenAnswer((_) => Stream.value(const AuthUser(uid: 'u1', email: 'a@b.c')));
  final authCubit = AuthCubit(auth)..initialize();
  addTearDown(authCubit.close);

  final router = GoRouter(
    initialLocation: '/collections/deals',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('home')),
        routes: [
          GoRoute(
            path: 'collections/:id',
            // Inside the persistent shell, as in the app.
            builder: (_, _) => AppShellScaffold(
              collectionId: 'deals',
              child: BlocProvider.value(
                value: cubit,
                child: CollectionViewsPage(modes: defaultViewModeRegistry()),
              ),
            ),
            routes: [
              GoRoute(
                path: 'edit',
                builder: (_, state) => Scaffold(
                  body: Text('editor:${state.pathParameters['id']}'),
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    RepositoryProvider<DataRepository>.value(
      value: repo,
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: sync),
          BlocProvider.value(value: authCubit),
        ],
        child: MaterialApp.router(
          // As in the app: mouse drags scroll.
          scrollBehavior: const AppScrollBehavior(),
          theme: AppTheme.light,
          routerConfig: router,
          debugShowCheckedModeBanner: false,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return cubit;
}
