import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:morkva_crm/api/data/data_repository.dart';
import 'package:morkva_crm/design/design.dart';
import 'package:morkva_crm/features/settings/settings_page.dart';

import '../automation/view/automation_view_harness.dart'
    show phoneWindow, setWindow, wideWindow;
import '../collections/fake_data_repository.dart';

void main() {
  for (final (name, size, scale) in [
    ('a short window', const Size(390, 240), 1.0),
    ('large text on a landscape phone', const Size(844, 330), 2.0),
  ]) {
    testWidgets('$name scrolls to Sign out', (tester) async {
      setWindow(tester, size);
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: SettingsPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // Without the scroll view Sign out sat below the window, unreachable.
      expect(find.text('Sign out').hitTestable(), findsNothing);
      await tester.drag(find.byType(SettingsPage), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(find.text('Sign out').hitTestable(), findsOneWidget);
    });
  }

  testWidgets('a tall window keeps Sign out at the bottom', (tester) async {
    setWindow(tester, const Size(1440, 900));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: SettingsPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.getBottomLeft(find.text('Sign out')).dy, greaterThan(800));
  });

  for (final (name, size) in [('wide', wideWindow), ('phone', phoneWindow)]) {
    testWidgets('$name: browser Back mid-import keeps the sheet; Open still '
        'navigates', (tester) async {
      setWindow(tester, size);
      final repo = FakeDataRepository();
      // As the app: a shell page under the root navigator, Settings inside.
      final router = GoRouter(
        initialLocation: '/settings',
        routes: [
          ShellRoute(
            builder: (context, state, child) => Scaffold(body: child),
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const Text('home'),
                routes: [
                  GoRoute(
                    path: 'settings',
                    builder: (context, state) => const SettingsPage(),
                  ),
                ],
              ),
              GoRoute(
                path: '/collections/:id',
                builder: (context, state) => const Text('collection'),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        RepositoryProvider<DataRepository>.value(
          value: repo,
          child: MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Trello'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Paste'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        File(
          'test/core/import/trello/fixtures/sample_board.json',
        ).readAsStringSync(),
      );
      await tester.pump();
      await tester.ensureVisible(find.text('Add board'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add board'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      repo.batchNeverCompletes = true;
      await tester.tap(find.text('Import 3 collections'));
      await tester.pump();
      await tester.pump();
      // Browser Back: the URL changes under the sheet; Settings goes away.
      router.go('/');
      await tester.pump();
      // Past any exit animation: a sheet on the shell's navigator is gone.
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('home'), findsOneWidget);
      expect(find.text('Importing from Trello'), findsOneWidget);

      await tester.pump(const Duration(seconds: 29));
      await tester.pump();
      repo.batchNeverCompletes = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Your boards are in'), findsOneWidget);

      final boardId = (await repo.getCollections())
          .firstWhere((c) => c.name == 'Sales Pipeline')
          .id;
      await tester.tap(find.text('Open').first);
      await tester.pumpAndSettle();
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        '/collections/$boardId',
      );
      expect(find.text('collection'), findsOneWidget);
    });
  }
}
