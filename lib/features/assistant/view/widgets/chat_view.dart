import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/agent/agent_event.dart' show Receipt;
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
  final _snackKey = GlobalKey();

  /// How far the shown snackbar reaches up over the chat list: the list
  /// pads its end by this so the latest card stays readable.
  final _snackInset = ValueNotifier<double>(0);
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _snack;
  bool _tracking = false;

  /// How long the undo snackbar stays; Undo also stays on the applied card.
  static const snackDuration = Duration(seconds: 6);

  @override
  void dispose() {
    _snackInset.dispose();
    super.dispose();
  }

  void _onTransition(
    BuildContext context,
    AssistantState prev,
    AssistantState s,
  ) {
    if (_snack != null && _movedOn(prev, s)) {
      _messenger.currentState?.hideCurrentSnackBar();
    }
    _onApplied(context, prev, s);
  }

  /// The conversation moved past the applied plan: another thread, a new
  /// message or a new plan to review.
  static bool _movedOn(AssistantState prev, AssistantState s) {
    if (prev.threadId != s.threadId) return true;
    final seen = {for (final i in prev.items) i.id};
    return s.items.any(
      (i) =>
          !seen.contains(i.id) &&
          (i is UserItem || (i is PlanItem && i.status == PlanStatus.pending)),
    );
  }

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
      final messenger = _messenger.currentState;
      if (messenger == null) return;
      messenger.hideCurrentSnackBar();
      final snack = messenger.showSnackBar(
        SnackBar(
          key: _snackKey,
          content: Text(_snackText(applied.receipt)),
          margin: EdgeInsets.fromLTRB(14, 0, 14, lift + 16),
          // With an action a snackbar persists by default, and under
          // accessible navigation (web semantics on) it never times out.
          duration: snackDuration,
          persist: false,
          action: journal == null
              ? null
              : SnackBarAction(
                  label: 'Undo',
                  onPressed: () => actions.undo(journal),
                ),
        ),
      );
      _snack = snack;
      snack.closed.whenComplete(() {
        if (!identical(_snack, snack)) return;
        _snack = null;
        if (mounted) _snackInset.value = 0;
      });
      if (!_tracking) _measureSnack();
    });
  }

  /// [_snackInset]: from the snackbar's top down to the composer's, plus a
  /// gap. The bar grows in (and a replaced one shrinks out) over frames, so
  /// it is measured after every frame while a snackbar is up.
  void _measureSnack() {
    _tracking = mounted && _snack != null;
    if (!_tracking) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureSnack());
    final bar = _snackKey.currentContext?.findRenderObject();
    final composer = _composerKey.currentContext?.findRenderObject();
    if (bar is! RenderBox || !bar.hasSize) return;
    if (composer is! RenderBox || !composer.hasSize) return;
    final top = bar.localToGlobal(Offset.zero).dy;
    final bottom = composer.localToGlobal(Offset.zero).dy;
    _snackInset.value = math.max(0.0, bottom - top + 8);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AssistantColors.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final messenger = ScaffoldMessenger(
      key: _messenger,
      child: Scaffold(
        backgroundColor: colors.panel,
        body: _Body(
          bloc: widget.bloc,
          header: widget.header,
          composerKey: _composerKey,
          composerFocus: widget.composerFocus,
          autofocus: widget.autofocus,
          snackInset: _snackInset,
          onTransition: _onTransition,
        ),
      ),
    );
    if (scheme.brightness == Brightness.dark) return messenger;
    // Light: the ink (#2B2018) the mockup draws, darker than the seeded
    // inverseSurface.
    return Theme(
      data: theme.copyWith(
        snackBarTheme: theme.snackBarTheme.copyWith(
          backgroundColor: scheme.onSurface,
        ),
      ),
      child: messenger,
    );
  }
}

/// "12 orders updated": the applied count with the noun of the receipt's
/// "Updated 12 orders"; any other summary (created, partial) reads as is.
String _snackText(Receipt receipt) {
  final noun = RegExp(r'^Updated \d+ (.+)$').firstMatch(receipt.summary)?[1];
  if (noun == null || receipt.failed.isNotEmpty || receipt.stale.isNotEmpty) {
    return receipt.summary;
  }
  return '${receipt.applied.length} $noun updated';
}

class _Body extends StatefulWidget {
  const _Body({
    required this.bloc,
    required this.header,
    required this.composerKey,
    required this.composerFocus,
    required this.autofocus,
    required this.snackInset,
    required this.onTransition,
  });

  final StateStreamable<AssistantState> bloc;
  final Widget header;
  final GlobalKey composerKey;
  final FocusNode? composerFocus;
  final bool autofocus;
  final ValueListenable<double> snackInset;
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
                  : ValueListenableBuilder(
                      valueListenable: widget.snackInset,
                      builder: (context, inset, _) =>
                          ChatList(state: state, bottomInset: inset),
                    ),
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
