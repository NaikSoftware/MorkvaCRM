import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/inbox/inbox.dart';
import 'package:morkva_crm/features/inbox/bloc/inbox_cubit.dart';

import 'fake_inbox_repository.dart';

/// Saturday 2026-11-14, 21:00 local (02:00Z next day under New York).
final _now = DateTime(2026, 11, 14, 21);

InboxItem _item(
  String id, {
  InboxKind kind = InboxKind.task,
  DateTime? dueAt,
  bool allDay = false,
}) => InboxItem(
  id: id,
  kind: kind,
  title: id,
  dueAt: dueAt,
  allDay: allDay,
  assigneeUid: 'u1',
  createdBy: 'u1',
  createdAt: DateTime.utc(2026, 11, 1),
  updatedAt: DateTime.utc(2026, 11, 1),
);

void main() {
  late FakeInboxRepository repo;
  late InboxCubit cubit;

  setUp(() {
    repo = FakeInboxRepository();
  });

  tearDown(() async {
    await cubit.close();
    await repo.dispose();
  });

  InboxCubit build() => cubit = InboxCubit(repo, now: () => _now);

  test('loading, then ready with items and the badge', () async {
    repo.seed([
      _item('overdue', dueAt: DateTime.utc(2026, 11, 10), allDay: true),
      _item('today', dueAt: DateTime(2026, 11, 14, 9).toUtc()),
      _item('later', dueAt: DateTime.utc(2026, 11, 20), allDay: true),
      _item('note', kind: InboxKind.note),
    ]);
    build();
    expect(cubit.state, const InboxLoading());
    expect(cubit.items, isEmpty);
    await pumpEventQueue();
    expect(cubit.state, isA<InboxReady>());
    expect(cubit.items, hasLength(4));
    expect(cubit.badgeCount, 2);
  });

  test('a cache snapshot is ready fromCache; the same items confirmed by '
      'the server are a new state', () async {
    repo.seed([_item('a')], fromCache: true);
    build();
    await pumpEventQueue();
    expect(cubit.state, InboxReady([_item('a')], fromCache: true));

    repo.recover();
    await pumpEventQueue();
    expect(cubit.state, InboxReady([_item('a')]));
  });

  test('a failed listener shows failed; retry resubscribes', () async {
    build();
    await pumpEventQueue();
    repo.failWatch();
    await pumpEventQueue();
    expect(cubit.state, isA<InboxFailed>());
    expect((cubit.state as InboxFailed).message, contains('permission-denied'));

    repo
      ..seed([_item('a')])
      ..recover();
    final states = <InboxState>[];
    final sub = cubit.stream.listen(states.add);
    await cubit.retry();
    await pumpEventQueue();
    await sub.cancel();
    expect(states.first, const InboxLoading());
    expect(cubit.items.map((i) => i.id), ['a']);
  });

  test('add, update and setDone write through the repository', () async {
    build();
    cubit.add(_item('a'));
    await pumpEventQueue();
    cubit.update('a', {'title': 'Renamed'});
    cubit.setDone('a', true);
    await pumpEventQueue();
    var a = cubit.items.single;
    expect(a.title, 'Renamed');
    expect(a.done, isTrue);
    expect(a.doneAt, _now.toUtc());

    cubit.setDone('a', false);
    await pumpEventQueue();
    a = cubit.items.single;
    expect(a.done, isFalse);
    expect(a.doneAt, isNull);
  });

  test('delete returns the item and restore writes it back', () async {
    repo.seed([_item('a')]);
    build();
    await pumpEventQueue();
    final deleted = cubit.delete('a');
    await pumpEventQueue();
    expect(deleted?.id, 'a');
    expect(cubit.items, isEmpty);
    expect(cubit.delete('missing'), isNull);

    cubit.restore(deleted!);
    await pumpEventQueue();
    expect(cubit.items.single, _item('a'));
  });

  test('move all overdue to today, then undo', () async {
    final timedDue = DateTime(2026, 11, 12, 8, 30).toUtc();
    final allDayDue = DateTime.utc(2026, 11, 10);
    repo.seed([
      _item('timed', dueAt: timedDue),
      _item('allDay', dueAt: allDayDue, allDay: true),
      _item(
        'note',
        kind: InboxKind.note,
        dueAt: DateTime.utc(2026, 11, 9),
        allDay: true,
      ),
      _item('today', dueAt: DateTime(2026, 11, 14, 8).toUtc()),
    ]);
    build();
    await pumpEventQueue();

    final previous = cubit.moveAllOverdueToToday();
    await pumpEventQueue();
    expect(previous, {'timed': timedDue, 'allDay': allDayDue});
    InboxItem byId(String id) => cubit.items.firstWhere((i) => i.id == id);
    // All-day lands on today's calendar date even when UTC is already the
    // next day; a timed task keeps its local time of day.
    expect(byId('allDay').dueAt, DateTime.utc(2026, 11, 14));
    expect(byId('timed').dueAt, DateTime(2026, 11, 14, 8, 30).toUtc());
    expect(byId('note').dueAt, DateTime.utc(2026, 11, 9));
    expect(inboxBadgeCount(cubit.items, _now), 3);

    cubit.restoreDueAts(previous);
    await pumpEventQueue();
    expect(byId('timed').dueAt, timedDue);
    expect(byId('allDay').dueAt, allDayDue);
  });

  test('failed writes are reported on errors, state untouched', () async {
    repo.seed([_item('a')]);
    build();
    await pumpEventQueue();
    final errors = <String>[];
    final sub = cubit.errors.listen(errors.add);
    repo.failWrites = kInboxDenied;

    cubit.setDone('a', true);
    cubit.add(_item('b'));
    expect(cubit.delete('a')?.id, 'a');
    await pumpEventQueue();
    await sub.cancel();

    expect(errors, hasLength(3));
    expect(errors.first, contains('permission-denied'));
    expect(cubit.items.single.done, isFalse);
  });

  test('a write failing after close is dropped', () async {
    build();
    await pumpEventQueue();
    repo.failWrites = kInboxDenied;
    cubit.add(_item('b'));
    await cubit.close();
    await pumpEventQueue();
  });
}
