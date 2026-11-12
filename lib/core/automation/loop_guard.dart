import 'dart:collection';

import '../../api/data/data_repository.dart';
import '../domain/automation/automation.dart';

/// A run's place in its trigger chain: event runs take the change's depth
/// + 1 and its chain + this automation; button, Run-again and test runs
/// start at depth 1 with `[automationId]`.
typedef RunLineage = ({int depth, List<String> chain});

/// What [LoopGuard] said about a would-be run.
sealed class LoopVerdict {
  const LoopVerdict(this.lineage);

  /// The depth and chain the run (or its skip row) carries.
  final RunLineage lineage;
}

/// The run may be queued; the guard has counted it.
final class LoopAdmitted extends LoopVerdict {
  const LoopAdmitted(super.lineage);
}

/// The run is skipped with [reason].
final class LoopRefused extends LoopVerdict {
  const LoopRefused(
    super.lineage,
    this.reason, {
    this.persist = true,
    this.parentRunId,
    this.dropped = 0,
  });

  /// `duplicate`, `loop`, `depth_limit`, `fan_out`, `loop_suspected` or
  /// `queue_full`. `loop_suspected` means the rate breaker tripped: pause
  /// the automation.
  final RunReason reason;

  /// False for `duplicate` and a direct self-trigger (`loop` with
  /// `chain.last == automationId`): no run doc; the parent run
  /// ([parentRunId]) counts the self-trigger in its log instead.
  final bool persist;

  /// The run whose write caused this change, when one did.
  final String? parentRunId;

  /// `fan_out` only: how many runs of this automation the commit has
  /// dropped so far, this one included. 1 = write the one coalesced row,
  /// more = update its count ("82 more cards were not processed").
  final int dropped;
}

/// Loop and rate safety for automation runs (design spec, Loop & rate
/// safety, guards 3–9). Asked about a run that would start, after the
/// trigger's fire rule passed (so a write the conditions ignore never
/// becomes a `loop` row). Session memory only; time comes from [now], so it
/// holds no timers.
final class LoopGuard {
  LoopGuard({DateTime Function()? now}) : _now = now ?? DateTime.now;

  static const int kMaxDepth = 3;
  static const int kFanOutCap = 100;
  static const int kSeenCap = 10000;
  static const int kFanOutKeysCap = 1000;
  static const Duration kBreakerWindow = Duration(seconds: 60);
  static const int kBreakerPerAutomation = 30;
  static const int kBreakerPerWorkspace = 120;
  static const Duration kAutoBudgetWindow = Duration(minutes: 10);
  static const int kAutoBudgetItems = 1000;
  static const int kQueuePerAutomation = 100;
  static const int kQueuePerWorkspace = 500;

  final DateTime Function() _now;

  /// `automationId|writeId` keys, oldest first (an LRU of [kSeenCap]).
  final LinkedHashSet<String> _seen = LinkedHashSet();

  /// Started / dropped runs per `automationId|commitId`, oldest first.
  final LinkedHashMap<String, _FanOut> _fanOut = LinkedHashMap();

  /// Start times of admitted chained (depth ≥ 2) runs.
  final Map<String, Queue<DateTime>> _chainedByAutomation = {};
  final Queue<DateTime> _chainedAll = Queue();

  final Queue<({DateTime at, int items})> _autoApplied = Queue();

  /// An event run of [automationId] caused by [change]. [queuedOfAutomation]
  /// and [queuedTotal] are the queue's current counts.
  LoopVerdict checkEvent(
    String automationId,
    CardChange change, {
    required int queuedOfAutomation,
    required int queuedTotal,
  }) {
    final origin = change.origin;
    final lineage = (
      depth: origin.depth + 1,
      chain: List<String>.unmodifiable([...origin.chain, automationId]),
    );
    if (!_seen.add('$automationId|${change.writeId}')) {
      return LoopRefused(lineage, RunReason.duplicate, persist: false);
    }
    if (_seen.length > kSeenCap) _seen.remove(_seen.first);

    if (origin.chain.contains(automationId)) {
      return LoopRefused(
        lineage,
        RunReason.loop,
        persist: origin.chain.last != automationId,
        parentRunId: origin.runId,
      );
    }
    if (lineage.depth > kMaxDepth) {
      return LoopRefused(lineage, RunReason.depthLimit);
    }

    final commitId = origin.commitId;
    final fanOut = commitId == null
        ? null
        : _fanOut.putIfAbsent('$automationId|$commitId', _FanOut.new);
    if (_fanOut.length > kFanOutKeysCap) _fanOut.remove(_fanOut.keys.first);
    if (fanOut != null && fanOut.started >= kFanOutCap) {
      return LoopRefused(lineage, RunReason.fanOut, dropped: ++fanOut.dropped);
    }

    final now = _now();
    final chained = lineage.depth >= 2;
    final mine = _chainedByAutomation.putIfAbsent(automationId, Queue.new);
    if (chained) {
      _prune(mine, now);
      _prune(_chainedAll, now);
      if (mine.length >= kBreakerPerAutomation ||
          _chainedAll.length >= kBreakerPerWorkspace) {
        return LoopRefused(lineage, RunReason.loopSuspected);
      }
    }

    if (_queueFull(queuedOfAutomation, queuedTotal)) {
      return LoopRefused(lineage, RunReason.queueFull);
    }

    fanOut?.started++;
    if (chained) {
      mine.add(now);
      _chainedAll.add(now);
    }
    return LoopAdmitted(lineage);
  }

  /// A button or Run-again run of [automationId] (test runs bypass the
  /// queue): depth 1, only the queue caps apply.
  LoopVerdict checkManual(
    String automationId, {
    required int queuedOfAutomation,
    required int queuedTotal,
  }) {
    final lineage = (
      depth: 1,
      chain: List<String>.unmodifiable([automationId]),
    );
    return _queueFull(queuedOfAutomation, queuedTotal)
        ? LoopRefused(lineage, RunReason.queueFull)
        : LoopAdmitted(lineage);
  }

  /// Spends [items] of the workspace auto-apply budget ([kAutoBudgetItems]
  /// per sliding [kAutoBudgetWindow]). False, spending nothing, when they
  /// don't fit: the run goes to review instead ("Auto-apply paused for
  /// 10 min").
  bool takeAutoBudget(int items) {
    final now = _now();
    while (_autoApplied.isNotEmpty &&
        !now.isBefore(_autoApplied.first.at.add(kAutoBudgetWindow))) {
      _autoApplied.removeFirst();
    }
    final spent = _autoApplied.fold(0, (sum, e) => sum + e.items);
    if (spent + items > kAutoBudgetItems) return false;
    if (items > 0) _autoApplied.add((at: now, items: items));
    return true;
  }

  /// The user resumed [automationId] after a `loop_suspected` pause: its
  /// breaker window starts over.
  void resume(String automationId) => _chainedByAutomation.remove(automationId);

  /// Forgets everything (sign-out).
  void reset() {
    _seen.clear();
    _fanOut.clear();
    _chainedByAutomation.clear();
    _chainedAll.clear();
    _autoApplied.clear();
  }

  static bool _queueFull(int ofAutomation, int total) =>
      ofAutomation >= kQueuePerAutomation || total >= kQueuePerWorkspace;

  static void _prune(Queue<DateTime> window, DateTime now) {
    while (window.isNotEmpty &&
        !now.isBefore(window.first.add(kBreakerWindow))) {
      window.removeFirst();
    }
  }
}

final class _FanOut {
  int started = 0;
  int dropped = 0;
}
