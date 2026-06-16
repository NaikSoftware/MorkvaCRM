import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/design/design.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: Center(child: child)),
      );

  group('ListTileCard', () {
    testWidgets('renders title and subtitle', (tester) async {
      await tester.pumpWidget(
        wrap(const ListTileCard(title: 'Acme Inc', subtitle: 'Customer')),
      );

      expect(find.text('Acme Inc'), findsOneWidget);
      expect(find.text('Customer'), findsOneWidget);
    });

    testWidgets('renders leading and trailing widgets', (tester) async {
      await tester.pumpWidget(
        wrap(const ListTileCard(
          title: 'With slots',
          leading: Icon(Icons.person),
          trailing: Icon(Icons.chevron_right),
        )),
      );

      expect(find.byIcon(Icons.person), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('fires onTap when pressed', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        wrap(ListTileCard(title: 'Tappable', onTap: () => taps++)),
      );

      await tester.tap(find.text('Tappable'));
      await tester.pump();

      expect(taps, 1);
    });

    testWidgets('is at least 44px tall', (tester) async {
      await tester.pumpWidget(
        wrap(const SizedBox(
          width: 300,
          child: ListTileCard(title: 'x'),
        )),
      );

      expect(tester.getSize(find.byType(ListTileCard)).height,
          greaterThanOrEqualTo(44.0));
    });
  });
}
