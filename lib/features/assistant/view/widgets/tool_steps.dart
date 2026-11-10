import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../../bloc/chat_item.dart';
import 'assistant_scope.dart';

/// What the assistant did, as a collapsed chip ("Looked at Orders · filtered
/// 148 → 5 · summed Total") that expands to one line per step. It stays open
/// while a step runs (the running step in bold, with a spinner) unless the
/// user toggled it.
class ToolSteps extends StatefulWidget {
  const ToolSteps({super.key, required this.item});

  final StepsItem item;

  @override
  State<ToolSteps> createState() => _ToolStepsState();
}

class _ToolStepsState extends State<ToolSteps> {
  bool? _expanded;

  bool get _isExpanded => _expanded ?? widget.item.running;

  void _toggle() => setState(() => _expanded = !_isExpanded);

  @override
  Widget build(BuildContext context) {
    final colors = AssistantColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final steps = widget.item.steps;
    if (steps.isEmpty) return const SizedBox.shrink();

    if (!_isExpanded) {
      final status = _overall(steps);
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: PressableScale(
          onPressed: _toggle,
          semanticLabel: 'Steps: ${widget.item.headline}. Show each step',
          borderRadius: BorderRadius.circular(14),
          // A 44 px hit area around the 28 px chip.
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Container(
              height: 28,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: colors.panel,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _StepGlyph(status),
                  const SizedBox(width: Spacing.xs),
                  Flexible(
                    child: Text(
                      widget.item.headline,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: Spacing.xs),
                  Icon(
                    Icons.expand_more_rounded,
                    size: 16,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Semantics(
      container: true,
      label: 'Steps',
      child: PressableScale(
        onPressed: widget.item.running ? null : _toggle,
        pressedScale: 1,
        semanticLabel: widget.item.running ? null : 'Hide steps',
        borderRadius: Radii.mdAll,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: colors.panel,
            borderRadius: Radii.mdAll,
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [for (final step in steps) _StepLine(step)],
          ),
        ),
      ),
    );
  }

  static StepStatus _overall(List<StepView> steps) {
    if (steps.any((s) => s.status == StepStatus.running)) {
      return StepStatus.running;
    }
    if (steps.any((s) => s.status == StepStatus.failed)) {
      return StepStatus.failed;
    }
    return StepStatus.done;
  }
}

class _StepLine extends StatelessWidget {
  const _StepLine(this.step);

  final StepView step;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final running = step.status == StepStatus.running;
    final failed = step.status == StepStatus.failed;
    final text = failed
        ? '${step.label.replaceAll('…', '')} — ${step.summary ?? 'failed'}'
        : step.text;
    return Semantics(
      liveRegion: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 24),
        child: Row(
          children: [
            _StepGlyph(step.status),
            const SizedBox(width: Spacing.xs),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text(
                  text,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: running ? scheme.onSurface : scheme.onSurfaceVariant,
                    fontWeight: running ? FontWeight.w600 : FontWeight.w400,
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

/// A done check, a running spinner or a failed mark, 14 px.
class _StepGlyph extends StatelessWidget {
  const _StepGlyph(this.status);

  final StepStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final semantic = theme.extension<MorkvaSemanticColors>();
    return SizedBox.square(
      dimension: 14,
      child: switch (status) {
        StepStatus.done => Icon(
          Icons.check_rounded,
          size: 14,
          color: semantic?.success ?? scheme.primary,
        ),
        StepStatus.failed => Icon(
          Icons.error_outline_rounded,
          size: 14,
          color: scheme.error,
        ),
        StepStatus.running =>
          MediaQuery.disableAnimationsOf(context)
              ? Icon(Icons.more_horiz_rounded, size: 14, color: scheme.primary)
              : Padding(
                  padding: const EdgeInsets.all(1),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: scheme.primary,
                  ),
                ),
      },
    );
  }
}
