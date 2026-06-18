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
///
/// Routes through [MorkvaTextField] so every per-type config input shares the
/// app's one input feel (themed fill, carrot focus ring, label-above layout).
/// Owns a controller seeded from [value]; it re-syncs from [value] only when the
/// field is unfocused, so an external change never stomps the caret mid-type.
class ConfigTextField extends StatefulWidget {
  const ConfigTextField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.hint,
    this.keyboardType,
    this.minLines,
    this.maxLines = 1,
  });

  final String label;
  final String? hint;
  final String value;
  final TextInputType? keyboardType;
  final int? minLines;
  final int? maxLines;
  final ValueChanged<String> onChanged;

  @override
  State<ConfigTextField> createState() => _ConfigTextFieldState();
}

class _ConfigTextFieldState extends State<ConfigTextField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );
  final FocusNode _focus = FocusNode();

  @override
  void didUpdateWidget(ConfigTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text && !_focus.hasFocus) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: MorkvaTextField(
        controller: _controller,
        focusNode: _focus,
        label: widget.label,
        hint: widget.hint,
        keyboardType: widget.keyboardType,
        minLines: widget.minLines,
        maxLines: widget.maxLines,
        onChanged: widget.onChanged,
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

/// A non-blocking, warning-toned inline note (e.g. a reference field whose
/// target is not yet chosen). Mirrors [ComputedLaterBanner]'s shape but uses the
/// semantic warning color so it reads as "attention", not a normal hint.
class InlineWarningNote extends StatelessWidget {
  const InlineWarningNote({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final warning = theme.extension<MorkvaSemanticColors>()!.warning;
    return Container(
      padding: const EdgeInsets.all(Spacing.sm),
      decoration: BoxDecoration(
        color: warning.withValues(alpha: 0.12),
        borderRadius: Radii.smAll,
        border: Border.all(color: warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, size: 18, color: warning),
          const SizedBox(width: Spacing.xs),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
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
