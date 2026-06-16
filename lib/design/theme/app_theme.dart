import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../tokens/colors.dart';
import '../tokens/motion.dart';
import '../tokens/radii.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';

/// Assembles the "Warm Carrot" [ThemeData] for light and dark from the design
/// tokens. This is the contract every screen and component inherits — set
/// component defaults here, not per-widget.
abstract final class AppTheme {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = MorkvaColors.scheme(brightness);
    final text = MorkvaTypography.textTheme(scheme);
    final semantic = brightness == Brightness.light
        ? MorkvaSemanticColors.light
        : MorkvaSemanticColors.dark;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: text,
      scaffoldBackgroundColor: scheme.surface,
      canvasColor: scheme.surface,
      visualDensity: VisualDensity.standard,
      // InkSparkle loads a fragment shader that misbehaves on web; use the
      // standard ripple there and the sparkle only where it's supported.
      splashFactory:
          kIsWeb ? InkRipple.splashFactory : InkSparkle.splashFactory,
      extensions: [semantic],
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(borderRadius: Radii.lgAll),
      ),
      filledButtonTheme: FilledButtonThemeData(style: _filledButtonStyle(text)),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: _filledButtonStyle(text).copyWith(
          backgroundColor: WidgetStatePropertyAll(scheme.surfaceContainerLowest),
          foregroundColor: WidgetStatePropertyAll(scheme.onSurface),
          elevation: const WidgetStatePropertyAll(0),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: _baseButtonStyle(text).copyWith(
          side: WidgetStateProperty.resolveWith(
            (states) => BorderSide(
              color: states.contains(WidgetState.pressed)
                  ? scheme.primary
                  : scheme.outline,
            ),
          ),
          foregroundColor: WidgetStatePropertyAll(scheme.onSurface),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: _baseButtonStyle(text).copyWith(
          foregroundColor: WidgetStatePropertyAll(scheme.primary),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainer,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Spacing.md,
          vertical: Spacing.sm,
        ),
        hintStyle: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        labelStyle: text.bodyMedium,
        border: const OutlineInputBorder(
          borderRadius: Radii.mdAll,
          borderSide: BorderSide.none,
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: Radii.mdAll,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: Radii.mdAll,
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: Radii.mdAll,
          borderSide: BorderSide(color: scheme.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: Radii.mdAll,
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surfaceContainer,
        indicatorColor: scheme.primaryContainer,
        indicatorShape:
            const RoundedRectangleBorder(borderRadius: Radii.fullAll),
        selectedIconTheme: IconThemeData(color: scheme.onPrimaryContainer),
        unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
        selectedLabelTextStyle:
            text.labelMedium?.copyWith(color: scheme.onSurface),
        unselectedLabelTextStyle:
            text.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        elevation: 0,
        labelTextStyle: WidgetStatePropertyAll(text.labelMedium),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.onPrimaryContainer
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle:
            text.bodyMedium?.copyWith(color: scheme.onInverseSurface),
        shape: const RoundedRectangleBorder(borderRadius: Radii.mdAll),
      ),
    );
  }

  static ButtonStyle _baseButtonStyle(TextTheme text) => ButtonStyle(
        textStyle: WidgetStatePropertyAll(text.labelLarge),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.sm),
        ),
        minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
        shape: const WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: Radii.mdAll),
        ),
        animationDuration: MotionDurations.fast,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      );

  static ButtonStyle _filledButtonStyle(TextTheme text) =>
      _baseButtonStyle(text).copyWith(elevation: const WidgetStatePropertyAll(0));
}
