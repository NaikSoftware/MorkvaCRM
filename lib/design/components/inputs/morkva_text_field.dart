import 'package:flutter/material.dart';

import '../../tokens/spacing.dart';

/// A text input that leans on the themed [InputDecoration] (see
/// `AppTheme.inputDecorationTheme`) and optionally renders a field [label]
/// above the field.
///
/// Reads all color/text from the theme — never hardcodes a hex, font, radius,
/// or spacing. Use this everywhere a single-line (or obscured) text input is
/// needed so the whole app shares one input feel.
class MorkvaTextField extends StatelessWidget {
  const MorkvaTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.label,
    this.hint,
    this.errorText,
    this.obscureText = false,
    this.keyboardType,
    this.prefixIcon,
    this.suffixIcon,
    this.onChanged,
    this.enabled = true,
    this.autofocus = false,
    this.textInputAction,
    this.onSubmitted,
    this.minLines,
    this.maxLines = 1,
  });

  final TextEditingController? controller;

  /// Optional focus node, so callers can re-sync the controller only while the
  /// field is unfocused (and never stomp the caret mid-type).
  final FocusNode? focusNode;

  /// Optional label rendered above the field (labelMedium).
  final String? label;
  final String? hint;
  final String? errorText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final bool autofocus;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  /// Minimum visible lines; pair with [maxLines] for a multiline input.
  final int? minLines;

  /// Maximum visible lines. Defaults to 1 (single-line); set higher (or null)
  /// for a multiline field.
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final labelStyle = theme.textTheme.labelMedium?.copyWith(
      color: enabled ? scheme.onSurface : scheme.onSurfaceVariant,
    );

    final field = TextField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      autofocus: autofocus,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      minLines: minLines,
      maxLines: maxLines,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      style: theme.textTheme.bodyLarge,
      cursorColor: scheme.primary,
      decoration: InputDecoration(
        hintText: hint,
        errorText: errorText,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
      ),
    );

    if (label == null) return field;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label!, style: labelStyle),
        const SizedBox(height: Spacing.xs),
        field,
      ],
    );
  }
}
