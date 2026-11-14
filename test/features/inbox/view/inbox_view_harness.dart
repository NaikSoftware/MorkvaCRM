/// Shared rig for the Inbox view tests: the real [InboxCubit] over
/// [FakeInboxRepository], a [FakeDataRepository] with an Orders collection,
/// a signed-in [AuthCubit] stub and a [GoRouter] whose card route echoes
/// where it was sent. The clock is pinned to Sat 14 Nov 2026, 12:00 local.
library;

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:morkva_crm/api/auth/auth_cubit.dart';
import 'package:morkva_crm/api/auth/auth_user.dart';
import 'package:morkva_crm/api/data/data_repository.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/core/domain/inbox/inbox.dart';
import 'package:morkva_crm/design/design.dart';
import 'package:morkva_crm/features/inbox/inbox.dart';
import 'package:morkva_crm/features/inbox/reminders/reminder_scheduler.dart';
import 'package:morkva_crm/l10n/l10n.dart';

import '../../collections/fake_data_repository.dart';
import '../fake_inbox_repository.dart';

class _MockAuth extends MockCubit<AuthState> implements AuthCubit {}

/// Sat 14 Nov 2026, 12:00 local.
final kNow = DateTime(2026, 11, 14, 12);
DateTime clock() => kNow;

const kOrders = Collection(
  id: 'orders',
  name: 'Orders',
  icon: 'cart',
  fields: [TextFieldDefinition(id: 'number', name: 'Number')],
);

MorkvaObject order(String id, String number) => MorkvaObject.create(
  id: id,
  collection: kOrders,
  values: {'number': TextFieldValue(number)},
  createdAt: DateTime.utc(2026, 11),
  updatedAt: DateTime.utc(2026, 11),
);

/// An item; [due] is a local instant (timed) or, with [allDay], a day.
InboxItem item(
  String id,
  String title, {
  InboxKind kind = InboxKind.task,
  DateTime? due,
  bool allDay = false,
  List<int> reminders = const [],
  InboxLink? link,
  bool done = false,
  DateTime? doneAt,
  DateTime? createdAt,
}) => InboxItem(
  id: id,
  kind: kind,
  title: title,
  dueAt: due == null ? null : (allDay ? allDayDue(due) : due.toUtc()),
  allDay: due != null && allDay,
  reminders: reminders,
  link: link,
  assigneeUid: 'me',
  createdBy: 'me',
  done: done,
  doneAt: doneAt?.toUtc(),
  createdAt: (createdAt ?? DateTime(2026, 11, 1)).toUtc(),
  updatedAt: DateTime.utc(2026, 11),
);

/// Records permission requests; starts at [permission].
final class FakeNotifier implements SystemNotifier {
  FakeNotifier(this.permission);

  @override
  NotificationPermission permission;
  var requests = 0;

  @override
  Future<NotificationPermission> requestPermission() async {
    requests++;
    return permission = NotificationPermission.granted;
  }

  @override
  bool show({
    required String tag,
    required String title,
    required String body,
    required void Function() onClick,
  }) => false;
}

const kWide = Size(1440, 900);
const kPhone = Size(390, 844);

/// Streams are made in [pump], inside the test's fake-async zone (made in
/// `setUp`, their microtasks would not run on `pump`); [seed] before it.
final class InboxRig {
  InboxRig() {
    when(() => auth.state).thenReturn(
      const AuthAuthenticated(AuthUser(uid: 'me', email: 'me@example.com')),
    );
  }

  final _seed = <InboxItem>[];
  late final FakeDataRepository data;
  late final FakeInboxRepository repo;
  late final InboxCubit inbox;
  var _pumped = false;

  void seed(List<InboxItem> items) => _seed.addAll(items);
  final auth = _MockAuth();
  final notifier = FakeNotifier(NotificationPermission.defaultState);
  late GoRouter router;

  /// Pumps [home] (default: the Inbox page) at [size] in [locale] (the
  /// device's, i.e. English, when null) and settles.
  Future<void> pump(
    WidgetTester tester, {
    Size size = kWide,
    Widget? home,
    String? itemId,
    DateTime? day,
    Locale? locale,
  }) async {
    data = FakeDataRepository([kOrders])
      ..seedObjects('orders', [order('o1', '#1042'), order('o2', '#1043')]);
    repo = FakeInboxRepository(now: () => kNow.toUtc())..seed(_seed);
    inbox = InboxCubit(repo, now: clock);
    _pumped = true;
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body:
                home ??
                InboxPage(
                  day: day,
                  itemId: itemId,
                  now: clock,
                  notifier: notifier,
                ),
          ),
        ),
        GoRoute(
          path: '/collections/:id',
          builder: (_, s) => Scaffold(
            body: Text(
              'card ${s.pathParameters['id']}/${s.uri.queryParameters['card']}',
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      RepositoryProvider<DataRepository>.value(
        value: data,
        child: MultiBlocProvider(
          providers: [
            BlocProvider<AuthCubit>.value(value: auth),
            BlocProvider<InboxCubit>.value(value: inbox),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: router,
            locale: locale,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> dispose() async {
    if (!_pumped) return;
    await inbox.close();
    await repo.dispose();
  }
}
