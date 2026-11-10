/// A persisted record: plain JSON values only (String, num, bool, null, List,
/// Map). Dates are ISO-8601 **UTC** strings, so `updatedAt` sorts correctly.
typedef AssistantRecord = Map<String, Object?>;

/// The last threads a thread list shows.
const int kThreadListLimit = 50;

/// Ask Morkva chat history of one workspace member, stored per member at
/// `workspaces/{wid}/members/{uid}/assistantThreads/{tid}` with one message
/// doc per turn under `messages/m_<seq padded>`.
///
/// Records are opaque maps: the thread meta
/// (`{title, createdAt, updatedAt, model, lastSnippet, tokens, schema}`) and the
/// turn doc (`{seq, createdAt, status, llm, ui, journal?, usage?}`) are shaped
/// by the bloc layer, so `lib/api` never imports `lib/features`. Measure a turn
/// with `fitMessageToBudget` before [checkpoint].
abstract interface class ThreadRepository {
  /// Binds the repository to [workspaceId] and the member [uid].
  void initialize({required String workspaceId, required String uid});

  /// A fresh thread id (minted locally, works offline).
  String newThreadId();

  /// The newest [limit] threads by `updatedAt`, each with its doc id under
  /// `id`.
  Stream<List<AssistantRecord>> watchThreads({int limit = kThreadListLimit});

  /// Every turn doc of [threadId], ordered by `seq`.
  Future<List<AssistantRecord>> loadMessages(String threadId);

  /// Writes turn [seq] of [threadId] (replacing the whole doc, so the three
  /// checkpoints of a turn — plan proposed, committed, done — overwrite one
  /// doc) and, when given, merges [thread] into the thread meta, in one
  /// batch. Merging is shallow: pass nested maps such as `tokens` whole.
  Future<void> checkpoint(
    String threadId, {
    required int seq,
    required AssistantRecord message,
    AssistantRecord? thread,
  });

  /// Removes the journal mirror from turn [seq] once its undo window passed.
  Future<void> dropJournal(String threadId, int seq);

  /// Deletes [threadId] and all its turn docs.
  Future<void> deleteThread(String threadId);
}

/// The doc id of turn [seq]: zero-padded so ids sort like seqs.
String messageDocId(int seq) => 'm_${seq.toString().padLeft(6, '0')}';
