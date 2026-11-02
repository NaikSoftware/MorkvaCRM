import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/design/design.dart';

void main() {
  Future<double> opacityOf(WidgetTester t, PrimaryButton button) async {
    await t.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: Center(child: button)),
      ),
    );
    return t
        .widget<Opacity>(
          find.descendant(
            of: find.byType(PrimaryButton),
            matching: find.byType(Opacity),
          ),
        )
        .opacity;
  }

  testWidgets('disabled dims the whole button to 38 %', (t) async {
    expect(
      await opacityOf(t, const PrimaryButton(label: 'Save', onPressed: null)),
      0.38,
    );
  });

  testWidgets('enabled and loading are fully opaque', (t) async {
    expect(
      await opacityOf(t, PrimaryButton(label: 'Save', onPressed: () {})),
      1,
    );
    expect(
      await opacityOf(
        t,
        PrimaryButton(label: 'Save', onPressed: () {}, loading: true),
      ),
      1,
    );
  });
}
