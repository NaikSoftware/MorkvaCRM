import 'package:flutter/material.dart';

import '../../../core/domain/domain.dart';
import '../../../design/design.dart';
import '../../../l10n/l10n.dart';
import '../../views/widgets/view_labels.dart';
import '../widgets/reference_picker.dart';
import 'field_value_editor.dart';
import 'value_editor_parts.dart';

/// reference: linked objects as chips (✕ unlinks) plus "+ Link ⟨item⟩",
/// which opens the [ReferencePicker]. A single link shows only its chip;
/// tapping the chip changes it. Chips pulse as stubs while the target's
/// labels load.
class ReferenceValueEditor extends FieldValueEditor {
  const ReferenceValueEditor();

  @override
  String get typeId => kReferenceFieldType;

  @override
  Widget build(BuildContext context, ValueEditorContext ctx) {
    final field = ctx.field as ReferenceFieldDefinition;
    final ids = (ctx.value as ReferenceFieldValue).objectIds;
    final labels = ctx.references.labelsFor(field);
    final target = ctx.references.targetOf(field);
    final item = target == null ? 'item' : itemLabelOf(target);
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;

    Future<void> pick() async {
      final picked = await ReferencePicker.show(
        context,
        field: field,
        choices: ctx.references,
        selected: ids,
      );
      if (picked == null || !context.mounted) return;
      ctx.onChanged(ReferenceFieldValue(picked));
    }

    final canPick = ctx.enabled && labels != null;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Wrap(
          spacing: Spacing.xs,
          runSpacing: Spacing.xxs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final id in ids)
              if (labels == null)
                const SkeletonBox(width: 96, height: 32)
              else
                RemovableChip(
                  label: labels[id] ?? l10n.objectsUnknownItem(item),
                  leading: Icon(
                    MorkvaIcons.link,
                    size: 16,
                    color: scheme.onSurfaceVariant,
                  ),
                  deleteTooltip: l10n.objectsUnlinkNamed(
                    labels[id] ?? l10n.objectsUnknownItem(item),
                  ),
                  onDeleted: ctx.enabled
                      ? () => ctx.onChanged(
                          ReferenceFieldValue([
                            for (final i in ids)
                              if (i != id) i,
                          ]),
                        )
                      : null,
                  onPressed: canPick && !field.multiple ? pick : null,
                ),
            if (field.multiple || ids.isEmpty)
              AddValueButton(
                label: l10n.objectsLinkItem(item),
                onPressed: canPick ? pick : null,
              ),
          ],
        ),
      ),
    );
  }
}
