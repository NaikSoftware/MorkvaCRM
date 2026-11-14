import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/inbox/inbox.dart';
import 'package:morkva_crm/features/inbox/bloc/inbox_page_cubit.dart';

InboxItem _timed(DateTime dueAt) => InboxItem(
  id: 'i',
  kind: InboxKind.task,
  title: 'Call',
  dueAt: dueAt,
  reminders: const [InboxReminders.atTime],
  assigneeUid: 'u',
  createdBy: 'u',
  createdAt: DateTime.utc(2026, 10),
  updatedAt: DateTime.utc(2026, 10),
);

/// Run under `TZ=America/New_York` too: 2026-11-01 01:30 happens twice there.
void main() {
  group('changesFrom writes dueAt only when the date or time changed', () {
    for (final due in [
      DateTime.utc(2026, 11, 1, 5, 30), // 01:30 EDT (New York)
      DateTime.utc(2026, 11, 1, 6, 30), // 01:30 EST, the repeated hour
      DateTime.utc(2026, 11, 14, 9, 0, 30), // seconds the draft can't hold
    ]) {
      test('$due', () {
        final item = _timed(due);
        final draft = InboxDraft.of(item).copyWith(title: 'Call back');

        expect(draft.changesFrom(item), {'title': 'Call back'});
      });
    }

    test('a moved time still writes it', () {
      final item = _timed(DateTime.utc(2026, 11, 14, 9));
      final draft = InboxDraft.of(item).withMinutes(10 * 60);

      expect(
        draft.changesFrom(item)['dueAt'],
        DateTime(item.day!.year, item.day!.month, item.day!.day, 10).toUtc(),
      );
    });
  });
}
