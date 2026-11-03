import 'package:flutter/material.dart';

import '../../../core/domain/domain.dart';
import '../../../design/design.dart';
import '../../views/widgets/option_pill.dart';
import '../../views/widgets/view_labels.dart';
import 'field_value_editor.dart';
import 'value_editor_parts.dart';

/// The tint a select option's chip uses, matching [OptionPill].
Color _tint(ColorScheme scheme, Color? color) => color == null
    ? scheme.surfaceContainerHigh
    : Color.alphaBlend(
        color.withValues(alpha: 0.16),
        scheme.surfaceContainerLowest,
      );

/// single_select: a field-like button showing the chosen option's pill (or
/// "Choose…") that opens a menu of option pills, plus "Clear" when set.
class SingleSelectValueEditor extends FieldValueEditor {
  const SingleSelectValueEditor();

  @override
  String get typeId => kSingleSelectFieldType;

  @override
  Widget build(BuildContext context, ValueEditorContext ctx) {
    final field = ctx.field as SingleSelectFieldDefinition;
    final selected = (ctx.value as SingleSelectFieldValue).optionId;
    final option = field.options.where((o) => o.id == selected).firstOrNull;
    final scheme = Theme.of(context).colorScheme;
    return MenuAnchor(
      menuChildren: [
        for (final o in field.options)
          MenuItemButton(
            onPressed: () => ctx.onChanged(SingleSelectFieldValue(o.id)),
            trailingIcon: o.id == selected
                ? Icon(Icons.check, size: 18, color: scheme.primary)
                : null,
            child: OptionPill(label: o.label, color: optionColor(field, o.id)),
          ),
        if (field.options.isEmpty)
          const MenuItemButton(child: Text('No options yet')),
        if (selected != null) ...[
          const Divider(height: 1),
          MenuItemButton(
            leadingIcon: const Icon(Icons.close, size: 18),
            onPressed: () => ctx.onChanged(const SingleSelectFieldValue(null)),
            child: const Text('Clear'),
          ),
        ],
      ],
      builder: (context, menu, _) => Semantics(
        button: true,
        label: ctx.field.name,
        child: InkWell(
          borderRadius: Radii.mdAll,
          onTap: ctx.enabled
              ? () => menu.isOpen ? menu.close() : menu.open()
              : null,
          child: InputDecorator(
            isEmpty: option == null,
            decoration: InputDecoration(
              enabled: ctx.enabled,
              hintText: 'Choose…',
              error: ctx.error == null ? null : const SizedBox.shrink(),
              suffixIcon: Icon(
                Icons.expand_more,
                color: scheme.onSurfaceVariant,
              ),
            ),
            child: option == null
                ? const SizedBox(height: 24)
                : Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: OptionPill(
                      label: option.label,
                      color: optionColor(field, option.id),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// multi_select: the chosen options as tinted chips (✕ removes) plus "+ Add",
/// a checklist menu that stays open while toggling.
class MultiSelectValueEditor extends FieldValueEditor {
  const MultiSelectValueEditor();

  @override
  String get typeId => kMultiSelectFieldType;

  @override
  Widget build(BuildContext context, ValueEditorContext ctx) {
    final field = ctx.field as MultiSelectFieldDefinition;
    final ids = (ctx.value as MultiSelectFieldValue).optionIds;
    final scheme = Theme.of(context).colorScheme;

    void toggle(String id) => ctx.onChanged(
      MultiSelectFieldValue(
        ids.contains(id)
            ? [
                for (final i in ids)
                  if (i != id) i,
              ]
            // Keep the schema's option order.
            : [
                for (final o in field.options)
                  if (ids.contains(o.id) || o.id == id) o.id,
              ],
      ),
    );

    return Wrap(
      spacing: Spacing.xs,
      runSpacing: Spacing.xxs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final id in ids)
          if (field.options.where((o) => o.id == id).firstOrNull
              case final option?)
            RemovableChip(
              label: option.label,
              color: _tint(scheme, optionColor(field, id)),
              shape: const StadiumBorder(),
              deleteTooltip: 'Remove ${option.label}',
              onDeleted: ctx.enabled ? () => toggle(id) : null,
            ),
        MenuAnchor(
          menuChildren: [
            for (final o in field.options)
              CheckboxMenuButton(
                value: ids.contains(o.id),
                closeOnActivate: false,
                onChanged: (_) => toggle(o.id),
                child: OptionPill(
                  label: o.label,
                  color: optionColor(field, o.id),
                ),
              ),
            if (field.options.isEmpty)
              const MenuItemButton(child: Text('No options yet')),
          ],
          builder: (context, menu, _) => AddValueButton(
            label: 'Add',
            onPressed: ctx.enabled
                ? () => menu.isOpen ? menu.close() : menu.open()
                : null,
          ),
        ),
      ],
    );
  }
}
