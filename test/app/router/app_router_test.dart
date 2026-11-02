import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:morkva_crm/api/api.dart';
import 'package:morkva_crm/app/navigation/navigation_cubit.dart';
import 'package:morkva_crm/app/router/app_router.dart';
import 'package:morkva_crm/design/design.dart';
import 'package:morkva_crm/features/collections/collections.dart';
import 'package:morkva_crm/features/views/views.dart';

import '../../features/collections/fake_data_repository.dart';
import '../../features/views/views_fixtures.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late GoRouter router;

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final auth = _MockAuthRepository();
    when(() => auth.authStateChanges).thenAnswer(
      (_) => Stream.value(const AuthUser(uid: 'u1', email: 'a@b.c')),
    );
    final authCubit = AuthCubit(auth)..initialize();
    addTearDown(authCubit.close);
    final data = FakeDataRepository([deals]);
    data.seedObjects('deals', sampleDeals());
    router = createAppRouter(authCubit, sessionReady: ValueNotifier(true));
    addTearDown(router.dispose);

    await tester.pumpWidget(
      RepositoryProvider<DataRepository>.value(
        value: data,
        child: MultiBlocProvider(
          providers: [
            BlocProvider.value(value: authCubit),
            BlocProvider(create: (_) => SyncStatusCubit()),
            BlocProvider(create: (_) => NavigationCubit()),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: router,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('/collections/:id is the Work page, /edit the editor', (
    tester,
  ) async {
    await pumpApp(tester);

    router.go('/collections/deals');
    await tester.pump();
    await tester.pump();
    expect(find.byType(CollectionViewsPage), findsOneWidget);
    expect(find.text('Acme renewal'), findsOneWidget);

    router.go('/collections/deals/edit');
    await tester.pump();
    await tester.pump();
    expect(find.byType(CollectionEditorPage), findsOneWidget);

    // The editor sits on top of the Work page: going back reveals it.
    router.pop();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(CollectionViewsPage), findsOneWidget);
  });
}
