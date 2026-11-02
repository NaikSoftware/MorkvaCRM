import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/features/collections/field_editors/widgets/color_swatch_picker.dart';

void main() {
  testWidgets('swatches sit in a 5 × 2 grid, none orphaned', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: ColorSwatchPicker(selected: null, onChanged: (_) {}),
          ),
        ),
      ),
    );
    final rows = find.descendant(
      of: find.byType(ColorSwatchPicker),
      matching: find.byType(Row),
    );
    final counts = [
      for (final e in rows.evaluate())
        if (e.widget case final Row r
            when r.children.length == 5 &&
                e.findAncestorWidgetOfExactType<Row>() == null)
          r.children.length,
    ];
    expect(ColorSwatchPicker.palette.length + 1, 10);
    expect(counts, [5, 5]);
  });
}
