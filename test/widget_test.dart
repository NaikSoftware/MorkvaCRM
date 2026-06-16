import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/app/app.dart';

void main() {
  testWidgets('App boots into the themed shell with the home empty state',
      (tester) async {
    await tester.pumpWidget(const MorkvaApp());
    await tester.pumpAndSettle();

    // Brand shows in the app bar on the home destination.
    expect(find.text('MorkvaCRM'), findsOneWidget);
    // Home renders the empty-collections state.
    expect(find.text('No collections yet'), findsOneWidget);
    // Both navigation destinations are present.
    expect(find.text('Settings'), findsWidgets);
    // The shell is navigable: tapping Settings switches the active page.
    await tester.tap(find.byIcon(Icons.settings_outlined).first);
    await tester.pumpAndSettle();
    expect(find.text('Workspace and account settings will live here.'),
        findsOneWidget);
  });
}
