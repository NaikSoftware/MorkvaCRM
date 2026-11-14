import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:morkva_crm/api/data/data_repository.dart';
import 'package:morkva_crm/design/design.dart';
import 'package:morkva_crm/features/settings/settings_page.dart';
import 'package:morkva_crm/features/settings/theme_mode_cubit.dart';
import 'package:morkva_crm/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../automation/view/automation_view_harness.dart'
    show phoneWindow, setWindow, wideWindow;
import '../collections/fake_data_repository.dart';

void main() {
  late ThemeModeCubit themeMode;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    themeMode = ThemeModeCubit(await SharedPreferences.getInstance());
  });

  // As the app provides it above MaterialApp.
  Widget withTheme(Widget app) =>
      BlocProvider<ThemeModeCubit>.value(value: themeMode, child: app);

  for (final (name, size, scale) in [
    ('a short window', const Size(390, 240), 1.0),
    ('large text on a landscape phone', const Size(844, 330), 2.0),
  ]) {
    testWidgets('$name scrolls to Sign out', (tester) async {
      setWindow(tester, size);
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        withTheme(
          MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(body: SettingsPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // Without the scroll view Sign out sat below the window, unreachable.
      expect(find.text('Sign out').hitTestable(), findsNothing);
      await tester.drag(find.byType(SettingsPage), const Offset(0, -1000));
      await tester.pumpAndSettle();
      expect(find.text('Sign out').hitTestable(), findsOneWidget);
    });
  }

  testWidgets('wide: a centred column, as on Automations, with its own '
      'title on one left edge and Sign out under the sections', (tester) async {
    setWindow(tester, const Size(1440, 900));
    await tester.pumpWidget(
      withTheme(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: SettingsPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final card = find.byType(ListTileCard).first;
    expect(tester.getCenter(card).dx, 720);
    expect(tester.getSize(card).width, 1040);
    final edge = tester.getTopLeft(card).dx;
    for (final finder in [
      find.text('Settings'),
      find.text('WORKSPACE'),
      find.text('ACCOUNT'),
      find.byType(SecondaryButton),
    ]) {
      expect(tester.getTopLeft(finder).dx, edge);
    }
    // Sign out used to sit centred at the window bottom.
    expect(
      tester.getTopLeft(find.byType(SecondaryButton)).dy,
      lessThan(tester.getBottomLeft(find.text('ACCOUNT')).dy + Spacing.md),
    );
  });

  testWidgets('phone: no own title; the column sits on the shell header '
      'gutter', (tester) async {
    setWindow(tester, const Size(390, 844));
    await tester.pumpWidget(
      withTheme(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: SettingsPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsNothing);
    expect(tester.getTopLeft(find.byType(ListTileCard).first).dx, Spacing.md);
    expect(tester.getTopLeft(find.byType(SecondaryButton)).dx, Spacing.md);
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
        withTheme(
          RepositoryProvider<DataRepository>.value(
            value: repo,
            child: MaterialApp.router(
              theme: AppTheme.light,
              routerConfig: router,
            ),
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

  group('Appearance', () {
    Future<void> pumpSettings(WidgetTester tester, Size size) async {
      setWindow(tester, size);
      await tester.pumpWidget(
        withTheme(
          MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(body: SettingsPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Finder picker() => find.byType(SegmentedButton<ThemeMode>);

    testWidgets('sits between the workspace sections and Account', (
      tester,
    ) async {
      await pumpSettings(tester, const Size(1440, 900));
      final y = [
        'IMPORT FROM OTHER APPS',
        'APPEARANCE',
        'ACCOUNT',
      ].map((t) => tester.getTopLeft(find.text(t)).dy).toList();
      expect(y, orderedEquals([...y]..sort()));
      expect(find.text('Saved on this device'), findsOneWidget);
    });

    testWidgets('wide: the picker ends the Theme row, 44 px tall', (
      tester,
    ) async {
      await pumpSettings(tester, const Size(1440, 900));
      final title = tester.getRect(find.text('Theme'));
      final box = tester.getRect(picker());
      expect(box.left, greaterThan(title.right));
      expect(box.center.dy, closeTo(title.center.dy, 12));
      expect(box.height, 44);
    });

    testWidgets('phone: the picker drops under the title, full width', (
      tester,
    ) async {
      await pumpSettings(tester, const Size(390, 844));
      final title = tester.getRect(find.text('Theme'));
      final box = tester.getRect(picker());
      expect(box.top, greaterThan(title.bottom));
      // The card's 16 px gutter plus its 16 px padding on each side.
      expect(box.left, 2 * Spacing.md);
      expect(box.width, 390 - 4 * Spacing.md);
    });

    testWidgets('phone, large text: no overflow', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpSettings(tester, const Size(390, 844));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Ukrainian, phone at large text: worded, no overflow', (
      tester,
    ) async {
      setWindow(tester, const Size(390, 844));
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        withTheme(
          MaterialApp(
            locale: const Locale('uk'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            theme: AppTheme.light,
            home: const Scaffold(body: SettingsPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (final text in ['ВИГЛЯД', 'Тема', 'Світла', 'Темна', 'Системна']) {
        expect(find.text(text), findsOneWidget);
      }
    });

    testWidgets('a tap picks the theme and saves it on this device', (
      tester,
    ) async {
      await pumpSettings(tester, const Size(1440, 900));
      SegmentedButton<ThemeMode> button() => tester.widget(picker());
      expect(button().selected, {ThemeMode.system});

      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      expect(themeMode.state, ThemeMode.dark);
      expect(button().selected, {ThemeMode.dark});
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(ThemeModeCubit.prefsKey), 'dark');

      await tester.tap(find.text('Light'));
      await tester.pumpAndSettle();
      expect(prefs.getString(ThemeModeCubit.prefsKey), 'light');
    });

    testWidgets(
      'segments meet the 44 px tap target on the web/desktop density',
      (tester) async {
        await pumpSettings(tester, const Size(1440, 900));
        await expectLater(
          tester,
          meetsGuideline(
            const MinimumTapTargetGuideline(
              size: Size(44, 44),
              link: 'DESIGN.md §7',
            ),
          ),
        );
      },
      variant: TargetPlatformVariant.only(TargetPlatform.linux),
    );
  });
}
