import '../bloc/chat_item.dart';
import 'widgets/plan_card_scope.dart';

/// What the assistant UI can ask for. The widgets never touch the bloc's
/// events directly, so the same widgets run against `FakeAssistantBloc` in
/// tests and the real `AssistantBloc` in the app: the host (T13b) implements
/// this by adding the named `AssistantEvent` or navigating.
///
/// The plan-card intents ([PlanCardActions]) map to `PlanSelectionChanged`,
/// `PlanApproved`, `PlanRejected`, `UndoRequested`, `RetryFailedRequested`
/// and `RetryRequested` (an error row's "Try again", an expired plan's
/// "Rebuild").
abstract interface class AssistantActions implements PlanCardActions {
  /// The composer's Send (`PromptSubmitted`).
  void submit(String text);

  /// An empty-state suggestion or a card shortcut such as "Save as a view"
  /// (`SuggestionTapped`).
  void suggest(String text);

  /// The composer's Stop (`StopRequested`).
  void stop();

  /// The rate-limit banner's "Retry now" (`RetryNowRequested`).
  void retryNow();

  /// The focus chip's ✕ (`FocusCleared`).
  void clearFocus();

  /// The header's "New conversation" (`NewThreadRequested`).
  void newThread();

  /// An object or view chip: open the collection (and view / card) through
  /// the deep-link contract. On phone the host pops the chat route first.
  @override
  void openObject({
    required String collectionId,
    String? cardId,
    String? viewId,
  });

  /// A table card's "Open as filtered view": the host turns the item's query
  /// spec into `/collections/:id?filter=…`.
  void openTable(TableItem item);
}
