import 'package:flutter/material.dart';

import '../../../design/design.dart';
import '../../../l10n/l10n.dart';
import '../../collections/field_editors/built_in_field_editors.dart';
import 'field_value_editor.dart';

final _fieldEditors = defaultFieldEditorRegistry();

/// The fallback for a field type with no registered value editor: a muted,
/// read-only "Can't edit ⟨type⟩ here" line.
class UnsupportedValueEditor extends FieldValueEditor {
  const UnsupportedValueEditor(this.typeId);

  @override
  final String typeId;

  @override
  bool get isReadOnly => true;

  @override
  Widget build(BuildContext context, ValueEditorContext ctx) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final type = _fieldEditors.forType(typeId)?.label(context.l10n) ?? typeId;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Row(
        children: [
          Icon(MorkvaIcons.block, size: 18, color: muted),
          const SizedBox(width: Spacing.xs),
          Expanded(
            child: Text(
              context.l10n.objectsCantEditType(type),
              style: theme.textTheme.bodyMedium?.copyWith(color: muted),
            ),
          ),
        ],
      ),
    );
  }
}
