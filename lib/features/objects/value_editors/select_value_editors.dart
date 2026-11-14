import 'package:flutter/material.dart';

import '../../../core/domain/domain.dart';
import '../../../design/design.dart';
import '../../../l10n/l10n.dart';
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
                ? Icon(MorkvaIcons.check, size: 18, color: scheme.primary)
                : null,
            child: OptionPill(label: o.label, color: optionColor(field, o.id)),
          ),
        if (field.options.isEmpty)
          MenuItemButton(child: Text(context.l10n.objectsNoOptions)),
        if (selected != null) ...[
          const Divider(height: 1),
          MenuItemButton(
            leadingIcon: const Icon(MorkvaIcons.close, size: 18),
            onPressed: () => ctx.onChanged(const SingleSelectFieldValue(null)),
            child: Text(context.l10n.commonClear),
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
              hintText: context.l10n.objectsChoose,
              error: ctx.error == null ? null : const SizedBox.shrink(),
              suffixIcon: Icon(
                MorkvaIcons.expandMore,
                color: scheme.onSurfaceVariant,
              ),
            ),
            child: option == null
                // An empty Text gives the hint a baseline, so it sits centered.
                ? Text('', style: Theme.of(context).textTheme.bodyLarge)
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
  Widget build(BuildContext context, ValueEditorContext ctx) =>
      _MultiSelectChips(ctx);
}

class _MultiSelectChips extends StatefulWidget {
  const _MultiSelectChips(this.ctx);

  final ValueEditorContext ctx;

  @override
  State<_MultiSelectChips> createState() => _MultiSelectChipsState();
}

class _MultiSelectChipsState extends State<_MultiSelectChips> {
  final _menu = MenuController();

  /// Opens under the Add button, pinned to the editor's top-left: chips added
  /// while picking push Add along, but the menu stays under the pointer.
  void _toggleMenu(BuildContext addContext) {
    if (_menu.isOpen) return _menu.close();
    final add = addContext.findRenderObject()! as RenderBox;
    _menu.open(
      position: add.localToGlobal(
        Offset(0, add.size.height),
        ancestor: context.findRenderObject(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctx = widget.ctx;
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

    return Stack(
      children: [
        Wrap(
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
                  deleteTooltip: context.l10n.objectsRemoveNamed(option.label),
                  onDeleted: ctx.enabled ? () => toggle(id) : null,
                ),
            // In the menu's tap group, so a second tap closes rather than
            // closing-then-reopening.
            TapRegion(
              groupId: _menu,
              child: Builder(
                builder: (addContext) => AddValueButton(
                  label: context.l10n.commonAdd,
                  onPressed: ctx.enabled ? () => _toggleMenu(addContext) : null,
                ),
              ),
            ),
          ],
        ),
        // A zero-size anchor at the editor's top-left (LTR math, so not
        // directional): the field around it still dismisses the menu on tap.
        Positioned(
          left: 0,
          top: 0,
          child: MenuAnchor(
            controller: _menu,
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
                MenuItemButton(child: Text(context.l10n.objectsNoOptions)),
            ],
            child: const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}
