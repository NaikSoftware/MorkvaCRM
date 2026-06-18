import 'package:flutter/material.dart';

import '../../../../design/design.dart';

/// Inert, read-only silhouettes used by `FieldEditor.buildPreviewAffordance` to
/// render the *shape* of a field's value in the card preview.
///
/// None of these accept input or carry data: they are pure placeholders so the
/// schema author sees the form a card will take (data entry is Epic 5). Keeping
/// them here lets every per-type editor share one consistent vocabulary while
/// the card preview stays free of any `switch (type)`.

/// A flat, inert input silhouette (text/number/date/reference/file fields).
class PreviewStubInput extends StatelessWidget {
  const PreviewStubInput({super.key, this.icon, this.hint, this.height = 36});

  /// Optional leading glyph (e.g. a calendar or attachment icon).
  final IconData? icon;

  /// Optional muted hint text shown inside the silhouette.
  final String? hint;

  /// The silhouette height; taller hints at a multiline field.
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
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}

/// An inert switch silhouette for boolean fields.
class PreviewStubSwitch extends StatelessWidget {
  const PreviewStubSwitch({super.key});

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

/// Inert tag chips for select fields, honoring each option's `#RRGGBB` hint.
class PreviewStubChips extends StatelessWidget {
  const PreviewStubChips({
    super.key,
    required this.labels,
    required this.colors,
  });

  /// The chip labels (already truncated to a sensible count by the caller).
  final List<String> labels;

  /// Per-chip `#RRGGBB` color hints, parallel to [labels]; entries may be null.
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
              color: _chipFill(scheme, i),
              borderRadius: Radii.smAll,
              border: Border.all(color: _chipBorder(scheme, i)),
            ),
            child: Text(
              labels[i],
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurface,
              ),
            ),
          ),
      ],
    );
  }

  Color _chipFill(ColorScheme scheme, int i) {
    final parsed = _hexAt(i);
    // A firmer fill so pale palette entries still read, while text stays
    // AA-contrast against the surface (the label uses onSurface).
    if (parsed != null) return parsed.withValues(alpha: 0.32);
    return scheme.surfaceContainerHighest;
  }

  Color _chipBorder(ColorScheme scheme, int i) {
    final parsed = _hexAt(i);
    // A matching-hue hairline gives the chip a defined edge even when the fill
    // is faint, so the color reads regardless of palette lightness.
    if (parsed != null) return parsed.withValues(alpha: 0.7);
    return scheme.outlineVariant;
  }

  Color? _hexAt(int i) => _parseHex(i < colors.length ? colors[i] : null);

  static Color? _parseHex(String? hex) {
    if (hex == null) return null;
    var value = hex.replaceFirst('#', '');
    if (value.length == 6) value = 'FF$value';
    final parsed = int.tryParse(value, radix: 16);
    return parsed == null ? null : Color(parsed);
  }
}
