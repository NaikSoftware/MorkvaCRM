// The automation runner (design spec, Triggers, Apply policy, Loop & rate
// safety, Run queue & lifecycle, Run log schema): turns card changes and
// button presses into runs, executes them one at a time in fresh sandboxes
// through the shared HarnessSession, decides auto or review for each sealed
// plan, and keeps the run log.
//
// Run docs are written fire-and-forget: Firestore store writes resolve on the
// server's ack, so awaiting them would stall the queue offline. The only
// awaited run-doc write is approve's `applyStartedAt`, whose refusal means
// another window replaced the review.
import 'dart:async';

import '../../api/data/data_repository.dart';
import '../domain/automation/automation.dart';
import '../domain/domain.dart';
import '../domain/ids.dart';
import '../harness/api/capability.dart';
import '../harness/api/envelope.dart';
import '../harness/automation_validation.dart';
import '../harness/cache/derived_snapshot.dart';
import '../harness/cache/workspace_cache.dart';
import '../harness/plan/plan.dart';
import '../harness/plan/plan_committer.dart' show ItemOutcome;
import '../harness/query/cache_workspace_reader.dart';
import '../harness/session/harness_session.dart';
import 'apply_policy.dart';
import 'bridge.dart';
import 'card_shaper.dart';
import 'engine/protocol.dart' show kBootBudget;
import 'engine/script_engine.dart';
import 'host_commits.dart';
import 'loop_guard.dart';
import 'run_log_builder.dart';
import 'run_queue.dart';
import 'runner_api.dart';
import 'trigger_evaluator.dart';

/// How long a plan waiting for review is kept in memory (FLAG F3).
const Duration kReviewTtl = Duration(hours: 8);

/// Runs waiting for review per workspace in this session.
const int kReviewBacklog = 50;

/// Card changes kept while the automations load at start-up.
const int kStartupBuffer = 500;

/// Skip reasons written as one row per automation per session, with a count.
const Set<RunReason> kCoalescedReasons = {
  RunReason.needsConsent,
  RunReason.broken,
  RunReason.crashed,
  RunReason.reviewBacklog,
  RunReason.loopSuspected,
};

/// The message of a refused approve after the module or consent changed.
const String kPermissionsChanged =
    "This module's permissions changed — run it again.";

/// The final-transition keys the run rules allow (`awaiting_review` /
/// `applying` → terminal).
const Set<String> kFinalRunKeys = {
  'status',
  'reason',
  'endedAt',
  'durationMs',
  'receipt',
  'journalId',
  'touchedCardIds',
  'summary',
  'error',
  'log',
};

/// The keys an Undo / Retry failed update of a `succeeded` run may touch.
const Set<String> kAppliedRunKeys = {
  'receipt',
  'summary',
  'journalId',
  'touchedCardIds',
};

/// Implements [AutomationRunnerApi] and [RunnerHooks] over the shared
/// [HarnessSession] (D17).
///
/// Lifecycle: [initialize] after `session.initialize(wid)` (it subscribes to
/// [repository]'s changes synchronously, before the app is ready), [reset]
/// on sign-out before the assistant's and the session's resets.
final class AutomationRunner implements AutomationRunnerApi {
  AutomationRunner({
    required this.session,
    required this.repository,
    required this.stores,
    required this.engine,
    required this.sessionId,
    CrashMarker? crashMarker,
    this.device = 'web',
    this.timeZoneName = '',
    DateTime Function()? now,
    IdGenerator? ids,
    Duration bootBudget = kBootBudget,
    this.settleTimeout = const Duration(seconds: 5),
  }) : crashMarker = crashMarker ?? const _NoCrashMarker(),
       _now = now ?? DateTime.now,
       _ids = ids ?? IdGenerator() {
    _bridge = ScriptBridge(
      harness: session.harness,
      plans: session.plans,
      results: session.results,
      engine: engine,
      now: _now,
      bootBudget: bootBudget,
    );
    _evaluator = TriggerEvaluator(
      session.cache,
      settleTimeout: settleTimeout,
      now: _now,
    );
    _guard = LoopGuard(now: _now);
    _host = HostCommits(
      session,
      uid: () => _uid,
      workspaceId: () => _workspaceId,
      now: _now,
      timeZoneName: timeZoneName,
    );
    _shaper = CardShaper(session.cache);
  }

  final HarnessSession session;

  /// Where card changes come from (the session does not expose it).
  final DataRepository repository;
  final AutomationStores stores;
  final ScriptEngine engine;
  final CrashMarker crashMarker;

  @override
  final String sessionId;

  /// `web`, `android` or `ios` (run docs).
  final String device;
  final String timeZoneName;
  final Duration settleTimeout;
  final DateTime Function() _now;
  final IdGenerator _ids;

  late final ScriptBridge _bridge;
  late final TriggerEvaluator _evaluator;
  late final LoopGuard _guard;
  late final HostCommits _host;
  late final CardShaper _shaper;
  static const _policy = ApplyPolicy();

  /// Bumped by [initialize] and [reset]: anything an older epoch started
  /// writes and announces nothing.
  int _epoch = 0;
  String? _uid;
  String? _workspaceId;

  final _subs = <StreamSubscription<Object?>>[];
  Map<String, AutomationRecord> _automations = const {};
  Map<String, ModuleRecord> _modules = const {};
  Map<String, GrantRecord> _consents = const {};
  var _seen = 0; // which of the three first emissions arrived
  bool get _loaded => _seen == 7;
  final _buffer = <CardChange>[];

  /// Changes dropped from a full start-up buffer, by collection and kind.
  final _overflow = <(String, TriggerKind), int>{};
  Future<void> _tail = Future.value();

  final _queue = RunQueue<_Run>();
  final _live = <String, _Run>{};

  /// This session's run docs as last written (Undo, Retry failed, Run
  /// again), newest last.
  final _records = <String, RunRecord>{};
  final _coalesced = <String, RunRecord>{};
  final _leases = <String, Future<Lease?>>{};
  var _created = 0;
  var _engineUnavailable = false;
  DateTime? _autoPausedUntil;

  final _activityChanges = StreamController<RunActivity>.broadcast();
  final _finished = StreamController<RunView>.broadcast();
  RunActivity _activity = RunActivity.idle;

  // ------------------------------------------------------------- lifecycle

  /// Binds the runner to [workspaceId] as [uid]: subscribes to the card
  /// changes at once and loads the automations without waiting (an offline
  /// start must not hang), finalizes this session's interrupted runs,
  /// recovers a crash breadcrumb and prunes old runs.
  void initialize({required String workspaceId, required String uid}) {
    _epoch++;
    _workspaceId = workspaceId;
    _uid = uid;
    final epoch = _epoch;
    _subs.add(repository.changes.listen(_onChange));
    _subs.add(
      stores.automations.watch().listen((list) {
        _automations = {for (final a in list) a.id: a};
        for (final id in _evaluatorIds.difference(_automations.keys.toSet())) {
          _evaluator.forget(id);
        }
        _evaluatorIds = _automations.keys.toSet();
        _refreshLeases();
        _arrived(1);
      }, onError: _ignore),
    );
    _subs.add(
      stores.modules.watch().listen((list) {
        _modules = {for (final m in list) m.id: m};
        _arrived(2);
        _checkReviews();
      }, onError: _ignore),
    );
    _subs.add(
      stores.grants.watch(uid).listen((map) {
        _consents = map;
        _arrived(4);
        _checkReviews();
      }, onError: _ignore),
    );
    var first = true;
    _subs.add(
      repository.watchCollections().listen((collections) {
        if (first || collections.isEmpty) {
          first = false;
          return; // the start-up snapshot; an empty one is a cold cache
        }
        // After the cache, which subscribed first, took the same emission.
        Future<void>.delayed(Duration.zero, () {
          if (epoch != _epoch) return;
          _refreshLeases();
          unawaited(_revalidate(epoch));
        });
      }, onError: _ignore),
    );
    stores.runs.watchRecent().first.then((runs) {
      if (epoch == _epoch) _finalizeOwn(runs);
    }, onError: _ignore);
    if (crashMarker.leftover() case final crash?) {
      unawaited(_recoverCrash(crash, epoch));
    }
    crashMarker.clear();
    _prune(epoch);
  }

  var _evaluatorIds = <String>{};

  /// Sign-out: bumps the epoch, kills the live sandbox, drops the queue
  /// without writing run docs, and cancels every subscription and lease.
  Future<void> reset() async {
    _epoch++;
    for (final run in _live.values) {
      run.expiry?.cancel();
      run.bridge?.stop();
    }
    _live.clear();
    _queue.clear();
    _records.clear();
    _coalesced.clear();
    _buffer.clear();
    _overflow.clear();
    _seen = 0;
    _automations = const {};
    _modules = const {};
    _consents = const {};
    _evaluatorIds = {};
    _evaluator.reset();
    _guard.reset();
    crashMarker.clear();
    _engineUnavailable = false;
    _autoPausedUntil = null;
    _tail = Future.value();
    final leases = [..._leases.values];
    _leases.clear();
    for (final l in leases) {
      l.then((lease) => lease?.release(), onError: _ignore);
    }
    final subs = [..._subs];
    _subs.clear();
    _uid = null;
    _workspaceId = null;
    _notify();
    await Future.wait([for (final s in subs) s.cancel()]);
  }

  Future<void> dispose() async {
    await reset();
    await _activityChanges.close();
    await _finished.close();
  }

  void _arrived(int bit) {
    if (_loaded) return;
    _seen |= bit;
    if (!_loaded) return;
    final buffered = [..._buffer];
    _buffer.clear();
    buffered.forEach(_process);
    _writeOverflow();
  }

  // -------------------------------------------------------------- activity

  @override
  RunActivity get activity => _activity;

  @override
  Stream<RunActivity> get activityChanges => _activityChanges.stream;

  @override
  Stream<RunView> get finished => _finished.stream;

  void _notify() {
    // The slot's holder until released, unless it already moved on to
    // review (listed below) or ended.
    final current = switch (_queue.current) {
      final r?
          when const {
            RunStatus.running,
            RunStatus.sealing,
            RunStatus.applying,
          }.contains(r.status) =>
        r,
      _ => null,
    };
    final paused = _autoPausedUntil;
    final next = RunActivity(
      runs: [
        if (current != null) _view(current),
        for (final r in _queue.waiting) _view(r),
        for (final r in _live.values)
          if (r != current && r.status == RunStatus.applying) _view(r),
        for (final r in _live.values)
          if (r.status == RunStatus.awaitingReview) _view(r),
      ],
      engineUnavailable: _engineUnavailable,
      autoPausedUntil: paused != null && _now().isBefore(paused)
          ? paused
          : null,
    );
    if (next == _activity) return;
    _activity = next;
    if (!_activityChanges.isClosed) _activityChanges.add(next);
  }

  RunView _view(_Run run) => RunView(
    runId: run.id,
    automationId: run.automation.id,
    moduleId: run.automation.moduleId,
    actionId: run.automation.actionId,
    label: run.label,
    status: run.status,
    reason: run.reason,
    trigger: run.trigger,
    startedAt: run.startedAt,
    queuedAhead: run.status == RunStatus.queued ? _queue.ahead(run) : null,
    progress: run.progress,
    summary: run.summary,
    planId: run.planId,
    error: run.error,
    links: run.links,
  );

  // ------------------------------------------------------------- triggers

  void _onChange(CardChange change) {
    if (_loaded) return _process(change);
    if (_buffer.length < kStartupBuffer) return _buffer.add(change);
    final kind = change.before == null
        ? TriggerKind.cardCreated
        : change.after == null
        ? TriggerKind.cardDeleted
        : TriggerKind.cardUpdated;
    final key = (change.collectionId, kind);
    _overflow[key] = (_overflow[key] ?? 0) + 1;
  }

  /// One `queue_full` row per automation that would have seen the changes
  /// a full start-up buffer dropped.
  void _writeOverflow() {
    for (final MapEntry(key: (collectionId, kind), :value)
        in _overflow.entries) {
      for (final a in _automations.values) {
        if (!a.enabled ||
            a.trigger.kind != kind ||
            a.trigger.collectionId != collectionId) {
          continue;
        }
        final row = _skipRecord(
          a,
          RunTrigger(kind: kind, collectionId: collectionId, cardCount: value),
          RunReason.queueFull,
        );
        _create(row.copyWith(count: value), _epoch);
      }
    }
    _overflow.clear();
  }

  /// Starts every watching automation's evaluation at once and consumes the
  /// outcomes in change order, so runs enqueue in the order of the writes.
  void _process(CardChange change) {
    final epoch = _epoch;
    final owner = switch (change.origin.runId) {
      final id? => _live[id],
      null => null,
    };
    if (owner != null) owner.settles.add(_settle(change));
    final pending = [
      for (final a in _automations.values)
        if (TriggerEvaluator.watches(a, change)) (a, _evaluate(a, change)),
    ];
    if (pending.isEmpty) return;
    final step = _tail = _tail.then((_) async {
      for (final (a, evaluation) in pending) {
        final result = await evaluation;
        if (epoch != _epoch) return;
        try {
          _onEvaluated(a, change, result);
        } catch (_) {
          // One automation's bookkeeping never stops the others.
        }
      }
    });
    owner?.settles.add(step);
  }

  Future<void> _settle(CardChange change) async {
    final after = change.after;
    try {
      await session.cache.settled(
        change.collectionId,
        change.cardId,
        after == null
            ? (card) => card == null
            : (card) =>
                  card != null && !card.updatedAt.isBefore(after.updatedAt),
        timeout: settleTimeout,
      );
    } catch (_) {
      // A reset or a deleted collection: nothing left to wait for.
    }
  }

  Future<_Eval> _evaluate(AutomationRecord a, CardChange change) async {
    final module = _modules[a.moduleId];
    final consent = _consents[a.moduleId];
    if (module == null || module.manifest == null) {
      return const _PreSkip(RunReason.broken);
    }
    switch (moduleStatusOf(module, consent)) {
      case ModuleStatus.broken:
        return const _PreSkip(RunReason.broken);
      case ModuleStatus.needsConsent:
        return const _PreSkip(RunReason.needsConsent);
      case ModuleStatus.ok:
        break;
    }
    switch (a.pausedReason) {
      case PausedReason.broken:
        return const _PreSkip(RunReason.broken);
      case PausedReason.crashed:
        return const _PreSkip(RunReason.crashed);
      case PausedReason.loopSuspected:
        return const _PreSkip(RunReason.loopSuspected);
      case null:
        break;
    }
    try {
      return _Outcome(
        await _evaluator.evaluate(
          change,
          a,
          grants: moduleGrants(
            module.manifest!,
            consent,
            collections: a.collections,
          ),
          today: _today(),
        ),
      );
    } catch (_) {
      return const _Dropped(); // the cache was reset or a stream failed
    }
  }

  void _onEvaluated(AutomationRecord a, CardChange change, _Eval result) {
    final lineage = (
      depth: change.origin.depth + 1,
      chain: [...change.origin.chain, a.id],
    );
    final parent = change.origin.runId;
    switch (result) {
      case _Dropped():
        return;
      case _PreSkip(:final reason):
        _evaluator.record(
          a.id,
          LastCheck(
            cardLabel: _labelOf(change),
            at: _now(),
            result: LastCheckResult.skipped,
            why: "${_reasonText(reason)} → didn't run",
          ),
        );
        _skipEvent(a, _eventTrigger(a, change), reason, lineage, parent);
      case _Outcome(outcome: TriggerSkipped(:final reason, :final why)):
        if (reason == RunReason.broken) {
          _pause(a, PausedReason.broken, why);
        }
        _skipEvent(a, _eventTrigger(a, change), reason, lineage, parent);
      case _Outcome(outcome: TriggerNotFired()):
        return;
      case _Outcome(outcome: final TriggerFired fired):
        _onFired(a, change, fired);
    }
  }

  void _onFired(AutomationRecord a, CardChange change, TriggerFired fired) {
    final trigger = _eventTrigger(
      a,
      change,
      after: fired.after,
      before: fired.before,
      changed: fired.changedFields,
    );
    final verdict = _guard.checkEvent(
      a.id,
      change,
      queuedOfAutomation: _queue.count((r) => r.automation.id == a.id),
      queuedTotal: _queue.length,
    );
    switch (verdict) {
      case LoopAdmitted(:final lineage):
        final run = _Run(
          id: _ids.runId(),
          automation: a,
          trigger: trigger,
          manual: false,
          startedAt: _now(),
          label: _labelFor(a),
          depth: lineage.depth,
          chain: lineage.chain,
          parentRunId: change.origin.runId,
          why: fired.why,
          after: fired.after,
          before: fired.before,
        );
        _live[run.id] = run;
        _queue.add(run, manual: false);
        _notify();
        _pump();
        return;
      case LoopRefused(persist: false, :final reason, :final parentRunId):
        if (reason == RunReason.loop && parentRunId != null) {
          _live[parentRunId]?.selfTriggers++;
        }
        return;
      case LoopRefused(:final reason, :final lineage, :final dropped):
        _evaluator.record(
          a.id,
          LastCheck(
            cardLabel: trigger.cardLabel ?? 'Untitled',
            at: _now(),
            result: LastCheckResult.skipped,
            why: "${_reasonText(reason)} → didn't run",
          ),
        );
        if (reason == RunReason.fanOut) {
          return _fanOut(a, trigger, change.origin.commitId ?? '', dropped);
        }
        if (reason == RunReason.loopSuspected) {
          _pause(a, PausedReason.loopSuspected, null);
          _skipQueued((r) => r.automation.id == a.id, RunReason.loopSuspected);
        }
        _skipEvent(a, trigger, reason, lineage, change.origin.runId);
    }
  }

  /// The stored trigger of an event run: the changed fields and their
  /// values before the change (Run again restores them).
  RunTrigger _eventTrigger(
    AutomationRecord a,
    CardChange change, {
    MorkvaObject? after,
    MorkvaObject? before,
    Set<String>? changed,
  }) {
    final kind = a.trigger.kind;
    after ??= change.after;
    before ??= change.before;
    List<String> filled(MorkvaObject? o) => [
      if (o != null)
        for (final MapEntry(:key, :value) in o.values.entries)
          if (value.isNotEmpty) key,
    ];
    final fields = switch (kind) {
      TriggerKind.cardCreated => filled(after),
      TriggerKind.cardDeleted => filled(before),
      _ => [...?changed],
    };
    return RunTrigger(
      kind: kind,
      collectionId: change.collectionId,
      cardId: change.cardId,
      cardLabel: _labelOf(change),
      changedFields: fields,
      before: before == null || kind == TriggerKind.cardCreated
          ? null
          : {for (final f in fields) f: before[f]?.toJson()},
      changedAt: _now(),
    );
  }

  String _labelOf(CardChange change) {
    final image = change.after ?? change.before!;
    final collection = session.cache.collection(change.collectionId);
    return collection == null
        ? 'Untitled'
        : objectLabels(collection, [image])[image.id] ?? 'Untitled';
  }

  // ----------------------------------------------------------------- queue

  void _pump() {
    final run = _queue.next();
    if (run == null) return;
    run.status = RunStatus.running;
    _notify();
    unawaited(_execute(run, _epoch));
  }

  void _release(_Run run) {
    _queue.release(run);
    _pump();
    _notify();
  }

  Future<void> _execute(_Run run, int epoch) async {
    try {
      await _executeChecked(run, epoch);
    } catch (e, stack) {
      if (epoch != _epoch) return;
      crashMarker.clear();
      _finish(
        run,
        RunStatus.failed,
        reason: RunReason.internal,
        error: RunError(code: 'internal', message: '$e', stack: '$stack'),
      );
    }
    if (epoch == _epoch) _release(run);
  }

  Future<void> _executeChecked(_Run run, int epoch) async {
    final uid = _uid!;
    final a = _loaded
        ? _automations[run.automation.id]
        : await stores.automations.get(run.automation.id);
    if (epoch != _epoch) return;
    if (a == null) {
      return _finish(run, RunStatus.skipped, reason: RunReason.cancelled);
    }
    run.automation = a;
    final module = await stores.modules.get(a.moduleId);
    final consent = await stores.grants.get(uid, a.moduleId);
    if (epoch != _epoch) return;
    run.module = module;
    run.apply =
        a.apply == ApplyMode.auto &&
            a.autoBy == uid &&
            consent?.autoApply == true
        ? ApplyMode.auto
        : ApplyMode.ask;
    final manifest = module?.manifest;
    final skip = switch (module == null || manifest == null
        ? ModuleStatus.broken
        : moduleStatusOf(module, consent)) {
      ModuleStatus.broken => RunReason.broken,
      ModuleStatus.needsConsent => RunReason.needsConsent,
      ModuleStatus.ok => switch (a.pausedReason) {
        PausedReason.broken => RunReason.broken,
        PausedReason.crashed => RunReason.crashed,
        PausedReason.loopSuspected => RunReason.loopSuspected,
        null => a.enabled ? null : RunReason.paused,
      },
    };
    if (skip != null) return _finish(run, RunStatus.skipped, reason: skip);

    final problems = await _problems(a, module, consent);
    if (epoch != _epoch) return;
    if (problems.isNotEmpty) {
      final scope = problems.every(_isScopeProblem);
      if (!scope) _pause(a, PausedReason.broken, problems.first.message);
      return _finish(
        run,
        RunStatus.skipped,
        reason: scope ? RunReason.notPermitted : RunReason.broken,
      );
    }
    if (!await _engineAvailable()) {
      if (epoch != _epoch) return;
      return _finish(
        run,
        RunStatus.skipped,
        reason: RunReason.engineUnavailable,
      );
    }
    if (epoch != _epoch) return;

    final grants = moduleGrants(manifest!, consent, collections: a.collections);
    final today = _today();
    final ctx = await _context(run, module!, grants, today);
    if (epoch != _epoch) return;
    if (ctx == null) {
      return _finish(run, RunStatus.skipped, reason: RunReason.cardGone);
    }
    if (run.stopped) {
      return _finish(run, RunStatus.skipped, reason: RunReason.cancelled);
    }

    final action = manifest.action(a.actionId)!;
    final log = RunLogBuilder(now: _now)..triggerEval = run.why;
    run.log = log;
    crashMarker.set(run.id, a.id);
    final bridge = run.bridge = _bridge.start(
      BridgeRequest(
        moduleId: module.id,
        code: module.code, // the string the hash above covered
        actionId: a.actionId,
        input: action.input?.withDefaults(a.params) ?? a.params,
        context: ctx,
        grants: grants,
        workspaceId: _workspaceId!,
        today: today,
        timeZoneName: timeZoneName,
        timeout: Duration(milliseconds: manifest.timeoutMs),
        onProgress: (p) {
          if (epoch != _epoch) return;
          run.progress = p;
          _notify();
        },
        log: log,
      ),
    );
    final outcome = await bridge.outcome;
    if (epoch != _epoch) return;
    crashMarker.clear();
    run.bridge = null;
    run.links = outcome.log.ui;
    run.summary = outcome.summary;
    switch (outcome.status) {
      case RunStatus.sealing:
        await _sealed(run, outcome.plan!, epoch);
      case RunStatus.failed when outcome.reason == RunReason.engineUnavailable:
        _engineUnavailable = true;
        _finish(run, RunStatus.skipped, reason: RunReason.engineUnavailable);
      case final status:
        _finish(
          run,
          status,
          reason: outcome.reason,
          error: outcome.error,
          summary: outcome.summary,
        );
    }
  }

  /// The action context (design spec, Action context); null when the card
  /// the run is about is gone.
  Future<Map<String, Object?>?> _context(
    _Run run,
    ModuleRecord module,
    Grants grants,
    DateTime today,
  ) async {
    final a = run.automation;
    final t = run.trigger;
    final now = _now();
    Map<String, Object?>? card;
    Map<String, Object?> trigger;
    switch (a.trigger) {
      case ButtonTrigger(scope: ButtonScope.card):
        card = await _shaper.current(
          t.collectionId,
          t.cardId!,
          grants,
          today: today,
        );
        if (card == null) return null;
        trigger = {
          'kind': 'button',
          'scope': 'card',
          'collectionId': t.collectionId,
          'cardId': t.cardId,
        };
      case ButtonTrigger():
        trigger = {
          'kind': 'button',
          'scope': 'collection',
          'collectionId': t.collectionId,
          'viewId': t.viewId,
          'cardIds': t.cardIds ?? const [],
        };
      case EventTrigger(:final kind):
        var after = run.after;
        var before = run.before;
        final schema = session.cache.collection(t.collectionId);
        if (schema == null) return null;
        if (run.manual) {
          // Run again: the card as it is now, before = the stored snapshot.
          final images = await _rerunImages(run, today);
          if (images == null) return null;
          (after, before) = images;
        }
        card = await _shaper.card(schema, after ?? before, grants);
        trigger = {
          'kind': kind.wire,
          'collectionId': t.collectionId,
          'cardId': t.cardId,
          'before': await _shaper.image(schema, before, grants),
          'after': await _shaper.image(schema, after, grants),
          'changedFields': t.changedFields,
        };
    }
    return {
      'runId': run.id,
      'module': {'id': module.id, 'version': module.version},
      'automation': {'id': a.id, 'name': a.name},
      'trigger': trigger,
      'card': card,
      'today': _day(today),
      'now': now.toUtc().toIso8601String(),
      'timeZone': timeZoneName,
    };
  }

  Future<(MorkvaObject?, MorkvaObject?)?> _rerunImages(
    _Run run,
    DateTime today,
  ) async {
    final t = run.trigger;
    final DerivedSnapshot derived;
    try {
      derived = await session.cache.derive(t.collectionId, today: today);
    } on MissingCollectionException {
      return null;
    }
    final stored = derived.base[t.cardId!];
    if (stored == null) return null;
    final after = derived.deriveWith(stored);
    if (t.kind == TriggerKind.cardCreated) return (after, null);
    final values = {...stored.values};
    for (final MapEntry(:key, :value) in (t.before ?? const {}).entries) {
      final field = derived.schema.fieldById(key);
      if (field != null && field is! CalculatedFieldDefinition) {
        values[key] = field.valueFromJson(value);
      }
    }
    return (after, derived.deriveWith(stored.copyWith(values: values)));
  }

  // ----------------------------------------------------------------- apply

  Future<void> _sealed(_Run run, Plan plan, int epoch) async {
    run.status = RunStatus.sealing;
    run.planId = plan.planId;
    _notify();
    final uid = _uid!;
    final a = run.automation;
    final module = await stores.modules.get(a.moduleId);
    final consent = await stores.grants.get(uid, a.moduleId);
    if (epoch != _epoch) return;
    final decision = _policy.decide(
      automation: a,
      uid: uid,
      module: module,
      consent: consent,
      codeHash: run.module!.bundleHash,
      plan: plan,
      takeBudget: _takeBudget,
    );
    final log = run.log!;
    if (decision case ApplyReview(:final why)) log.policy = why;
    final base = _base(run, RunStatus.applying).copyWith(
      planId: () => plan.planId,
      planTitle: () => plan.title,
      log: log.build(),
      summary: () => run.summary,
    );
    switch (decision) {
      case ApplyAuto():
        run.status = RunStatus.applying;
        final record = run.record = base.copyWith(applyStartedAt: () => _now());
        _create(record, epoch);
        _notify();
        final response = await _host.commit(
          record,
          onProgress: (done, total) => _progress(run, done, total, epoch),
        );
        if (epoch != _epoch) return;
        // The next run must not plan against the pre-commit cache.
        try {
          await Future.wait(
            run.settles,
          ).timeout(settleTimeout + const Duration(seconds: 1));
        } catch (_) {}
        if (epoch != _epoch) return;
        _applied(run, plan, response);
      case ApplyReview():
        if (_reviews >= kReviewBacklog) {
          await _host.reject(plan.planId, skipped: true);
          if (epoch != _epoch) return;
          return _finish(
            run,
            RunStatus.skipped,
            reason: RunReason.reviewBacklog,
          );
        }
        session.plans.extend(plan.planId, kReviewTtl, now: _now());
        run.status = RunStatus.awaitingReview;
        final record = run.record = base.copyWith(
          status: RunStatus.awaitingReview,
        );
        _create(record, epoch);
        run.expiry = Timer(kReviewTtl, () {
          if (epoch == _epoch) unawaited(_expire(run, null));
        });
        _announce(run);
    }
  }

  int get _reviews =>
      _live.values.where((r) => r.status == RunStatus.awaitingReview).length;

  bool _takeBudget(int items) {
    if (_guard.takeAutoBudget(items)) return true;
    _autoPausedUntil = _now().add(LoopGuard.kAutoBudgetWindow);
    return false;
  }

  void _progress(_Run run, int done, int total, int epoch) {
    if (epoch != _epoch) return;
    run.progress = RunProgress(done: done, total: total);
    _notify();
  }

  /// Ends an apply: [response] is the `plans.commit` result.
  void _applied(_Run run, Plan plan, HarnessResponse response) {
    switch (response) {
      case HarnessFailure(:final error):
        final offline = error.code == ErrorCode.offline;
        _finish(
          run,
          RunStatus.failed,
          reason: offline ? RunReason.offline : RunReason.internal,
          error: RunError(
            code: offline ? 'offline' : 'internal',
            message: error.message,
          ),
        );
      case HarnessOk(:final result):
        final (receipt, touched) = _receiptOf(plan, result);
        final written = receipt.applied + receipt.queued;
        _finish(
          run,
          written > 0 ? RunStatus.succeeded : RunStatus.failed,
          reason: written > 0 ? null : RunReason.notApplied,
          receipt: receipt,
          journalId: result['journalId'] as String?,
          touched: touched,
          summary: run.summary ?? result['summary'] as String?,
        );
    }
  }

  static (RunReceipt, List<String>) _receiptOf(
    Plan plan,
    Map<String, Object?> result,
  ) {
    List<Object?> list(String key) => (result[key] as List?) ?? const [];
    final failed = list('failed');
    final written = [...list('applied'), ...list('queued')];
    return (
      RunReceipt(
        applied: list('applied').length,
        queued: list('queued').length,
        failed: failed.length,
        stale: list('stale').length,
        unconfirmed: failed
            .where(
              (f) =>
                  f is Map && f['message'] == ItemOutcome.unconfirmed.message,
            )
            .length,
      ),
      [for (final id in written) ?plan.item('$id')?.targetId],
    );
  }

  // ------------------------------------------------------------------- end

  /// Ends [run] with [status]: writes or updates its doc (coalesced skips
  /// share one row), drops it from the live set and announces it.
  void _finish(
    _Run run,
    RunStatus status, {
    RunReason? reason,
    RunError? error,
    String? summary,
    RunReceipt? receipt,
    String? journalId,
    List<String> touched = const [],
    bool announce = true,
  }) {
    final epoch = _epoch;
    run.expiry?.cancel();
    run.status = status;
    run.reason = reason;
    run.error = error ?? run.error;
    run.summary = summary ?? run.summary;
    final now = _now();
    final log = run.log;
    if (log != null && run.selfTriggers > 0) {
      log.console('info', [
        '${run.selfTriggers} change${run.selfTriggers == 1 ? '' : 's'} by '
            "this run didn't re-trigger it",
      ]);
    }
    final previous = run.record;
    final record = (previous ?? _base(run, status)).copyWith(
      status: status,
      reason: () => reason,
      endedAt: () => now,
      durationMs: () => now.difference(run.startedAt).inMilliseconds,
      receipt: () => receipt ?? previous?.receipt,
      journalId: () => journalId ?? previous?.journalId,
      touchedCardIds: touched.isEmpty ? null : touched,
      summary: () => run.summary,
      error: () => run.error,
      log: log?.build() ?? previous?.log,
    );
    run.record = record;
    if (previous != null) {
      _update(record, kFinalRunKeys, epoch);
    } else if (status == RunStatus.skipped &&
        !run.manual &&
        kCoalescedReasons.contains(reason)) {
      _coalesce(record);
    } else {
      _create(record, epoch);
    }
    _records[run.id] = record;
    if (_records.length > 200) _records.remove(_records.keys.first);
    _live.remove(run.id);
    _queue.remove(run);
    _notify();
    if (announce) _announce(run);
  }

  void _announce(_Run run) {
    if (!_finished.isClosed) _finished.add(_view(run));
    _notify();
  }

  /// The doc of [run] so far, as [status].
  RunRecord _base(_Run run, RunStatus status) {
    final a = run.automation;
    final module = run.module ?? _modules[a.moduleId];
    return RunRecord(
      id: run.id,
      status: status,
      moduleId: a.moduleId,
      moduleName: module?.name ?? a.moduleId,
      moduleVersion: module?.version ?? '',
      codeHash: module?.bundleHash ?? '',
      actionId: a.actionId,
      actionLabel: module?.manifest?.action(a.actionId)?.label ?? a.actionId,
      automationId: a.id,
      automationName: a.name,
      trigger: run.trigger,
      params: a.params,
      apply: run.apply,
      by: 'user:$_uid',
      device: device,
      sessionId: sessionId,
      depth: run.depth,
      chain: run.chain,
      parentRunId: run.parentRunId,
      startedAt: run.startedAt,
      log: RunLog(triggerEval: run.why),
    );
  }

  /// A skip row of an event that never became a queued run.
  RunRecord _skipRecord(
    AutomationRecord a,
    RunTrigger trigger,
    RunReason reason, {
    RunLineage? lineage,
    String? parentRunId,
  }) {
    final run = _Run(
      id: _ids.runId(),
      automation: a,
      trigger: trigger,
      manual: false,
      startedAt: _now(),
      label: _labelFor(a),
      depth: lineage?.depth ?? 1,
      chain: lineage?.chain ?? [a.id],
      parentRunId: parentRunId,
    );
    final now = _now();
    return _base(
      run,
      RunStatus.skipped,
    ).copyWith(reason: () => reason, endedAt: () => now, durationMs: () => 0);
  }

  void _skipEvent(
    AutomationRecord a,
    RunTrigger trigger,
    RunReason reason,
    RunLineage lineage,
    String? parentRunId,
  ) {
    final row = _skipRecord(
      a,
      trigger,
      reason,
      lineage: lineage,
      parentRunId: parentRunId,
    );
    if (kCoalescedReasons.contains(reason)) {
      _coalesce(row);
    } else {
      _create(row, _epoch);
    }
  }

  /// One row per automation and reason this session; later skips bump it.
  void _coalesce(RunRecord row) {
    final key = '${row.automationId}|${row.reason?.wire}';
    final existing = _coalesced[key];
    if (existing == null) {
      _coalesced[key] = row;
      _create(row, _epoch);
      return;
    }
    final bumped = _coalesced[key] = existing.copyWith(
      count: existing.count + 1,
      endedAt: () => _now(),
    );
    _update(bumped, const {'count', 'endedAt'}, _epoch);
  }

  /// `fan_out`: one row per automation and commit, counting the dropped.
  void _fanOut(
    AutomationRecord a,
    RunTrigger trigger,
    String commitId,
    int dropped,
  ) {
    final key = '${a.id}|fan_out|$commitId';
    final existing = _coalesced[key];
    if (dropped == 1 || existing == null) {
      final row = _coalesced[key] = _skipRecord(a, trigger, RunReason.fanOut);
      _create(row, _epoch);
      return;
    }
    final bumped = _coalesced[key] = existing.copyWith(
      count: dropped,
      endedAt: () => _now(),
    );
    _update(bumped, const {'count', 'endedAt'}, _epoch);
  }

  void _create(RunRecord run, int epoch) {
    if (epoch != _epoch) return;
    // A failed audit write can't be retried usefully; the outcome is shown
    // from memory either way.
    stores.runs.create(run).catchError(_ignore);
    if (++_created % 25 == 0) _prune(epoch);
  }

  void _update(RunRecord run, Set<String> fields, int epoch) {
    if (epoch != _epoch) return;
    stores.runs.update(run, fields: fields).catchError(_ignore);
  }

  void _prune(int epoch) {
    if (epoch != _epoch) return;
    stores.runs.prune().then((_) {}, onError: _ignore);
  }

  void _pause(AutomationRecord a, PausedReason reason, String? detail) {
    final current = _automations[a.id] ?? a;
    if (current.pausedReason == reason) return;
    final paused = current.withPause(reason, detail: detail, now: _now());
    _automations = {..._automations, a.id: paused};
    stores.automations.save(paused).catchError(_ignore);
  }

  /// Skips every waiting run that passes [test].
  void _skipQueued(bool Function(_Run run) test, RunReason reason) {
    for (final run in _queue.removeWhere(test)) {
      _finish(run, RunStatus.skipped, reason: reason);
    }
  }

  // ---------------------------------------------------------------- checks

  Future<bool> _engineAvailable() async {
    EngineStatus status;
    try {
      status = await engine.status();
    } catch (_) {
      status = EngineStatus.unavailable;
    }
    final available = status == EngineStatus.available;
    if (_engineUnavailable == available) {
      _engineUnavailable = !available;
      _notify();
    }
    return available;
  }

  /// The save-time checks of [a] over the cache, with its trigger
  /// collection and reference targets leased so card operands resolve.
  Future<List<AutomationProblem>> _problems(
    AutomationRecord a,
    ModuleRecord? module,
    GrantRecord? consent,
  ) async {
    final cache = session.cache;
    await cache.ready;
    final id = a.trigger.collectionId;
    final collection = cache.collection(id);
    Lease? lease;
    if (collection != null) {
      try {
        lease = await cache.lease({
          id,
          for (final f in collection.fields)
            if (f case ReferenceFieldDefinition(
              :final targetCollectionId,
            ) when cache.collection(targetCollectionId) != null)
              targetCollectionId,
        });
      } on MissingCollectionException {
        // Validation reports what is gone.
      }
    }
    try {
      return validateAutomation(
        a,
        module: module,
        consent: consent,
        workspace: CacheWorkspaceReader(cache),
        today: _today(),
      );
    } finally {
      lease?.release();
    }
  }

  static bool _isScopeProblem(AutomationProblem p) =>
      p.path == 'trigger.collection' && p.code == ErrorCode.notPermitted.wire;

  /// Schema revalidation: an automation whose field, option or collection
  /// is gone becomes `broken` at once, not at its next run.
  Future<void> _revalidate(int epoch) async {
    for (final a in [..._automations.values]) {
      if (a.pausedReason != null) continue;
      final module = _modules[a.moduleId];
      if (module?.manifest == null) continue;
      final List<AutomationProblem> problems;
      try {
        problems = await _problems(a, module, _consents[a.moduleId]);
      } catch (_) {
        continue;
      }
      if (epoch != _epoch) return;
      final real = problems.where((p) => !_isScopeProblem(p));
      if (real.isNotEmpty) _pause(a, PausedReason.broken, real.first.message);
    }
  }

  /// One lease per collection that has an enabled event automation, so
  /// settle checks stay cheap.
  void _refreshLeases() {
    final cache = session.cache;
    final want = {
      for (final a in _automations.values)
        if (a.enabled &&
            a.trigger is EventTrigger &&
            cache.collection(a.trigger.collectionId) != null)
          a.trigger.collectionId,
    };
    for (final id in [..._leases.keys]) {
      if (want.contains(id)) continue;
      _leases.remove(id)!.then((l) => l?.release(), onError: _ignore);
    }
    for (final id in want) {
      _leases.putIfAbsent(
        id,
        () => cache.lease([id]).then<Lease?>((l) => l, onError: (_) => null),
      );
    }
  }

  /// Start-up: this session's reviews whose plan is gone expire, its runs
  /// left applying are finalized as interrupted; any session's review past
  /// 8 h expires.
  void _finalizeOwn(List<RunRecord> runs) {
    final now = _now();
    for (final r in runs) {
      final own = r.sessionId == sessionId && !_live.containsKey(r.id);
      final applying =
          r.status == RunStatus.applying ||
          r.status == RunStatus.awaitingReview && r.applyStartedAt != null;
      RunRecord? done;
      if (own && applying) {
        done = r.copyWith(
          status: RunStatus.failed,
          reason: () => RunReason.interrupted,
          endedAt: () => now,
          error: () => const RunError(
            code: 'interrupted',
            message: 'Interrupted — may be partly applied, check the cards.',
          ),
        );
      } else if (r.status == RunStatus.awaitingReview &&
          r.applyStartedAt == null &&
          (own || !now.isBefore(r.startedAt.add(kReviewTtl)))) {
        done = r.copyWith(status: RunStatus.expired, endedAt: () => now);
      }
      if (done != null) _update(done, kFinalRunKeys, _epoch);
    }
  }

  /// A breadcrumb left by a run the page died in: pause its automation as
  /// `crashed` and write the `failed: crashed` row.
  Future<void> _recoverCrash(
    ({String runId, String automationId}) crash,
    int epoch,
  ) async {
    try {
      final a = await stores.automations.get(crash.automationId);
      if (a == null || epoch != _epoch) return;
      final module = await stores.modules.get(a.moduleId);
      if (epoch != _epoch) return;
      const message =
          'The page stopped while this ran — probably out of memory';
      _automations = {..._automations, a.id: a};
      _pause(a, PausedReason.crashed, message);
      final run = _Run(
        id: crash.runId,
        automation: a,
        trigger: RunTrigger(
          kind: a.trigger.kind,
          collectionId: a.trigger.collectionId,
        ),
        manual: false,
        startedAt: _now(),
        label: _labelFor(a),
      )..module = module;
      final now = _now();
      _create(
        _base(run, RunStatus.failed).copyWith(
          reason: () => RunReason.crashed,
          endedAt: () => now,
          durationMs: () => 0,
          error: () => const RunError(code: 'crashed', message: message),
        ),
        epoch,
      );
    } catch (_) {
      // Best effort: the automation stays as it was.
    }
  }

  /// Rejects this session's reviews whose module is gone, changed or no
  /// longer consented.
  void _checkReviews() {
    if (!_loaded) return;
    for (final run in [..._live.values]) {
      if (run.status != RunStatus.awaitingReview) continue;
      final module = _modules[run.automation.moduleId];
      final consent = _consents[run.automation.moduleId];
      final reason = module == null
          ? RunReason.uninstalled
          : module.bundleHash != run.module?.bundleHash
          ? RunReason.codeChanged
          : consent == null
          ? RunReason.needsConsent
          : null;
      if (reason != null) unawaited(_rejectRun(run, reason));
    }
  }

  Future<void> _rejectRun(_Run run, RunReason? reason) async {
    if (run.status != RunStatus.awaitingReview) return;
    run.status = RunStatus.rejected; // no second reject meanwhile
    final epoch = _epoch;
    await _host.reject(run.planId!);
    if (epoch != _epoch) return;
    _finish(run, RunStatus.rejected, reason: reason);
  }

  Future<void> _expire(_Run run, RunReason? reason) async {
    if (run.status != RunStatus.awaitingReview) return;
    run.status = RunStatus.expired;
    final epoch = _epoch;
    await _host.reject(run.planId!, skipped: true);
    if (epoch != _epoch) return;
    _finish(run, RunStatus.expired, reason: reason);
  }

  // ------------------------------------------------------------ user: runs

  @override
  Future<String> pressCard(String automationId, {required String cardId}) =>
      _press(automationId, ButtonScope.card, (a) {
        final collection = session.cache.collection(a.trigger.collectionId);
        final card = session.cache.current(a.trigger.collectionId)?[cardId];
        return RunTrigger(
          kind: TriggerKind.button,
          collectionId: a.trigger.collectionId,
          cardId: cardId,
          cardLabel: collection == null || card == null
              ? null
              : objectLabels(collection, [card])[cardId],
        );
      });

  @override
  Future<String> pressCollection(
    String automationId, {
    required List<String> cardIds,
    String? viewId,
  }) => _press(
    automationId,
    ButtonScope.collection,
    (a) => RunTrigger(
      kind: TriggerKind.button,
      collectionId: a.trigger.collectionId,
      viewId: viewId,
      cardIds: cardIds.take(kRunCardIdsMax).toList(),
      cardCount: cardIds.length,
    ),
  );

  Future<String> _press(
    String automationId,
    ButtonScope scope,
    RunTrigger Function(AutomationRecord a) trigger,
  ) async {
    // The automations listener may lag a button the UI already shows.
    final a =
        _automations[automationId] ??
        await stores.automations.get(automationId);
    if (_uid == null ||
        a == null ||
        a.trigger is! ButtonTrigger ||
        (a.trigger as ButtonTrigger).scope != scope) {
      throw const AutomationRefused('broken', 'This button is gone.');
    }
    return _startManual(a, trigger(a));
  }

  String _startManual(
    AutomationRecord a,
    RunTrigger trigger, {
    String? parentRunId,
  }) {
    final verdict = _guard.checkManual(
      a.id,
      queuedOfAutomation: _queue.count((r) => r.automation.id == a.id),
      queuedTotal: _queue.length,
    );
    final run = _Run(
      id: _ids.runId(),
      automation: a,
      trigger: trigger,
      manual: true,
      startedAt: _now(),
      label: _labelFor(a),
      parentRunId: parentRunId,
      chain: verdict.lineage.chain,
    );
    if (verdict case LoopRefused(:final reason)) {
      _finish(run, RunStatus.skipped, reason: reason);
      return run.id;
    }
    _live[run.id] = run;
    _queue.add(run, manual: true);
    _notify();
    _pump();
    return run.id;
  }

  @override
  Future<String> runAgain(String runId) async {
    final epoch = _epoch;
    final old = _records[runId] ?? await stores.runs.get(runId);
    if (epoch != _epoch) {
      throw const AutomationRefused('cancelled', 'Signed out.');
    }
    final automationId = old?.automationId;
    final a = automationId == null ? null : _automations[automationId];
    if (old == null || a == null) {
      throw const AutomationRefused('broken', 'This automation is gone.');
    }
    if (old.trigger.kind == TriggerKind.cardDeleted) {
      throw const AutomationRefused('card_gone', 'The card was deleted.');
    }
    final unknown =
        old.reason == RunReason.interrupted ||
        old.status == RunStatus.applying ||
        old.status == RunStatus.awaitingReview && old.applyStartedAt != null ||
        (old.receipt?.unconfirmed ?? 0) > 0;
    if (unknown) {
      throw const AutomationRefused(
        'unknown',
        'It may already be applied — check the cards first.',
      );
    }
    _requireOnline();
    if (old.status == RunStatus.awaitingReview) {
      final live = _live[runId];
      if (live != null) {
        await _expire(live, RunReason.superseded);
      } else {
        _update(
          old.copyWith(
            status: RunStatus.expired,
            reason: () => RunReason.superseded,
            endedAt: () => _now(),
          ),
          kFinalRunKeys,
          epoch,
        );
      }
    }
    return _startManual(a, old.trigger, parentRunId: old.id);
  }

  @override
  void stop(String runId) {
    final run = _live[runId];
    if (run == null) return;
    if (_queue.remove(run)) {
      _finish(run, RunStatus.skipped, reason: RunReason.cancelled);
    } else if (run.status == RunStatus.running) {
      run.stopped = true;
      run.bridge?.stop();
    }
  }

  @override
  Future<void> approve(String runId, {Set<String>? itemIds}) async {
    final run = _live[runId];
    if (run == null ||
        run.status != RunStatus.awaitingReview ||
        run.approving) {
      throw const AutomationRefused(
        'expired',
        'This review is no longer available.',
      );
    }
    run.approving = true;
    try {
      await _approve(run, itemIds);
    } finally {
      run.approving = false;
    }
  }

  Future<void> _approve(_Run run, Set<String>? itemIds) async {
    final epoch = _epoch;
    final plan = session.plans.get(run.planId!);
    if (plan == null || plan.isExpired(_now())) {
      await _expire(run, null);
      throw const AutomationRefused(
        'expired',
        'This review expired — run it again.',
      );
    }
    _requireOnline();
    final uid = _uid!;
    final module = await stores.modules.get(run.automation.moduleId);
    final consent = await stores.grants.get(uid, run.automation.moduleId);
    if (epoch != _epoch) {
      throw const AutomationRefused('cancelled', 'Signed out.');
    }
    if (module == null ||
        moduleStatusOf(module, consent) != ModuleStatus.ok ||
        module.bundleHash != run.module!.bundleHash) {
      throw const AutomationRefused('needs_consent', kPermissionsChanged);
    }
    // Rules refuse `applyStartedAt` unless the doc still awaits review here.
    final doc = await stores.runs.get(run.id);
    var record = run.record!;
    if (doc == null ||
        doc.status != RunStatus.awaitingReview ||
        doc.applyStartedAt != null ||
        doc.sessionId != sessionId) {
      throw const AutomationRefused(
        'replaced',
        'This review was replaced in another window.',
      );
    }
    record = run.record = record.copyWith(applyStartedAt: () => _now());
    try {
      await stores.runs.update(record, fields: const {'applyStartedAt'});
    } catch (_) {
      throw const AutomationRefused(
        'replaced',
        'This review was replaced in another window.',
      );
    }
    if (epoch != _epoch) {
      throw const AutomationRefused('cancelled', 'Signed out.');
    }
    run.status = RunStatus.applying;
    _notify();
    final response = await _host.commit(
      record,
      itemIds: itemIds,
      onProgress: (done, total) => _progress(run, done, total, epoch),
    );
    if (epoch != _epoch) return;
    if (response case HarnessFailure(
      :final error,
    ) when error.code == ErrorCode.offline) {
      // Nothing was written: back to review.
      run.status = RunStatus.awaitingReview;
      run.progress = null;
      record = run.record = record.copyWith(applyStartedAt: () => null);
      _update(record, const {'applyStartedAt'}, epoch);
      _notify();
      throw AutomationRefused('offline', error.message);
    }
    _applied(run, plan, response);
  }

  @override
  Future<void> reject(String runId) async {
    final run = _live[runId];
    if (run == null || run.approving) return;
    await _rejectRun(run, null);
  }

  @override
  Future<void> undo(String runId) async {
    final record = _records[runId];
    if (record == null || !canUndo(runId)) {
      throw const AutomationRefused(
        'expired',
        "Undo isn't available any more.",
      );
    }
    final epoch = _epoch;
    final response = await _host.undo(record);
    if (epoch != _epoch) return;
    switch (response) {
      case HarnessFailure(:final error):
        throw AutomationRefused(error.code.wire, error.message);
      case HarnessOk():
        final undone = _records[runId] = record.copyWith(
          undoneAt: () => _now(),
        );
        _update(undone, const {'undoneAt'}, epoch);
        _notify();
    }
  }

  @override
  bool canUndo(String runId) {
    final record = _records[runId];
    final journalId = record?.journalId;
    if (record == null || journalId == null || record.undoneAt != null) {
      return false;
    }
    final entry = session.journal.get(journalId);
    return entry != null && !entry.isExpired(_now());
  }

  @override
  Future<void> retryFailed(String runId) async {
    final record = _records[runId];
    final plan = record?.planId == null
        ? null
        : session.plans.get(record!.planId!);
    if (record == null || plan == null) {
      throw const AutomationRefused(
        'expired',
        "Retry isn't available any more — run it again.",
      );
    }
    _requireOnline();
    final epoch = _epoch;
    final response = await _host.retryFailed(record);
    if (epoch != _epoch) return;
    switch (response) {
      case HarnessFailure(:final error):
        throw AutomationRefused(error.code.wire, error.message);
      case HarnessOk(:final result):
        final (receipt, touched) = _receiptOf(plan, result);
        final updated = _records[runId] = record.copyWith(
          receipt: () => receipt,
          summary: () => result['summary'] as String? ?? record.summary,
          journalId: () => result['journalId'] as String? ?? record.journalId,
          touchedCardIds: touched,
        );
        _update(updated, kAppliedRunKeys, epoch);
        _notify();
    }
  }

  @override
  Map<String, Object?>? reviewPlan(String runId) {
    final run = _live[runId];
    if (run == null || run.status != RunStatus.awaitingReview) return null;
    final plan = session.plans.get(run.planId!);
    return plan == null || plan.isExpired(_now()) ? null : plan.toJson();
  }

  void _requireOnline() {
    try {
      session.committer.requireOnline();
    } on HarnessException catch (e) {
      throw AutomationRefused('offline', e.error.message);
    }
  }

  // --------------------------------------------------------- user: modules

  @override
  Future<void> install(
    ModuleBundle bundle, {
    required List<String>? collections,
  }) async {
    final uid = _signedIn();
    final existing = await stores.modules.get(bundle.manifest.id);
    final module = ModuleRecord.fromBundle(
      bundle,
      source: ModuleSource.import,
      createdBy: existing?.createdBy ?? 'user:$uid',
      now: _now(),
      createdAt: existing?.createdAt,
    );
    await _write(() => stores.modules.save(module));
    await _write(
      () => stores.grants.save(uid, _consentTo(bundle, collections)),
    );
  }

  @override
  Future<void> allow(
    ModuleBundle displayed, {
    required List<String>? collections,
  }) async {
    final uid = _signedIn();
    await _write(
      () => stores.grants.save(uid, _consentTo(displayed, collections)),
    );
  }

  GrantRecord _consentTo(ModuleBundle bundle, List<String>? collections) =>
      GrantRecord(
        moduleId: bundle.manifest.id,
        codeHash: bundleHashOf(bundle.manifestJson, bundle.code),
        version: bundle.manifest.version,
        codeBytes: bundle.codeBytes,
        caps: bundle.manifest.capabilities,
        collections: collections,
        autoApply: false,
        grantedAt: _now(),
        via: GrantVia.consentSheet,
      );

  @override
  Future<void> changeAccess(
    String moduleId, {
    required List<String>? collections,
  }) async {
    final uid = _signedIn();
    final consent = await stores.grants.get(uid, moduleId);
    if (consent == null) {
      throw const AutomationRefused('needs_consent', 'Allow the module first.');
    }
    await _write(
      () => stores.grants.save(
        uid,
        consent.copyWith(collections: () => collections),
      ),
    );
  }

  @override
  Future<void> setAutoApply(String moduleId, {required bool on}) async {
    final uid = _signedIn();
    final module = await stores.modules.get(moduleId);
    final consent = await stores.grants.get(uid, moduleId);
    if (module == null || consent == null) {
      throw const AutomationRefused('needs_consent', 'Allow the module first.');
    }
    if (on &&
        (moduleStatusOf(module, consent) != ModuleStatus.ok ||
            !module.manifest!.autoApplyEligible)) {
      throw const AutomationRefused(
        'not_permitted',
        "This module's changes always need review.",
      );
    }
    await _write(
      () => stores.grants.save(uid, consent.copyWith(autoApply: on)),
    );
  }

  @override
  Future<void> revoke(String moduleId) async {
    final uid = _signedIn();
    await _dropModuleRuns(moduleId, RunReason.needsConsent);
    await _write(() => stores.grants.delete(uid, moduleId));
  }

  @override
  Future<void> uninstall(String moduleId) async {
    final uid = _signedIn();
    final automations = [
      for (final a in _automations.values)
        if (a.moduleId == moduleId) a.id,
    ];
    await _dropModuleRuns(moduleId, RunReason.uninstalled);
    for (final id in automations) {
      await _write(() => stores.automations.delete(id));
    }
    await _write(() => stores.grants.delete(uid, moduleId));
    await _write(() => stores.modules.delete(moduleId));
  }

  /// Before the docs go (their watches would reject with a vaguer reason):
  /// waiting runs are skipped, reviews rejected with [reason].
  Future<void> _dropModuleRuns(String moduleId, RunReason reason) {
    _skipQueued(
      (r) => r.automation.moduleId == moduleId,
      RunReason.needsConsent,
    );
    return Future.wait([
      for (final run in [..._live.values])
        if (run.automation.moduleId == moduleId) _rejectRun(run, reason),
    ]);
  }

  String _signedIn() =>
      _uid ?? (throw const AutomationRefused('not_permitted', 'Signed out.'));

  static Future<void> _write(Future<void> Function() write) async {
    try {
      await write();
    } catch (_) {
      throw const AutomationRefused(
        'internal',
        "Couldn't save the change. Try again.",
      );
    }
  }

  // ----------------------------------------------------- user: automations

  @override
  Future<List<AutomationProblem>> validate(AutomationRecord draft) async {
    final module = await stores.modules.get(draft.moduleId);
    final uid = _uid;
    final consent = uid == null
        ? null
        : await stores.grants.get(uid, draft.moduleId);
    return _problems(draft, module, consent);
  }

  @override
  Future<void> saveAutomation(AutomationRecord automation) async {
    final problems = await validate(automation);
    if (problems.isNotEmpty) throw ManifestProblems(problems);
    final saved = automation.pausedReason == PausedReason.broken
        ? automation.withPause(null, now: _now())
        : automation.copyWith(updatedAt: _now());
    await _write(() => stores.automations.save(saved));
  }

  @override
  Future<void> deleteAutomation(String automationId) async {
    await _write(() => stores.automations.delete(automationId));
    _skipQueued((r) => r.automation.id == automationId, RunReason.cancelled);
    _evaluator.forget(automationId);
  }

  @override
  Future<void> resume(String automationId) async {
    final a =
        _automations[automationId] ??
        await stores.automations.get(automationId);
    if (a == null) {
      throw const AutomationRefused('broken', 'This automation is gone.');
    }
    _guard.resume(automationId);
    await _write(() => stores.automations.save(a.withPause(null, now: _now())));
  }

  // ----------------------------------------------------------------- hooks

  @override
  List<LastCheck> lastChecks(String automationId, {int limit = 20}) =>
      _evaluator.lastChecks(automationId, limit: limit);

  /// A dry run outside the queue. The bridge seals whatever was planned;
  /// the plan is dropped at once, never committed, and no run doc is
  /// written.
  @override
  Future<TestRunResult> testRun(TestRunRequest request) async {
    final uid = _uid;
    final module = await stores.modules.get(request.moduleId);
    final consent = uid == null
        ? null
        : await stores.grants.get(uid, request.moduleId);
    final manifest = module?.manifest;
    if (module == null || manifest == null) {
      return const TestRunResult(
        status: RunStatus.skipped,
        reason: RunReason.broken,
      );
    }
    if (moduleStatusOf(module, consent) != ModuleStatus.ok) {
      return const TestRunResult(
        status: RunStatus.skipped,
        reason: RunReason.needsConsent,
      );
    }
    final action = manifest.action(request.actionId);
    if (action == null) {
      return const TestRunResult(
        status: RunStatus.skipped,
        reason: RunReason.broken,
      );
    }
    if (!await _engineAvailable()) {
      return const TestRunResult(
        status: RunStatus.skipped,
        reason: RunReason.engineUnavailable,
      );
    }
    final grants = moduleGrants(manifest, consent);
    final today = _today();
    final collectionId = request.collectionId;
    Map<String, Object?>? card;
    if (request.cardId case final cardId?) {
      if (collectionId == null) {
        return const TestRunResult(
          status: RunStatus.skipped,
          reason: RunReason.cardGone,
        );
      }
      card = await _shaper.current(collectionId, cardId, grants, today: today);
      if (card == null) {
        return const TestRunResult(
          status: RunStatus.skipped,
          reason: RunReason.cardGone,
        );
      }
    }
    final runId = _ids.runId();
    final outcome = await _bridge
        .start(
          BridgeRequest(
            moduleId: module.id,
            code: module.code,
            actionId: action.id,
            input: action.input?.withDefaults(request.params) ?? request.params,
            context: {
              'runId': runId,
              'module': {'id': module.id, 'version': module.version},
              'automation': null,
              'trigger': {
                'kind': 'test',
                'as': request.cardId == null
                    ? {
                        'kind': 'button',
                        'scope': 'collection',
                        'collectionId': collectionId,
                        'viewId': null,
                        'cardIds': const <String>[],
                      }
                    : {
                        'kind': 'button',
                        'scope': 'card',
                        'collectionId': collectionId,
                        'cardId': request.cardId,
                      },
              },
              'card': card,
              'today': _day(today),
              'now': _now().toUtc().toIso8601String(),
              'timeZone': timeZoneName,
            },
            grants: grants,
            workspaceId: _workspaceId ?? '',
            today: today,
            timeZoneName: timeZoneName,
            timeout: Duration(milliseconds: manifest.timeoutMs),
          ),
        )
        .outcome;
    if (outcome.plan case final plan?) session.plans.remove(plan.planId);
    final (status, reason) = switch (outcome.status) {
      RunStatus.sealing => (RunStatus.succeeded, null),
      RunStatus.failed when outcome.reason == RunReason.engineUnavailable => (
        RunStatus.skipped,
        RunReason.engineUnavailable,
      ),
      final s => (s, outcome.reason),
    };
    return TestRunResult(
      status: status,
      reason: reason,
      summary: outcome.summary,
      plan: outcome.log.plan,
      log: outcome.log,
      error: outcome.error,
    );
  }

  // --------------------------------------------------------------- helpers

  DateTime _today() {
    final n = _now();
    return DateTime(n.year, n.month, n.day);
  }

  static String _day(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// The button label, else the action's label, else the automation name.
  String _labelFor(AutomationRecord a) =>
      a.button?.label ??
      _modules[a.moduleId]?.manifest?.action(a.actionId)?.label ??
      a.name;

  static String _reasonText(RunReason reason) => switch (reason) {
    RunReason.needsConsent => 'The module needs consent',
    RunReason.broken => 'The automation is broken',
    RunReason.crashed => 'The automation crashed earlier',
    RunReason.loopSuspected => 'Paused: it looked like a loop',
    RunReason.loop => 'It would loop',
    RunReason.depthLimit => 'Too many automations in a row',
    RunReason.fanOut => 'Too many cards in one change',
    RunReason.queueFull => 'Too many runs waiting',
    _ => 'Skipped (${reason.wire})',
  };

  static void _ignore(Object error, [StackTrace? stack]) {}
}

/// One run of this session, from trigger to its end.
final class _Run {
  _Run({
    required this.id,
    required this.automation,
    required this.trigger,
    required this.manual,
    required this.startedAt,
    required this.label,
    this.depth = 1,
    List<String>? chain,
    this.parentRunId,
    this.why,
    this.after,
    this.before,
  }) : chain = chain ?? [automation.id];

  final String id;

  /// As of the trigger; refreshed when the run starts.
  AutomationRecord automation;
  final RunTrigger trigger;

  /// A button press or Run again (ahead of event runs; button-like policy).
  final bool manual;
  final DateTime startedAt;
  final String label;
  final int depth;
  final List<String> chain;
  final String? parentRunId;

  /// The trigger evaluation line.
  final String? why;

  /// Event images with calculated values (TriggerFired).
  final MorkvaObject? after;
  final MorkvaObject? before;

  RunStatus status = RunStatus.queued;
  RunReason? reason;
  RunProgress? progress;
  String? summary;
  RunError? error;
  List<UiLink> links = const [];
  String? planId;
  ApplyMode apply = ApplyMode.ask;

  /// The module record read once at start: its hash and code are the run's.
  ModuleRecord? module;
  RunLogBuilder? log;
  BridgeRun? bridge;
  RunRecord? record;
  Timer? expiry;
  bool stopped = false;
  bool approving = false;

  /// Direct self-triggers of its own writes (not persisted; logged).
  int selfTriggers = 0;

  /// Settle and evaluation of the changes its commit caused.
  final settles = <Future<void>>[];
}

sealed class _Eval {
  const _Eval();
}

/// Not evaluated: the module or the automation can't run.
final class _PreSkip extends _Eval {
  const _PreSkip(this.reason);
  final RunReason reason;
}

final class _Outcome extends _Eval {
  const _Outcome(this.outcome);
  final TriggerOutcome outcome;
}

/// The evaluation threw (a reset): nothing to record.
final class _Dropped extends _Eval {
  const _Dropped();
}

final class _NoCrashMarker implements CrashMarker {
  const _NoCrashMarker();

  @override
  void set(String runId, String automationId) {}

  @override
  void clear() {}

  @override
  ({String runId, String automationId})? leftover() => null;
}
