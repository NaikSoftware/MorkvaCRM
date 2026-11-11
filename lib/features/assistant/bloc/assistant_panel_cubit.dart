import 'package:flutter_bloc/flutter_bloc.dart';

/// Whether the assistant panel (the wide side panel, the rail's modal sheet
/// or the phone route) is open. Shell-level, provided next to the assistant
/// bloc; [onChanged] tells the session, which keeps the collections it leased
/// warm while the panel is open.
class AssistantPanelCubit extends Cubit<bool> {
  AssistantPanelCubit({void Function(bool open)? onChanged})
    : _onChanged = onChanged,
      super(false);

  final void Function(bool open)? _onChanged;

  bool get isOpen => state;

  void show() => _set(true);

  void hide() => _set(false);

  /// Ctrl+J.
  void toggle() => _set(!state);

  void _set(bool open) {
    if (open == state) return;
    emit(open);
    _onChanged?.call(open);
  }
}
