/// Spacing scale — one source of truth for gaps, padding, and insets.
///
/// Use these named steps instead of magic numbers so vertical rhythm stays
/// consistent across every screen. Steps follow a 4-based scale.
abstract final class Spacing {
  /// 4 — hairline gaps, icon-to-label nudges.
  static const xxs = 4.0;

  /// 8 — tight internal padding, chip gaps.
  static const xs = 8.0;

  /// 12 — default control padding, list item gaps.
  static const sm = 12.0;

  /// 16 — default content padding, card insets.
  static const md = 16.0;

  /// 24 — section gaps, generous card insets.
  static const lg = 24.0;

  /// 32 — between major blocks.
  static const xl = 32.0;

  /// 48 — page-level breathing room, empty-state framing.
  static const xxl = 48.0;
}
