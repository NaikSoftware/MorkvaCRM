import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../design/design.dart';
import '../../bloc/assistant_state.dart';
import 'assistant_scope.dart';
import 'focus_chip.dart';
import 'limit_banner.dart' show clockTime;

/// The panel footer: an optional status hint, the focus chip, the message
/// field with Send (Stop while a turn runs) and the disclaimer.
///
/// Enter sends, Shift+Enter breaks the line. Sending while a plan waits
/// skips that plan (the bloc does it); while changes apply, Send waits.
class Composer extends StatefulWidget {
  const Composer({
    super.key,
    required this.state,
    this.focusNode,
    this.autofocus = false,
  });

  final AssistantState state;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  State<Composer> createState() => _ComposerState();
}

class _ComposerState extends State<Composer> {
  final _text = TextEditingController();
  FocusNode? _ownFocus;

  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _text.addListener(_onText);
    _focus.addListener(_onText);
  }

  @override
  void didUpdateWidget(Composer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownFocus)?.removeListener(_onText);
      _focus.addListener(_onText);
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onText);
    _text.dispose();
    _ownFocus?.dispose();
    super.dispose();
  }

  void _onText() => setState(() {});

  AssistantState get _state => widget.state;

  bool get _applying => _state.phase is ApplyingPhase;

  /// A turn runs: the button is Stop.
  bool get _running => _state.phase.active && !_applying;

  bool get _enabled => _state.availability.canSend;

  bool get _canSend =>
      _enabled && !_applying && !_running && _text.text.trim().isNotEmpty;

  void _send() {
    if (!_canSend) return;
    AssistantScope.of(context).actions.submit(_text.text.trim());
    _text.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = AssistantColors.of(context);
    final scope = AssistantScope.of(context);
    final phone = scope.phone;
    final focused = _focus.hasFocus && _enabled;
    final hint = _hint();
    final focusLabel = _state.focus?.label;
    final primaryText =
        theme.extension<MorkvaSemanticColors>()?.primaryText ?? scheme.primary;

    final field = CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.enter): _send},
      child: TextField(
        controller: _text,
        focusNode: _focus,
        autofocus: widget.autofocus,
        enabled: _enabled,
        minLines: 1,
        maxLines: 6,
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.newline,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontSize: scope.messageSize,
          fontWeight: FontWeight.w500,
          color: scheme.onSurface,
        ),
        decoration: InputDecoration(
          isCollapsed: true,
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: phone ? 10 : 12),
          hintText: _state.items.isEmpty
              ? 'Ask about your data, or tell me what to change…'
              : 'Ask a follow-up…',
          hintStyle: theme.textTheme.bodyMedium?.copyWith(
            fontSize: scope.messageSize,
            fontWeight: FontWeight.w500,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ),
    );

    final box = AnimatedContainer(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : MotionDurations.fast,
      constraints: const BoxConstraints(minHeight: 52),
      padding: EdgeInsetsDirectional.fromSTEB(
        14,
        phone ? 6 : 4,
        phone ? 6 : 4,
        phone ? 6 : 4,
      ),
      decoration: BoxDecoration(
        color: focused || phone ? colors.panel : colors.canvas,
        borderRadius: BorderRadius.circular(phone ? 18 : 16),
        border: focused
            ? Border.all(color: primaryText, width: 2)
            : Border.all(color: colors.inputBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Semantics(label: 'Message Morkva', child: field),
          ),
          const SizedBox(width: Spacing.xs),
          _running
              ? _SendButton.stop(
                  radius: phone ? 14 : 13,
                  onPressed: scope.actions.stop,
                )
              : _SendButton.send(
                  radius: phone ? 14 : 13,
                  onPressed: _canSend ? _send : null,
                ),
        ],
      ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.panel,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: Padding(
        padding: phone
            ? const EdgeInsets.fromLTRB(12, 10, 12, 18)
            : const EdgeInsets.fromLTRB(14, 10, 14, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hint != null) ...[
              Semantics(
                liveRegion: true,
                child: Text(hint, style: theme.textTheme.bodySmall),
              ),
              const SizedBox(height: 6),
            ],
            if (focusLabel != null) ...[
              FocusChip(
                label: focusLabel,
                iconKey: _state.focus?.collectionIcon,
                onRemove: scope.actions.clearFocus,
              ),
              const SizedBox(height: Spacing.xxs),
            ],
            box,
            if (!phone) ...[
              const SizedBox(height: Spacing.xs),
              Text(
                'Answers can be wrong — check important numbers.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String? _hint() {
    switch (_state.availability) {
      case AvailabilityOffline():
        return 'You’re offline — Ask Morkva needs a connection.';
      case AvailabilityQuotaExhausted(:final until):
        return 'Ask Morkva is paused until ${clockTime(until)}.';
      case AvailabilityUnavailable(:final message):
        return message;
      case AvailabilityChecking() ||
          AvailabilityEnabled() ||
          AvailabilityNeedsConsent() ||
          AvailabilityDisabledByFlag() ||
          AvailabilityNotSetUp():
        break;
    }
    if (_applying) return 'Applying changes…';
    if (_state.phase is AwaitingApprovalPhase) {
      final plan = _state.pendingPlan?.plan;
      if (plan != null && plan.destructive) {
        final noun = RegExp(r'^Delete \d+ (.+)$').firstMatch(plan.title)?[1];
        return 'Approve or keep the ${noun ?? 'items'} above — or send a new '
            'message to skip them.';
      }
      return 'Approve or reject the changes above — or send a new message to '
          'skip them.';
    }
    return null;
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton.send({required this.radius, required this.onPressed})
    : stop = false;

  const _SendButton.stop({required this.radius, required this.onPressed})
    : stop = true;

  final double radius;
  final bool stop;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onPressed != null;
    final Color bg;
    final Color fg;
    if (stop) {
      bg = scheme.onSurface;
      fg = scheme.surface;
    } else if (enabled) {
      bg = scheme.primary;
      fg = scheme.onPrimary;
    } else {
      bg = scheme.surfaceContainerHigh;
      fg = scheme.onSurfaceVariant;
    }
    final label = stop ? 'Stop generating' : 'Send';
    return Tooltip(
      message: label,
      child: PressableScale(
        onPressed: onPressed,
        semanticLabel: label,
        borderRadius: BorderRadius.circular(radius),
        child: AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : MotionDurations.fast,
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(radius),
          ),
          child: Icon(
            stop ? Icons.stop_rounded : Icons.arrow_upward_rounded,
            size: stop ? 20 : 18,
            color: fg,
          ),
        ),
      ),
    );
  }
}
