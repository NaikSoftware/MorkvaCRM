import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../api/ai/gemini_llm_client.dart';
import '../../../api/assistant/assistant_config_repository.dart';
import '../../../api/assistant/thread_repository.dart';
import '../../../api/auth/auth_user.dart';
import '../../../api/sync/sync_status.dart';
import '../../../core/agent/agent_loop.dart';
import '../../../core/agent/llm_client.dart';
import '../../../core/domain/domain.dart';
import '../../../core/harness/cache/workspace_cache.dart';
import '../../../core/harness/harness.dart';
import '../../../core/harness/query/workspace_digest.dart';
import '../../../core/harness/session/harness_session.dart';
import '../host/result_reader.dart';
import 'assistant_bloc.dart';
import 'assistant_focus.dart';
import 'assistant_panel_cubit.dart';

/// Everything Ask Morkva runs on for one signed-in member, built **once**
/// (a `late final` field of the app's State, always provided above the
/// router) and re-bound per session: [initialize] after the data repository
/// is ready for a workspace, [reset] on sign-out or before a workspace
/// switch. Nothing is disposed until [dispose].
///
/// It runs on the app's one [HarnessSession] (shared with the automation
/// runner: cache, queries, plans, journal, committer and every op) and adds
/// the [AgentLoop] over an [LlmClient], the [AssistantBloc] (the chat's
/// user-actor caller), the shell's [panel] cubit and the [focus] the views
/// page publishes. Until the app drives the session itself, [initialize]
/// and [reset] bind and reset it.
class AssistantSession {
  AssistantSession({
    required this.harnessSession,
    required ThreadRepository threads,
    required AssistantConfigRepository config,
    required StateStreamable<SyncStatus> syncStatus,
    LlmClient Function()? llmFactory,
    Stream<String>? runsStarted,
    DateTime Function()? now,
  }) : _threads = threads,
       _config = config,
       _now = now ?? DateTime.now {
    bool online() => syncStatus.state is! SyncOffline;
    llm = (llmFactory ?? GeminiLlmClient.new)();
    // Read per call: switching threads needs no re-registration.
    harnessSession.chatThread = () => bloc.state.threadId ?? '';
    agentLoop = AgentLoop(
      llm: llm,
      harness: harnessSession.harness,
      workspace: _CacheWorkspace(cache),
      grants: Grants(kAssistantCaps),
      now: _now,
    );
    bloc = AssistantBloc(
      agentLoop: agentLoop,
      harness: harnessSession.harness,
      threads: threads,
      config: config,
      llm: llm,
      results: ResultReader(
        queries: harnessSession.queries,
        aggregates: harnessSession.aggregates,
      ),
      collectionNames: () => [for (final c in cache.collections) c.name],
      online: syncStatus.stream.map((s) => s is! SyncOffline),
      initiallyOnline: online(),
      onConfig: (c) => cache.leaseTtl = Duration(minutes: c.leaseTtlMinutes),
      runsStarted: runsStarted,
      now: _now,
    );
    focus.addListener(() {
      if (!bloc.isClosed) bloc.add(FocusChanged(focus.value));
    });
  }

  final ThreadRepository _threads;
  final AssistantConfigRepository _config;
  final DateTime Function() _now;

  /// The harness every caller shares.
  final HarnessSession harnessSession;
  WorkspaceCache get cache => harnessSession.cache;
  late final LlmClient llm;
  late final AgentLoop agentLoop;
  late final AssistantBloc bloc;

  /// What the views page and the card editor publish.
  final AssistantFocusNotifier focus = AssistantFocusNotifier();

  /// Open or closed; while open, every leased collection stays warm.
  late final AssistantPanelCubit panel = AssistantPanelCubit(
    onChanged: (open) => cache.panelOpen = open,
  );

  String? _workspaceId;
  String? _uid;

  /// The workspace the session is bound to, or null.
  String? get workspaceId => _workspaceId;

  /// Binds the session to [workspaceId] for [user]; the [DataRepository]
  /// must already be initialized for it. Re-binding another workspace or
  /// user resets first.
  Future<void> initialize(String workspaceId, {required AuthUser user}) async {
    if (_workspaceId == workspaceId && _uid == user.uid) return;
    if (_workspaceId != null) await reset();
    _workspaceId = workspaceId;
    _uid = user.uid;
    if (bloc.isClosed) throw StateError('AssistantSession was disposed.');
    harnessSession.initialize(workspaceId);
    _threads.initialize(workspaceId: workspaceId, uid: user.uid);
    _config.initialize(workspaceId: workspaceId, uid: user.uid);
    agentLoop.timeZoneName = _now().timeZoneName;
    bloc.add(
      AssistantStarted(
        workspaceId: workspaceId,
        uid: user.uid,
        userFirstName: firstNameOf(user.displayName),
      ),
    );
  }

  /// Unbinds the session: stops the turn, forgets plans, journals, result
  /// handles and turns, cancels every listener and timer, and returns the
  /// bloc to Idle with no thread. [initialize] may follow.
  Future<void> reset() async {
    _workspaceId = null;
    _uid = null;
    if (!bloc.isClosed) bloc.reset();
    agentLoop.stop();
    panel.hide();
    await harnessSession.reset();
  }

  /// Closes everything (the app is going away).
  Future<void> dispose() async {
    await reset();
    await bloc.close();
    await panel.close();
    focus.dispose();
  }

  /// The greeting's name: the first word of [displayName].
  static String? firstNameOf(String? displayName) {
    final words = displayName?.trim().split(RegExp(r'\s+')) ?? const [];
    return words.isEmpty || words.first.isEmpty ? null : words.first;
  }
}

/// The workspace the agent loop grounds its turns in, read fresh per
/// request from the cache.
final class _CacheWorkspace implements AgentWorkspace {
  _CacheWorkspace(this.cache);

  final WorkspaceCache cache;

  static const WorkspaceDigest _digest = WorkspaceDigest();

  @override
  String get workspaceId => cache.workspaceId ?? '';

  @override
  List<Collection> get collections => cache.collections;

  @override
  String digest() => _digest.ofCache(cache);
}
