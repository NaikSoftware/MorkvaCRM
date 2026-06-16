import 'package:flutter/material.dart';

import 'morkva_text_field.dart';

/// A search-styled [MorkvaTextField]: a leading search icon, a "Search" hint,
/// and a trailing clear (✕) button that appears only while there is text and
/// clears the field when tapped.
///
/// Owns its [TextEditingController] when one is not supplied (and disposes it),
/// so the clear button works out of the box.
class SearchField extends StatefulWidget {
  const SearchField({
    super.key,
    this.controller,
    this.hintText = 'Search',
    this.onChanged,
    this.onCleared,
  });

  final TextEditingController? controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onCleared;

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

    return MorkvaTextField(
      controller: _controller,
      hint: widget.hintText,
      onChanged: widget.onChanged,
      textInputAction: TextInputAction.search,
      prefixIcon: const Icon(Icons.search),
      suffixIcon: hasText
          ? IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Clear',
              onPressed: _clear,
            )
          : null,
    );
  }
}
