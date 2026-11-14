import 'package:flutter/material.dart';

import '../../../core/domain/domain.dart';
import '../../../design/design.dart';
import '../../../l10n/l10n.dart';
import 'field_value_editor.dart';

/// number: keeps the raw text while typing, accepts '.' or ',' as the decimal
/// separator, reports "Enter a number" for text that does not parse, shows the
/// unit as a suffix and rounds to `decimalPlaces` on blur.
class NumberValueEditor extends FieldValueEditor {
  const NumberValueEditor();

  @override
  String get typeId => kNumberFieldType;

  @override
  Widget build(BuildContext context, ValueEditorContext ctx) =>
      _NumberInput(ctx: ctx);
}

/// The parse result of [raw]: `(value, ok)`; blank is a valid empty value.
// shortcut: "1,000" reads as 1.0 (a lone ',' is the decimal mark); add
// locale-aware parsing once the app has a locale setting.
(num?, bool) parseNumberInput(String raw) {
  var text = raw.replaceAll(' ', '');
  if (text.isEmpty) return (null, true);
  text = text.contains('.')
      ? text.replaceAll(',', '') // "1,234.5": ',' groups thousands
      : text.replaceAll(',', '.');
  final n = num.tryParse(text);
  if (n == null || !n.isFinite) return (null, false);
  return (n, true);
}

/// Editable text for [n]: fixed to [decimalPlaces] when set, else plain
/// (no float noise, no thousands separators so it parses back).
String numberInputText(num? n, int? decimalPlaces) {
  if (n == null) return '';
  if (decimalPlaces != null) return n.toStringAsFixed(decimalPlaces);
  if (n is int) return '$n';
  if (n == n.truncateToDouble()) return n.toStringAsFixed(0);
  return '${double.parse(n.toStringAsPrecision(12))}';
}

class _NumberInput extends StatefulWidget {
  const _NumberInput({required this.ctx});

  final ValueEditorContext ctx;

  @override
  State<_NumberInput> createState() => _NumberInputState();
}

class _NumberInputState extends State<_NumberInput> {
  late final _controller = TextEditingController(text: _canonical);
  final _focus = FocusNode();
  bool _invalid = false;

  NumberFieldDefinition get _field => widget.ctx.field as NumberFieldDefinition;

  num? get _value => (widget.ctx.value as NumberFieldValue).value;

  String get _canonical => numberInputText(_value, _field.decimalPlaces);

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(_NumberInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_focus.hasFocus || oldWidget.ctx.value == widget.ctx.value) return;
    // The value changed elsewhere (live sync) while not typing: show it.
    _controller.text = _canonical;
    if (_invalid) {
      _invalid = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.ctx.onInputError(null);
      });
    }
  }

  void _onChanged(String raw) {
    final (n, ok) = parseNumberInput(raw);
    _invalid = !ok;
    if (!ok) {
      widget.ctx.onInputError(context.l10n.objectsEnterNumber);
      return;
    }
    widget.ctx.onInputError(null);
    widget.ctx.onChanged(NumberFieldValue(n));
  }

  void _onFocusChange() {
    if (_focus.hasFocus) return;
    // Read the text, not ctx.value: the host may not have rebuilt yet.
    final (n, ok) = parseNumberInput(_controller.text);
    if (!ok) return; // keep the raw text so the user sees what to fix
    final places = _field.decimalPlaces;
    if (n != null && places != null) {
      final rounded = num.parse(n.toStringAsFixed(places));
      if (rounded != n) widget.ctx.onChanged(NumberFieldValue(rounded));
    }
    _controller.text = numberInputText(n, places);
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unit = _field.unitLabel;
    return MorkvaTextField(
      controller: _controller,
      focusNode: _focus,
      enabled: widget.ctx.enabled,
      hasError: widget.ctx.error != null,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      suffixText: unit == null || unit.isEmpty ? null : unit,
      onChanged: _onChanged,
    );
  }
}
