import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/design/design.dart';

void main() {
  Future<void> pump(WidgetTester t, {required bool mondayFirst}) {
    final picker = CalendarDatePicker(
      initialDate: DateTime(2026, 11, 10),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      onDateChanged: (_) {},
    );
    return t.pumpWidget(
      MaterialApp(
        home: Scaffold(body: mondayFirst ? MondayFirst(child: picker) : picker),
      ),
    );
  }

  testWidgets('date pickers start the week on Monday, like the grid', (
    t,
  ) async {
    // 1 Nov 2026 is a Sunday.
    await pump(t, mondayFirst: false);
    expect(
      t.getCenter(find.text('1')).dx,
      lessThan(t.getCenter(find.text('2')).dx),
    );
    await pump(t, mondayFirst: true);
    expect(
      t.getCenter(find.text('1')).dx,
      greaterThan(t.getCenter(find.text('2')).dx),
    );
  });
}
