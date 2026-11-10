/// A real Ask Morkva session over the seed workspace, for the bloc tests:
/// the [AssistantSession] with every harness op, the agent loop over a
/// scripted LLM, the Firestore thread and config repositories over
/// `fake_cloud_firestore`, and a [SyncStatusCubit] the test flips offline.
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/api/assistant/assistant_config_repository.dart';
import 'package:morkva_crm/api/assistant/firestore_thread_repository.dart';
import 'package:morkva_crm/api/assistant/thread_repository.dart';
import 'package:morkva_crm/api/auth/auth_user.dart';
import 'package:morkva_crm/api/sync/sync_status_cubit.dart';
import 'package:morkva_crm/core/agent/llm_client.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/features/assistant/bloc/assistant_bloc.dart';
import 'package:morkva_crm/features/assistant/bloc/assistant_session.dart';
import 'package:morkva_crm/features/assistant/bloc/assistant_state.dart';
import 'package:morkva_crm/features/assistant/bloc/chat_item.dart';

import '../../../core/agent/fake_llm_client.dart';
import '../../../core/harness/fixtures/seed_workspace.dart';
import '../../collections/fake_data_repository.dart';

export '../../../core/agent/fake_llm_client.dart';
export '../../../core/harness/fixtures/seed_workspace.dart';

const String workspaceId = 'w1';
const AuthUser user = AuthUser(
  uid: 'u1',
  email: 'olena@example.com',
  displayName: 'Olena Koval',
);

/// A [FakeLlmClient] whose persisted model contents look like Gemini's
/// (`functionCall` parts), so a restored plan gate is recognisable.
final class ScriptedLlm implements LlmClient {
  ScriptedLlm([Iterable<FakeReply> replies = const []])
    : inner = FakeLlmClient(replies);

  final FakeLlmClient inner;

  List<LlmRequest> get requests => inner.requests;

  void add(FakeReply reply) => inner.add(reply);

  @override
  Stream<LlmChunk> generate(LlmRequest request) => inner.generate(request);

  @override
  Map<String, Object?> encodeContent(LlmContent content) => switch (content) {
    LlmModelContent(opaque: final FakeModelContent c) => {
      'role': 'model',
      'parts': [
        if (c.text.isNotEmpty) {'text': c.text},
        for (final call in c.calls)
          {
            'functionCall': {
              'name': call.name,
              'args': call.args,
              'id': ?call.geminiId,
            },
          },
      ],
    },
    _ => inner.encodeContent(content),
  };
}

final class AssistantRig {
  AssistantRig({
    SeedWorkspace? seed,
    FakeDataRepository? repository,
    FakeFirebaseFirestore? firestore,
    Iterable<FakeReply> replies = const [],
    ThreadRepository Function(ThreadRepository firestore)? threads,
  }) : seed = seed ?? SeedWorkspace(),
       firestore = firestore ?? FakeFirebaseFirestore(),
       llm = ScriptedLlm(replies) {
    repo = repository ?? this.seed.repository();
    final store = FirestoreThreadRepository(firestore: this.firestore);
    this.threads = threads?.call(store) ?? store;
    session = AssistantSession(
      dataRepository: repo,
      threads: this.threads,
      config: AssistantConfigRepository(
        firestore: this.firestore,
        now: () => clock,
      ),
      syncStatus: sync,
      llmFactory: () => llm,
      now: () => clock,
    );
  }

  final SeedWorkspace seed;
  late final FakeDataRepository repo;
  final FakeFirebaseFirestore firestore;
  final ScriptedLlm llm;
  late final ThreadRepository threads;
  final SyncStatusCubit sync = SyncStatusCubit();
  late final AssistantSession session;

  /// The clock everything reads (the seed's "today", mid-afternoon).
  DateTime clock = DateTime(2026, 11, 10, 14, 30);

  AssistantBloc get bloc => session.bloc;
  AssistantState get state => bloc.state;

  /// Records the workspace's opt-in (as a member enabling it would).
  Future<void> consent() => firestore
      .collection('workspaces')
      .doc(workspaceId)
      .collection('config')
      .doc('assistant')
      .set({'consentedBy': user.uid, 'consentedAt': '2026-11-01T10:00:00Z'});

  /// Signs the member in, consenting first unless told not to, and waits
  /// for the config to arrive.
  Future<void> start({bool consented = true}) async {
    if (consented) await consent();
    await session.initialize(workspaceId, user: user);
    await until((s) => s.availability is! AvailabilityChecking);
    await session.cache.ready;
  }

  /// The first state (the current one included) passing [test].
  Future<AssistantState> until(
    bool Function(AssistantState s) test, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (test(bloc.state)) return bloc.state;
    return bloc.stream.firstWhere(test).timeout(timeout);
  }

  Future<AssistantState> idle() =>
      until((s) => s.phase is IdlePhase && s.items.isNotEmpty);

  Future<AssistantState> awaitingApproval() =>
      until((s) => s.phase is AwaitingApprovalPhase);

  /// Sends [text] and waits for the turn to start.
  Future<void> ask(String text) async {
    bloc.add(PromptSubmitted(text));
    await until(
      (s) => s.items.whereType<UserItem>().any((u) => u.text == text),
    );
  }

  /// Lets repository emissions and pending writes settle.
  Future<void> settle() async {
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  PlanItem get plan => state.items.whereType<PlanItem>().last;
  AppliedItem get applied => state.items.whereType<AppliedItem>().last;

  /// The stored card [number] of Orders.
  MorkvaObject? order(int number) => repo
      .objectsOf(SeedIds.orders)
      .where((o) => o.id == SeedCards.order(number))
      .firstOrNull;

  String? statusOf(int number) =>
      (order(number)?[OrderFields.status] as SingleSelectFieldValue?)?.optionId;

  /// The turn docs of [threadId] (of member [uid]), by seq.
  Future<List<Map<String, Object?>>> turnDocs(
    String threadId, {
    String uid = 'u1',
  }) async {
    final snapshot = await firestore
        .collection('workspaces')
        .doc(workspaceId)
        .collection('members')
        .doc(uid)
        .collection('assistantThreads')
        .doc(threadId)
        .collection('messages')
        .orderBy('seq')
        .get();
    return [for (final d in snapshot.docs) d.data()];
  }

  Future<void> dispose() async {
    await session.dispose();
    await sync.close();
  }
}

/// The Firestore thread repository, with reads made to fail or to look
/// cache-only (offline, holding only some turns).
final class FlakyThreads implements ThreadRepository {
  FlakyThreads(this.inner);

  final ThreadRepository inner;

  /// Thrown by the next reads while set.
  Object? loadError;

  /// The seqs a cache-only read holds; null reads the server.
  Set<int>? cachedSeqs;

  @override
  void initialize({required String workspaceId, required String uid}) =>
      inner.initialize(workspaceId: workspaceId, uid: uid);

  @override
  String newThreadId() => inner.newThreadId();

  @override
  Stream<List<AssistantRecord>> watchThreads({int limit = kThreadListLimit}) =>
      inner.watchThreads(limit: limit);

  @override
  Future<({List<AssistantRecord> records, bool fromCache})> loadMessages(
    String threadId,
  ) async {
    if (loadError case final error?) throw error;
    final loaded = await inner.loadMessages(threadId);
    final cached = cachedSeqs;
    if (cached == null) return loaded;
    return (
      records: [
        for (final r in loaded.records)
          if (cached.contains(r['seq'])) r,
      ],
      fromCache: true,
    );
  }

  @override
  Future<void> checkpoint(
    String threadId, {
    required int seq,
    required AssistantRecord message,
    AssistantRecord? thread,
  }) => inner.checkpoint(threadId, seq: seq, message: message, thread: thread);

  @override
  Future<void> dropJournal(String threadId, int seq) =>
      inner.dropJournal(threadId, seq);

  @override
  Future<void> deleteThread(String threadId) => inner.deleteThread(threadId);
}

/// The first [count] order numbers of [seed] not yet shipped.
List<int> notShipped(int count, [SeedWorkspace? seed]) => [
  for (final o in (seed ?? SeedWorkspace()).orderCards)
    if ((o[OrderFields.status] as SingleSelectFieldValue?)?.optionId !=
        SeedOptions.shipped)
      int.parse(o.id.substring('b_or_'.length)),
].take(count).toList();

/// `cards.update` of [numbers] to Shipped (what the model sends).
LlmCall shipCall(List<int> numbers) => call('cards_update', {
  'collection': 'Orders',
  'target': {
    'ids': [for (final n in numbers) SeedCards.order(n)],
  },
  'set': {'Status': 'Shipped'},
});

/// A `cards.query` of open orders shown as a table.
LlmCall queryCall({String status = 'Packing'}) => call('cards_query', {
  'collection': 'Orders',
  'where': [
    {'field': 'Status', 'op': 'equals', 'value': status},
  ],
  'present': 'table',
});

/// The state matcher shorthand.
TypeMatcher<AssistantState> stateWhere(
  bool Function(AssistantState s) test, [
  String description = 'state',
]) => isA<AssistantState>().having(test, description, isTrue);
