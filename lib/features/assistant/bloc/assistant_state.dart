import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:morkva_crm/core/agent/agent_event.dart';

import 'assistant_focus.dart';
import 'chat_item.dart';

/// Where the current turn stands; drives the composer (Send / Stop / hint)
/// and the "Thinking…" row.
sealed class TurnPhase extends Equatable {
  const TurnPhase();

  /// A turn is running: the composer shows Stop.
  bool get active => switch (this) {
    IdlePhase() || FailedPhase() || AwaitingApprovalPhase() => false,
    _ => true,
  };

  @override
  List<Object?> get props => const [];
}

/// No turn running.
final class IdlePhase extends TurnPhase {
  const IdlePhase();
}

/// Before the first token or step (also while waiting out a rate limit,
/// with a [RetryBanner]): the "Thinking…" shimmer.
final class ThinkingPhase extends TurnPhase {
  const ThinkingPhase();
}

/// Answer text is arriving.
final class StreamingPhase extends TurnPhase {
  const StreamingPhase();
}

/// A tool call runs; [stepLabel] is its running line.
final class RunningToolsPhase extends TurnPhase {
  const RunningToolsPhase(this.stepLabel);

  final String stepLabel;

  @override
  List<Object?> get props => [stepLabel];
}

/// The plan card [planId] waits for the user. The composer says "Approve or
/// reject the changes above — or send a new message to skip them".
final class AwaitingApprovalPhase extends TurnPhase {
  const AwaitingApprovalPhase(this.planId);

  final String planId;

  @override
  List<Object?> get props => [planId];
}

/// An approved plan is being written: "Updating [done] of [total]…". The
/// thread list is disabled until the receipt is saved.
final class ApplyingPhase extends TurnPhase {
  const ApplyingPhase(this.done, this.total);

  final int done;
  final int total;

  @override
  List<Object?> get props => [done, total];
}

/// The last turn failed (its [ErrorItem] is in the list).
final class FailedPhase extends TurnPhase {
  const FailedPhase(this.kind, this.message, {this.retryable = true});

  final ChatErrorKind kind;
  final String message;
  final bool retryable;

  @override
  List<Object?> get props => [kind, message, retryable];
}

/// Whether the assistant can take a message.
sealed class Availability extends Equatable {
  const Availability();

  /// The composer is enabled.
  bool get canSend => this is AvailabilityEnabled;

  @override
  List<Object?> get props => const [];
}

/// Config not read yet.
final class AvailabilityChecking extends Availability {
  const AvailabilityChecking();
}

final class AvailabilityEnabled extends Availability {
  const AvailabilityEnabled();
}

/// The feature flag is off: "Ask Morkva isn't enabled for your account."
final class AvailabilityDisabledByFlag extends Availability {
  const AvailabilityDisabledByFlag();
}

/// "Ask Morkva isn't set up for this project yet."
final class AvailabilityNotSetUp extends Availability {
  const AvailabilityNotSetUp();
}

/// The service refuses this user; [message] says why.
final class AvailabilityUnavailable extends Availability {
  const AvailabilityUnavailable(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

/// "You're offline — Ask Morkva needs a connection"; the chat stays readable.
final class AvailabilityOffline extends Availability {
  const AvailabilityOffline();
}

/// Today's AI limit is used up until [until] (shown with a
/// [DailyLimitBanner]).
final class AvailabilityQuotaExhausted extends Availability {
  const AvailabilityQuotaExhausted(this.until);

  final DateTime until;

  @override
  List<Object?> get props => [until];
}

/// A warning banner under the panel header. Separate from [TurnPhase]
/// because it can sit over any phase.
sealed class LimitBanner extends Equatable {
  const LimitBanner();
}

/// "Gemini is busy. Retrying in N s · Retry now" (TPM: "This conversation is
/// large; waiting N s"), counting down to [until].
final class RetryBanner extends LimitBanner {
  const RetryBanner(this.until, this.reason);

  final DateTime until;
  final RetryReason reason;

  @override
  List<Object?> get props => [until, reason];
}

/// "Today's AI limit is used up. It resets at HH:MM." (no retry).
final class DailyLimitBanner extends LimitBanner {
  const DailyLimitBanner(this.resetsAt);

  final DateTime resetsAt;

  @override
  List<Object?> get props => [resetsAt];
}

/// The assistant chat state.
///
/// Equality compares [items] by **identity**: the bloc makes a new list only
/// when an item is added or replaced, so a streaming delta (which goes through
/// [AssistantTextItem.live]) does not rebuild the list.
final class AssistantState {
  const AssistantState({
    this.threadId,
    this.threadTitle,
    this.items = const [],
    this.phase = const IdlePhase(),
    this.availability = const AvailabilityChecking(),
    this.banner,
    this.focus,
    this.usage = TokenUsage.zero,
    this.userFirstName,
    this.collectionNames = const [],
    this.saveFailed = false,
  });

  /// The open thread; null before the first message of a new one.
  final String? threadId;

  /// The header subtitle (the thread's title).
  final String? threadTitle;
  final List<ChatItem> items;
  final TurnPhase phase;
  final Availability availability;
  final LimitBanner? banner;

  /// What the composer chip shows; null when removed or nothing is on screen.
  final AssistantFocus? focus;
  final TokenUsage usage;

  /// For the empty state's greeting ("Hi Olena.").
  final String? userFirstName;

  /// The workspace's collection names, for the empty state ("I can read all
  /// 8 of your collections") and its suggestions.
  final List<String> collectionNames;

  /// "Couldn't save this conversation".
  final bool saveFailed;

  /// The pending plan card, if any (only one at a time).
  PlanItem? get pendingPlan {
    for (final item in items.reversed) {
      if (item is PlanItem && item.status == PlanStatus.pending) return item;
    }
    return null;
  }

  AssistantState copyWith({
    String? threadId,
    String? threadTitle,
    List<ChatItem>? items,
    TurnPhase? phase,
    Availability? availability,
    LimitBanner? banner,
    bool clearBanner = false,
    AssistantFocus? focus,
    bool clearFocus = false,
    TokenUsage? usage,
    String? userFirstName,
    List<String>? collectionNames,
    bool? saveFailed,
  }) => AssistantState(
    threadId: threadId ?? this.threadId,
    threadTitle: threadTitle ?? this.threadTitle,
    items: items ?? this.items,
    phase: phase ?? this.phase,
    availability: availability ?? this.availability,
    banner: clearBanner ? null : banner ?? this.banner,
    focus: clearFocus ? null : focus ?? this.focus,
    usage: usage ?? this.usage,
    userFirstName: userFirstName ?? this.userFirstName,
    collectionNames: collectionNames ?? this.collectionNames,
    saveFailed: saveFailed ?? this.saveFailed,
  );

  /// A new thread: same availability, focus, user and collections.
  AssistantState cleared() => AssistantState(
    availability: availability,
    focus: focus,
    userFirstName: userFirstName,
    collectionNames: collectionNames,
  );

  @override
  bool operator ==(Object other) =>
      other is AssistantState &&
      identical(other.items, items) &&
      other.threadId == threadId &&
      other.threadTitle == threadTitle &&
      other.phase == phase &&
      other.availability == availability &&
      other.banner == banner &&
      other.focus == focus &&
      other.usage == usage &&
      other.userFirstName == userFirstName &&
      listEquals(other.collectionNames, collectionNames) &&
      other.saveFailed == saveFailed;

  @override
  int get hashCode => Object.hash(
    identityHashCode(items),
    threadId,
    threadTitle,
    phase,
    availability,
    banner,
    focus,
    usage,
    userFirstName,
    Object.hashAll(collectionNames),
    saveFailed,
  );

  @override
  String toString() =>
      'AssistantState(thread: $threadId, items: ${items.length}, '
      'phase: ${phase.runtimeType}, availability: ${availability.runtimeType})';
}
