/// What the agent loop tells its host (the assistant bloc) while a turn runs,
/// and what the host hands back at the plan gate. Pure Dart.
library;

import 'package:equatable/equatable.dart';

import 'llm_client.dart';

/// Tokens spent, summed over rounds and turns.
final class TokenUsage extends Equatable {
  const TokenUsage({this.promptTokens = 0, this.outputTokens = 0});

  factory TokenUsage.fromJson(Map<String, Object?> json) => TokenUsage(
    promptTokens: (json['prompt'] as num?)?.toInt() ?? 0,
    outputTokens: (json['output'] as num?)?.toInt() ?? 0,
  );

  static const TokenUsage zero = TokenUsage();

  final int promptTokens;
  final int outputTokens;

  TokenUsage operator +(TokenUsage other) => TokenUsage(
    promptTokens: promptTokens + other.promptTokens,
    outputTokens: outputTokens + other.outputTokens,
  );

  /// The thread-doc shape `{prompt, output}`.
  Map<String, Object?> toJson() => {
    'prompt': promptTokens,
    'output': outputTokens,
  };

  @override
  List<Object?> get props => [promptTokens, outputTokens];
}

/// How the host renders a stored result.
enum PresentKind { table, bar, line }

/// Why the loop is waiting before the next model call.
enum RetryReason { rpm, tpm, transient }

/// The compact plan `plans.seal` returns: title, counts, warnings, notes and
/// the first 5 items. The host fetches the full plan through `plans.get`.
final class CompactPlan {
  const CompactPlan(this.json);

  /// Throws [FormatException] without a `planId`.
  factory CompactPlan.fromJson(Map<String, Object?> json) {
    if (json['planId'] is! String) {
      throw const FormatException('A plan needs a "planId"');
    }
    return CompactPlan(json);
  }

  /// The plan JSON as the harness returned it.
  final Map<String, Object?> json;

  String get planId => json['planId']! as String;
  String get title => json['title'] as String? ?? '';
  String get risk => json['risk'] as String? ?? 'low';
  int get itemCount => (json['itemCount'] as num?)?.toInt() ?? 0;
}

// ---------------------------------------------------------------------------
// Agent events.

sealed class AgentEvent {
  const AgentEvent();
}

/// The turn opened under [turnId] (minted by `Harness.openTurn`).
final class TurnStarted extends AgentEvent {
  const TurnStarted(this.turnId);

  final String turnId;
}

/// Model round [round] (1-based) starts on [model].
final class RoundStarted extends AgentEvent {
  const RoundStarted(this.round, this.model);

  final int round;
  final String model;
}

/// More answer text (coalesced, about every 50 ms).
final class TextDelta extends AgentEvent {
  const TextDelta(this.text);

  final String text;
}

/// The answer hit the output-token limit; the text so far is kept.
final class TextCutShort extends AgentEvent {
  const TextCutShort();
}

/// A tool call started; [label] is the running line ("Filtering 36 fabrics…").
final class StepStarted extends AgentEvent {
  const StepStarted({
    required this.callId,
    required this.op,
    required this.label,
  });

  /// The loop's local id (`r2.1`).
  final String callId;

  /// The harness op id (`cards.query`).
  final String op;
  final String label;
}

/// A tool call finished; [summary] is the result's one-line summary
/// ("Filtered 148 → 5 Orders") or the error message.
final class StepFinished extends AgentEvent {
  const StepFinished({
    required this.callId,
    required this.summary,
    required this.ok,
    this.errorCode,
  });

  final String callId;
  final String summary;
  final bool ok;

  /// The harness error code (`unknown_field`) when [ok] is false.
  final String? errorCode;
}

/// A read op asked the host to render its stored result ([handle]).
final class ResultPresented extends AgentEvent {
  const ResultPresented({
    required this.callId,
    required this.handle,
    required this.kind,
    required this.title,
    this.spec,
    this.summary,
  });

  final String callId;
  final String handle;
  final PresentKind kind;
  final String title;

  /// The query spec behind [handle], persisted so a table re-runs after a
  /// reload (handles are not persisted).
  final Map<String, Object?>? spec;
  final String? summary;
}

/// `ui.open` was called: show a chip that navigates on tap.
final class ObjectChipShown extends AgentEvent {
  const ObjectChipShown({
    required this.collectionId,
    this.cardId,
    this.viewId,
    required this.label,
  });

  final String collectionId;
  final String? cardId;
  final String? viewId;
  final String label;
}

/// A merged plan is ready and the turn is suspended until the host calls
/// `deliverOutcome(plan.planId, …)`.
final class PlanProposed extends AgentEvent {
  const PlanProposed(this.plan);

  final CompactPlan plan;
}

/// The loop waits until [until] before retrying the model.
final class RetryWaiting extends AgentEvent {
  const RetryWaiting(this.until, this.reason);

  final DateTime until;
  final RetryReason reason;
}

/// The thread switched to a fallback model.
final class ModelSwitched extends AgentEvent {
  const ModelSwitched(this.from, this.to);

  final String from;
  final String to;
}

/// The turn ended with [failure]. [nothingChanged] is true when no plan of
/// this turn was committed.
final class TurnFailed extends AgentEvent {
  const TurnFailed(this.failure, {required this.nothingChanged});

  final LlmFailure failure;
  final bool nothingChanged;
}

/// The turn ended by Stop; partial text is kept.
final class TurnStopped extends AgentEvent {
  const TurnStopped();
}

/// The turn ended normally.
final class TurnDone extends AgentEvent {
  const TurnDone(this.usage);

  final TokenUsage usage;
}

// ---------------------------------------------------------------------------
// The plan gate.

/// What the host hands back to `AgentLoop.deliverOutcome`.
sealed class PlanOutcome extends Equatable {
  const PlanOutcome();

  /// The FunctionResponse body each held plan call gets.
  Map<String, Object?> toModelJson();
}

/// Why a plan was not applied.
enum RejectReason { user, skipped, stopped }

/// The user rejected the plan, skipped it with a new message, or stopped.
final class Rejection extends PlanOutcome {
  const Rejection(this.reason);

  final RejectReason reason;

  @override
  Map<String, Object?> toModelJson() => {
    'status': 'rejected',
    // The model only distinguishes a decision from a skip.
    'reason': reason == RejectReason.skipped ? 'skipped' : 'user',
  };

  @override
  List<Object?> get props => [reason];
}

/// Why an item was skipped at commit.
enum StaleReason {
  changedElsewhere('changed_elsewhere'),
  missing('missing');

  const StaleReason(this.wire);

  final String wire;

  static StaleReason fromWire(String wire) => values.firstWhere(
    (r) => r.wire == wire,
    orElse: () => throw FormatException('Unknown stale reason "$wire"'),
  );
}

/// One item skipped because it changed since the preview.
final class StaleItem extends Equatable {
  const StaleItem(this.itemId, this.reason);

  final String itemId;
  final StaleReason reason;

  Map<String, Object?> toJson() => {'itemId': itemId, 'reason': reason.wire};

  @override
  List<Object?> get props => [itemId, reason];
}

/// One item that failed to write (`offline`, `not_permitted`, …).
final class FailedItem extends Equatable {
  const FailedItem(this.itemId, this.code, this.message);

  final String itemId;

  /// A harness error code (wire form).
  final String code;
  final String message;

  Map<String, Object?> toJson() => {
    'itemId': itemId,
    'code': code,
    'message': message,
  };

  @override
  List<Object?> get props => [itemId, code, message];
}

/// The result of `plans.commit` / `plans.retryFailed`; also persisted on the
/// turn doc and shown by the applied card.
final class Receipt extends PlanOutcome {
  const Receipt({
    required this.planId,
    this.applied = const [],
    this.queued = const [],
    this.declinedByUser = const [],
    this.stale = const [],
    this.failed = const [],
    this.journalId,
    this.undoUntil,
    required this.summary,
  });

  /// Parses the harness JSON. Throws [FormatException] on a wrong shape.
  factory Receipt.fromJson(Map<String, Object?> json) {
    List<String> ids(String key) => switch (json[key]) {
      null => const [],
      final List list => [
        for (final id in list)
          id is String ? id : throw FormatException('"$key" holds a non-id'),
      ],
      _ => throw FormatException('"$key" must be a list'),
    };
    List<Map<String, Object?>> maps(String key) => switch (json[key]) {
      null => const [],
      final List list => [
        for (final m in list)
          m is Map
              ? m.cast<String, Object?>()
              : throw FormatException('"$key" holds a non-object'),
      ],
      _ => throw FormatException('"$key" must be a list'),
    };
    String str(Map<String, Object?> m, String key) => switch (m[key]) {
      final String s => s,
      _ => throw FormatException('"$key" must be a string'),
    };
    final planId = json['planId'];
    if (planId is! String) {
      throw const FormatException('A receipt needs a "planId"');
    }
    final undoUntil = json['undoUntil'];
    return Receipt(
      planId: planId,
      applied: ids('applied'),
      queued: ids('queued'),
      declinedByUser: ids('declinedByUser'),
      stale: [
        for (final s in maps('stale'))
          StaleItem(str(s, 'itemId'), StaleReason.fromWire(str(s, 'reason'))),
      ],
      failed: [
        for (final f in maps('failed'))
          FailedItem(str(f, 'itemId'), str(f, 'code'), str(f, 'message')),
      ],
      journalId: json['journalId'] as String?,
      undoUntil: undoUntil is String ? DateTime.parse(undoUntil) : null,
      summary: json['summary'] as String? ?? '',
    );
  }

  final String planId;
  final List<String> applied;

  /// Written locally, server ack pending (the connection dropped mid-commit).
  final List<String> queued;
  final List<String> declinedByUser;
  final List<StaleItem> stale;
  final List<FailedItem> failed;

  /// The undo journal entry, when anything was applied.
  final String? journalId;
  final DateTime? undoUntil;

  /// Harness-written, e.g. "Updated 12 orders".
  final String summary;

  /// Items the user approved (everything but [declinedByUser]).
  int get approvedCount => totalCount - declinedByUser.length;

  /// Every item of the plan this receipt covers.
  int get totalCount =>
      applied.length +
      queued.length +
      declinedByUser.length +
      stale.length +
      failed.length;

  Map<String, Object?> toJson() => {
    'planId': planId,
    'applied': applied,
    'queued': queued,
    'declinedByUser': declinedByUser,
    'stale': [for (final s in stale) s.toJson()],
    'failed': [for (final f in failed) f.toJson()],
    if (journalId != null) 'journalId': journalId,
    if (undoUntil != null) 'undoUntil': undoUntil!.toUtc().toIso8601String(),
    'summary': summary,
  };

  @override
  Map<String, Object?> toModelJson() => {
    'status': 'applied',
    'applied': applied.length,
    'queued': queued.length,
    'declinedByUser': declinedByUser,
    'stale': [for (final s in stale) s.toJson()],
    'failed': [for (final f in failed) f.toJson()],
    'summary': summary,
  };

  @override
  List<Object?> get props => [
    planId,
    applied,
    queued,
    declinedByUser,
    stale,
    failed,
    journalId,
    undoUntil,
    summary,
  ];
}
