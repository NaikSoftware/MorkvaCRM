import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../design/design.dart';
import '../bloc/assistant_state.dart';
import 'assistant_actions.dart';
import 'widgets/assistant_header.dart';
import 'widgets/assistant_scope.dart';
import 'widgets/chat_view.dart';

/// The phone route (`/assistant`, root navigator): the chat full screen
/// under a back arrow, with the history list one tap away. Object chips
/// pop this route first (the host does that in [AssistantActions.openObject])
/// and the conversation survives in the bloc.
class AssistantPage extends StatelessWidget {
  const AssistantPage({
    super.key,
    required this.bloc,
    required this.actions,
    required this.onBack,
    this.onOpenHistory,
    this.indicator,
    this.draft,
    this.autofocus = false,
    this.now = DateTime.now,
  });

  final StateStreamable<AssistantState> bloc;
  final AssistantActions actions;

  /// See [AssistantScope.draft].
  final ValueNotifier<String?>? draft;
  final VoidCallback onBack;

  /// Opens `/assistant/history`; the button hides when null.
  final VoidCallback? onOpenHistory;

  /// The automation run indicator, first in the header's actions.
  final Widget? indicator;
  final bool autofocus;
  final DateTime Function() now;

  @override
  Widget build(BuildContext context) {
    return AssistantScope(
      actions: actions,
      draft: draft,
      now: now,
      phone: true,
      child: Builder(
        builder: (context) => ColoredBox(
          color: AssistantColors.of(context).panel,
          child: SafeArea(
            child: AssistantChatView(
              bloc: bloc,
              autofocus: autofocus,
              header:
                  BlocBuilder<StateStreamable<AssistantState>, AssistantState>(
                    bloc: bloc,
                    buildWhen: (a, b) =>
                        a.threadTitle != b.threadTitle ||
                        a.items.isEmpty != b.items.isEmpty ||
                        a.availability.runtimeType !=
                            b.availability.runtimeType,
                    builder: (context, state) => AssistantHeader(
                      subtitle: state.threadTitle,
                      onBack: onBack,
                      actions: [
                        ?indicator,
                        if (onOpenHistory != null)
                          IconActionButton(
                            icon: Icons.history_rounded,
                            tooltip: 'Conversation history',
                            onPressed: onOpenHistory,
                          ),
                        if (state.items.isNotEmpty &&
                            state.availability.canSend)
                          IconActionButton(
                            icon: Icons.edit_square,
                            tooltip: 'New conversation',
                            onPressed: actions.newThread,
                          ),
                      ],
                    ),
                  ),
            ),
          ),
        ),
      ),
    );
  }
}
