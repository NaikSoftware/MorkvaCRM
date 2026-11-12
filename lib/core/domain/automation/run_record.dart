import 'dart:convert';

import 'package:equatable/equatable.dart';

import 'automation_record.dart';
import 'codec.dart';

/// A run's lifecycle state. [queued], [running] and [sealing] live in memory
/// only (`RunView`); a run doc never carries them.
enum RunStatus {
  queued('queued'),
  running('running'),
  sealing('sealing'),
  skipped('skipped'),
  failed('failed'),
  timedOut('timed_out'),
  succeeded('succeeded'),
  awaitingReview('awaiting_review'),
  applying('applying'),
  rejected('rejected'),
  expired('expired');

  const RunStatus(this.wire);

  final String wire;

  /// Whether a run doc may hold this status.
  bool get persisted => this != queued && this != running && this != sealing;

  /// No transition leaves it (Undo / Retry failed keep `succeeded`).
  bool get terminal => switch (this) {
    skipped || failed || timedOut || succeeded || rejected || expired => true,
    _ => false,
  };
}

/// A skip reason, a failure code or why a review was rejected or expired
/// (design spec, Run queue & lifecycle; UX spec §9).
enum RunReason {
  // Skips.
  needsConsent('needs_consent'),
  broken('broken'),
  crashed('crashed'),
  paused('paused'),
  loopSuspected('loop_suspected'),
  engineUnavailable('engine_unavailable'),
  notSettled('not_settled'),
  notPermitted('not_permitted'),
  loop('loop'),
  depthLimit('depth_limit'),
  fanOut('fan_out'),
  queueFull('queue_full'),
  reviewBacklog('review_backlog'),
  cardGone('card_gone'),
  cancelled('cancelled'),
  duplicate('duplicate'),
  // Failures (also crashed, not_permitted, cancelled above).
  loadError('load_error'),
  bootError('boot_error'),
  loadTimeout('load_timeout'),
  moduleError('module_error'),
  planRefused('plan_refused'),
  abuse('abuse'),
  limitExceeded('limit_exceeded'),
  offline('offline'),
  notApplied('not_applied'),
  interrupted('interrupted'),
  internal('internal'),
  // Rejected / expired.
  codeChanged('code_changed'),
  uninstalled('uninstalled'),
  superseded('superseded');

  const RunReason(this.wire);

  final String wire;

  static RunReason? fromWire(Object? wire) {
    for (final r in values) {
      if (r.wire == wire) return r;
    }
    return null;
  }
}

/// Size caps of a run doc (design spec, Run log schema), in UTF-8 bytes
/// unless named `chars`.
const int kRunDocMaxBytes = 200 * 1024;
const int kRunLogMaxBytes = 64 * 1024;
const int kRunBeforeValueMaxBytes = 2 * 1024;
const int kRunBeforeMaxBytes = 16 * 1024;
const int kRunParamsMaxBytes = 4 * 1024;
const int kRunSummaryMaxChars = 200;
const int kRunErrorMessageMaxChars = 1024;
const int kRunErrorStackMaxChars = 4096;
const int kRunTouchedMax = 50;
const int kRunCardIdsMax = 500;

/// What fired a run, as stored with it.
final class RunTrigger extends Equatable {
  const RunTrigger({
    required this.kind,
    required this.collectionId,
    this.cardId,
    this.cardLabel,
    this.changedFields = const [],
    this.before,
    this.viewId,
    this.cardIds,
    this.cardCount = 1,
    this.changedAt,
  });

  factory RunTrigger.fromJson(Map<String, Object?> json) => RunTrigger(
    kind:
        TriggerKind.fromWire(json['kind']) ??
        (throw FormatException('Unknown trigger "${json['kind']}"')),
    collectionId: readString(json, 'collectionId'),
    cardId: readStringOrNull(json, 'cardId'),
    cardLabel: readStringOrNull(json, 'cardLabel'),
    changedFields: readStringsOrNull(json, 'changedFields') ?? const [],
    before: readMapOrNull(json, 'before'),
    viewId: readStringOrNull(json, 'viewId'),
    cardIds: readStringsOrNull(json, 'cardIds'),
    cardCount: readIntOrNull(json, 'cardCount') ?? 1,
    changedAt: readDateOrNull(json, 'changedAt'),
  );

  final TriggerKind kind;
  final String collectionId;

  /// Card buttons and events.
  final String? cardId;
  final String? cardLabel;
  final List<String> changedFields;

  /// The changed fields' values before the change (events), for Run again;
  /// capped per value and in total, so a value may be missing.
  final Map<String, Object?>? before;

  /// Collection buttons: the view and the shown card ids (≤ 500).
  final String? viewId;
  final List<String>? cardIds;
  final int cardCount;
  final DateTime? changedAt;

  Map<String, Object?> toJson() => {
    'kind': kind.wire,
    'collectionId': collectionId,
    'cardId': cardId,
    'cardLabel': cardLabel,
    'changedFields': changedFields,
    'before': _cappedBefore(before),
    'viewId': viewId,
    'cardIds': ?cardIds?.take(kRunCardIdsMax).toList(),
    'cardCount': cardCount,
    'changedAt': changedAt,
  };

  @override
  List<Object?> get props => [
    kind,
    collectionId,
    cardId,
    cardLabel,
    changedFields,
    before,
    viewId,
    cardIds,
    cardCount,
    changedAt,
  ];
}

/// The apply outcome counts.
final class RunReceipt extends Equatable {
  const RunReceipt({
    this.applied = 0,
    this.queued = 0,
    this.failed = 0,
    this.stale = 0,
    this.unconfirmed = 0,
  });

  factory RunReceipt.fromJson(Map<String, Object?> json) => RunReceipt(
    applied: readIntOrNull(json, 'applied') ?? 0,
    queued: readIntOrNull(json, 'queued') ?? 0,
    failed: readIntOrNull(json, 'failed') ?? 0,
    stale: readIntOrNull(json, 'stale') ?? 0,
    unconfirmed: readIntOrNull(json, 'unconfirmed') ?? 0,
  );

  final int applied;
  final int queued;
  final int failed;
  final int stale;
  final int unconfirmed;

  Map<String, Object?> toJson() => {
    'applied': applied,
    'queued': queued,
    'failed': failed,
    'stale': stale,
    'unconfirmed': unconfirmed,
  };

  @override
  List<Object?> get props => [applied, queued, failed, stale, unconfirmed];
}

/// A run's error: message ≤ 1 KB, stack ≤ 4 KB (cut on write).
final class RunError extends Equatable {
  const RunError({required this.code, required this.message, this.stack});

  factory RunError.fromJson(Map<String, Object?> json) => RunError(
    code: readString(json, 'code'),
    message: readString(json, 'message'),
    stack: readStringOrNull(json, 'stack'),
  );

  final String code;
  final String message;
  final String? stack;

  Map<String, Object?> toJson() => {
    'code': code,
    'message': cutText(message, kRunErrorMessageMaxChars),
    'stack': ?switch (stack) {
      final s? => cutText(s, kRunErrorStackMaxChars),
      null => null,
    },
  };

  @override
  List<Object?> get props => [code, message, stack];
}

/// `workspaces/{wid}/runs/{runId}`: the audit row of one run.
///
/// Dates are [DateTime] in [toJson]/[fromJson]; the store converts
/// Timestamps. [toJson] applies every field cap and the 200 KB doc cap, and
/// always writes `log` as a string (the rules require one).
final class RunRecord extends Equatable {
  const RunRecord({
    required this.id,
    required this.status,
    required this.moduleId,
    required this.moduleName,
    required this.moduleVersion,
    required this.codeHash,
    required this.actionId,
    required this.actionLabel,
    required this.trigger,
    required this.apply,
    required this.by,
    required this.device,
    required this.sessionId,
    required this.startedAt,
    this.reason,
    this.automationId,
    this.automationName,
    this.params,
    this.depth = 1,
    this.chain = const [],
    this.parentRunId,
    this.count = 1,
    this.applyStartedAt,
    this.endedAt,
    this.durationMs,
    this.planId,
    this.planTitle,
    this.receipt,
    this.journalId,
    this.touchedCardIds = const [],
    this.summary,
    this.error,
    this.undoneAt,
    this.log = RunLog.empty,
  });

  /// Throws [FormatException] on a doc that is not a run record; a log that
  /// does not decode reads as empty.
  factory RunRecord.fromJson(String id, Map<String, Object?> json) {
    final status = readEnum(json, 'status', RunStatus.values, (s) => s.wire);
    if (!status.persisted) {
      throw FormatException('A run doc can\'t be "${status.wire}"');
    }
    final reasonWire = json['reason'];
    return RunRecord(
      id: id,
      status: status,
      reason: reasonWire == null
          ? null
          : RunReason.fromWire(reasonWire) ??
                (throw FormatException('Unknown reason "$reasonWire"')),
      moduleId: readString(json, 'moduleId'),
      moduleName: readString(json, 'moduleName'),
      moduleVersion: readString(json, 'moduleVersion'),
      codeHash: readString(json, 'codeHash'),
      actionId: readString(json, 'actionId'),
      actionLabel: readString(json, 'actionLabel'),
      automationId: readStringOrNull(json, 'automationId'),
      automationName: readStringOrNull(json, 'automationName'),
      trigger: RunTrigger.fromJson(readMap(json, 'trigger')),
      params: readMapOrNull(json, 'params'),
      apply: readEnum(json, 'apply', ApplyMode.values, (a) => a.name),
      by: readString(json, 'by'),
      device: readString(json, 'device'),
      sessionId: readString(json, 'sessionId'),
      depth: readIntOrNull(json, 'depth') ?? 1,
      chain: readStringsOrNull(json, 'chain') ?? const [],
      parentRunId: readStringOrNull(json, 'parentRunId'),
      count: readIntOrNull(json, 'count') ?? 1,
      startedAt: readDate(json, 'startedAt'),
      applyStartedAt: readDateOrNull(json, 'applyStartedAt'),
      endedAt: readDateOrNull(json, 'endedAt'),
      durationMs: readIntOrNull(json, 'durationMs'),
      planId: readStringOrNull(json, 'planId'),
      planTitle: readStringOrNull(json, 'planTitle'),
      receipt: switch (readMapOrNull(json, 'receipt')) {
        final r? => RunReceipt.fromJson(r),
        null => null,
      },
      journalId: readStringOrNull(json, 'journalId'),
      touchedCardIds: readStringsOrNull(json, 'touchedCardIds') ?? const [],
      summary: readStringOrNull(json, 'summary'),
      error: switch (readMapOrNull(json, 'error')) {
        final e? => RunError.fromJson(e),
        null => null,
      },
      undoneAt: readDateOrNull(json, 'undoneAt'),
      log: decodeRunLog(json['log']),
    );
  }

  final String id;
  final RunStatus status;
  final RunReason? reason;
  final String moduleId;
  final String moduleName;
  final String moduleVersion;
  final String codeHash;
  final String actionId;
  final String actionLabel;

  /// Null for coalesced rows only.
  final String? automationId;
  final String? automationName;
  final RunTrigger trigger;
  final Map<String, Object?>? params;

  /// The effective apply mode.
  final ApplyMode apply;

  /// `user:<uid>`.
  final String by;

  /// `web`, `android` or `ios`.
  final String device;

  /// The tab / app start that ran it (`session_key.dart`).
  final String sessionId;
  final int depth;

  /// Automation ids, root first.
  final List<String> chain;
  final String? parentRunId;

  /// Coalesced rows: how many times it was skipped.
  final int count;
  final DateTime startedAt;
  final DateTime? applyStartedAt;
  final DateTime? endedAt;
  final int? durationMs;
  final String? planId;
  final String? planTitle;
  final RunReceipt? receipt;
  final String? journalId;
  final List<String> touchedCardIds;
  final String? summary;
  final RunError? error;
  final DateTime? undoneAt;
  final RunLog log;

  /// Nullable fields take a function so they can be cleared
  /// (`applyStartedAt: () => null`).
  RunRecord copyWith({
    RunStatus? status,
    RunReason? Function()? reason,
    int? count,
    DateTime? Function()? applyStartedAt,
    DateTime? Function()? endedAt,
    int? Function()? durationMs,
    String? Function()? planId,
    String? Function()? planTitle,
    RunReceipt? Function()? receipt,
    String? Function()? journalId,
    List<String>? touchedCardIds,
    String? Function()? summary,
    RunError? Function()? error,
    DateTime? Function()? undoneAt,
    RunLog? log,
  }) => RunRecord(
    id: id,
    status: status ?? this.status,
    reason: reason == null ? this.reason : reason(),
    moduleId: moduleId,
    moduleName: moduleName,
    moduleVersion: moduleVersion,
    codeHash: codeHash,
    actionId: actionId,
    actionLabel: actionLabel,
    automationId: automationId,
    automationName: automationName,
    trigger: trigger,
    params: params,
    apply: apply,
    by: by,
    device: device,
    sessionId: sessionId,
    depth: depth,
    chain: chain,
    parentRunId: parentRunId,
    count: count ?? this.count,
    startedAt: startedAt,
    applyStartedAt: applyStartedAt == null
        ? this.applyStartedAt
        : applyStartedAt(),
    endedAt: endedAt == null ? this.endedAt : endedAt(),
    durationMs: durationMs == null ? this.durationMs : durationMs(),
    planId: planId == null ? this.planId : planId(),
    planTitle: planTitle == null ? this.planTitle : planTitle(),
    receipt: receipt == null ? this.receipt : receipt(),
    journalId: journalId == null ? this.journalId : journalId(),
    touchedCardIds: touchedCardIds ?? this.touchedCardIds,
    summary: summary == null ? this.summary : summary(),
    error: error == null ? this.error : error(),
    undoneAt: undoneAt == null ? this.undoneAt : undoneAt(),
    log: log ?? this.log,
  );

  /// The doc, every field capped; over [kRunDocMaxBytes] it sheds the log
  /// first, then `trigger.before`, then `params`.
  Map<String, Object?> toJson() {
    if (!status.persisted) {
      throw StateError('A run doc can\'t be "${status.wire}"');
    }
    final paramsJson = params == null || _bytes(params) > kRunParamsMaxBytes
        ? null
        : params;
    final doc = <String, Object?>{
      'schema': 1,
      'status': status.wire,
      'reason': reason?.wire,
      'moduleId': moduleId,
      'moduleName': moduleName,
      'moduleVersion': moduleVersion,
      'codeHash': codeHash,
      'actionId': actionId,
      'actionLabel': actionLabel,
      'automationId': automationId,
      'automationName': automationName,
      'trigger': trigger.toJson(),
      'params': paramsJson,
      'apply': apply.name,
      'by': by,
      'device': device,
      'sessionId': sessionId,
      'depth': depth,
      'chain': chain,
      'parentRunId': parentRunId,
      'count': count,
      'startedAt': startedAt,
      'applyStartedAt': applyStartedAt,
      'endedAt': endedAt,
      'durationMs': durationMs,
      'planId': planId,
      'planTitle': planTitle == null ? null : cutText(planTitle!, 200),
      'receipt': receipt?.toJson(),
      'journalId': journalId,
      'touchedCardIds': touchedCardIds.take(kRunTouchedMax).toList(),
      'summary': summary == null
          ? null
          : cutText(summary!, kRunSummaryMaxChars),
      'error': error?.toJson(),
      'undoneAt': undoneAt,
      'log': '',
    };
    // The log is escaped inside the doc, so shrink its budget by the overflow
    // until the doc fits (or the log is down to its counts).
    var budget = kRunDocMaxBytes - _bytes(doc);
    if (budget > kRunLogMaxBytes) budget = kRunLogMaxBytes;
    for (var i = 0; i < 4; i++) {
      doc['log'] = encodeRunLog(log, maxBytes: budget);
      final over = _bytes(doc) - kRunDocMaxBytes;
      if (over <= 0) break;
      budget -= over;
    }
    if (_bytes(doc) > kRunDocMaxBytes) {
      (doc['trigger']! as Map<String, Object?>)['before'] = null;
    }
    if (_bytes(doc) > kRunDocMaxBytes) doc['params'] = null;
    return doc;
  }

  @override
  List<Object?> get props => [
    id,
    status,
    reason,
    moduleId,
    moduleName,
    moduleVersion,
    codeHash,
    actionId,
    actionLabel,
    automationId,
    automationName,
    trigger,
    params,
    apply,
    by,
    device,
    sessionId,
    depth,
    chain,
    parentRunId,
    count,
    startedAt,
    applyStartedAt,
    endedAt,
    durationMs,
    planId,
    planTitle,
    receipt,
    journalId,
    touchedCardIds,
    summary,
    error,
    undoneAt,
    log,
  ];
}

// ------------------------------------------------------------------ run log

/// One harness call of a run: args and result are summaries (≤ 300 chars),
/// never card values in full.
final class RunCall extends Equatable {
  const RunCall({
    required this.t,
    required this.op,
    required this.kind,
    required this.args,
    required this.ok,
    required this.result,
    required this.ms,
  });

  factory RunCall.fromJson(Map<String, Object?> json) => RunCall(
    t: readInt(json, 't'),
    op: readString(json, 'op'),
    kind: readString(json, 'kind'),
    args: readString(json, 'args'),
    ok: readBool(json, 'ok'),
    result: readString(json, 'result'),
    ms: readInt(json, 'ms'),
  );

  /// Milliseconds since the run started.
  final int t;
  final String op;

  /// The op kind (`read`, `plan`, `ui`).
  final String kind;
  final String args;
  final bool ok;
  final String result;
  final int ms;

  Map<String, Object?> toJson() => {
    't': t,
    'op': cutText(op, 80),
    'kind': kind,
    'args': cutText(args, 300),
    'ok': ok,
    'result': cutText(result, 300),
    'ms': ms,
  };

  @override
  List<Object?> get props => [t, op, kind, args, ok, result, ms];
}

/// One console / `morkva.log` line (≤ 500 chars, plain text).
final class ConsoleLine extends Equatable {
  const ConsoleLine({required this.t, required this.level, required this.text});

  factory ConsoleLine.fromJson(Map<String, Object?> json) => ConsoleLine(
    t: readInt(json, 't'),
    level: readString(json, 'level'),
    text: readString(json, 'text'),
  );

  final int t;

  /// `debug`, `info`, `warn` or `error`.
  final String level;
  final String text;

  Map<String, Object?> toJson() => {
    't': t,
    'level': level,
    'text': cutText(text, 500),
  };

  @override
  List<Object?> get props => [t, level, text];
}

/// One planned change, in words: "Shipped on: — → 2026-11-12".
final class PlanLine extends Equatable {
  const PlanLine({
    required this.kind,
    required this.label,
    required this.change,
  });

  factory PlanLine.fromJson(Map<String, Object?> json) => PlanLine(
    kind: readString(json, 'kind'),
    label: readString(json, 'label'),
    change: readString(json, 'change'),
  );

  /// The plan item kind (`updateCard`, …).
  final String kind;
  final String label;
  final String change;

  Map<String, Object?> toJson() => {
    'kind': kind,
    'label': cutText(label, 80),
    'change': cutText(change, 300),
  };

  @override
  List<Object?> get props => [kind, label, change];
}

/// A `ui.open` chip: an in-app ref only, opened on tap.
final class UiLink extends Equatable {
  const UiLink({required this.kind, required this.ref, required this.label});

  factory UiLink.fromJson(Map<String, Object?> json) => UiLink(
    kind: readString(json, 'kind'),
    ref: readString(json, 'ref'),
    label: readString(json, 'label'),
  );

  final String kind;
  final String ref;
  final String label;

  Map<String, Object?> toJson() => {
    'kind': kind,
    'ref': cutText(ref, 120),
    'label': cutText(label, 80),
  };

  @override
  List<Object?> get props => [kind, ref, label];
}

/// Entries the encoder (or the bridge's own caps) left out.
final class RunLogDropped extends Equatable {
  const RunLogDropped({this.calls = 0, this.console = 0, this.plan = 0});

  final int calls;
  final int console;
  final int plan;

  @override
  List<Object?> get props => [calls, console, plan];
}

/// The decoded `log` of a run doc.
final class RunLog extends Equatable {
  const RunLog({
    this.triggerEval,
    this.calls = const [],
    this.console = const [],
    this.plan = const [],
    this.ui = const [],
    this.policy,
    this.returned,
    this.dropped = const RunLogDropped(),
  });

  static const RunLog empty = RunLog();
  static const int kMaxPlanRows = 50;
  static const int kMaxUiLinks = 20;
  static const int kMaxReturnedBytes = 4 * 1024;

  factory RunLog.fromJson(Map<String, Object?> json) {
    List<T> list<T>(String key, T Function(Map<String, Object?>) item) =>
        switch (json[key]) {
          null => const [],
          final List<Object?> l => [
            for (final e in l)
              item(switch (e) {
                final Map<Object?, Object?> m => m.cast<String, Object?>(),
                _ => throw FormatException('"$key" must hold objects'),
              }),
          ],
          _ => throw FormatException('"$key" must be a list'),
        };
    final dropped = readMapOrNull(json, 'dropped') ?? const {};
    return RunLog(
      triggerEval: readStringOrNull(
        readMapOrNull(json, 'trigger') ?? const {},
        'eval',
      ),
      calls: list('calls', RunCall.fromJson),
      console: list('console', ConsoleLine.fromJson),
      plan: list('plan', PlanLine.fromJson),
      ui: list('ui', UiLink.fromJson),
      policy: readStringOrNull(json, 'policy'),
      returned: readMapOrNull(json, 'returned'),
      dropped: RunLogDropped(
        calls: readIntOrNull(dropped, 'calls') ?? 0,
        console: readIntOrNull(dropped, 'console') ?? 0,
        plan: readIntOrNull(dropped, 'plan') ?? 0,
      ),
    );
  }

  /// The first line: why it fired ("whereB=false whereA=true changed=[Status]").
  final String? triggerEval;
  final List<RunCall> calls;
  final List<ConsoleLine> console;
  final List<PlanLine> plan;
  final List<UiLink> ui;

  /// Why it did not auto-apply ("review: 23 items > 20").
  final String? policy;

  /// The action's returned object without `message` (≤ 4 KB, else dropped).
  final Map<String, Object?>? returned;
  final RunLogDropped dropped;

  @override
  List<Object?> get props => [
    triggerEval,
    calls,
    console,
    plan,
    ui,
    policy,
    returned,
    dropped,
  ];
}

/// [log] as JSON within [maxBytes] UTF-8 bytes: the trigger line, links and
/// policy first, then plan rows (≤ 50), calls and console lines in order
/// until the budget is spent; the rest is counted in `dropped`.
String encodeRunLog(RunLog log, {int maxBytes = kRunLogMaxBytes}) {
  final plan = [for (final p in log.plan.take(RunLog.kMaxPlanRows)) p.toJson()];
  final calls = [for (final c in log.calls) c.toJson()];
  final console = [for (final c in log.console) c.toJson()];
  final droppedPlan =
      log.dropped.plan + log.plan.length - plan.length; // over the row cap
  final all = plan.length + calls.length + console.length;
  final returned =
      log.returned == null || _bytes(log.returned) > RunLog.kMaxReturnedBytes
      ? null
      : log.returned;

  Map<String, Object?> body(
    List<Object?> p,
    List<Object?> ca,
    List<Object?> co,
    int dCalls,
    int dConsole,
    int dPlan,
  ) => {
    'v': 1,
    'trigger': {if (log.triggerEval case final e?) 'eval': cutText(e, 500)},
    'calls': ca,
    'console': co,
    'plan': p,
    'ui': [for (final u in log.ui.take(RunLog.kMaxUiLinks)) u.toJson()],
    if (log.policy case final s?) 'policy': cutText(s, 300),
    'returned': ?returned,
    'dropped': {'calls': dCalls, 'console': dConsole, 'plan': dPlan},
  };

  // The empty body with the largest possible drop counts reserves their digits.
  final base = _bytes(
    body(
      const [],
      const [],
      const [],
      log.dropped.calls + all,
      log.dropped.console + all,
      droppedPlan + all,
    ),
  );
  if (base > maxBytes) {
    return jsonEncode({
      'v': 1,
      'dropped': {
        'calls': log.dropped.calls + calls.length,
        'console': log.dropped.console + console.length,
        'plan': droppedPlan + plan.length,
      },
    });
  }
  var room = maxBytes - base;
  var full = false;
  List<Object?> fill(List<Map<String, Object?>> entries) {
    final kept = <Object?>[];
    for (final e in entries) {
      final size = _bytes(e) + 1; // + the comma
      if (full || size > room) {
        full = true;
        continue;
      }
      room -= size;
      kept.add(e);
    }
    return kept;
  }

  final keptPlan = fill(plan);
  final keptCalls = fill(calls);
  final keptConsole = fill(console);
  return jsonEncode(
    body(
      keptPlan,
      keptCalls,
      keptConsole,
      log.dropped.calls + calls.length - keptCalls.length,
      log.dropped.console + console.length - keptConsole.length,
      droppedPlan + plan.length - keptPlan.length,
    ),
  );
}

/// The run doc's `log` string decoded; anything malformed reads as empty.
RunLog decodeRunLog(Object? encoded) {
  if (encoded is! String || encoded.isEmpty) return RunLog.empty;
  try {
    final json = jsonDecode(encoded);
    return json is Map<String, Object?> ? RunLog.fromJson(json) : RunLog.empty;
  } on FormatException {
    return RunLog.empty;
  }
}

Map<String, Object?>? _cappedBefore(Map<String, Object?>? before) {
  if (before == null) return null;
  final out = <String, Object?>{};
  var total = 2; // {}
  for (final MapEntry(:key, :value) in before.entries) {
    final size = _bytes({key: value});
    if (size > kRunBeforeValueMaxBytes) continue;
    if (total + size > kRunBeforeMaxBytes) break;
    total += size;
    out[key] = value;
  }
  return out;
}

/// UTF-8 size of [value] as JSON; dates count as ISO strings.
int _bytes(Object? value) => utf8
    .encode(
      jsonEncode(
        value,
        toEncodable: (o) => o is DateTime
            ? o.toIso8601String()
            : throw JsonUnsupportedObjectError(o),
      ),
    )
    .length;
