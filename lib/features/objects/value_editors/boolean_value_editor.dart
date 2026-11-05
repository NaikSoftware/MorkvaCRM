import 'package:flutter/material.dart';

import '../../../core/domain/domain.dart';
import '../../../design/design.dart';
import 'field_value_editor.dart';

/// boolean: a switch row with the field name on the left, so the form skips
/// its own label ([rendersOwnLabel]). An unset value shows as off.
class BooleanValueEditor extends FieldValueEditor {
  const BooleanValueEditor();

  @override
  String get typeId => kBooleanFieldType;

  @override
  bool get rendersOwnLabel => true;

  @override
  Widget build(BuildContext context, ValueEditorContext ctx) {
    final theme = Theme.of(context);
    final on = (ctx.value as BooleanFieldValue).value ?? false;
    final field = ctx.field;
    return MergeSemantics(
      child: InkWell(
        borderRadius: Radii.mdAll,
        onTap: ctx.enabled ? () => ctx.onChanged(BooleanFieldValue(!on)) : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.xxs),
            child: Row(
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      text: field.name,
                      children: [
                        if (field.isRequired)
                          TextSpan(
                            text: ' *',
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                      ],
                    ),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                Switch(
                  value: on,
                  onChanged: ctx.enabled
                      ? (v) => ctx.onChanged(BooleanFieldValue(v))
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
