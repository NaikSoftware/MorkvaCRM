import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/automation/automation.dart';

import '../../../automation/fakes/fake_stores.dart';
import 'run_record_test.dart' show run;

void main() {
  test(
    'prune keeps the newest rows, cheap ones go first, applying stays',
    () async {
      final store = FakeRunStore();
      addTearDown(store.dispose);
      final t0 = DateTime.utc(2026, 11, 1);
      // Oldest first: s0 failed, s1 applying, s2 succeeded, s3 awaiting, s4 skipped, s5 succeeded.
      const statuses = [
        RunStatus.failed,
        RunStatus.applying,
        RunStatus.succeeded,
        RunStatus.awaitingReview,
        RunStatus.skipped,
        RunStatus.succeeded,
      ];
      for (var i = 0; i < statuses.length; i++) {
        store.putRaw(
          's$i',
          run(status: statuses[i]).toJson()
            ..['startedAt'] = t0.add(Duration(minutes: i)),
        );
      }

      expect(await store.prune(keep: 6), 0);
      expect(await store.prune(keep: 3), 3);
      expect(await _ids(store), {'s0', 's1', 's3'});
      // Over the cheap rows: the oldest of the rest, never the applying one.
      expect(await store.prune(keep: 2), 1);
      expect(await _ids(store), {'s1', 's3'});
      expect(await store.prune(keep: 0), 1);
      expect(await _ids(store), {'s1'});
    },
  );
}

Future<Set<String>> _ids(FakeRunStore store) async => {
  for (final id in ['s0', 's1', 's2', 's3', 's4', 's5'])
    if (await store.get(id) != null) id,
};
