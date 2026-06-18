import 'package:flutter/material.dart';

import '../../../../design/design.dart';

/// A compact row of color swatches for tagging a select option.
///
/// Values are `#RRGGBB` hex strings (matching `SelectOption.color`). The palette
/// is drawn from the Warm-Carrot tokens so option chips stay on-brand. A "none"
/// swatch clears the color (emits `null`).
class ColorSwatchPicker extends StatelessWidget {
  const ColorSwatchPicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  /// The currently selected `#RRGGBB` color, or null for none.
  final String? selected;

  /// Called with the new `#RRGGBB` color, or null when "none" is chosen.
  final ValueChanged<String?> onChanged;

  /// The pickable palette, as `#RRGGBB` strings drawn from [MorkvaPalette].
  static const List<String> palette = [
    '#E8821E', // carrot
    '#F59B3C', // carrot bright
    '#4C7A34', // leaf
    '#8FCB6B', // leaf bright
    '#3A7CA5', // info blue
    '#2E8B57', // success green
    '#D4A017', // warning amber
    '#C0392B', // error red
    '#6B5E52', // ink medium (neutral)
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      // The 44dp hit boxes already carry ~16dp of visual gap between the 28dp
      // discs, so no extra inter-swatch spacing is needed.
      spacing: 0,
      runSpacing: 0,
      children: [
        _NoneSwatch(selected: selected == null, onTap: () => onChanged(null)),
        for (final hex in palette)
          _ColorSwatch(
            hex: hex,
            selected: _sameHex(selected, hex),
            onTap: () => onChanged(hex),
          ),
      ],
    );
  }

  static bool _sameHex(String? a, String b) =>
      a != null && a.toUpperCase() == b.toUpperCase();
}

/// Parses a `#RRGGBB` string into a [Color]; falls back to grey on malformed
/// input so a bad stored value never crashes the picker.
Color colorFromHex(String hex) {
  final cleaned = hex.replaceAll('#', '').trim();
  final value = int.tryParse(cleaned, radix: 16);
  if (value == null || cleaned.length != 6) return const Color(0xFF9E9E9E);
  return Color(0xFF000000 | value);
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.hex,
    required this.selected,
    required this.onTap,
  });

  final String hex;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = colorFromHex(hex);
    // White reads on dark swatches, ink on pale ones, so the check never
    // disappears against a light palette entry.
    final checkColor = color.computeLuminance() > 0.5
        ? const Color(0xFF2B2018) // inkHigh
        : Colors.white;
    return Semantics(
      label: 'Color $hex',
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: Radii.fullAll,
        // A 44dp hit area around the 28dp disc keeps the touch target accessible
        // without enlarging the visual swatch.
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? Theme.of(context).colorScheme.onSurface
                      : Theme.of(context).colorScheme.outlineVariant,
                  width: selected ? 2.5 : 1,
                ),
              ),
              child: selected
                  ? Icon(Icons.check, size: 16, color: checkColor)
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _NoneSwatch extends StatelessWidget {
  const _NoneSwatch({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'No color',
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: Radii.fullAll,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? scheme.onSurface : scheme.outlineVariant,
                  width: selected ? 2.5 : 1,
                ),
              ),
              child: Icon(
                Icons.format_color_reset_outlined,
                size: 16,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
