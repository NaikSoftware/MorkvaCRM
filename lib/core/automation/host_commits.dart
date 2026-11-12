// The only automation code that builds a user actor (D18): the user-only
// host ops (`plans.commit/reject/retryFailed`, `journal.undo`) on behalf of
// a run. A module's own context can never commit.
import '../../api/data/data_repository.dart';
import '../domain/automation/automation.dart';
import '../harness/api/capability.dart';
import '../harness/api/envelope.dart';
import '../harness/api/harness_context.dart';
import '../harness/session/harness_session.dart';

/// Commits, rejects, retries and undoes run plans in the signed-in user's
/// context, through the session's one [HarnessSession.harness].
final class HostCommits {
  HostCommits(
    this.session, {
    required this.uid,
    required this.workspaceId,
    DateTime Function()? now,
    this.timeZoneName = '',
  }) : _now = now ?? DateTime.now;

  final HarnessSession session;
  final String? Function() uid;
  final String? Function() workspaceId;
  final DateTime Function() _now;
  final String timeZoneName;
  var _calls = 0;

  /// Applies [run]'s plan ([itemIds]: the ticked items, null = all). Its
  /// card writes carry the run's origin, keyed by the plan id. Refused
  /// (`internal`) when the plan in memory is not [run]'s or not built by
  /// its module. Once nothing failed the plan is dropped from the store.
  Future<HarnessResponse> commit(
    RunRecord run, {
    Set<String>? itemIds,
    void Function(int done, int total)? onProgress,
  }) async {
    if (_mismatch(run) case final failure?) return failure;
    final response = await _call(
      'plans.commit',
      {'planId': run.planId, 'itemIds': ?itemIds?.toList()},
      origin: _origin(run, WriteKind.automation),
      onProgress: onProgress,
    );
    _dropIfDone(run.planId!, response);
    return response;
  }

  /// Retries the failed items of [run]'s committed plan.
  Future<HarnessResponse> retryFailed(RunRecord run) async {
    if (_mismatch(run) case final failure?) return failure;
    final response = await _call('plans.retryFailed', {
      'planId': run.planId,
    }, origin: _origin(run, WriteKind.automation));
    _dropIfDone(run.planId!, response);
    return response;
  }

  /// Drops [planId] without writing ([skipped]: the runner's own drop, e.g.
  /// a full review backlog, not the user's).
  Future<HarnessResponse> reject(String planId, {bool skipped = false}) =>
      _call('plans.reject', {
        'planId': planId,
        'reason': skipped ? 'skipped' : 'user',
      });

  /// Reverts [run]'s commit while the journal still holds it. Undo writes
  /// fire nothing.
  Future<HarnessResponse> undo(RunRecord run) => _call('journal.undo', {
    'journalId': run.journalId,
  }, origin: _origin(run, WriteKind.undo));

  HarnessFailure? _mismatch(RunRecord run) {
    final planId = run.planId;
    final plan = planId == null ? null : session.plans.get(planId);
    if (plan == null) {
      return HarnessFailure(
        HarnessError(
          code: ErrorCode.planExpired,
          message: 'The preview of this run is gone.',
        ),
      );
    }
    if (plan.planId != planId ||
        plan.createdBy.actor != Actor.plugin(run.moduleId)) {
      return HarnessFailure(
        HarnessError(
          code: ErrorCode.internal,
          message: 'The plan does not belong to this run.',
        ),
      );
    }
    return null;
  }

  void _dropIfDone(String planId, HarnessResponse response) {
    if (response case HarnessOk(
      :final result,
    ) when (result['failed'] as List?)?.isEmpty ?? true) {
      session.plans.remove(planId);
    }
  }

  static WriteOrigin _origin(RunRecord run, WriteKind kind) => WriteOrigin(
    kind: kind,
    actor: Actor.plugin(run.moduleId).wire,
    runId: run.id,
    commitId: run.planId,
    depth: run.depth,
    chain: run.chain,
  );

  Future<HarnessResponse> _call(
    String op,
    Map<String, Object?> args, {
    WriteOrigin? origin,
    void Function(int done, int total)? onProgress,
  }) {
    final member = uid();
    if (member == null) {
      return Future.value(
        HarnessFailure(
          HarnessError(code: ErrorCode.notPermitted, message: 'Signed out.'),
        ),
      );
    }
    final now = _now();
    return session.harness.call(
      HarnessRequest(op: op, args: args, callId: 'host.${++_calls}'),
      HarnessContext(
        workspaceId: workspaceId() ?? '',
        actor: Actor.user(member),
        grants: Grants.all(),
        now: now,
        today: now,
        timeZoneName: timeZoneName,
        origin: origin,
        events: onProgress == null ? null : _ProgressSink(onProgress),
      ),
    );
  }
}

final class _ProgressSink implements Sink<HarnessEvent> {
  _ProgressSink(this._onProgress);

  final void Function(int done, int total) _onProgress;

  @override
  void add(HarnessEvent event) {
    if (event case ProgressEvent(:final done, :final total)) {
      _onProgress(done, total);
    }
  }

  @override
  void close() {}
}
