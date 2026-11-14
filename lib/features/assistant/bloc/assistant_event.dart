part of 'assistant_bloc.dart';

/// What the assistant bloc reacts to: the user's actions in the chat (added
/// by the host's `AssistantActions`), the session lifecycle and, privately,
/// the agent loop's events, config changes and timers.
sealed class AssistantEvent {
  const AssistantEvent();
}

/// The session bound a signed-in member to a workspace
/// (`AssistantSession.initialize`): the bloc starts on a new, empty thread.
final class AssistantStarted extends AssistantEvent {
  const AssistantStarted({
    required this.workspaceId,
    required this.uid,
    this.userFirstName,
  });

  final String workspaceId;

  /// The member; the bloc commits as `user:<uid>`.
  final String uid;

  /// For the empty state's greeting.
  final String? userFirstName;
}

/// The composer's Send.
final class PromptSubmitted extends AssistantEvent {
  const PromptSubmitted(this.text);

  final String text;
}

/// An empty-state suggestion or a card shortcut; sent like a prompt.
final class SuggestionTapped extends AssistantEvent {
  const SuggestionTapped(this.text);

  final String text;
}

/// The composer's Stop.
final class StopRequested extends AssistantEvent {
  const StopRequested();
}

/// A plan card's ticks changed.
final class PlanSelectionChanged extends AssistantEvent {
  const PlanSelectionChanged(this.planId, this.itemIds);

  final String planId;
  final Set<String> itemIds;
}

/// "Approve N changes".
final class PlanApproved extends AssistantEvent {
  const PlanApproved(this.planId);

  final String planId;
}

/// "Reject".
final class PlanRejected extends AssistantEvent {
  const PlanRejected(this.planId);

  final String planId;
}

/// An applied card's (or its snackbar's) Undo.
final class UndoRequested extends AssistantEvent {
  const UndoRequested(this.journalId);

  final String journalId;
}

/// "Retry failed" on a partly failed apply.
final class RetryFailedRequested extends AssistantEvent {
  const RetryFailedRequested(this.planId);

  final String planId;
}

/// An error row's "Try again" or an expired plan's "Rebuild": re-sends the
/// last user message.
final class RetryRequested extends AssistantEvent {
  const RetryRequested();
}

/// The rate-limit banner's "Retry now".
final class RetryNowRequested extends AssistantEvent {
  const RetryNowRequested();
}

/// What the user looks at changed (published through
/// `AssistantFocusNotifier`); null when nothing is on screen.
final class FocusChanged extends AssistantEvent {
  const FocusChanged(this.focus);

  final AssistantFocus? focus;
}

/// The focus chip's ✕: the next message goes without the screen line until
/// the screen changes.
final class FocusCleared extends AssistantEvent {
  const FocusCleared();
}

/// A conversation picked in the history list.
final class ThreadSelected extends AssistantEvent {
  const ThreadSelected(this.threadId);

  final String threadId;
}

/// The header's "New conversation".
final class NewThreadRequested extends AssistantEvent {
  const NewThreadRequested();
}

/// A conversation deleted in the history list.
final class ThreadDeleted extends AssistantEvent {
  const ThreadDeleted(this.threadId);

  final String threadId;
}

/// One event of the running turn [turn].
final class _AgentEventReceived extends AssistantEvent {
  const _AgentEventReceived(this.turn, this.event);

  final _Turn turn;
  final AgentEvent event;
}

/// The agent stream of [turn] closed (the loop is no longer busy).
final class _TurnClosed extends AssistantEvent {
  const _TurnClosed(this.turn);

  final _Turn turn;
}

final class _ConfigChanged extends AssistantEvent {
  const _ConfigChanged(this.config);

  final AssistantConfig config;
}

final class _SyncChanged extends AssistantEvent {
  const _SyncChanged(this.online);

  final bool online;
}

/// An undo window may have closed.
final class _UndoTick extends AssistantEvent {
  const _UndoTick();
}

/// A conversation write failed.
final class _SaveFailed extends AssistantEvent {
  const _SaveFailed();
}

/// An automation run started from a commit's writes (its root `commitId`).
final class _RunStarted extends AssistantEvent {
  const _RunStarted(this.commitId);

  final String commitId;
}

/// Sign-out (or a workspace switch): back to Idle with no thread.
final class _SessionReset extends AssistantEvent {
  const _SessionReset();
}
