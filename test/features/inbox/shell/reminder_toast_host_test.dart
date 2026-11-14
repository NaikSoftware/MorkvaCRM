import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/api/api.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/core/domain/inbox/inbox.dart';
import 'package:morkva_crm/design/design.dart';
import 'package:morkva_crm/features/inbox/bloc/inbox_cubit.dart';
import 'package:morkva_crm/features/inbox/reminders/reminder_scheduler.dart';
import 'package:morkva_crm/features/inbox/reminders/reminder_toast_host.dart';
import 'package:morkva_crm/features/inbox/view/inbox_item_editor.dart';
import 'package:morkva_crm/features/inbox/view/inbox_link_chip.dart';

import '../../collections/fake_data_repository.dart';
import '../fake_inbox_repository.dart';

class _Store implements ReminderStore {
  final data = <String, String>{};

  @override
  String? read(String key) => data[key];

  @override
  void write(String key, String? value) =>
      value == null ? data.remove(key) : data[key] = value;

  @override
  Stream<String> get changes => const Stream.empty();
}

class _Focused implements Attention {
  @override
  bool get focused => true;

  @override
  Stream<void> get changes => const Stream.empty();
}

class _NoNotifier implements SystemNotifier {
  @override
  NotificationPermission get permission => NotificationPermission.unsupported;

  @override
  Future<NotificationPermission> requestPermission() async => permission;

  @override
  bool show({
    required String tag,
    required String title,
    required String body,
    required void Function() onClick,
  }) => false;
}

final _now = DateTime(2026, 11, 14, 10, 5);

/// A timed item due today at [hour]:00 with an at-time reminder.
InboxItem _item(
  String id, {
  int hour = 10,
  InboxKind kind = InboxKind.task,
  String? title,
  InboxLink? link,
}) => InboxItem(
  id: id,
  kind: kind,
  title: title ?? 'Item $id',
  dueAt: DateTime(2026, 11, 14, hour).toUtc(),
  reminders: const [InboxReminders.atStart],
  link: link,
  assigneeUid: 'u1',
  createdBy: 'u1',
  createdAt: DateTime.utc(2026, 11, 1),
  updatedAt: DateTime.utc(2026, 11, 1),
);

PendingReminder _entry(String id, {int hour = 10, bool catchUp = false}) {
  final at = DateTime(2026, 11, 14, hour);
  return PendingReminder(
    key: '$id@${at.millisecondsSinceEpoch}',
    itemId: id,
    fireAt: at,
    catchUp: catchUp,
  );
}

void main() {
  late FakeInboxRepository repo;
  late InboxCubit inbox;
  late _Store store;
  late ReminderScheduler scheduler;

  /// Pumps the host over a page with [items] live and [pending] stored.
  Future<void> pump(
    WidgetTester tester, {
    required List<InboxItem> items,
    required List<PendingReminder> pending,
    Size size = const Size(1280, 800),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    store.data[ReminderScheduler.pendingKey] = jsonEncode({
      'entries': [for (final e in pending) e.toJson()],
    });
    repo.seed(items);
    await tester.pumpWidget(
      RepositoryProvider<DataRepository>.value(
        value: FakeDataRepository([
          const Collection(id: 'suppliers', name: 'Suppliers'),
        ]),
        child: MultiBlocProvider(
          providers: [
            BlocProvider.value(value: inbox),
            RepositoryProvider.value(value: scheduler),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const ReminderToastHost(child: Scaffold(body: Text('page'))),
          ),
        ),
      ),
    );
    await tester.pump();
    // The app feeds the scheduler from the cubit's loaded lists.
    scheduler.updateItems(inbox.items);
    await tester.pumpAndSettle();
  }

  setUp(() {
    repo = FakeInboxRepository();
    inbox = InboxCubit(repo, now: () => _now);
    store = _Store();
    // The mark is "now", so updateItems fires nothing new.
    store.data[ReminderScheduler.lastTickKey] =
        '${_now.millisecondsSinceEpoch}';
    scheduler = ReminderScheduler(
      now: () => _now,
      attention: _Focused(),
      store: store,
      notifier: _NoNotifier(),
      bodyOf: (i) => i.title,
      onOpen: (_) {},
    );
  });

  tearDown(() async {
    scheduler.dispose();
    await inbox.close();
    await repo.dispose();
  });

  List<String> storedKeys() {
    final raw = store.data[ReminderScheduler.pendingKey];
    if (raw == null) return const [];
    final entries = (jsonDecode(raw) as Map)['entries'] as List;
    return [for (final e in entries) (e as Map)['key'] as String];
  }

  testWidgets('a task toast: Done marks it done and dismisses', (tester) async {
    await pump(
      tester,
      items: [
        _item(
          'a',
          title: 'Pay the invoice',
          link: const InboxLink(
            collectionId: 'suppliers',
            cardId: 'k1',
            label: 'Textile Co',
          ),
        ),
      ],
      pending: [_entry('a')],
    );
    expect(find.text('Pay the invoice'), findsOneWidget);
    expect(find.text('10:00'), findsOneWidget);
    expect(find.byType(InboxLinkChip), findsOneWidget);
    expect(find.textContaining('Textile Co'), findsOneWidget);
    // Wide: bottom-right, 400 wide, 16 px in.
    final card = tester.getRect(
      find
          .ancestor(
            of: find.text('Pay the invoice'),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(card.width, ReminderToastHost.width);
    expect(card.right, 1280 - Spacing.md);
    expect(card.bottom, 800 - Spacing.md);
    // Done's check lines up with the title.
    expect(
      tester.getTopLeft(find.byIcon(MorkvaIcons.check)).dx,
      tester.getTopLeft(find.text('Pay the invoice')).dx,
    );

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(repo.writes.single.$3['done'], isTrue);
    expect(storedKeys(), isEmpty);
    expect(find.text('Pay the invoice'), findsNothing);
  });

  testWidgets('× dismisses; a note has no Done', (tester) async {
    await pump(
      tester,
      items: [_item('n', kind: InboxKind.note, title: 'Courier at 10')],
      pending: [_entry('n')],
    );
    expect(find.text('Courier at 10'), findsOneWidget);
    expect(find.text('Done'), findsNothing);
    expect(find.text('Open'), findsOneWidget);
    await tester.tap(find.byTooltip('Dismiss'));
    await tester.pumpAndSettle();
    expect(storedKeys(), isEmpty);
    expect(find.text('Courier at 10'), findsNothing);
    expect(repo.writes, isEmpty);
  });

  testWidgets('Open dismisses the toast', (tester) async {
    await pump(tester, items: [_item('a')], pending: [_entry('a')]);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(storedKeys(), isEmpty);
    final editor = find.byType(InboxItemEditor);
    expect(tester.widget<InboxItemEditor>(editor).item?.id, 'a');
  });

  testWidgets('renders the live item; a done or deleted item has no toast', (
    tester,
  ) async {
    await pump(
      tester,
      items: [
        _item('a', title: 'Old title'),
        _item('b'),
      ],
      pending: [_entry('a'), _entry('b'), _entry('gone')],
    );
    expect(find.text('Old title'), findsOneWidget);
    expect(find.text('Item b'), findsOneWidget);

    await repo.update('a', {'title': 'New title'});
    await repo.update('b', {'done': true});
    await tester.pump();
    scheduler.updateItems(inbox.items);
    await tester.pumpAndSettle();
    expect(find.text('New title'), findsOneWidget);
    expect(find.text('Item b'), findsNothing);
  });

  testWidgets('catch-up entries share one "while you were away" toast', (
    tester,
  ) async {
    await pump(
      tester,
      items: [_item('a', hour: 8), _item('b', hour: 9), _item('c')],
      pending: [
        _entry('a', hour: 8, catchUp: true),
        _entry('b', hour: 9, catchUp: true),
        _entry('c'),
      ],
    );
    expect(find.text('2 reminders while you were away'), findsOneWidget);
    expect(find.text('Item a'), findsOneWidget);
    expect(find.text('Item b'), findsOneWidget);
    expect(find.text('Item c'), findsOneWidget);
    // Wide: the newest (c) nearest the bottom edge, the older group above.
    expect(
      tester.getTopLeft(find.text('2 reminders while you were away')).dy,
      lessThan(tester.getTopLeft(find.text('Item c')).dy),
    );

    // A row opens its item and leaves the rest.
    await tester.tap(find.text('Item a'));
    await tester.pumpAndSettle();
    expect(find.text('1 reminder while you were away'), findsOneWidget);
    // Close the item editor it opened.
    Navigator.of(tester.element(find.text('page'))).popUntil((r) => r.isFirst);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Dismiss all'));
    await tester.pumpAndSettle();
    expect(find.textContaining('while you were away'), findsNothing);
    expect(storedKeys(), [_entry('c').key]);
  });

  testWidgets('at most three, then "+N more"', (tester) async {
    final ids = ['a', 'b', 'c', 'd', 'e'];
    await pump(
      tester,
      items: [for (final (i, id) in ids.indexed) _item(id, hour: 5 + i)],
      pending: [for (final (i, id) in ids.indexed) _entry(id, hour: 5 + i)],
    );
    expect(find.text('Open'), findsNWidgets(3));
    expect(find.text('+2 more'), findsOneWidget);
    // Newest first: 09:00 (e) is shown, 05:00 (a) waits.
    expect(find.text('Item e'), findsOneWidget);
    expect(find.text('Item a'), findsNothing);
  });

  testWidgets('phone: the stack sits at the top', (tester) async {
    await pump(
      tester,
      items: [_item('a')],
      pending: [_entry('a')],
      size: const Size(390, 844),
    );
    final top = tester.getTopLeft(find.text('Item a')).dy;
    expect(top, lessThan(100));
  });

  testWidgets('nothing without a scheduler', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ReminderToastHost(child: Text('page'))),
    );
    expect(find.text('page'), findsOneWidget);
  });
}
