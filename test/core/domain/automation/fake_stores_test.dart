import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/automation/automation.dart';

import '../../../automation/fakes/fake_stores.dart';
import 'run_record_test.dart' show run;

final _t0 = DateTime.utc(2026, 11, 1);

/// Puts runs `s0…` with [statuses], oldest first.
FakeRunStore _store(List<RunStatus> statuses) {
  final store = FakeRunStore();
  addTearDown(store.dispose);
  for (var i = 0; i < statuses.length; i++) {
    store.putRaw(
      's$i',
      run(status: statuses[i]).toJson()
        ..['startedAt'] = _t0.add(Duration(minutes: i)),
    );
  }
  return store;
}

Future<Set<String>> _ids(FakeRunStore store) async => {
  for (final r in await store.watchRecent().first) r.id,
};

void main() {
  test('prune drops every run past the newest, except applying ones', () async {
    final store = _store(const [
      RunStatus.failed,
      RunStatus.applying,
      RunStatus.succeeded,
      RunStatus.awaitingReview,
      RunStatus.skipped,
      RunStatus.succeeded,
    ]);
    expect(await store.prune(keep: 6), 0);
    expect(await store.prune(keep: 3), 2);
    expect(await _ids(store), {'s1', 's3', 's4', 's5'});
  });

  test('old failed rows never crowd out new runs', () async {
    final store = _store(const [
      RunStatus.failed,
      RunStatus.failed,
      RunStatus.succeeded,
    ]);
    expect(await store.prune(keep: 2), 1);
    expect(await _ids(store), {'s1', 's2'});
  });
}
