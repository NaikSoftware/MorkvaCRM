import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:morkva_crm/api/api.dart';
import 'package:morkva_crm/app/router/app_router.dart';
import 'package:morkva_crm/app/shell/shell_sidebar.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/core/domain/inbox/inbox.dart';
import 'package:morkva_crm/design/design.dart';
import 'package:morkva_crm/features/inbox/bloc/inbox_cubit.dart';
import 'package:morkva_crm/features/inbox/view/inbox_page.dart';

import '../../features/collections/fake_data_repository.dart';
import '../../features/inbox/fake_inbox_repository.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

const _orders = Collection(id: 'orders', name: 'Orders');

/// A task due on local [day] (all-day).
InboxItem _task(String id, DateTime day, {bool done = false}) => InboxItem(
  id: id,
  kind: InboxKind.task,
  title: 'Task $id',
  dueAt: allDayDue(day),
  allDay: true,
  done: done,
  assigneeUid: 'u1',
  createdBy: 'u1',
  createdAt: DateTime.utc(2026, 11, 1),
  updatedAt: DateTime.utc(2026, 11, 1),
);

/// The Inbox's shell entries (spec §4 Navigation, AC1–AC3).
void main() {
  late FakeInboxRepository repo;
  late InboxCubit inbox;
  var now = DateTime(2026, 11, 14, 10);

  setUp(() {
    now = DateTime(2026, 11, 14, 10);
    repo = FakeInboxRepository();
    inbox = InboxCubit(repo, now: () => now);
  });

  tearDown(() async {
    await inbox.close();
    await repo.dispose();
  });

  group('sidebar', () {
    Future<void> pump(
      WidgetTester tester, {
      bool extended = true,
      VoidCallback? onInbox,
      ShellPlace place = ShellPlace.allCollections,
    }) async {
      final sync = SyncStatusCubit();
      addTearDown(sync.close);
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider.value(value: sync),
            BlocProvider.value(value: inbox),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: Row(
                children: [
                  ShellSidebar(
                    extended: extended,
                    place: place,
                    pinned: const [_orders],
                    onAllCollections: () {},
                    onToggleExtended: () {},
                    onCollection: (_) {},
                    onSettings: () {},
                    onJumpTo: () {},
                    onUnpin: (_) {},
                    onReorder: (_, _) {},
                    onInbox: onInbox ?? () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('full: Inbox sits above All collections with a count pill', (
      tester,
    ) async {
      repo.seed([
        _task('late', DateTime(2026, 11, 12)),
        _task('today', DateTime(2026, 11, 14)),
        _task('later', DateTime(2026, 11, 20)),
        _task('done', DateTime(2026, 11, 14), done: true),
      ]);
      var opened = false;
      await pump(tester, onInbox: () => opened = true);
      final inboxY = tester.getTopLeft(find.text('Inbox')).dy;
      expect(
        inboxY,
        lessThan(tester.getTopLeft(find.text('All collections')).dy),
      );
      expect(find.text('2'), findsOneWidget);
      await tester.tap(find.text('Inbox'));
      expect(opened, isTrue);
    });

    testWidgets('full: no pill at 0', (tester) async {
      repo.seed([_task('later', DateTime(2026, 11, 20))]);
      await pump(tester);
      expect(find.text('Inbox'), findsOneWidget);
      expect(find.text('0'), findsNothing);
      expect(find.text('1'), findsNothing);
    });

    testWidgets('full: the count turns over with the day', (tester) async {
      repo.seed([_task('tomorrow', DateTime(2026, 11, 15))]);
      await pump(tester);
      expect(find.text('1'), findsNothing);
      now = DateTime(2026, 11, 15, 0, 1);
      await tester.pump(const Duration(minutes: 1));
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('rail: an Inbox button with a carrot badge', (tester) async {
      repo.seed([_task('today', DateTime(2026, 11, 14))]);
      await pump(tester, extended: false);
      expect(find.byTooltip('Inbox'), findsOneWidget);
      final badge = tester.widget<Badge>(find.byType(Badge));
      expect(badge.isLabelVisible, isTrue);
      expect(badge.backgroundColor, AppTheme.light.colorScheme.primary);
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('no onInbox: no Inbox entry', (tester) async {
      final sync = SyncStatusCubit();
      addTearDown(sync.close);
      await tester.pumpWidget(
        BlocProvider.value(
          value: sync,
          child: MaterialApp(
            home: Scaffold(
              body: Row(
                children: [
                  ShellSidebar(
                    extended: true,
                    place: ShellPlace.allCollections,
                    pinned: const [],
                    onAllCollections: () {},
                    onToggleExtended: () {},
                    onCollection: (_) {},
                    onSettings: () {},
                    onJumpTo: () {},
                    onUnpin: (_) {},
                    onReorder: (_, _) {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      expect(find.text('Inbox'), findsNothing);
    });
  });

  group('app', () {
    late GoRouter router;

    Future<void> pumpApp(
      WidgetTester tester, {
      Size size = const Size(1440, 900),
      List<String> pins = const [],
      bool withInbox = true,
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
      final data = FakeDataRepository([_orders]);
      data.pinnedIds.add(pins);
      router = createAppRouter(authCubit, sessionReady: ValueNotifier(true));
      addTearDown(router.dispose);
      await tester.pumpWidget(
        RepositoryProvider<DataRepository>.value(
          value: data,
          child: MultiBlocProvider(
            providers: [
              BlocProvider.value(value: authCubit),
              BlocProvider(create: (_) => SyncStatusCubit()),
              if (withInbox) BlocProvider.value(value: inbox),
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

    Finder inBar(String label) => find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text(label),
    );

    testWidgets('phone, no pins: the bar is Inbox · All and /inbox is a tab', (
      tester,
    ) async {
      repo.seed([_task('today', DateTime(2026, 11, 14))]);
      await pumpApp(tester, size: const Size(390, 844));
      expect(inBar('Inbox'), findsOneWidget);
      expect(inBar('All'), findsOneWidget);
      final bar = find.byType(NavigationBar);
      expect(tester.widget<NavigationBar>(bar).selectedIndex, 1);

      await tester.tap(inBar('Inbox'));
      await tester.pumpAndSettle();
      expect(router.state.uri.toString(), '/inbox');
      expect(find.byType(InboxPage), findsOneWidget);
      expect(tester.widget<NavigationBar>(bar).selectedIndex, 0);
      // The shell header names the page; a tab has no back button.
      expect(find.text('Inbox'), findsNWidgets(2));
      expect(find.byTooltip('Back'), findsNothing);

      await tester.tap(inBar('All'));
      await tester.pumpAndSettle();
      expect(router.state.uri.toString(), '/');
    });

    testWidgets('phone, pins: Inbox first, then the pins, then All', (
      tester,
    ) async {
      await pumpApp(tester, size: const Size(390, 844), pins: ['orders']);
      final labels = tester
          .widget<NavigationBar>(find.byType(NavigationBar))
          .destinations
          .map((d) => (d as NavigationDestination).label)
          .toList();
      expect(labels, ['Inbox', 'Orders', 'All']);
    });

    testWidgets('phone without the Inbox: no pins, no bar (as before)', (
      tester,
    ) async {
      await pumpApp(tester, size: const Size(390, 844), withInbox: false);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets(
      'wide: the sidebar row opens /inbox; the page draws its header',
      (tester) async {
        await pumpApp(tester);
        await tester.tap(
          find.descendant(
            of: find.byType(ShellSidebar),
            matching: find.text('Inbox'),
          ),
        );
        await tester.pumpAndSettle();
        expect(router.state.uri.toString(), '/inbox');
        expect(
          tester.widget<ShellSidebar>(find.byType(ShellSidebar)).place,
          ShellPlace.inbox,
        );
        expect(find.byType(InboxPage), findsOneWidget);
        // The sidebar row and the page's own title: no shell header.
        expect(find.text('Inbox'), findsNWidgets(2));
      },
    );

    testWidgets('?day and ?item reach the page', (tester) async {
      await pumpApp(tester);
      router.go('/inbox?day=2026-11-20&item=i1');
      await tester.pumpAndSettle();
      final page = tester.widget<InboxPage>(find.byType(InboxPage));
      expect(page.day, DateTime(2026, 11, 20));
      expect(page.itemId, 'i1');

      router.go('/inbox?day=nope');
      await tester.pumpAndSettle();
      final plain = tester.widget<InboxPage>(find.byType(InboxPage));
      expect(plain.day, isNull);
      expect(plain.itemId, isNull);
    });
  });

  test('parseInboxDay: strict yyyy-MM-dd, local midnight, no rollover', () {
    expect(parseInboxDay('2026-11-20'), DateTime(2026, 11, 20));
    expect(parseInboxDay('2026-02-31'), isNull);
    expect(parseInboxDay('2026-1-2'), isNull);
    expect(parseInboxDay('2026-11-20T00:00'), isNull);
    expect(parseInboxDay(''), isNull);
    expect(parseInboxDay(null), isNull);
  });

  test('parseInboxDay: only within ten years of now', () {
    final now = DateTime(2026, 11, 14);
    expect(parseInboxDay('1990-01-01', now: now), isNull);
    expect(parseInboxDay('2015-12-31', now: now), isNull);
    expect(parseInboxDay('2016-01-01', now: now), DateTime(2016));
    expect(parseInboxDay('2036-12-31', now: now), DateTime(2036, 12, 31));
    expect(parseInboxDay('2037-01-01', now: now), isNull);
  });
}
