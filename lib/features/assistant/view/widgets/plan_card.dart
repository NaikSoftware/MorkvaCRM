import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../../../../l10n/l10n.dart';
import '../../bloc/assistant_state.dart';
import '../../bloc/chat_item.dart';
import 'assistant_scope.dart';
import 'object_chip.dart';
import 'plan_card_scope.dart';

/// How long an applied plan can be undone (D9: the journal keeps inverse
/// operations for 10 minutes).
const kUndoWindowMinutes = 10;

/// A change preview awaiting approval. Every string on it is written by the
/// harness, never the model.
///
/// - 2 px `primary` border; `error` and a trash tile when destructive.
/// - A uniform old → new value shows once in the header; rows list items.
/// - Tri-state select-all (one per kind in a mixed plan), at most 5 rows
///   (3 when destructive) then "Show N more" (a lazy list past 20).
/// - "Approve N changes" follows the selection and is disabled at 0; a
///   collection delete also asks for the collection's name.
///
/// - A module install ([PlanView.grantsPermissions]) or an automation enrolled
///   into auto-apply ([PlanView.autoApplies]) gets the shield header; the
///   latter also adds "Applies changes without asking".
///
/// Settled cards collapse to one line ("Rejected — nothing changed"); an
/// applied plan renders nothing, its [AppliedItem] follows it. Actions go
/// through [PlanCardScope].
class PlanCard extends StatefulWidget {
  const PlanCard({
    super.key,
    required this.item,
    this.progress,
    this.provenance,
  });

  final PlanItem item;

  /// The apply progress while [PlanStatus.committing].
  final ApplyingPhase? progress;

  /// The module that proposed the plan, when the host shows one (the review
  /// sheet): always rendered "Module · name (id)", so module-supplied text
  /// never stands alone.
  final ({String id, String name})? provenance;

  @override
  State<PlanCard> createState() => _PlanCardState();
}

class _PlanCardState extends State<PlanCard> {
  final Set<String> _expandedKinds = {};

  PlanItem get item => widget.item;
  PlanView get plan => item.plan;

  @override
  Widget build(BuildContext context) {
    return switch (item.status) {
      PlanStatus.pending || PlanStatus.committing => _open(context),
      PlanStatus.applied => const SizedBox.shrink(),
      _ => _ClosedPlanCard(item: item),
    };
  }

  Widget _open(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = AssistantColors.of(context);
    final destructive = plan.destructive;
    final accent = destructive ? scheme.error : scheme.primary;
    final groups = plan.groups;
    final committing = item.status == PlanStatus.committing;

    return Semantics(
      container: true,
      label: destructive
          ? context.l10n.assistantProposedDeletion
          : context.l10n.assistantProposedChanges,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: colors.panel,
          borderRadius: Radii.lgAll,
          boxShadow: destructive || scheme.brightness == Brightness.dark
              ? null
              : [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.14),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        // Over the content, so the footer fill never covers the border.
        foregroundDecoration: BoxDecoration(
          borderRadius: Radii.lgAll,
          border: Border.all(color: accent, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(plan: plan, provenance: widget.provenance),
            if (plan.sharedChange != null)
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(52, 0, 14, 10),
                child: DiffLine(change: plan.sharedChange!),
              ),
            if (plan.autoApplies)
              _WarningLine(
                message: context.l10n.assistantAppliesWithoutAsking,
                icon: Icons.bolt_rounded,
              ),
            for (final w in plan.warnings)
              // The shield header says it as its subtitle.
              if (!(_shield(plan) && w.code == kGrantsPermissionsWarning))
                _WarningLine(message: w.message),
            if (!destructive)
              for (final note in plan.notes)
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(52, 0, 14, 8),
                  child: Text(note, style: theme.textTheme.bodySmall),
                ),
            if (groups.length == 1)
              ..._group(
                context,
                groups.single,
                mixed: false,
                locked: committing,
              )
            else
              for (final g in groups)
                ..._group(context, g, mixed: true, locked: committing),
            if (!plan.isComplete)
              _divided(
                colors,
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(42, 12, 14, 12),
                  child: Text(
                    context.l10n.assistantMoreNotShown(
                      plan.itemCount - plan.rows.length,
                    ),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ),
            _Footer(
              item: item,
              progress: committing ? widget.progress : null,
              onApprove: () => _approve(context),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _group(
    BuildContext context,
    PlanGroup group, {
    required bool mixed,
    required bool locked,
  }) {
    final colors = AssistantColors.of(context);
    final rows = group.rows;
    final limit = plan.destructive ? 3 : 5;
    final expanded = _expandedKinds.contains(group.kind);
    final shown = expanded || rows.length <= limit
        ? rows
        : rows.take(limit).toList();
    final hidden = rows.length - shown.length;

    final ids = {for (final r in rows) r.itemId};
    final picked = ids.where(item.selected.contains).length;
    final bool? all = picked == ids.length
        ? true
        : picked == 0
        ? false
        : null;
    final header = mixed || rows.length > 1 || plan.itemCount > 1;

    Widget rowView(PlanRow r) => _divided(
      colors,
      _PlanRowTile(
        row: r,
        selected: item.selected.contains(r.itemId),
        destructive: plan.destructive,
        showDiffs: plan.sharedChange == null,
        onChanged: locked ? null : (v) => _select({r.itemId}, v),
      ),
    );

    return [
      if (header)
        _divided(
          colors,
          _SelectAllTile(
            value: all,
            destructive: plan.destructive,
            label: mixed
                ? '${kindLabel(group.kind, context.l10n)} · ${rows.length}'
                : _selectionLabel(context.l10n, picked, rows.length),
            emphasis: mixed && group.risk != PlanRisk.low,
            onChanged: locked ? null : (_) => _select(ids, all != true),
          ),
        ),
      if (expanded && rows.length > 20)
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 320),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: rows.length,
            itemBuilder: (context, i) => rowView(rows[i]),
          ),
        )
      else
        for (final r in shown) rowView(r),
      if (hidden > 0)
        _divided(
          colors,
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(start: 30),
              child: TextActionButton(
                label: context.l10n.assistantShowMore(hidden),
                onPressed: () => setState(() => _expandedKinds.add(group.kind)),
              ),
            ),
          ),
        ),
    ];
  }

  String _selectionLabel(AppLocalizations l10n, int picked, int total) {
    if (picked == total) return l10n.assistantAllSelected(total);
    if (picked == 0) return l10n.assistantNoneSelected;
    return l10n.assistantSomeSelected(picked, total);
  }

  void _select(Set<String> ids, bool? on) {
    final next = {...item.selected};
    if (on ?? false) {
      next.addAll(ids);
    } else {
      next.removeAll(ids);
    }
    PlanCardScope.of(context).actions.changePlanSelection(plan.planId, next);
  }

  Future<void> _approve(BuildContext context) async {
    final actions = PlanCardScope.of(context).actions;
    final collection = plan.rows
        .where((r) => r.kind == 'deleteCollection')
        .firstOrNull;
    if (collection != null) {
      final l10n = context.l10n;
      final ok = await MorkvaConfirmDialog.show(
        context,
        title: l10n.assistantDeleteCollectionTitle(collection.label),
        message: l10n.assistantDeleteCollectionBody(
          collection.label,
          _undoSentence(l10n, plan, destructive: true),
        ),
        confirmLabel: l10n.assistantDeleteCollection,
        destructive: true,
        confirmText: collection.label,
      );
      if (ok != true) return;
    }
    actions.approvePlan(plan.planId);
  }
}

/// The confirm of a whole destructive plan: "Delete collection" for a
/// collection, else the title up to its first " · " or quoted name ("Delete
/// 7 orders", "Delete 2 cards", "Delete field").
/// The title part is the harness's English: other languages say "Delete".
String _deleteLabel(AppLocalizations l10n, PlanView plan) {
  if (plan.rows.any((r) => r.kind == 'deleteCollection')) {
    return l10n.assistantDeleteCollection;
  }
  if (l10n.localeName != 'en') return l10n.commonDelete;
  final title = plan.title.split(' · ').first;
  final quote = title.indexOf(' “');
  if (quote < 0) return title;
  final head = title.substring(0, quote);
  // "Delete 2 cards from “X”" keeps its count; "Delete field “X” from Y"
  // its noun.
  return head.endsWith(' from') || head.endsWith(' in')
      ? head.substring(0, head.lastIndexOf(' '))
      : head;
}

/// The warning code of a module install (its text is the shield subtitle).
const kGrantsPermissionsWarning = 'grants_permissions';

/// The shield header: a module install or an auto-apply enrolment that
/// deletes nothing.
bool _shield(PlanView plan) =>
    (plan.grantsPermissions || plan.autoApplies) && !plan.destructive;

/// "Update card", "Add field" — a plan item kind for a mixed plan's group;
/// [l10n] words the known kinds, others are split from the name.
String kindLabel(String kind, [AppLocalizations? l10n]) {
  final words = kind
      .replaceAllMapped(RegExp('([A-Z])'), (m) => ' ${m[1]!.toLowerCase()}')
      .trim();
  final split = words.isEmpty
      ? kind
      : words[0].toUpperCase() + words.substring(1);
  return l10n?.assistantPlanKind(kind, split) ?? split;
}

String _undoSentence(
  AppLocalizations l10n,
  PlanView plan, {
  required bool destructive,
}) => switch (plan.undo) {
  'none' => l10n.assistantUndoNone,
  'partial' =>
    destructive
        ? l10n.assistantUndoPartialFor(kUndoWindowMinutes)
        : l10n.assistantUndoPartialLater,
  _ =>
    destructive
        ? l10n.assistantUndoFor(kUndoWindowMinutes)
        : l10n.assistantUndoLater,
};

Widget _divided(AssistantColors colors, Widget child) => DecoratedBox(
  decoration: BoxDecoration(
    border: Border(top: BorderSide(color: colors.divider)),
  ),
  child: child,
);

class _Header extends StatelessWidget {
  const _Header({required this.plan, this.provenance});

  final PlanView plan;
  final ({String id, String name})? provenance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = AssistantColors.of(context);
    final destructive = plan.destructive;
    final shield = _shield(plan);
    final grantsWarning = plan.warnings
        .where((w) => w.code == kGrantsPermissionsWarning)
        .firstOrNull;
    final subtitle = destructive
        ? [
            ...plan.notes,
            _undoSentence(context.l10n, plan, destructive: true),
          ].join(' ')
        : shield && grantsWarning != null
        ? grantsWarning.message
        : context.l10n.assistantNothingChangesUntilApproved(
            _undoSentence(context.l10n, plan, destructive: false),
          );
    final source = provenance;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      child: Row(
        crossAxisAlignment: destructive
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: destructive
                  ? scheme.errorContainer
                  : scheme.primaryContainer,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              destructive
                  ? Icons.delete_outline_rounded
                  : shield
                  ? Icons.shield_outlined
                  : Icons.edit_outlined,
              size: 16,
              color: destructive
                  ? scheme.onErrorContainer
                  : colors.objectChipText,
            ),
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
                if (source != null)
                  Text(
                    context.l10n.assistantModuleSource(source.name, source.id),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      letterSpacing: 0,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: destructive ? scheme.error : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Status  [Packing] → [Shipped]": the old value struck through on a warm
/// sand tint, the new one on leaf.
class DiffLine extends StatelessWidget {
  const DiffLine({super.key, required this.change, this.markEmpty = false});

  final PlanChange change;

  /// A value set from empty reads "— → new" (the run log's Plan), not
  /// just the new pill.
  final bool markEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final before = change.beforeText;
    final after = change.afterText;
    return Wrap(
      spacing: Spacing.xs,
      runSpacing: Spacing.xxs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          change.field,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontSize: 13,
            color: scheme.onSurfaceVariant,
          ),
        ),
        if (before != null && before.isNotEmpty)
          DiffPill(before, before: true)
        else if (markEmpty && after != null && after.isNotEmpty)
          Text(
            '—',
            semanticsLabel: context.l10n.assistantDiffFromEmpty,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        if (after != null &&
            ((before != null && before.isNotEmpty) ||
                (markEmpty && after.isNotEmpty)))
          Icon(
            Icons.arrow_forward_rounded,
            size: 14,
            color: scheme.onSurfaceVariant,
          ),
        if (after != null)
          DiffPill(after.isEmpty ? context.l10n.assistantDiffEmpty : after),
      ],
    );
  }
}

/// A value pill of a diff: [before] values are struck through on the sand
/// tint (changed), new values sit on the leaf tint.
class DiffPill extends StatelessWidget {
  const DiffPill(this.text, {super.key, this.before = false});

  final String text;
  final bool before;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tints = theme.colorScheme.brightness == Brightness.dark
        ? CollectionTints.dark
        : CollectionTints.light;
    // 4 = sand (a change's old value), 1 = leaf (the new value).
    final tint = tints[before ? 4 : 1];
    return Container(
      height: 22,
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: tint.background,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Align(
        widthFactor: 1,
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          semanticsLabel: before
              ? context.l10n.assistantDiffFrom(text)
              : context.l10n.assistantDiffTo(text),
          style: theme.textTheme.labelMedium?.copyWith(
            color: tint.foreground,
            letterSpacing: 0,
            decoration: before ? TextDecoration.lineThrough : null,
            decorationColor: tint.foreground,
          ),
        ),
      ),
    );
  }
}

class _WarningLine extends StatelessWidget {
  const _WarningLine({
    required this.message,
    this.icon = Icons.warning_amber_rounded,
  });

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<MorkvaSemanticColors>()!;
    return Container(
      margin: const EdgeInsetsDirectional.fromSTEB(14, 0, 14, 10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: semantic.warningContainer,
        borderRadius: Radii.smAll,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: semantic.onWarningContainer),
          const SizedBox(width: Spacing.xs),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: semantic.onWarningContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A checkbox sized to the mockups' 18 px box, tinted per card.
class _PlanCheckbox extends StatelessWidget {
  const _PlanCheckbox({
    required this.value,
    required this.destructive,
    required this.onChanged,
    this.tristate = false,
  });

  final bool? value;
  final bool destructive;
  final bool tristate;
  final ValueChanged<bool?>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = AssistantColors.of(context);
    final fill = destructive ? scheme.error : colors.objectChipText;
    return SizedBox.square(
      dimension: 18,
      child: Checkbox(
        value: value,
        tristate: tristate,
        onChanged: onChanged,
        activeColor: fill,
        checkColor: colors.panel,
        side: BorderSide(color: scheme.outline, width: 1.5),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
        splashRadius: 0,
      ),
    );
  }
}

class _SelectAllTile extends StatelessWidget {
  const _SelectAllTile({
    required this.value,
    required this.destructive,
    required this.label,
    required this.onChanged,
    this.emphasis = false,
  });

  final bool? value;
  final bool destructive;
  final String label;
  final bool emphasis;
  final ValueChanged<bool?>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return MergeSemantics(
      child: _TapRow(
        onTap: onChanged == null ? null : () => onChanged!(value != true),
        child: Row(
          children: [
            _PlanCheckbox(
              value: value,
              tristate: true,
              destructive: destructive,
              onChanged: onChanged == null
                  ? null
                  : (_) => onChanged!(value != true),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  letterSpacing: 0,
                  color: emphasis && destructive
                      ? scheme.error
                      : scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A 44 px row that toggles on tap anywhere (the mockups' `<label>` rows).
class _TapRow extends StatelessWidget {
  const _TapRow({required this.onTap, required this.child});

  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: MouseRegion(
      cursor: onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: child,
        ),
      ),
    ),
  );
}

class _PlanRowTile extends StatelessWidget {
  const _PlanRowTile({
    required this.row,
    required this.selected,
    required this.destructive,
    required this.showDiffs,
    required this.onChanged,
  });

  final PlanRow row;
  final bool selected;
  final bool destructive;

  /// Per-row diffs; off when the header shows the one shared diff.
  final bool showDiffs;
  final ValueChanged<bool?>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isCard = row.kind.endsWith('Card');
    final cut = row.label.indexOf(' · ');
    final head = cut < 0 ? row.label : row.label.substring(0, cut);
    final rest = cut < 0 ? '' : row.label.substring(cut + 3);
    // The auto-number head ("#1042", "ORD-0002") of `cardLabel`.
    final chip = isCard && cut >= 0 && head.contains(RegExp(r'\d'));
    final textStyle = theme.textTheme.bodyMedium?.copyWith(fontSize: 13);
    final strong = textStyle?.copyWith(
      fontWeight: destructive ? FontWeight.w400 : FontWeight.w600,
    );
    // Every change Approve writes is shown: this is the consent surface.
    final diffs = row.changes;
    final detail = row.detail;
    final code = row.code;

    final main = Row(
      children: [
        _PlanCheckbox(
          value: selected,
          destructive: destructive,
          onChanged: onChanged,
        ),
        const SizedBox(width: 10),
        if (chip) ...[
          ObjectChip(
            label: head,
            onTap: row.targetId == null || row.collectionId == null
                ? null
                : () => PlanCardScope.of(context).actions.openObject(
                    collectionId: row.collectionId!,
                    cardId: row.targetId,
                  ),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Text(
            chip ? rest : row.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: isCard
                ? strong
                : textStyle?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        if (detail != null && detail.isNotEmpty) ...[
          const SizedBox(width: 10),
          if (isCard)
            Text(
              detail,
              style: textStyle?.copyWith(color: scheme.onSurfaceVariant),
            )
          else
            TypeTag(detail),
        ],
      ],
    );

    return Semantics(
      checked: selected,
      label: row.label,
      child: _TapRow(
        onTap: onChanged == null ? null : () => onChanged!(!selected),
        child: (diffs.isEmpty || !showDiffs) && code == null
            ? main
            : Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    main,
                    if (showDiffs)
                      for (final d in diffs)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(
                            start: 28,
                            bottom: 6,
                          ),
                          child: DiffLine(change: d),
                        ),
                    if (code != null)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(start: 18),
                        child: TextActionButton(
                          label: context.l10n.assistantViewCode,
                          icon: Icons.code_rounded,
                          onPressed: () =>
                              PlanCardScope.of(context).actions.viewCode(row),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}

/// A field-type tag ("Select · Kyiv, Lviv, Odesa").
class TypeTag extends StatelessWidget {
  const TypeTag(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AssistantColors.of(context);
    return Container(
      // Sits at a row's end: the name keeps the room, long types ellipsize.
      constraints: const BoxConstraints(maxWidth: 200),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: colors.neutralChip,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 0),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.item,
    required this.progress,
    required this.onApprove,
  });

  final PlanItem item;
  final ApplyingPhase? progress;
  final VoidCallback onApprove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = AssistantColors.of(context);
    final actions = PlanCardScope.of(context).actions;
    final plan = item.plan;
    final destructive = plan.destructive;
    final count = item.selected.length;
    final committing = item.status == PlanStatus.committing;
    // While applying the button is a bare spinner: say what it is doing.
    final l10n = context.l10n;
    final approveLabel = committing
        ? l10n.assistantApplyingChangesLabel
        : plan.itemCount == 1 && plan.rows.firstOrNull?.kind == 'saveModule'
        ? (plan.title.startsWith('Update')
              ? l10n.assistantUpdateModule
              : l10n.assistantInstallModule)
        : destructive && plan.title.startsWith('Delete')
        ? (count != plan.itemCount
              ? l10n.assistantDeleteSomeOf(count, plan.itemCount)
              : _deleteLabel(l10n, plan))
        : l10n.assistantApproveChanges(count);
    final rejectLabel = destructive
        ? (plan.itemCount == 1 ? l10n.assistantKeepIt : l10n.assistantKeepThem)
        : l10n.assistantReject;
    final p = progress;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: destructive ? colors.panel : colors.cardFooter,
        border: Border(top: BorderSide(color: colors.divider)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (committing) ...[
              Semantics(
                liveRegion: true,
                child: Text(
                  p == null || p.total == 0
                      ? l10n.assistantApplying
                      : l10n.assistantUpdatingProgress(p.done, p.total),
                  style: theme.textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  minHeight: 4,
                  value: p == null || p.total == 0 ? null : p.done / p.total,
                  color: destructive ? scheme.error : scheme.primary,
                  backgroundColor: colors.divider,
                ),
              ),
              const SizedBox(height: 6),
            ],
            // Approve was refused (offline): say so on the card.
            if (item.message case final message? when !committing) ...[
              CardNote(message),
              const SizedBox(height: 6),
            ],
            // One row; the confirm label ellipsizes rather than wrapping
            // under the safe choice.
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!committing) ...[
                  destructive
                      ? _PlainButton(
                          label: rejectLabel,
                          onPressed: () => actions.rejectPlan(plan.planId),
                        )
                      : TextActionButton(
                          label: rejectLabel,
                          onPressed: () => actions.rejectPlan(plan.planId),
                        ),
                  const SizedBox(width: Spacing.xs),
                ],
                Flexible(
                  child: destructive
                      ? _DangerButton(
                          label: approveLabel,
                          loading: committing,
                          onPressed: count == 0 ? null : onApprove,
                        )
                      : PrimaryButton(
                          label: approveLabel,
                          loading: committing,
                          onPressed: count == 0 ? null : onApprove,
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Why the last action on a card did not run ("Needs a connection"),
/// announced once.
class CardNote extends StatelessWidget {
  const CardNote(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return Semantics(
      container: true,
      liveRegion: true,
      label: message,
      child: ExcludeSemantics(
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded, size: 16, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Keep them": a text button in `onSurface`, so the safe choice next to a
/// red delete never reads as another warning.
class _PlainButton extends StatelessWidget {
  const _PlainButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PressableScale(
      onPressed: onPressed,
      semanticLabel: label,
      borderRadius: Radii.mdAll,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Align(
          widthFactor: 1,
          child: Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

/// The destructive confirm: `error` fill, `onError` label, 44 px.
class _DangerButton extends StatelessWidget {
  const _DangerButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return PressableScale(
      onPressed: loading ? null : onPressed,
      semanticLabel: label,
      borderRadius: Radii.mdAll,
      child: Opacity(
        opacity: onPressed == null && !loading ? 0.38 : 1,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: scheme.error,
            borderRadius: Radii.mdAll,
          ),
          child: Align(
            widthFactor: 1,
            child: loading
                ? SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: scheme.onError,
                    ),
                  )
                : Text(
                    label,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: scheme.onError,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _ClosedPlanCard extends StatelessWidget {
  const _ClosedPlanCard({required this.item});

  final PlanItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = AssistantColors.of(context);
    final actions = PlanCardScope.of(context).actions;
    final message = item.message;
    final l10n = context.l10n;
    final (icon, line) = switch (item.status) {
      PlanStatus.rejected => (
        Icons.block_rounded,
        l10n.assistantRejectedNothingChanged,
      ),
      PlanStatus.skipped => (
        Icons.redo_rounded,
        l10n.assistantSkippedNothingChanged,
      ),
      PlanStatus.stale => (
        Icons.sync_problem_rounded,
        l10n.assistantNothingChangedAfter(
          message ?? l10n.assistantChangedElsewhere,
        ),
      ),
      PlanStatus.expired => (
        Icons.timer_off_outlined,
        l10n.assistantPreviewExpired,
      ),
      PlanStatus.interrupted => (
        Icons.help_outline_rounded,
        l10n.assistantInterrupted,
      ),
      _ => (
        Icons.error_outline_rounded,
        l10n.assistantNothingChangedAfter(
          message ?? l10n.assistantCouldNotApply,
        ),
      ),
    };
    return Semantics(
      container: true,
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 8, 12),
        decoration: BoxDecoration(
          color: colors.panel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: colors.neutralChip,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 14, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.plan.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  Text(line, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            if (item.status == PlanStatus.expired)
              TextActionButton(
                label: l10n.assistantRebuild,
                onPressed: actions.retry,
              ),
          ],
        ),
      ),
    );
  }
}
