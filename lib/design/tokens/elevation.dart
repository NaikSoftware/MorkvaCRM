import 'package:flutter/material.dart';

/// Soft, warm-tinted shadows — depth without the harsh stock-Material drop
/// shadow. Used for cards, menus, and pressed/raised surfaces. On dark surfaces
/// these are nearly invisible by design; depth there comes from surface-color
/// steps (see [MorkvaColors]).
abstract final class MorkvaElevation {
  /// Resting card / list surface.
  static const List<BoxShadow> level1 = [
    BoxShadow(
      color: Color(0x14000000), // ~8% black
      blurRadius: 2,
      offset: Offset(0, 1),
    ),
    BoxShadow(
      color: Color(0x0F4A3520), // faint warm tint
      blurRadius: 6,
      offset: Offset(0, 3),
    ),
  ];

  /// Hovered / lifted card.
  static const List<BoxShadow> level2 = [
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 4,
      offset: Offset(0, 2),
    ),
    BoxShadow(
      color: Color(0x14523A22),
      blurRadius: 14,
      offset: Offset(0, 8),
    ),
  ];

  /// Menus, popovers, dialogs.
  static const List<BoxShadow> level3 = [
    BoxShadow(
      color: Color(0x24000000),
      blurRadius: 10,
      offset: Offset(0, 4),
    ),
    BoxShadow(
      color: Color(0x1A523A22),
      blurRadius: 28,
      offset: Offset(0, 16),
    ),
  ];
}
