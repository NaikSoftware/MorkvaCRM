import 'package:flutter/material.dart';

import '../../../../design/design.dart';

/// Small shared building blocks for per-type config editors.
///
/// These keep each [FieldEditor.buildConfigEditor] terse and visually
/// consistent (labels, switches, banners) without imposing a layout. Final
/// visual polish is a later design pass; correctness and reuse come first.

/// A labelled on/off switch row (e.g. "Multiline", "Multiple").
class ConfigSwitch extends StatelessWidget {
  const ConfigSwitch({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: subtitle == null ? null : Text(subtitle!),
      value: value,
      onChanged: onChanged,
    );
  }
}

/// A labelled text input bound to a debounce-free [onChanged].
class ConfigTextField extends StatelessWidget {
  const ConfigTextField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.hint,
    this.keyboardType,
  });

  final String label;
  final String? hint;
  final String value;
  final TextInputType? keyboardType;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: TextFormField(
        initialValue: value,
        keyboardType: keyboardType,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

/// A "declared now, computed in a later update" note for computed field types.
class ComputedLaterBanner extends StatelessWidget {
  const ComputedLaterBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: Spacing.md),
      padding: const EdgeInsets.all(Spacing.sm),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: Radii.smAll,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.schedule, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: Spacing.xs),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

/// Parses [text] into an `int?` — empty/blank/invalid → null.
int? parseOptionalInt(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;
  return int.tryParse(trimmed);
}

/// Parses [text] into a `num?` — empty/blank/invalid → null.
num? parseOptionalNum(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;
  return num.tryParse(trimmed);
}
