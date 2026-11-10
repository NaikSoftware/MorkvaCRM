import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/assistant_state.dart';
import '../../bloc/chat_item.dart';
import 'assistant_scope.dart';
import 'chat_list.dart';
import 'composer.dart';
import 'empty_chat.dart';
import 'limit_banner.dart';

/// The chat under a header, shared by the side panel and the phone route:
/// the limit banner, the conversation (or the empty / unavailable state)
/// and the composer, inside a nested [ScaffoldMessenger] so the "12 orders
/// updated · Undo" snackbar stays in the chat.
class AssistantChatView extends StatefulWidget {
  const AssistantChatView({
    super.key,
    required this.bloc,
    required this.header,
    this.composerFocus,
    this.autofocus = false,
  });

  final StateStreamable<AssistantState> bloc;
  final Widget header;
  final FocusNode? composerFocus;
  final bool autofocus;

  @override
  State<AssistantChatView> createState() => _AssistantChatViewState();
}

class _AssistantChatViewState extends State<AssistantChatView> {
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  final _composerKey = GlobalKey();

  /// A plan this state just finished applying: snackbar it. Only a plan the
  /// previous state was committing counts, so an applied card that arrives
  /// with a loaded or restored thread stays quiet.
  void _onApplied(BuildContext context, AssistantState prev, AssistantState s) {
    if (prev.threadId != s.threadId) return;
    final wasApplied = {
      for (final i in prev.items.whereType<AppliedItem>()) i.receipt.planId,
    };
    final committing = {
      for (final i in prev.items.whereType<PlanItem>())
        if (i.status == PlanStatus.committing) i.plan.planId,
    };
    final applying = prev.phase is ApplyingPhase;
    final fresh = s.items.whereType<AppliedItem>().where(
      (i) =>
          !wasApplied.contains(i.receipt.planId) &&
          (applying || committing.contains(i.receipt.planId)),
    );
    if (fresh.isEmpty) return;
    final applied = fresh.last;
    final journal = applied.receipt.journalId;
    final actions = AssistantScope.of(context).actions;
    // After the frame: the composer leaves its applying state in this same
    // rebuild, and the snackbar sits above its new height.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final composer = _composerKey.currentContext?.findRenderObject();
      final lift = composer is RenderBox && composer.hasSize
          ? composer.size.height
          : 96.0;
      _messenger.currentState
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(applied.receipt.summary),
            margin: EdgeInsets.fromLTRB(14, 0, 14, lift + 8),
            action: journal == null
                ? null
                : SnackBarAction(
                    label: 'Undo',
                    onPressed: () => actions.undo(journal),
                  ),
          ),
        );
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AssistantColors.of(context);
    return ScaffoldMessenger(
      key: _messenger,
      child: Scaffold(
        backgroundColor: colors.panel,
        body: _Body(
          bloc: widget.bloc,
          header: widget.header,
          composerKey: _composerKey,
          composerFocus: widget.composerFocus,
          autofocus: widget.autofocus,
          onTransition: _onApplied,
        ),
      ),
    );
  }
}

class _Body extends StatefulWidget {
  const _Body({
    required this.bloc,
    required this.header,
    required this.composerKey,
    required this.composerFocus,
    required this.autofocus,
    required this.onTransition,
  });

  final StateStreamable<AssistantState> bloc;
  final Widget header;
  final GlobalKey composerKey;
  final FocusNode? composerFocus;
  final bool autofocus;
  final void Function(BuildContext, AssistantState, AssistantState)
  onTransition;

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  late AssistantState _last;

  @override
  void initState() {
    super.initState();
    // Not a lazy initializer: read on the first change, it would already be
    // the new state.
    _last = widget.bloc.state;
  }

  @override
  void didUpdateWidget(_Body oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bloc != widget.bloc) _last = widget.bloc.state;
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<StateStreamable<AssistantState>, AssistantState>(
      bloc: widget.bloc,
      listener: (context, state) {
        widget.onTransition(context, _last, state);
        _last = state;
      },
      builder: (context, state) {
        final availability = state.availability;
        final closed =
            availability is AvailabilityDisabledByFlag ||
            availability is AvailabilityNotSetUp;
        final banner =
            state.banner ??
            switch (availability) {
              AvailabilityQuotaExhausted(:final until) => DailyLimitBanner(
                until,
              ),
              _ => null,
            };
        final consent = availability is AvailabilityNeedsConsent;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            widget.header,
            if (banner != null && !closed) LimitBannerView(banner: banner),
            Expanded(
              child: closed
                  ? AssistantUnavailable(availability: availability)
                  : state.items.isEmpty
                  ? ColoredBox(
                      color: AssistantColors.of(context).canvas,
                      child: EmptyChat(state: state),
                    )
                  : ChatList(state: state),
            ),
            if (!closed && !consent)
              KeyedSubtree(
                key: widget.composerKey,
                child: Composer(
                  state: state,
                  focusNode: widget.composerFocus,
                  autofocus: widget.autofocus,
                ),
              ),
          ],
        );
      },
    );
  }
}
