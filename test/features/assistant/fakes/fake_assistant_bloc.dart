import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:morkva_crm/features/assistant/bloc/assistant_state.dart';

import 'assistant_seeds.dart';

/// A stand-in for the assistant bloc while the UI is built (T12) before the
/// real `AssistantBloc` (T11) exists: a [Cubit] holding a seeded
/// [AssistantState] per mockup artboard, driven by [set].
///
/// UI code should read the state through `StateStreamable<AssistantState>`
/// (`BlocBuilder<StateStreamable<AssistantState>, AssistantState>`) or be
/// handed the state, so the same widgets take this fake in tests and the real
/// bloc in the app.
class FakeAssistantBloc extends Cubit<AssistantState> {
  FakeAssistantBloc([super.initial = const AssistantState()]);

  /// Main: table answer + pending plan.
  FakeAssistantBloc.main() : this(AssistantSeeds.main());

  /// Empty: first open.
  FakeAssistantBloc.empty() : this(AssistantSeeds.empty());

  /// The empty state awaiting the workspace's consent.
  FakeAssistantBloc.consent() : this(AssistantSeeds.consent());

  /// Analyze: chart + applied card with Undo.
  FakeAssistantBloc.analyze({DateTime? now})
    : this(AssistantSeeds.analyze(now: now));

  /// Schema: rate-limit banner, applied schema change, destructive plan,
  /// error row.
  FakeAssistantBloc.schema({DateTime? now})
    : this(AssistantSeeds.schema(now: now));

  /// Phone: streaming answer. [live] carries the growing text; append to it
  /// to simulate deltas.
  FakeAssistantBloc.phoneStreaming({ValueNotifier<String>? live})
    : this(AssistantSeeds.phoneStreaming(live: live));

  /// Tablet: the conversation behind the history sheet (see
  /// [AssistantSeeds.threads] for the list itself).
  FakeAssistantBloc.tabletHistory() : this(AssistantSeeds.tabletHistory());

  /// Moves the fake to [state] (a transition a widget test wants to see).
  void set(AssistantState state) => emit(state);
}
