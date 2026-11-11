import 'package:flutter/material.dart';

/// Raw "Warm Carrot" palette values — the single source of truth for color.
///
/// Widgets must never hardcode hex; they read from [ColorScheme] (built by
/// [MorkvaColors.scheme]) or from the [MorkvaSemanticColors] theme extension.
/// Warmth lives in the carrot accent and the paper-neutral surfaces; data
/// surfaces stay quiet so dense tables and boards read without fatigue.
abstract final class MorkvaPalette {
  // Carrot — the brand accent.
  static const carrot = Color(0xFFE8821E);
  static const carrotBright = Color(0xFFF59B3C); // dark-mode primary
  static const carrotDeep = Color(0xFF8A4708); // carrot text on paper (AA)
  static const carrotContainerLight = Color(0xFFFFE0C2);
  static const onCarrotContainerLight = Color(0xFF4E2A00);

  // Carrot-top green — the warm complement (secondary actions, accents).
  static const leaf = Color(0xFF4C7A34);
  static const leafBright = Color(0xFF8FCB6B);

  // Warm-paper neutrals (light).
  static const paper = Color(0xFFFBF7F2); // app canvas / main area
  static const paperRaised = Color(0xFFFFFFFF); // cards, sheets
  static const paperSunk = Color(0xFFF4EDE3); // nav rail / sidebar
  static const paperSunkHigh = Color(0xFFEEE5D8);
  static const paperSunkHighest = Color(0xFFE8DECD);
  static const inkHigh = Color(0xFF2B2018);
  static const inkMedium = Color(0xFF6B5E52);
  static const outline = Color(0xFFB6A593);
  static const outlineSoft = Color(0xFFE0D5C7);

  // Warm near-black neutrals (dark).
  static const espresso = Color(0xFF1A1410); // app canvas
  static const espressoRaised = Color(0xFF241D17);
  static const espressoSunk = Color(0xFF141009);
  static const creamHigh = Color(0xFFF3EBE0);
  static const creamMedium = Color(0xFFC3B6A6);
  static const outlineDark = Color(0xFF4A4036);

  // Background doodles: decor only, barely there on the canvas.
  static const doodleLight = Color(0x1A6B5E52); // inkMedium @ 10%
  static const doodleDark = Color(0x12C3B6A6); // creamMedium @ 7%

  // Semantic (kept distinct from the carrot primary so a warning never reads
  // as a normal action).
  static const success = Color(0xFF2E8B57);
  static const warning = Color(0xFFD4A017);
  static const error = Color(0xFFC0392B);
  static const info = Color(0xFF3A7CA5);
}

/// Builds the Material [ColorScheme] for each brightness. We start from a seed
/// (for correct tonal roles) then override surfaces to the warm-paper steps so
/// the shell has real surface hierarchy (sidebar vs main vs card).
abstract final class MorkvaColors {
  static ColorScheme scheme(Brightness brightness) =>
      brightness == Brightness.light ? _light : _dark;

  static final ColorScheme _light =
      ColorScheme.fromSeed(
        seedColor: MorkvaPalette.carrot,
        brightness: Brightness.light,
      ).copyWith(
        primary: MorkvaPalette.carrot,
        // White on carrot is ~2.8:1; dark brown clears WCAG AA.
        onPrimary: const Color(0xFF3A1E00),
        primaryContainer: MorkvaPalette.carrotContainerLight,
        onPrimaryContainer: MorkvaPalette.onCarrotContainerLight,
        secondary: MorkvaPalette.leaf,
        onSecondary: Colors.white,
        error: MorkvaPalette.error,
        onError: Colors.white,
        surface: MorkvaPalette.paper,
        onSurface: MorkvaPalette.inkHigh,
        onSurfaceVariant: MorkvaPalette.inkMedium,
        surfaceContainerLowest: Colors.white,
        surfaceContainerLow: const Color(0xFFFAF4EC),
        surfaceContainer: MorkvaPalette.paperSunk,
        surfaceContainerHigh: MorkvaPalette.paperSunkHigh,
        surfaceContainerHighest: MorkvaPalette.paperSunkHighest,
        outline: MorkvaPalette.outline,
        outlineVariant: MorkvaPalette.outlineSoft,
      );

  static final ColorScheme _dark =
      ColorScheme.fromSeed(
        seedColor: MorkvaPalette.carrot,
        brightness: Brightness.dark,
      ).copyWith(
        primary: MorkvaPalette.carrotBright,
        onPrimary: const Color(0xFF3A1E00),
        secondary: MorkvaPalette.leafBright,
        onSecondary: const Color(0xFF12300A),
        error: const Color(0xFFE6786B),
        onError: const Color(0xFF44120B),
        surface: MorkvaPalette.espresso,
        onSurface: MorkvaPalette.creamHigh,
        onSurfaceVariant: MorkvaPalette.creamMedium,
        surfaceContainerLowest: MorkvaPalette.espressoSunk,
        surfaceContainerLow: const Color(0xFF1F1813),
        surfaceContainer: MorkvaPalette.espressoRaised,
        surfaceContainerHigh: const Color(0xFF2E2620),
        surfaceContainerHighest: const Color(0xFF39302A),
        outline: MorkvaPalette.outlineDark,
        outlineVariant: const Color(0xFF332A22),
      );
}

/// A collection's tile colours: a soft [background] and an AA-legible
/// [foreground] for its glyph.
typedef CollectionTint = ({Color background, Color foreground});

/// The soft tints that tell collections apart (sidebar, cards, headers).
/// Picked from a collection's id, so a collection keeps its colour everywhere
/// and across sessions without storing one.
abstract final class CollectionTints {
  static const List<CollectionTint> light = [
    (background: Color(0xFFFFE0C2), foreground: Color(0xFF8A4708)), // carrot
    (background: Color(0xFFE3EEDB), foreground: Color(0xFF3B6128)), // leaf
    (background: Color(0xFFDCEAF3), foreground: Color(0xFF2F5F80)), // sky
    (background: Color(0xFFEDE0EE), foreground: Color(0xFF6B3F70)), // plum
    (background: Color(0xFFF6EBC8), foreground: Color(0xFF6E5310)), // sand
    (background: Color(0xFFF7DEDA), foreground: Color(0xFF8A3328)), // rose
    (background: Color(0xFFE6E2DC), foreground: Color(0xFF4A4036)), // slate
    (background: Color(0xFFD8EEEA), foreground: Color(0xFF23605A)), // teal
  ];

  static const List<CollectionTint> dark = [
    (background: Color(0xFF4A2A0E), foreground: Color(0xFFFFC48A)),
    (background: Color(0xFF263A1C), foreground: Color(0xFFB5D99E)),
    (background: Color(0xFF1C3344), foreground: Color(0xFFA9CCE6)),
    (background: Color(0xFF3A2340), foreground: Color(0xFFDDB8E2)),
    (background: Color(0xFF3D3112), foreground: Color(0xFFEBD38A)),
    (background: Color(0xFF44201B), foreground: Color(0xFFF2B3A8)),
    (background: Color(0xFF35302A), foreground: Color(0xFFD3C9BC)),
    (background: Color(0xFF163834), foreground: Color(0xFF9FD9CF)),
  ];

  /// The tint for [seed] (a collection id). A hand-rolled hash because
  /// `String.hashCode` differs between the VM and the web.
  static CollectionTint of(String seed, Brightness brightness) {
    var hash = 0;
    for (final unit in seed.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    final tints = brightness == Brightness.light ? light : dark;
    return tints[hash % tints.length];
  }
}

/// Semantic colors that have no home in [ColorScheme]. Read them with
/// `Theme.of(context).extension<MorkvaSemanticColors>()!`.
@immutable
class MorkvaSemanticColors extends ThemeExtension<MorkvaSemanticColors> {
  const MorkvaSemanticColors({
    required this.success,
    required this.onSuccess,
    required this.warning,
    required this.onWarning,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.info,
    required this.onInfo,
    required this.primaryText,
    required this.doodle,
  });

  final Color success;
  final Color onSuccess;
  final Color warning;
  final Color onWarning;

  /// Soft amber fill for warning banners (rate limit, plan limits); pair it
  /// with [onWarningContainer] for the banner's text and icon.
  final Color warningContainer;
  final Color onWarningContainer;
  final Color info;
  final Color onInfo;

  /// Carrot for text-coloured actions/links on surfaces; raw `primary` text
  /// is too light on paper to pass WCAG AA.
  final Color primaryText;

  /// Line colour of the main panel's background doodles.
  final Color doodle;

  static const light = MorkvaSemanticColors(
    success: MorkvaPalette.success,
    onSuccess: Colors.white,
    warning: MorkvaPalette.warning,
    onWarning: Color(0xFF3D2E00),
    warningContainer: Color(0xFFFBF3DC),
    onWarningContainer: Color(0xFF5A4410),
    info: MorkvaPalette.info,
    onInfo: Colors.white,
    primaryText: MorkvaPalette.carrotDeep,
    doodle: MorkvaPalette.doodleLight,
  );

  static const dark = MorkvaSemanticColors(
    success: Color(0xFF5BB585),
    onSuccess: Color(0xFF06311B),
    warning: Color(0xFFE6BE54),
    onWarning: Color(0xFF3D2E00),
    warningContainer: Color(0xFF3A2F12),
    onWarningContainer: Color(0xFFF1DC9A),
    info: Color(0xFF6FA8C9),
    onInfo: Color(0xFF06243A),
    primaryText: MorkvaPalette.carrotBright,
    doodle: MorkvaPalette.doodleDark,
  );

  @override
  MorkvaSemanticColors copyWith({
    Color? success,
    Color? onSuccess,
    Color? warning,
    Color? onWarning,
    Color? warningContainer,
    Color? onWarningContainer,
    Color? info,
    Color? onInfo,
    Color? primaryText,
    Color? doodle,
  }) {
    return MorkvaSemanticColors(
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      warningContainer: warningContainer ?? this.warningContainer,
      onWarningContainer: onWarningContainer ?? this.onWarningContainer,
      info: info ?? this.info,
      onInfo: onInfo ?? this.onInfo,
      primaryText: primaryText ?? this.primaryText,
      doodle: doodle ?? this.doodle,
    );
  }

  @override
  MorkvaSemanticColors lerp(
    covariant ThemeExtension<MorkvaSemanticColors>? other,
    double t,
  ) {
    if (other is! MorkvaSemanticColors) return this;
    return MorkvaSemanticColors(
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      warningContainer: Color.lerp(
        warningContainer,
        other.warningContainer,
        t,
      )!,
      onWarningContainer: Color.lerp(
        onWarningContainer,
        other.onWarningContainer,
        t,
      )!,
      info: Color.lerp(info, other.info, t)!,
      onInfo: Color.lerp(onInfo, other.onInfo, t)!,
      primaryText: Color.lerp(primaryText, other.primaryText, t)!,
      doodle: Color.lerp(doodle, other.doodle, t)!,
    );
  }
}
