import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/domain/domain.dart';
import '../../../design/design.dart';
import '../../../l10n/l10n.dart';
import '../../views/widgets/option_pill.dart';
import '../../views/widgets/view_labels.dart';
import '../object_editor.dart';
import '../object_editor_cubit.dart';

/// The items of another collection that link to the edited object, listed
/// inside its form: tick a yes/no field in place, tap an item to edit it,
/// add one already linked here.
///
/// A row reads its item's fields (see [SublistRow]) with a checkbox for the
/// first yes/no field; a ticked item reads as done.
class SublistSection extends StatelessWidget {
  const SublistSection({
    super.key,
    required this.sublist,
    required this.parent,
  });

  final Sublist sublist;

  /// The collection of the edited object.
  final Collection parent;

  Collection get _collection => sublist.collection;

  BooleanFieldDefinition? get _check =>
      _collection.fields.whereType<BooleanFieldDefinition>().firstOrNull;

  Future<void> _add(BuildContext context) async {
    final cubit = context.read<ObjectEditorCubit>();
    final result = await showObjectEditor(
      context,
      collection: _collection,
      prefill: cubit.prefillFor(sublist),
      prefillNote: context.l10n.objectsLinkedToThis(itemLabelOf(parent)),
      derive: (draft) => cubit.deriveChild(sublist, draft),
      notes: _notes(cubit),
    );
    if (result is ObjectEditorSaved) cubit.childAdded(sublist, result.id);
  }

  /// What each calculated field of an item computes, in one line.
  Map<String, String> _notes(ObjectEditorCubit cubit) => {
    for (final f in _collection.fields.whereType<CalculatedFieldDefinition>())
      f.id: calculationSummary(f, _collection, cubit.workspace),
  };

  Future<void> _open(BuildContext context, MorkvaObject item) async {
    final cubit = context.read<ObjectEditorCubit>();
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l10n = context.l10n;
    final result = await showObjectEditor(
      context,
      collection: _collection,
      object: item,
      derive: (draft) => cubit.deriveChild(sublist, draft),
      notes: _notes(cubit),
    );
    if (result is! ObjectEditorDeleted) return;
    if (!await cubit.deleteChild(sublist, item)) {
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            l10n.objectsCouldNotDeleteItem(itemLabelOf(_collection)),
          ),
        ),
      );
    }
  }

  Future<void> _toggle(
    BuildContext context,
    MorkvaObject item,
    BooleanFieldDefinition field,
    bool value,
  ) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l10n = context.l10n;
    final ok = await context.read<ObjectEditorCubit>().setChildValue(
      sublist,
      item,
      field.id,
      BooleanFieldValue(value),
    );
    if (!ok) {
      messenger?.showSnackBar(
        SnackBar(content: Text(l10n.objectsCouldNotUpdate(field.name))),
      );
    }
  }

  static bool _isOn(MorkvaObject item, BooleanFieldDefinition? f) =>
      f != null && item[f.id] == const BooleanFieldValue(true);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final items = sublist.items;
    final check = _check;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final l10n = context.l10n;
    final count = items == null || items.isEmpty
        ? null
        : check == null
        ? '${items.length}'
        : l10n.objectsCheckedOf(
            items.where((i) => _isOn(i, check)).length,
            items.length,
            check.name.toLowerCase(),
          );
    final item = itemLabelOf(_collection);
    return Semantics(
      container: true,
      label: _collection.name,
      child: Column(
        key: ValueKey('sublist-${sublist.key}'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: _collection.name,
                    style: theme.textTheme.titleMedium,
                    children: [
                      if (count != null)
                        TextSpan(text: '  · $count', style: muted),
                    ],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: Spacing.sm),
              SecondaryButton(
                icon: Icons.add,
                label: l10n.objectsAddItem(item),
                onPressed: () => _add(context),
              ),
            ],
          ),
          Text(l10n.objectsLinkingVia(sublist.via.name), style: muted),
          const SizedBox(height: Spacing.xs),
          if (items == null)
            const Padding(
              padding: EdgeInsets.all(Spacing.md),
              child: Center(child: LoadingIndicator()),
            )
          else if (items.isEmpty)
            Container(
              padding: const EdgeInsets.all(Spacing.md),
              decoration: BoxDecoration(
                borderRadius: Radii.lgAll,
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Text(
                l10n.objectsNoItemsYet(_collection.name.toLowerCase()),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(Spacing.xxs),
              decoration: BoxDecoration(
                borderRadius: Radii.lgAll,
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (i, o) in items.indexed) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        indent: check == null ? Spacing.sm : 52,
                        endIndent: Spacing.xs,
                        color: scheme.outlineVariant.withValues(alpha: 0.6),
                      ),
                    _ItemRow(
                      key: ValueKey('sublist-item-${o.id}'),
                      row: SublistRow.of(
                        _collection,
                        o,
                        viaFieldId: sublist.via.id,
                      ),
                      check: check,
                      done: _isOn(o, check),
                      onTap: () => _open(context, o),
                      onToggle: check == null
                          ? null
                          : (v) => _toggle(context, o, check, v),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// What a sublist row shows for an item, read in its form's field order
/// (so rearranging the card layout rearranges the row):
/// - [title]: the first filled text, select or number-like value — a picked
///   option titles the row, nobody has to type it;
/// - [pills]: the other select values;
/// - [note]: the first other text, one line;
/// - [amount]: the first other number, with its field name.
/// Links, files and yes/no fields stay out (the checkbox shows yes/no), and
/// so does the link back to the open object with its lookups.
class SublistRow {
  SublistRow._(this.title, this.note, this.pills, this.amount);

  factory SublistRow.of(
    Collection collection,
    MorkvaObject item, {
    required String viaFieldId,
  }) {
    final layout = collection.layout.reconcile([
      for (final f in collection.fields) f.id,
    ]);
    final ordered = [
      for (final section in layout.sections)
        for (final row in section.rows)
          for (final cell in row.cells) ?collection.fieldById(cell.fieldId),
    ];
    String? title;
    String? note;
    (String, String)? amount;
    final pills = <SelectOption>[];
    for (final raw in ordered) {
      // The link back, and lookups through it, only repeat the open object.
      if (raw.id == viaFieldId ||
          (raw is CalculatedFieldDefinition &&
              raw.lookup?.referenceFieldId == viaFieldId)) {
        continue;
      }
      final (field, value) = presentedAs(raw, item[raw.id] ?? raw.emptyValue());
      if (value.isEmpty) continue;
      if (field is ReferenceFieldDefinition ||
          field is FileFieldDefinition ||
          field is BooleanFieldDefinition) {
        continue;
      }
      final text = formatFieldValue(field, value).trim();
      if (text.isEmpty) continue;
      final options = switch (field) {
        SingleSelectFieldDefinition(:final options) ||
        MultiSelectFieldDefinition(:final options) => options,
        _ => null,
      };
      if (title == null) {
        title = text;
      } else if (options != null) {
        final ids = switch (value) {
          SingleSelectFieldValue(:final optionId?) => [optionId],
          MultiSelectFieldValue(:final optionIds) => optionIds,
          _ => const <String>[],
        };
        for (final id in ids) {
          if (options.where((o) => o.id == id).firstOrNull case final o?) {
            pills.add(o);
          }
        }
      } else if ((field is NumberFieldDefinition ||
              field is AutoNumberFieldDefinition) &&
          amount == null) {
        amount = (raw.name, text);
      } else if (field is TextFieldDefinition && note == null) {
        note = text;
      }
    }
    return SublistRow._(
      title ?? CoreWords.current.untitled,
      note,
      pills,
      amount,
    );
  }

  final String title;
  final String? note;
  final List<SelectOption> pills;

  /// The field name and the formatted number.
  final (String, String)? amount;
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    super.key,
    required this.row,
    required this.check,
    required this.done,
    required this.onTap,
    required this.onToggle,
  });

  final SublistRow row;
  final BooleanFieldDefinition? check;
  final bool done;
  final VoidCallback onTap;
  final ValueChanged<bool>? onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final title = row.title;
    final pills = row.pills;
    final amount = row.amount;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: Radii.mdAll,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              onToggle == null ? Spacing.sm : 0,
              Spacing.xxs,
              Spacing.xs,
              Spacing.xxs,
            ),
            child: Row(
              children: [
                if (onToggle != null)
                  Checkbox(
                    value: done,
                    semanticLabel: check!.name,
                    onChanged: (v) => onToggle!(v ?? false),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: done ? scheme.onSurfaceVariant : null,
                          decoration: done ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      if (row.note case final note?)
                        Text(
                          note,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      if (pills.isNotEmpty) ...[
                        const SizedBox(height: Spacing.xxs),
                        Wrap(
                          spacing: Spacing.xxs,
                          runSpacing: Spacing.xxs,
                          children: [
                            for (final o in pills)
                              OptionPill(
                                label: o.label,
                                color: o.color == null
                                    ? null
                                    : colorFromHex(o.color!),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (amount != null) ...[
                  const SizedBox(width: Spacing.sm),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        amount.$1,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        amount.$2,
                        style: MorkvaTypography.tabular(
                          theme.textTheme.titleSmall ?? const TextStyle(),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(width: Spacing.xxs),
                Icon(Icons.chevron_right, color: scheme.outline),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
