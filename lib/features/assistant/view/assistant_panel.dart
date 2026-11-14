import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../design/design.dart';
import '../../../l10n/l10n.dart';
import '../bloc/assistant_state.dart';
import 'assistant_actions.dart';
import 'widgets/assistant_header.dart';
import 'widgets/assistant_scope.dart';
import 'widgets/chat_view.dart';

/// Builds the conversation list inside the panel. [backToChat] returns to
/// the chat (after a thread is picked, or from the header).
typedef AssistantHistoryBuilder =
    Widget Function(BuildContext context, VoidCallback backToChat);

/// The 440 px Ask Morkva side panel (sidebar and rail layouts). It reads the
/// chat from [bloc] (the real `AssistantBloc` or a fake) and reports every
/// intent through [actions]; the shell (T13b) places it beside the page or
/// as a modal sheet ([overlay]).
///
/// `Esc` closes it ([onClose]); the composer takes focus on open.
class AssistantPanel extends StatefulWidget {
  const AssistantPanel({
    super.key,
    required this.bloc,
    required this.actions,
    this.onClose,
    this.historyBuilder,
    this.initiallyShowHistory = false,
    this.composerFocus,
    this.draft,
    this.autofocus = true,
    this.overlay = false,
    this.now = DateTime.now,
  });

  static const double width = 440;

  final StateStreamable<AssistantState> bloc;
  final AssistantActions actions;

  /// See [AssistantScope.draft].
  final ValueNotifier<String?>? draft;
  final VoidCallback? onClose;

  /// Hidden history button when null.
  final AssistantHistoryBuilder? historyBuilder;
  final bool initiallyShowHistory;

  /// The composer's focus node, so the host can return focus on close.
  final FocusNode? composerFocus;
  final bool autofocus;

  /// A modal sheet over the page (rail, or a window under 1280 px): a
  /// stronger shadow and no rule on its edge.
  final bool overlay;
  final DateTime Function() now;

  @override
  State<AssistantPanel> createState() => _AssistantPanelState();
}

class _AssistantPanelState extends State<AssistantPanel> {
  late bool _history =
      widget.initiallyShowHistory && widget.historyBuilder != null;

  void _setHistory(bool on) => setState(() => _history = on);

  @override
  void initState() {
    super.initState();
    widget.draft?.addListener(_onDraft);
    _onDraft();
  }

  @override
  void didUpdateWidget(AssistantPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.draft != widget.draft) {
      oldWidget.draft?.removeListener(_onDraft);
      widget.draft?.addListener(_onDraft);
    }
  }

  @override
  void dispose() {
    widget.draft?.removeListener(_onDraft);
    super.dispose();
  }

  /// A draft goes to the composer, so the chat replaces the history list.
  void _onDraft() {
    if (_history && widget.draft?.value != null) {
      if (mounted) setState(() => _history = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AssistantScope(
      actions: widget.actions,
      draft: widget.draft,
      now: widget.now,
      child: Builder(
        builder: (context) {
          final colors = AssistantColors.of(context);
          final panel = Container(
            width: AssistantPanel.width,
            decoration: BoxDecoration(
              color: colors.panel,
              border: widget.overlay
                  ? null
                  : Border(left: BorderSide(color: colors.border)),
              boxShadow: [
                BoxShadow(
                  color: scheme.shadow.withValues(
                    alpha: widget.overlay ? 0.22 : 0.08,
                  ),
                  blurRadius: widget.overlay ? 32 : 28,
                  offset: Offset(widget.overlay ? -12 : -8, 0),
                ),
              ],
            ),
            child: _history
                ? _HistoryPane(
                    header: _header(context, history: true),
                    child: widget.historyBuilder!(
                      context,
                      () => _setHistory(false),
                    ),
                  )
                : AssistantChatView(
                    bloc: widget.bloc,
                    header: _header(context, history: false),
                    composerFocus: widget.composerFocus,
                    autofocus: widget.autofocus,
                  ),
          );
          return CallbackShortcuts(
            bindings: {
              if (widget.onClose != null)
                const SingleActivator(LogicalKeyboardKey.escape):
                    widget.onClose!,
            },
            child: Semantics(
              container: true,
              explicitChildNodes: true,
              label: context.l10n.assistantAskMorkva,
              child: FocusTraversalGroup(child: panel),
            ),
          );
        },
      ),
    );
  }

  Widget _header(BuildContext context, {required bool history}) {
    final close = widget.onClose == null
        ? null
        : IconActionButton(
            icon: MorkvaIcons.close,
            tooltip: context.l10n.assistantCloseAssistant,
            onPressed: widget.onClose,
          );
    final historyButton = widget.historyBuilder == null
        ? null
        : IconActionButton(
            icon: MorkvaIcons.history,
            tooltip: history
                ? context.l10n.assistantBackToConversation
                : context.l10n.assistantConversationHistory,
            onPressed: () => _setHistory(!history),
          );
    if (history) {
      return AssistantHeader(actions: [?historyButton, ?close]);
    }
    return BlocBuilder<StateStreamable<AssistantState>, AssistantState>(
      bloc: widget.bloc,
      buildWhen: (a, b) =>
          a.threadTitle != b.threadTitle ||
          a.items.isEmpty != b.items.isEmpty ||
          a.availability.runtimeType != b.availability.runtimeType,
      builder: (context, state) => AssistantHeader(
        subtitle: state.threadTitle,
        actions: [
          ?historyButton,
          if (state.items.isNotEmpty && state.availability.canSend)
            IconActionButton(
              icon: MorkvaIcons.compose,
              tooltip: context.l10n.assistantNewConversation,
              onPressed: widget.actions.newThread,
            ),
          ?close,
        ],
      ),
    );
  }
}

class _HistoryPane extends StatelessWidget {
  const _HistoryPane({required this.header, required this.child});

  final Widget header;
  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
    color: AssistantColors.of(context).canvas,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        Expanded(child: child),
      ],
    ),
  );
}
