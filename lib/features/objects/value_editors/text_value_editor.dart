import 'package:flutter/material.dart';

import '../../../core/domain/domain.dart';
import '../../../design/design.dart';
import 'field_value_editor.dart';

/// text: a single-line field, or a 3–8 line growing one when `multiline`;
/// a "n / max" counter when `maxLength` is set (not enforced — validation
/// reports the overflow).
class TextValueEditor extends FieldValueEditor {
  const TextValueEditor();

  @override
  String get typeId => kTextFieldType;

  @override
  Widget build(BuildContext context, ValueEditorContext ctx) =>
      _TextInput(ctx: ctx);
}

class _TextInput extends StatefulWidget {
  const _TextInput({required this.ctx});

  final ValueEditorContext ctx;

  @override
  State<_TextInput> createState() => _TextInputState();
}

class _TextInputState extends State<_TextInput> {
  late final _controller = TextEditingController(text: _text(widget.ctx));
  final _focus = FocusNode();

  static String _text(ValueEditorContext ctx) =>
      (ctx.value as TextFieldValue).text ?? '';

  @override
  void didUpdateWidget(_TextInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Follow outside changes (live sync) only while not typing.
    final text = _text(widget.ctx);
    if (!_focus.hasFocus && _controller.text != text) _controller.text = text;
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctx = widget.ctx;
    final field = ctx.field as TextFieldDefinition;
    final max = field.maxLength;
    final input = MorkvaTextField(
      controller: _controller,
      focusNode: _focus,
      enabled: ctx.enabled,
      hasError: ctx.error != null,
      minLines: field.multiline ? 3 : null,
      maxLines: field.multiline ? 8 : 1,
      keyboardType: field.multiline ? TextInputType.multiline : null,
      textInputAction: field.multiline ? TextInputAction.newline : null,
      onChanged: (text) =>
          ctx.onChanged(TextFieldValue(text.isEmpty ? null : text)),
    );
    if (max == null) return input;

    final theme = Theme.of(context);
    final length = _text(ctx).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        input,
        const SizedBox(height: Spacing.xxs),
        Text(
          '$length / $max',
          textAlign: TextAlign.end,
          style: MorkvaTypography.tabular(
            (theme.textTheme.bodySmall ?? const TextStyle()).copyWith(
              color: length > max
                  ? theme.colorScheme.error
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
