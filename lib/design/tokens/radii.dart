import 'package:flutter/widgets.dart';

/// Named border-radius scale. Committing to a small set keeps every surface
/// speaking the same spatial language. Buttons/inputs use [md]; cards use [lg];
/// pills use [full].
abstract final class Radii {
  /// 8 — chips, small controls, nested elements.
  static const sm = 8.0;

  /// 12 — buttons, inputs, list tiles.
  static const md = 12.0;

  /// 16 — cards, sheets, dialogs.
  static const lg = 16.0;

  /// 28 — pill (fully rounded) for nav indicators and FAB-like actions.
  static const full = 28.0;

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius fullAll = BorderRadius.all(Radius.circular(full));
}
