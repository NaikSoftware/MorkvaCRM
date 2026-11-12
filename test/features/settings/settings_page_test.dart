import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/design/design.dart';
import 'package:morkva_crm/features/settings/settings_page.dart';

import '../automation/view/automation_view_harness.dart' show setWindow;

void main() {
  for (final (name, size, scale) in [
    ('a short window', const Size(390, 360), 1.0),
    ('large text on a phone', const Size(390, 640), 2.0),
  ]) {
    testWidgets('$name scrolls instead of overflowing', (tester) async {
      setWindow(tester, size);
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: SettingsPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text('Sign out'), 100);
      expect(find.text('Sign out').hitTestable(), findsOneWidget);
    });
  }

  testWidgets('a tall window keeps Sign out at the bottom', (tester) async {
    setWindow(tester, const Size(1440, 900));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: SettingsPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.getBottomLeft(find.text('Sign out')).dy, greaterThan(800));
  });
}
