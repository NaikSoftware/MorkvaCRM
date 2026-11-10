import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/agent/agent_event.dart' show RetryReason;
import '../../../../design/design.dart';
import '../../bloc/assistant_state.dart';
import 'assistant_scope.dart';

/// The warning strip under the panel header: a transient rate limit with a
/// live countdown and "Retry now", or today's limit with no retry.
class LimitBannerView extends StatefulWidget {
  const LimitBannerView({super.key, required this.banner});

  final LimitBanner banner;

  @override
  State<LimitBannerView> createState() => _LimitBannerViewState();
}

class _LimitBannerViewState extends State<LimitBannerView> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(LimitBannerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.banner != widget.banner) _schedule();
  }

  void _schedule() {
    _tick?.cancel();
    if (widget.banner is RetryBanner) {
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<MorkvaSemanticColors>()!;
    final scope = AssistantScope.of(context);
    final fg = semantic.onWarningContainer;
    final banner = widget.banner;

    final String text;
    final bool retry;
    switch (banner) {
      case RetryBanner(:final until, :final reason):
        final left = until.difference(scope.now());
        final seconds = left.isNegative
            ? 0
            : (left.inMilliseconds / 1000).ceil();
        text = switch (reason) {
          RetryReason.tpm => 'This conversation is large; waiting $seconds s.',
          _ =>
            seconds == 0
                ? 'Gemini is busy. Retrying now…'
                : 'Gemini is busy. Retrying in $seconds s.',
        };
        retry = seconds > 0;
      case DailyLimitBanner(:final resetsAt):
        text =
            'Today’s free AI limit is used up. It resets at '
            '${clockTime(resetsAt)}.';
        retry = false;
    }

    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: EdgeInsetsDirectional.fromSTEB(16, 0, retry ? 8 : 16, 0),
        decoration: BoxDecoration(
          color: semantic.warningContainer,
          border: Border(
            bottom: BorderSide(
              color: Color.alphaBlend(
                fg.withValues(alpha: 0.18),
                semantic.warningContainer,
              ),
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              banner is DailyLimitBanner
                  ? Icons.hourglass_bottom_rounded
                  : Icons.schedule_rounded,
              size: 18,
              color: fg,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  text,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 13,
                    color: fg,
                  ),
                ),
              ),
            ),
            if (retry)
              PressableScale(
                onPressed: scope.actions.retryNow,
                semanticLabel: 'Retry now',
                borderRadius: Radii.mdAll,
                child: SizedBox(
                  height: 44,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Align(
                      widthFactor: 1,
                      child: Text(
                        'Retry now',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontSize: 13,
                          color: fg,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// "09:00" in 24-hour local time, as the app prints times.
String clockTime(DateTime t) {
  final local = t.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.hour)}:${two(local.minute)}';
}
