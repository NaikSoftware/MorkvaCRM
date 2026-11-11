import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../assistant_actions.dart';

/// Hands the chat's widgets what every one of them may need — the [actions],
/// the clock for countdowns and whether they render in the phone layout —
/// without threading it through each constructor.
class AssistantScope extends InheritedWidget {
  const AssistantScope({
    super.key,
    required this.actions,
    this.now = DateTime.now,
    this.phone = false,
    required super.child,
  });

  final AssistantActions actions;

  /// The clock behind undo windows and retry countdowns (tests pin it).
  final DateTime Function() now;

  /// The full-screen phone route: 15 px message text, wider bubbles.
  final bool phone;

  static AssistantScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AssistantScope>();
    assert(scope != null, 'No AssistantScope above this assistant widget');
    return scope!;
  }

  /// Message text size: 14 in the panel, 15 on phone (per the mockups).
  double get messageSize => phone ? 15 : 14;

  @override
  bool updateShouldNotify(AssistantScope oldWidget) =>
      actions != oldWidget.actions ||
      now != oldWidget.now ||
      phone != oldWidget.phone;
}

/// The assistant's surface roles. The panel artboards step surfaces
/// differently in light and dark (a white panel over the paper canvas in
/// light, an `espressoRaised` panel over the espresso canvas in dark), so the
/// roles map to different [ColorScheme] tokens per brightness — never to hex.
@immutable
class AssistantColors {
  const AssistantColors._({
    required this.panel,
    required this.canvas,
    required this.border,
    required this.divider,
    required this.cardFooter,
    required this.neutralChip,
    required this.objectChip,
    required this.objectChipText,
    required this.inputBorder,
    required this.bar,
    required this.peakBar,
  });

  factory AssistantColors.of(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final primaryText =
        theme.extension<MorkvaSemanticColors>()?.primaryText ?? scheme.primary;
    final dark = scheme.brightness == Brightness.dark;
    final panel = dark
        ? scheme.surfaceContainer
        : scheme.surfaceContainerLowest;
    return AssistantColors._(
      panel: panel,
      canvas: scheme.surface,
      border: dark ? scheme.outline : scheme.surfaceContainerHigh,
      divider: dark ? scheme.outlineVariant : scheme.surfaceContainer,
      cardFooter: scheme.surfaceContainerLow,
      neutralChip: dark ? scheme.surfaceContainerHigh : scheme.surfaceContainer,
      objectChip: Color.alphaBlend(
        scheme.primary.withValues(alpha: 0.12),
        panel,
      ),
      objectChipText: primaryText,
      // Dark `outline` is too faint for an input's edge (< 3:1); a muted
      // cream reads like the artboard's #8C7E70.
      inputBorder: dark
          ? scheme.onSurfaceVariant.withValues(alpha: 0.6)
          : scheme.outline,
      // ≥ 3:1 against the card in both themes.
      bar: Color.lerp(scheme.outline, scheme.onSurfaceVariant, 0.5)!,
      peakBar: Color.lerp(scheme.primary, primaryText, 0.5)!,
    );
  }

  /// The panel, its header and composer, and every card.
  final Color panel;

  /// Behind the messages.
  final Color canvas;

  /// Header/footer rules and card outlines.
  final Color border;

  /// Row separators inside a card.
  final Color divider;

  /// A plan card's action strip.
  final Color cardFooter;

  /// Quiet action chips ("Copy table") and the focus chip.
  final Color neutralChip;

  /// `#1042` object chips.
  final Color objectChip;
  final Color objectChipText;
  final Color inputBorder;

  /// Chart bars and the peak bar.
  final Color bar;
  final Color peakBar;
}
