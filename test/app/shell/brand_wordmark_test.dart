import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/app/shell/brand_wordmark.dart';
import 'package:morkva_crm/design/design.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(body: child),
  );

  testWidgets('shows logomark and wordmark when extended', (tester) async {
    await tester.pumpWidget(host(const BrandWordmark(extended: true)));

    expect(find.byType(BrandLogomark), findsOneWidget);
    expect(find.text('Morkva'), findsOneWidget);
    expect(find.text('CRM'), findsOneWidget);
  });

  testWidgets('shows only the logomark when collapsed', (tester) async {
    await tester.pumpWidget(host(const BrandWordmark(extended: false)));

    expect(find.byType(BrandLogomark), findsOneWidget);
    expect(find.text('Morkva'), findsNothing);
  });

  testWidgets('tapping calls onTap when provided', (tester) async {
    var taps = 0;
    await tester.pumpWidget(host(BrandWordmark(onTap: () => taps++)));

    await tester.tap(find.byType(BrandLogomark));
    expect(taps, 1);
  });

  testWidgets('is not tappable without onTap', (tester) async {
    await tester.pumpWidget(host(const BrandWordmark()));

    expect(find.byType(InkWell), findsNothing);
  });
}
