import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Typography tokens.
///
/// **Bricolage Grotesque** (a humanist grotesque with real character) carries
/// display and heading roles — the brand's voice. **Hanken Grotesk** handles
/// body, labels, and data: quiet, highly legible, with tabular numerals for
/// number-dense CRM cells.
///
/// Display sizes get negative tracking so large type reads engineered rather
/// than stretched.
abstract final class MorkvaTypography {
  static TextTheme textTheme(ColorScheme scheme) {
    final ink = scheme.onSurface;

    TextStyle display(double size, FontWeight weight, double tracking,
            double height) =>
        GoogleFonts.bricolageGrotesque(
          fontSize: size,
          fontWeight: weight,
          letterSpacing: tracking,
          height: height,
          color: ink,
        );

    TextStyle text(double size, FontWeight weight,
            {double height = 1.45, double tracking = 0}) =>
        GoogleFonts.hankenGrotesk(
          fontSize: size,
          fontWeight: weight,
          height: height,
          letterSpacing: tracking,
          color: ink,
        );

    return TextTheme(
      displayLarge: display(48, FontWeight.w700, -1.0, 1.04),
      displayMedium: display(36, FontWeight.w700, -0.8, 1.08),
      displaySmall: display(30, FontWeight.w600, -0.6, 1.12),
      headlineLarge: display(28, FontWeight.w600, -0.5, 1.16),
      headlineMedium: display(24, FontWeight.w600, -0.4, 1.2),
      headlineSmall: display(20, FontWeight.w600, -0.3, 1.25),
      titleLarge: GoogleFonts.bricolageGrotesque(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        height: 1.3,
        color: ink,
      ),
      titleMedium: text(16, FontWeight.w600, height: 1.3),
      titleSmall: text(14, FontWeight.w600, height: 1.3),
      bodyLarge: text(16, FontWeight.w400, height: 1.5),
      bodyMedium: text(14, FontWeight.w400, height: 1.45),
      bodySmall: text(12, FontWeight.w400, height: 1.4)
          .copyWith(color: scheme.onSurfaceVariant),
      labelLarge: text(14, FontWeight.w600, tracking: 0.1),
      labelMedium: text(12, FontWeight.w600, tracking: 0.2),
      labelSmall: text(11, FontWeight.w600, tracking: 0.4)
          .copyWith(color: scheme.onSurfaceVariant),
    );
  }

  /// Returns [style] with tabular (monospaced) figures — use for prices,
  /// counts, IDs, and any number column so digits align vertically.
  static TextStyle tabular(TextStyle style) => style.copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
      );
}
