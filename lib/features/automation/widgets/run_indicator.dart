import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../design/design.dart';
import '../bloc/automation_runs_cubit.dart';
import 'action_buttons.dart';

/// What the run indicator shows, from [AutomationRunsState] (UX §5):
/// running > needs review > attention > reviews expired > engine warning.
final class IndicatorView {
  IndicatorView(AutomationRunsState state, String sessionId, {DateTime? now})
    : primary = state.primary(sessionId),
      running = state.running,
      needsReview = state.needsReview,
      failed = state.failed,
      didntRun = state.didntRun,
      expired = state.expired(sessionId),
      engineWarning = state.engineWarning,
      autoPaused = switch (state.activity.autoPausedUntil) {
        final until? => until.isAfter(now ?? DateTime.now()),
        null => false,
      };

  final IndicatorState primary;
  final int running;
  final int needsReview;
  final int failed;
  final int didntRun;
  final int expired;
  final bool engineWarning;

  /// The auto-apply budget is spent ("Auto-apply paused for 10 min").
  final bool autoPaused;

  bool get idle => primary == IndicatorState.idle;

  /// Where a tap goes: the Runs tab, filtered to what needs the user.
  String get path => AutomationPaths.runs(
    filter: switch (primary) {
      IndicatorState.needsReview => 'review',
      IndicatorState.attention => 'failed',
      _ => null,
    },
  );

  /// The short pill words (the 272 px sidebar row).
  String? get pill => switch (primary) {
    IndicatorState.running => 'Running · $running',
    IndicatorState.needsReview =>
      needsReview == 1 ? '1 needs review' : '$needsReview need review',
    IndicatorState.attention =>
      failed > 0 ? '$failed failed' : "$didntRun didn't run",
    _ => null,
  };

  /// The full sentence: tooltip, semantics and the polite announcement.
  String get sentence {
    final main = switch (primary) {
      IndicatorState.running =>
        '${_n(running, 'automation')} running'
            '${needsReview > 0 ? ', $needsReview need review' : ''}',
      IndicatorState.needsReview =>
        needsReview == 1
            ? '1 automation needs review'
            : '$needsReview automations need review',
      IndicatorState.attention => [
        if (failed > 0) '$failed failed',
        if (didntRun > 0) "${_n(didntRun, 'automation')} didn't run",
      ].join(', '),
      IndicatorState.reviewsExpired =>
        '${_n(expired, 'review')} expired · View',
      IndicatorState.engineUnavailable =>
        "Automations can't run on this device",
      IndicatorState.idle => 'Automations',
    };
    return autoPaused ? '$main · Auto-apply paused for 10 min' : main;
  }

  static String _n(int n, String noun) => n == 1 ? '1 $noun' : '$n ${noun}s';
}

IndicatorView _viewOf(AutomationRunsCubit cubit, AutomationRunsState s) =>
    IndicatorView(s, cubit.sessionId);

/// Builds [builder] over the app's [AutomationRunsCubit]; [orElse] without it.
class _IndicatorBuilder extends StatelessWidget {
  const _IndicatorBuilder({required this.builder, this.orElse});

  final Widget Function(BuildContext context, IndicatorView view) builder;
  final Widget? orElse;

  @override
  Widget build(BuildContext context) {
    final cubit = maybeRead<AutomationRunsCubit>(context);
    if (cubit == null) return orElse ?? const SizedBox.shrink();
    return BlocBuilder<AutomationRunsCubit, AutomationRunsState>(
      bloc: cubit,
      builder: (context, s) => builder(context, _viewOf(cubit, s)),
    );
  }
}

/// The "Automations" sidebar row's trailing pill (≥ 1240). The row itself
/// navigates to [IndicatorView.path] (T16 reads it with [runIndicatorPathOf]).
class RunIndicatorPill extends StatelessWidget {
  const RunIndicatorPill({super.key});

  @override
  Widget build(BuildContext context) => _IndicatorBuilder(
    builder: (context, v) {
      if (v.idle) return const SizedBox.shrink();
      final theme = Theme.of(context);
      final scheme = theme.colorScheme;
      final semantic = theme.extension<MorkvaSemanticColors>()!;
      final pill = v.pill;
      final (Color bg, Color fg) = switch (v.primary) {
        IndicatorState.running => (
          semantic.info.withValues(alpha: 0.12),
          semantic.info,
        ),
        IndicatorState.attention when v.failed > 0 => (
          scheme.errorContainer,
          scheme.onErrorContainer,
        ),
        _ => (semantic.warningContainer, semantic.onWarningContainer),
      };
      final dot = switch (v.primary) {
        IndicatorState.attention ||
        IndicatorState.engineUnavailable => semantic.warning,
        IndicatorState.reviewsExpired => scheme.onSurfaceVariant,
        _ => null,
      };
      return Semantics(
        liveRegion: true,
        label: v.sentence,
        excludeSemantics: true,
        child: Tooltip(
          message: v.sentence,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (dot != null) _Dot(color: dot),
              if (dot != null && pill != null)
                const SizedBox(width: Spacing.xxs),
              if (pill != null)
                Container(
                  height: 24,
                  padding: const EdgeInsets.symmetric(horizontal: Spacing.xs),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: Radii.fullAll,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (v.primary == IndicatorState.running) ...[
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: fg,
                          ),
                        ),
                        const SizedBox(width: Spacing.xxs),
                      ],
                      Text(
                        pill,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: fg,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              // While running, waiting reviews still show (a second badge).
              if (v.primary == IndicatorState.running && v.needsReview > 0) ...[
                const SizedBox(width: Spacing.xxs),
                _CountBadge(count: v.needsReview),
              ],
            ],
          ),
        ),
      );
    },
  );
}

/// The rail's bolt (840–1239): a spinner ring while running, an amber count
/// for reviews, a dot for attention / expired / engine.
class RunIndicatorRailIcon extends StatelessWidget {
  const RunIndicatorRailIcon({super.key, this.color});

  /// The bolt's ink (the rail's selected / unselected colour).
  final Color? color;

  @override
  Widget build(BuildContext context) => _IndicatorBuilder(
    orElse: Icon(Icons.bolt_rounded, color: color),
    builder: (context, v) => Tooltip(
      message: v.idle ? 'Automations' : 'Automations · ${v.sentence}',
      child: Semantics(
        liveRegion: !v.idle,
        label: v.idle ? 'Automations' : 'Automations, ${v.sentence}',
        excludeSemantics: true,
        child: _Bolt(view: v, color: color, badge: _RailBadge.containerCount),
      ),
    ),
  );
}

/// The phone indicator (< 840): an icon-only 44 px bolt, hidden while idle
/// ([idle] shows instead: the sync pill whose slot it takes). A tap opens
/// the Runs tab.
class RunIndicatorButton extends StatelessWidget {
  const RunIndicatorButton({super.key, this.idle});

  final Widget? idle;

  @override
  Widget build(BuildContext context) => _IndicatorBuilder(
    orElse: idle,
    builder: (context, v) {
      if (v.idle) return idle ?? const SizedBox.shrink();
      return Tooltip(
        message: v.sentence,
        child: Semantics(
          liveRegion: true,
          button: true,
          label: 'Automations, ${v.sentence}',
          excludeSemantics: true,
          child: PressableScale(
            onPressed: () => GoRouter.maybeOf(context)?.go(v.path),
            borderRadius: Radii.fullAll,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: _Bolt(view: v, badge: _RailBadge.solidCount),
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// The Runs tab link for the current state (T16's sidebar row and rail
/// button navigate here).
String runIndicatorPathOf(BuildContext context) {
  final cubit = maybeRead<AutomationRunsCubit>(context);
  return cubit == null
      ? AutomationPaths.runs()
      : _viewOf(cubit, cubit.state).path;
}

enum _RailBadge { containerCount, solidCount }

class _Bolt extends StatelessWidget {
  const _Bolt({required this.view, required this.badge, this.color});

  final IndicatorView view;
  final _RailBadge badge;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final semantic = theme.extension<MorkvaSemanticColors>()!;
    final ink = color ?? scheme.onSurfaceVariant;
    final v = view;
    final running = v.primary == IndicatorState.running;
    final dot = switch (v.primary) {
      IndicatorState.attention when v.failed > 0 => scheme.error,
      IndicatorState.attention ||
      IndicatorState.engineUnavailable => semantic.warning,
      IndicatorState.reviewsExpired => scheme.onSurfaceVariant,
      _ => null,
    };
    return SizedBox(
      width: 32,
      height: 32,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          if (running)
            SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(
                key: const ValueKey('indicator-ring'),
                strokeWidth: 2,
                color: semantic.info,
              ),
            ),
          Icon(Icons.bolt_rounded, size: running ? 18 : 24, color: ink),
          if (v.needsReview > 0)
            Positioned(
              right: -6,
              top: -4,
              child: badge == _RailBadge.containerCount && !running
                  ? _CountBadge(count: v.needsReview, container: true)
                  : _CountBadge(count: v.needsReview),
            )
          else if (dot != null)
            Positioned(right: 0, top: 0, child: _Dot(color: dot)),
        ],
      ),
    );
  }
}

/// An amber count: solid `warning` for a bare number, the container pair
/// for the rail badge.
class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count, this.container = false});

  final int count;
  final bool container;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<MorkvaSemanticColors>()!;
    return Container(
      key: const ValueKey('review-badge'),
      constraints: const BoxConstraints(minWidth: 18),
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: container ? semantic.warningContainer : semantic.warning,
        borderRadius: Radii.fullAll,
      ),
      child: Text(
        '$count',
        style: theme.textTheme.labelSmall?.copyWith(
          color: container ? semantic.onWarningContainer : semantic.onWarning,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('indicator-dot'),
    width: 8,
    height: 8,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}
