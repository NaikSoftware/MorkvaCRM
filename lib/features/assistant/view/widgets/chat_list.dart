import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../../bloc/assistant_state.dart';
import '../../bloc/chat_item.dart';
import 'applied_card.dart';
import 'assistant_scope.dart';
import 'assistant_text.dart';
import 'error_row.dart';
import 'object_chip.dart';
import 'plan_card.dart';
import 'result_chart_card.dart';
import 'result_table_card.dart';
import 'thinking_row.dart';
import 'tool_steps.dart';
import 'user_bubble.dart';

/// The conversation. It opens at the latest message and follows new content
/// (items and streaming text) while the reader is at the bottom; once they
/// scroll up, "Jump to latest" appears instead.
class ChatList extends StatefulWidget {
  const ChatList({super.key, required this.state});

  final AssistantState state;

  @override
  State<ChatList> createState() => _ChatListState();
}

class _ChatListState extends State<ChatList> {
  final _scroll = ScrollController();
  bool _atBottom = true;

  static const _stickSlack = 48.0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _toBottom());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final p = _scroll.position;
    final atBottom = p.pixels >= p.maxScrollExtent - _stickSlack;
    if (atBottom != _atBottom) setState(() => _atBottom = atBottom);
  }

  void _toBottom() {
    if (!mounted || !_scroll.hasClients) return;
    final max = _scroll.position.maxScrollExtent;
    if (_scroll.position.pixels != max) _scroll.jumpTo(max);
  }

  /// Content grew (a new item, a streaming delta, a lazily built row): stay
  /// pinned to the bottom if the reader was there.
  bool _onMetrics(ScrollMetricsNotification n) {
    if (_atBottom) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _toBottom());
    }
    return false;
  }

  void _jumpToLatest() {
    if (!_scroll.hasClients) return;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final max = _scroll.position.maxScrollExtent;
    if (reduce) {
      _scroll.jumpTo(max);
    } else {
      _scroll.animateTo(
        max,
        duration: MotionDurations.slow,
        curve: MotionCurves.emphasized,
      );
    }
    setState(() => _atBottom = true);
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final items = state.items;
    final thinking = state.phase is ThinkingPhase;
    final count = items.length + (thinking ? 1 : 0);
    final scope = AssistantScope.of(context);
    final colors = AssistantColors.of(context);

    return ColoredBox(
      color: colors.canvas,
      child: Stack(
        children: [
          NotificationListener<ScrollMetricsNotification>(
            onNotification: _onMetrics,
            child: ListView.builder(
              controller: _scroll,
              padding: scope.phone
                  ? const EdgeInsets.all(Spacing.md)
                  : const EdgeInsets.fromLTRB(18, 18, 18, 8),
              itemCount: count,
              // Keys sit on the builder's top-level child, so a card's state
              // follows its item id if items ever move.
              findChildIndexCallback: (key) {
                if (key is! ValueKey<String>) return null;
                final i = items.indexWhere((it) => it.id == key.value);
                return i < 0 ? null : i;
              },
              itemBuilder: (context, i) {
                final thinkingRow = i == items.length;
                final child = thinkingRow
                    ? const ThinkingRow()
                    : ChatItemView(item: items[i], state: state);
                return Padding(
                  key: thinkingRow
                      ? const ValueKey(#thinking)
                      : ValueKey(items[i].id),
                  padding: EdgeInsets.only(top: i == 0 ? 0 : _gap(items, i)),
                  child: child,
                );
              },
            ),
          ),
          if (!_atBottom)
            PositionedDirectional(
              bottom: 12,
              start: 0,
              end: 0,
              child: Center(child: _JumpToLatest(onPressed: _jumpToLatest)),
            ),
        ],
      ),
    );
  }

  /// 14 between messages; 10 inside one answer (steps → text → table).
  double _gap(List<ChatItem> items, int i) {
    if (i >= items.length) return 14;
    final prev = items[i - 1];
    final cur = items[i];
    final sameAnswer = prev is! UserItem && cur is! UserItem;
    final card = cur is PlanItem || cur is AppliedItem || cur is ErrorItem;
    return sameAnswer && !card ? 10 : 14;
  }
}

/// Renders one [ChatItem].
class ChatItemView extends StatelessWidget {
  const ChatItemView({super.key, required this.item, required this.state});

  final ChatItem item;
  final AssistantState state;

  @override
  Widget build(BuildContext context) {
    final item = this.item;
    return switch (item) {
      UserItem(:final text) => UserBubble(text: text),
      AssistantTextItem() => AssistantText(item: item),
      StepsItem() => ToolSteps(item: item),
      TableItem() => ResultTableCard(item: item),
      ChartItem() => ResultChartCard(
        item: item,
        collectionName: _collectionName(item.chart?.collectionId),
      ),
      ObjectChipItem() => ObjectChipMessage(item: item),
      PlanItem() => PlanCard(
        item: item,
        progress: switch (state.phase) {
          final ApplyingPhase p => p,
          _ => null,
        },
      ),
      AppliedItem() => AppliedCard(item: item),
      ErrorItem() => ErrorRow(item: item),
    };
  }

  /// The chart's collection name, when the focus names it.
  String? _collectionName(String? collectionId) {
    final focus = state.focus;
    if (collectionId == null || focus == null) return null;
    return focus.collectionId == collectionId ? focus.collectionName : null;
  }
}

class _JumpToLatest extends StatelessWidget {
  const _JumpToLatest({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return PressableScale(
      onPressed: onPressed,
      semanticLabel: 'Jump to latest',
      borderRadius: Radii.fullAll,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: scheme.onSurface,
          borderRadius: Radii.fullAll,
          boxShadow: MorkvaElevation.level2,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.arrow_downward_rounded, size: 16, color: scheme.surface),
            const SizedBox(width: 6),
            Text(
              'Jump to latest',
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.surface,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
