import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:morkva_crm/core/domain/automation/automation.dart';

import '../data/data_repository.dart' show maxBatchWrites;
import 'firestore_docs.dart';

/// [RunStore] over `workspaces/{wid}/runs/{runId}`: loaded by `startedAt`
/// only and filtered in memory, so no composite index.
final class FirestoreRunStore implements RunStore {
  FirestoreRunStore(this._workspace);

  final AutomationWorkspace _workspace;

  CollectionReference<Map<String, dynamic>> get _runs =>
      _workspace.collection('runs');

  Query<Map<String, dynamic>> get _newestFirst =>
      _runs.orderBy('startedAt', descending: true);

  @override
  Stream<List<RunRecord>> watchRecent() => _newestFirst
      .limit(RunStore.kWindow)
      .snapshots()
      .map((snapshot) => readRecords(snapshot, RunRecord.fromJson));

  @override
  Future<RunRecord?> get(String runId) async =>
      readRecord(await _runs.doc(runId).get(), RunRecord.fromJson);

  @override
  Future<void> create(RunRecord run) =>
      _runs.doc(run.id).set(encodeDoc(run.toJson()));

  /// A plain `update` of the named keys only: the rules check the diff's
  /// affected keys per transition.
  @override
  Future<void> update(RunRecord run, {required Set<String> fields}) {
    final json = encodeDoc(run.toJson());
    return _runs.doc(run.id).update({for (final f in fields) f: json[f]});
  }

  /// Drops as many runs as lie past the newest [keep] (read with
  /// `startAfterDocument`, as there is no `offset`), choosing the oldest
  /// `succeeded`/`skipped`/… rows first and `failed`/`awaiting_review` ones
  /// only after those; an `applying` run is never dropped.
  @override
  Future<int> prune({int keep = RunStore.kWindow}) async {
    assert(keep > 0, 'Firestore limits must be positive');
    final window = (await _newestFirst.limit(keep).get()).docs;
    if (window.length < keep) return 0;
    final past =
        (await _newestFirst.startAfterDocument(window.last).get()).docs;
    if (past.isEmpty) return 0;

    final oldestFirst = [
      for (final d in [...window, ...past].reversed)
        if (d.data()['status'] != RunStatus.applying.wire) d,
    ];
    bool keptLonger(QueryDocumentSnapshot<Map<String, dynamic>> d) =>
        _keptLonger.contains(d.data()['status']);
    final doomed = [
      ...oldestFirst.where((d) => !keptLonger(d)),
      ...oldestFirst.where(keptLonger),
    ].take(past.length).map((d) => d.reference).toList();

    for (var start = 0; start < doomed.length; start += maxBatchWrites) {
      final batch = _workspace.db.batch();
      for (final ref in doomed.skip(start).take(maxBatchWrites)) {
        batch.delete(ref);
      }
      await batch.commit();
    }
    return doomed.length;
  }

  static final _keptLonger = {
    RunStatus.failed.wire,
    RunStatus.awaitingReview.wire,
  };
}
