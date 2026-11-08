import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:morkva_crm/api/api.dart';
import 'package:morkva_crm/app/router/app_router.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/app/shell/shell_sidebar.dart';
import 'package:morkva_crm/design/design.dart';
import 'package:morkva_crm/features/collections/collections.dart';
import 'package:morkva_crm/features/settings/settings_page.dart';
import 'package:morkva_crm/features/views/views.dart';

import '../../features/collections/fake_data_repository.dart';
import '../../features/views/views_fixtures.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late GoRouter router;

  Future<void> pumpApp(
    WidgetTester tester, {
    Size size = const Size(1280, 800),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final auth = _MockAuthRepository();
    when(() => auth.authStateChanges).thenAnswer(
      (_) => Stream.value(const AuthUser(uid: 'u1', email: 'a@b.c')),
    );
    final authCubit = AuthCubit(auth)..initialize();
    addTearDown(authCubit.close);
    final data = FakeDataRepository([
      deals,
      const Collection(id: 'other', name: 'Other', fields: []),
    ]);
    data.seedObjects('deals', sampleDeals());
    data.pinnedIds.add(const ['deals']);
    router = createAppRouter(authCubit, sessionReady: ValueNotifier(true));
    addTearDown(router.dispose);

    await tester.pumpWidget(
      RepositoryProvider<DataRepository>.value(
        value: data,
        child: MultiBlocProvider(
          providers: [
            BlocProvider.value(value: authCubit),
            BlocProvider(create: (_) => SyncStatusCubit()),
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

  testWidgets('wide: the sidebar persists and the panel switches at once', (
    tester,
  ) async {
    await pumpApp(tester);
    final sidebar = tester.element(find.byType(ShellSidebar));
    ShellSidebar current() => tester.widget(find.byType(ShellSidebar));
    expect(current().place, ShellPlace.allCollections);
    expect(current().pinned.map((c) => c.id), ['deals']);

    // A pin in the sidebar opens its collection.
    await tester.tap(
      find.descendant(
        of: find.byType(ShellSidebar),
        matching: find.text('Deals'),
      ),
    );
    await tester.pump();
    await tester.pump();
    final page = find.byType(CollectionViewsPage);
    expect(page, findsOneWidget);
    // Same sidebar element: it was not rebuilt or re-animated with the page.
    expect(tester.element(find.byType(ShellSidebar)), same(sidebar));
    // No transition: the page is fully in without advancing the clock.
    expect(
      ModalRoute.of(tester.element(page))!.animation!.status,
      AnimationStatus.completed,
    );
    expect(current().place, ShellPlace.collection);
    expect(current().collectionId, 'deals');

    // Settings leaves the collection.
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(page, findsNothing);
    expect(find.byType(SettingsPage), findsOneWidget);
    expect(tester.element(find.byType(ShellSidebar)), same(sidebar));
    expect(current().place, ShellPlace.settings);
  });

  testWidgets('wide: the logo collapses the sidebar and expands the rail', (
    tester,
  ) async {
    await pumpApp(tester);
    ShellSidebar current() => tester.widget(find.byType(ShellSidebar));
    expect(current().extended, isTrue);

    await tester.tap(find.byTooltip('Collapse sidebar'));
    await tester.pumpAndSettle();
    expect(current().extended, isFalse);
    expect(current().place, ShellPlace.allCollections);

    await tester.tap(find.byTooltip('Expand sidebar'));
    await tester.pumpAndSettle();
    expect(current().extended, isTrue);
  });

  testWidgets('one collection to another swaps the page', (tester) async {
    await pumpApp(tester);
    router.go('/collections/deals');
    await tester.pumpAndSettle();
    expect(find.text('Acme renewal'), findsOneWidget);

    router.go('/collections/other');
    await tester.pumpAndSettle();
    expect(find.text('Acme renewal'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(CollectionViewsPage),
        matching: find.text('Other'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('phone: a full-screen page whose back returns Home', (
    tester,
  ) async {
    await pumpApp(tester, size: const Size(400, 800));
    expect(find.byType(NavigationBar), findsOneWidget);

    router.go('/collections/deals');
    await tester.pumpAndSettle();
    expect(find.byType(CollectionViewsPage), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    // Its own Scaffold owns snackbars, so they clear the FAB.
    ScaffoldMessenger.of(
      tester.element(find.byType(CollectionViewsPage)),
    ).showSnackBar(const SnackBar(content: Text('Saved')));
    await tester.pumpAndSettle();
    expect(
      tester
          .getRect(find.byType(SnackBar))
          .overlaps(tester.getRect(find.byType(FloatingActionButton))),
      isFalse,
    );
    ScaffoldMessenger.of(
      tester.element(find.byType(CollectionViewsPage)),
    ).removeCurrentSnackBar();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(CollectionViewsPage), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);
  });
}
