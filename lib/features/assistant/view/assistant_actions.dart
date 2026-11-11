import '../bloc/chat_item.dart';

/// What the assistant UI can ask for. The widgets never touch the bloc's
/// events directly, so the same widgets run against `FakeAssistantBloc` in
/// tests and the real `AssistantBloc` in the app: the host (T13b) implements
/// this by adding the named `AssistantEvent` or navigating.
abstract interface class AssistantActions {
  /// The composer's Send (`PromptSubmitted`).
  void submit(String text);

  /// An empty-state suggestion or a card shortcut such as "Save as a view"
  /// (`SuggestionTapped`).
  void suggest(String text);

  /// The composer's Stop (`StopRequested`).
  void stop();

  /// A plan card's ticks changed (`PlanSelectionChanged`).
  void changePlanSelection(String planId, Set<String> itemIds);

  /// "Approve N changes" / "Delete 7 orders" (`PlanApproved`).
  void approvePlan(String planId);

  /// "Reject" / "Keep them" (`PlanRejected`).
  void rejectPlan(String planId);

  /// An applied card's (or its snackbar's) Undo (`UndoRequested`).
  void undo(String journalId);

  /// "Retry failed" on a partly failed apply (`RetryFailedRequested`).
  void retryFailed(String planId);

  /// An error row's "Try again", an expired plan's "Rebuild"
  /// (`RetryRequested`).
  void retry();

  /// The rate-limit banner's "Retry now" (`RetryNowRequested`).
  void retryNow();

  /// The focus chip's ✕ (`FocusCleared`).
  void clearFocus();

  /// The header's "New conversation" (`NewThreadRequested`).
  void newThread();

  /// "Enable Ask Morkva" on the consent disclosure (`ConsentGranted`).
  void grantConsent();

  /// An object or view chip: open the collection (and view / card) through
  /// the deep-link contract. On phone the host pops the chat route first.
  void openObject({
    required String collectionId,
    String? cardId,
    String? viewId,
  });

  /// A table card's "Open as filtered view": the host turns the item's query
  /// spec into `/collections/:id?filter=…`.
  void openTable(TableItem item);
}
