import 'package:flutter/material.dart';

import '../../../core/domain/domain.dart';
import '../../../design/design.dart';
import '../field_editors/field_editor.dart';

/// A compact, read-only preview of an empty card for the current draft schema.
///
/// This is the editor's "what am I building" mirror: each field renders as a
/// label plus a type-appropriate, inert affordance placeholder (a stubbed
/// input, a switch shape, a chip row), so the author sees the *shape* of a card
/// without entering any data — data entry is Epic 5. Nothing here is
/// interactive; every control is a static silhouette.
///
/// Secondary by design: it lives in a quiet collapsible card so it informs
/// without competing with the field editor.
class CardPreview extends StatelessWidget {
  const CardPreview({
    super.key,
    required this.collection,
    required this.registry,
  });

  final Collection collection;
  final FieldEditorRegistry registry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fields = collection.fields;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: Radii.lgAll,
        border: Border.all(color: scheme.outlineVariant),
      ),
      padding: const EdgeInsets.all(Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.preview_outlined,
                size: 16,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: Spacing.xs),
              Text(
                'Card preview',
                style: theme.textTheme.labelMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: Spacing.md),
          Text(
            collection.name.trim().isEmpty
                ? 'Untitled collection'
                : collection.name,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: Spacing.md),
          if (fields.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
              child: Text(
                'Add fields to see the card take shape.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            )
          else
            for (final field in fields) ...[
              _PreviewField(field: field, registry: registry),
              if (field != fields.last)
                const SizedBox(height: Spacing.md),
            ],
        ],
      ),
    );
  }
}

/// One field in the preview: its label (with a required marker) over a
/// type-appropriate inert affordance.
class _PreviewField extends StatelessWidget {
  const _PreviewField({required this.field, required this.registry});

  final FieldDefinition field;
  final FieldEditorRegistry registry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final editor = registry.forType(field.type);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              editor?.icon ?? Icons.help_outline,
              size: 14,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(width: Spacing.xxs),
            Flexible(
              child: Text(
                field.name.trim().isEmpty ? 'Untitled field' : field.name,
                style: theme.textTheme.labelMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (field.isRequired)
              Text(
                ' *',
                style: theme.textTheme.labelMedium
                    ?.copyWith(color: scheme.error),
              ),
          ],
        ),
        const SizedBox(height: Spacing.xs),
        _affordance(context, field),
      ],
    );
  }

  Widget _affordance(BuildContext context, FieldDefinition field) {
    switch (field.type) {
      case kBooleanFieldType:
        return _StubSwitch();
      case kSingleSelectFieldType:
        final options = (field as SingleSelectFieldDefinition).options;
        return _StubChips(
          labels: options.isEmpty
              ? const ['—']
              : options.take(4).map((o) => o.label).toList(),
          colors: options.isEmpty
              ? const [null]
              : options.take(4).map((o) => o.color).toList(),
        );
      case kMultiSelectFieldType:
        final options = (field as MultiSelectFieldDefinition).options;
        return _StubChips(
          labels: options.isEmpty
              ? const ['—']
              : options.take(4).map((o) => o.label).toList(),
          colors: options.isEmpty
              ? const [null]
              : options.take(4).map((o) => o.color).toList(),
        );
      case kDateFieldType:
        return _StubInput(
          icon: Icons.calendar_today_outlined,
          height: 36,
        );
      case kReferenceFieldType:
        return _StubInput(icon: Icons.link, height: 36);
      case kFileFieldType:
        return _StubInput(
          icon: Icons.attach_file,
          height: 36,
          hint: 'No file',
        );
      case kTextFieldType:
        final multiline = (field as TextFieldDefinition).multiline;
        return _StubInput(height: multiline ? 56 : 36);
      case kNumberFieldType:
      case kAutoNumberFieldType:
      case kCalculatedFieldType:
        return _StubInput(height: 36);
      default:
        return _StubInput(height: 36);
    }
  }
}

/// A flat, inert input silhouette.
class _StubInput extends StatelessWidget {
  const _StubInput({this.icon, this.hint, this.height = 36});

  final IconData? icon;
  final String? hint;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: height,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: Radii.smAll,
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: scheme.onSurfaceVariant),
            const SizedBox(width: Spacing.xs),
          ],
          if (hint != null)
            Text(
              hint!,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}

/// An inert switch silhouette for boolean fields.
class _StubSwitch extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 40,
      height: 22,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: Radii.fullAll,
      ),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.all(3),
      child: Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: scheme.outline,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// Inert tag chips for select fields, honoring the option color hint.
class _StubChips extends StatelessWidget {
  const _StubChips({required this.labels, required this.colors});

  final List<String> labels;
  final List<String?> colors;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Wrap(
      spacing: Spacing.xs,
      runSpacing: Spacing.xs,
      children: [
        for (var i = 0; i < labels.length; i++)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.xs,
              vertical: 3,
            ),
            decoration: BoxDecoration(
              color: _chipColor(scheme, i),
              borderRadius: Radii.smAll,
            ),
            child: Text(
              labels[i],
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: scheme.onSurface),
            ),
          ),
      ],
    );
  }

  Color _chipColor(ColorScheme scheme, int i) {
    final hex = i < colors.length ? colors[i] : null;
    final parsed = _parseHex(hex);
    if (parsed != null) return parsed.withValues(alpha: 0.22);
    return scheme.surfaceContainerHighest;
  }

  static Color? _parseHex(String? hex) {
    if (hex == null) return null;
    var value = hex.replaceFirst('#', '');
    if (value.length == 6) value = 'FF$value';
    final parsed = int.tryParse(value, radix: 16);
    return parsed == null ? null : Color(parsed);
  }
}
