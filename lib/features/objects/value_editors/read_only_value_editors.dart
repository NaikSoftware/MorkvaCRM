import 'package:flutter/material.dart';

import '../../../core/domain/domain.dart';
import '../../../design/design.dart';
import 'field_value_editor.dart';

/// auto_number: shown, never edited; the number is assigned on save (Epic 6).
class AutoNumberValueEditor extends FieldValueEditor {
  const AutoNumberValueEditor();

  @override
  String get typeId => kAutoNumberFieldType;

  @override
  bool get isReadOnly => true;

  @override
  Widget build(BuildContext context, ValueEditorContext ctx) => ReadOnlyValue(
    icon: Icons.lock_outline,
    text: formatFieldValue(ctx.field, ctx.value),
    placeholder: 'Assigned on save',
    helper: 'Set automatically',
  );
}

/// calculated: shows the cached result; computing it is Epic 6.
class CalculatedValueEditor extends FieldValueEditor {
  const CalculatedValueEditor();

  @override
  String get typeId => kCalculatedFieldType;

  @override
  bool get isReadOnly => true;

  @override
  Widget build(BuildContext context, ValueEditorContext ctx) => ReadOnlyValue(
    icon: Icons.functions,
    text: formatFieldValue(ctx.field, ctx.value),
    placeholder: 'Not calculated yet',
    helper: 'Calculated',
  );
}

/// A value on a quiet well with a glyph, plus a helper line saying why it
/// cannot be edited.
class ReadOnlyValue extends StatelessWidget {
  const ReadOnlyValue({
    super.key,
    required this.icon,
    required this.text,
    required this.placeholder,
    required this.helper,
  });

  final IconData icon;
  final String text;
  final String placeholder;
  final String helper;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final empty = text.isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
          decoration: BoxDecoration(
            color: scheme.surfaceContainer,
            borderRadius: Radii.mdAll,
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: scheme.onSurfaceVariant),
              const SizedBox(width: Spacing.xs),
              Expanded(
                child: Text(
                  empty ? placeholder : text,
                  style: empty
                      ? theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        )
                      : MorkvaTypography.tabular(
                          (theme.textTheme.bodyLarge ?? const TextStyle())
                              .copyWith(fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Spacing.xxs),
        Text(
          helper,
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
