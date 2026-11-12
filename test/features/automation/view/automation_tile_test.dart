import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/features/automation/view/automations_page.dart';
import 'package:morkva_crm/features/automation/widgets/action_buttons.dart';

import '../widgets/automation_widget_rig.dart';

void main() {
  testWidgets('a tint-less button tile uses the same tint as the button', (
    tester,
  ) async {
    final a = buttonAutomation('a_stamp', 'Stamp today');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AutomationTile(automation: a)),
      ),
    );
    final box = tester
        .widgetList<Container>(find.byType(Container))
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .first;
    expect(
      box.color,
      buttonTintOf(null, 'c_orders', Brightness.light).background,
    );
  });
}
