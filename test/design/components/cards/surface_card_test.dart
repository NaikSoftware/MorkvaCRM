import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/design/design.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: Center(child: child)),
      );

  group('SurfaceCard', () {
    testWidgets('renders its child', (tester) async {
      await tester.pumpWidget(
        wrap(const SurfaceCard(child: Text('content'))),
      );

      expect(find.text('content'), findsOneWidget);
    });

    testWidgets('fires onTap when pressed', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        wrap(SurfaceCard(onTap: () => taps++, child: const Text('tap me'))),
      );

      await tester.tap(find.text('tap me'));
      await tester.pump();

      expect(taps, 1);
    });

    testWidgets('is not tappable when onTap is null', (tester) async {
      await tester.pumpWidget(
        wrap(const SurfaceCard(child: Text('static'))),
      );

      expect(find.byType(PressableScale), findsNothing);
    });
  });
}
