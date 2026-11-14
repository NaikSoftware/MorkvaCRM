import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../tokens/radii.dart';
import '../../tokens/spacing.dart';
import 'morkva_text_field.dart';
import 'package:morkva_crm/design/morkva_icons.dart';

/// A search-styled [MorkvaTextField]: a leading search icon, a "Search" hint,
/// and a trailing clear (✕) button that appears only while there is text and
/// clears the field when tapped.
///
/// Owns its [TextEditingController] when one is not supplied (and disposes it),
/// so the clear button works out of the box.
///
/// [dense]: a compact 44 px field with 16 px icons and a soft `outlineVariant`
/// edge, for filtering a short list inside a panel.
class SearchField extends StatefulWidget {
  const SearchField({
    super.key,
    this.controller,
    this.hintText,
    this.onChanged,
    this.onCleared,
    this.dense = false,
  });

  final TextEditingController? controller;
  /// Defaults to "Search".
  final String? hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onCleared;
  final bool dense;

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  TextEditingController? _internalController;
  TextEditingController get _controller =>
      widget.controller ?? _internalController!;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _internalController = TextEditingController();
    }
    _controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(SearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?.removeListener(_onTextChanged);
      _internalController?.removeListener(_onTextChanged);
      if (widget.controller == null) {
        _internalController ??= TextEditingController();
      } else {
        _internalController?.dispose();
        _internalController = null;
      }
      _controller.addListener(_onTextChanged);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _internalController?.dispose();
    super.dispose();
  }

  void _onTextChanged() => setState(() {});

  void _clear() {
    _controller.clear();
    widget.onChanged?.call('');
    widget.onCleared?.call();
  }

  @override
  Widget build(BuildContext context) {
    final hasText = _controller.text.isNotEmpty;
    final dense = widget.dense;
    final iconSize = dense ? 16.0 : null;

    final field = MorkvaTextField(
      controller: _controller,
      hint: widget.hintText ?? context.l10n.commonSearch,
      onChanged: widget.onChanged,
      textInputAction: TextInputAction.search,
      prefixIcon: Icon(MorkvaIcons.search, size: iconSize),
      suffixIcon: hasText
          ? IconButton(
              icon: Icon(MorkvaIcons.close, size: iconSize),
              tooltip: context.l10n.commonClear,
              onPressed: _clear,
              constraints: dense ? _denseIcon : null,
              padding: dense ? EdgeInsets.zero : null,
            )
          : null,
    );
    if (!dense) return field;

    final theme = Theme.of(context);
    final soft = OutlineInputBorder(
      borderRadius: Radii.mdAll,
      borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
    );
    return Theme(
      data: theme.copyWith(
        inputDecorationTheme: theme.inputDecorationTheme.copyWith(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: Spacing.sm,
            // A 24 px bodyLarge line + 20 = 44.
            vertical: 10,
          ),
          prefixIconConstraints: _denseIcon,
          suffixIconConstraints: _denseIcon,
          border: soft,
          enabledBorder: soft,
        ),
      ),
      child: field,
    );
  }

  static const _denseIcon = BoxConstraints(minWidth: 40, minHeight: 44);
}
