import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/design/tokens/colors.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  group('colour tokens meet WCAG AA (4.5:1)', () {
    test('light onPrimary on primary', () {
      final scheme = MorkvaColors.scheme(Brightness.light);
      expect(scheme.onPrimary, const Color(0xFF3A1E00));
      expect(_contrast(scheme.onPrimary, scheme.primary), greaterThan(4.5));
    });

    test('dark onPrimary on primary', () {
      final scheme = MorkvaColors.scheme(Brightness.dark);
      expect(_contrast(scheme.onPrimary, scheme.primary), greaterThan(4.5));
    });

    test('light primaryText on paper and raised surfaces', () {
      final scheme = MorkvaColors.scheme(Brightness.light);
      const text = MorkvaSemanticColors.light;
      expect(text.primaryText, const Color(0xFF8A4708));
      for (final bg in [scheme.surface, MorkvaPalette.paperRaised]) {
        expect(_contrast(text.primaryText, bg), greaterThan(4.5));
      }
    });

    test('dark primaryText on espresso surfaces', () {
      final scheme = MorkvaColors.scheme(Brightness.dark);
      const text = MorkvaSemanticColors.dark;
      for (final bg in [scheme.surface, MorkvaPalette.espressoRaised]) {
        expect(_contrast(text.primaryText, bg), greaterThan(4.5));
      }
    });

    test('primaryText survives copyWith and lerp', () {
      const light = MorkvaSemanticColors.light;
      const dark = MorkvaSemanticColors.dark;
      expect(light.copyWith().primaryText, light.primaryText);
      expect(light.lerp(dark, 1).primaryText, dark.primaryText);
    });

    test('warning banner text on its container, light and dark', () {
      for (final colors in [
        MorkvaSemanticColors.light,
        MorkvaSemanticColors.dark,
      ]) {
        expect(
          _contrast(colors.onWarningContainer, colors.warningContainer),
          greaterThan(4.5),
        );
      }
    });

    test('warning container pair survives copyWith and lerp', () {
      const light = MorkvaSemanticColors.light;
      const dark = MorkvaSemanticColors.dark;
      expect(light.copyWith().warningContainer, light.warningContainer);
      expect(light.copyWith().onWarningContainer, light.onWarningContainer);
      final lerped = light.lerp(dark, 1);
      expect(lerped.warningContainer, dark.warningContainer);
      expect(lerped.onWarningContainer, dark.onWarningContainer);
    });
  });
}
