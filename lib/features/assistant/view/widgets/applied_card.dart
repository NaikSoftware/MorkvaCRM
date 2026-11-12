import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../../bloc/chat_item.dart';
import 'assistant_scope.dart';
import 'chip_button.dart';
import 'plan_card.dart' show CardNote, TypeTag;
import 'plan_card_scope.dart';

/// The collapsed result of an approved plan ("Set Status to Done · 12
/// orders", "You approved 12 of 14 · undo available for 9 min") with a
/// persistent Undo for the whole window, then "Undo expired". Schema changes
/// list their fields; failures offer "Retry failed".
class AppliedCard extends StatefulWidget {
  const AppliedCard({super.key, required this.item});

  final AppliedItem item;

  @override
  State<AppliedCard> createState() => _AppliedCardState();
}

class _AppliedCardState extends State<AppliedCard> {
  Timer? _tick;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _schedule();
  }

  @override
  void didUpdateWidget(AppliedCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget.item;
    // The bloc never clears a note: one from before a later successful
    // retry (a new receipt) no longer applies.
    if (item.undoNote != old.undoNote) {
      _noteStale = false;
    } else if (item.receipt != old.receipt) {
      _noteStale = true;
    }
    _schedule();
  }

  bool _noteStale = false;

  /// Why Undo / Retry failed did not run while the card still offers them
  /// ("Needs a connection to undo").
  String? get _pendingNote => switch (item.undoState) {
    UndoState.available when !_noteStale => item.undoNote,
    _ => null,
  };

  /// Repaints every 15 s while the undo window is open, so the minutes and
  /// the expiry show without the bloc's help.
  void _schedule() {
    _tick?.cancel();
    if (_undoOpen) {
      _tick = Timer.periodic(const Duration(seconds: 15), (_) {
        if (!mounted) return;
        setState(() {});
        if (!_undoOpen) _tick?.cancel();
      });
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  AppliedItem get item => widget.item;

  Duration get _left {
    final until = item.undoUntil;
    if (until == null) return Duration.zero;
    return until.difference(PlanCardScope.of(context).now());
  }

  bool get _undoOpen =>
      item.receipt.journalId != null &&
      (item.undoState == UndoState.available ||
          item.undoState == UndoState.undoing) &&
      _left > Duration.zero;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final semantic = theme.extension<MorkvaSemanticColors>()!;
    final colors = AssistantColors.of(context);
    final actions = PlanCardScope.of(context).actions;
    final receipt = item.receipt;
    final plan = item.plan;
    final schema =
        plan.rows.isNotEmpty &&
        plan.rows.every((r) => !r.kind.endsWith('Card'));
    final failed = receipt.failed.length;
    final stale = receipt.stale.length;
    final done = receipt.applied.length;
    final undone = item.undoState == UndoState.undone;

    final (status, statusColor) = _status(semantic, scheme);
    final notesLine = !schema && plan.notes.isNotEmpty
        ? plan.notes.join(' ')
        : null;

    // The undo line ticks down by the minute: keep it out of the live region
    // so the status is announced once, not on every tick.
    final undoLine = switch (item.undoState) {
      UndoState.undone || UndoState.failed => null,
      _ => _undoLine(),
    };
    final spoken = undoLine == null
        ? status
        : status.replaceFirst(' · $undoLine', '');

    final undo = _undoOpen
        ? TintedButton(
            label: 'Undo',
            loading: item.undoState == UndoState.undoing,
            onPressed: () => actions.undo(receipt.journalId!),
          )
        : null;
    // A partly failed apply is journaled too: offer the retry while undo is
    // open, since the plan (which retry needs) outlives it only briefly.
    final retry = failed > 0 && !undone
        ? TintedButton(
            label: 'Retry failed',
            onPressed: () => actions.retryFailed(receipt.planId),
          )
        : null;
    final Widget? action = undo != null && retry != null
        ? Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [undo, retry],
          )
        : undo ?? retry;

    return Semantics(
      container: true,
      label: schema ? 'Applied schema change' : 'Applied changes',
      // Read on focus, never announced.
      value: undoLine,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: colors.panel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(
                14,
                schema ? 10 : 12,
                action == null ? 14 : 8,
                schema ? 10 : (notesLine == null && !undone ? 12 : 8),
              ),
              child: Row(
                children: [
                  _Badge(
                    schema: schema,
                    failed: failed > 0 && done == 0,
                    undone: undone,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Semantics(
                          container: true,
                          liveRegion: true,
                          label: spoken,
                          child: ExcludeSemantics(
                            child: Text(
                              status,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: statusColor,
                                fontWeight: statusColor == null
                                    ? null
                                    : FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        if (stale > 0)
                          Text(
                            '$stale changed elsewhere since the preview — '
                            'left as they were',
                            style: theme.textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                  ?action,
                ],
              ),
            ),
            if (_pendingNote case final note?)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: CardNote(note),
              ),
            if (notesLine != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: Text(
                  notesLine,
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 13),
                ),
              ),
            if (schema)
              for (final row in plan.rows.take(6))
                DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: colors.divider)),
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 36),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              row.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (row.detail != null) ...[
                            const SizedBox(width: 10),
                            TypeTag(row.detail!),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  /// The status line and, for good news, its colour.
  (String, Color?) _status(MorkvaSemanticColors semantic, ColorScheme scheme) {
    final receipt = item.receipt;
    final plan = item.plan;
    final done = receipt.applied.length;
    final failed = receipt.failed.length;
    final queued = receipt.queued.length;
    switch (item.undoState) {
      case UndoState.undone:
        return (item.undoNote ?? 'Reverted — nothing is changed now', null);
      case UndoState.failed:
        return (item.undoNote ?? 'Couldn’t undo these changes', scheme.error);
      case UndoState.available:
      case UndoState.undoing:
      case UndoState.expired:
        break;
    }
    final parts = <String>[];
    if (failed > 0) {
      parts.add('Updated $done, $failed failed');
    } else if (receipt.declinedByUser.isNotEmpty) {
      parts.add('You approved $done of ${plan.itemCount}');
    } else {
      parts.add('Applied');
    }
    if (queued > 0) parts.add('$queued waiting for a connection');
    final undo = _undoLine();
    if (undo != null) parts.add(undo);
    final good = failed == 0 && receipt.declinedByUser.isEmpty;
    // Raw `success` is under 4.5:1 for 12 px text; deepen it toward ink.
    final success = Color.lerp(semantic.success, scheme.onSurface, 0.3)!;
    final schema =
        plan.rows.isNotEmpty &&
        plan.rows.every((r) => !r.kind.endsWith('Card'));
    if (good && schema && plan.notes.isNotEmpty) {
      return ('Applied · ${plan.notes.first}', success);
    }
    return (parts.join(' · '), good && parts.length == 1 ? success : null);
  }

  String? _undoLine() {
    if (item.receipt.journalId == null || item.undoUntil == null) return null;
    if (item.undoState == UndoState.expired || _left <= Duration.zero) {
      return 'Undo expired';
    }
    if (item.undoSessionOnly) return 'undo available until you close Morkva';
    final minutes = (_left.inSeconds / 60).ceil();
    return minutes <= 1
        ? 'undo available for a minute'
        : 'undo available for $minutes min';
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.schema,
    required this.failed,
    required this.undone,
  });

  final bool schema;
  final bool failed;

  /// Reverted: a neutral undo tile, no longer the green check.
  final bool undone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = AssistantColors.of(context);
    final semantic = theme.extension<MorkvaSemanticColors>()!;
    if (undone) {
      return Container(
        width: schema ? 28 : 26,
        height: schema ? 28 : 26,
        decoration: BoxDecoration(
          color: colors.neutralChip,
          shape: schema ? BoxShape.rectangle : BoxShape.circle,
          borderRadius: schema ? BorderRadius.circular(9) : null,
        ),
        child: Icon(
          Icons.undo_rounded,
          size: schema ? 16 : 14,
          color: scheme.onSurfaceVariant,
        ),
      );
    }
    if (schema) {
      return Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(
          Icons.account_tree_outlined,
          size: 16,
          color: colors.objectChipText,
        ),
      );
    }
    final tints = scheme.brightness == Brightness.dark
        ? CollectionTints.dark
        : CollectionTints.light;
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: failed ? scheme.errorContainer : tints[1].background,
        shape: BoxShape.circle,
      ),
      child: Icon(
        failed ? Icons.priority_high_rounded : Icons.check_rounded,
        size: 14,
        color: failed ? scheme.onErrorContainer : semantic.success,
      ),
    );
  }
}
