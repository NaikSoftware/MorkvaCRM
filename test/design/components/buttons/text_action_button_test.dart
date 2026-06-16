import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/design/components/buttons/text_action_button.dart';
import 'package:morkva_crm/design/theme/app_theme.dart';

class _Host extends StatelessWidget {
  const _Host(this.child);

  final Widget child;

  @override
  Widget build(BuildContext context) => MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: Center(child: child)),
      );
}

void main() {
  group('TextActionButton', () {
    testWidgets('renders its label', (tester) async {
      await tester.pumpWidget(
        _Host(TextActionButton(label: 'Learn more', onPressed: () {})),
      );

      expect(find.text('Learn more'), findsOneWidget);
    });

    testWidgets('renders a leading icon when provided', (tester) async {
      await tester.pumpWidget(
        _Host(
          TextActionButton(
            label: 'Open',
            icon: Icons.open_in_new,
            onPressed: () {},
          ),
        ),
      );

      expect(find.byIcon(Icons.open_in_new), findsOneWidget);
    });

    testWidgets('fires onPressed when tapped', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _Host(TextActionButton(label: 'Tap me', onPressed: () => taps++)),
      );

      await tester.tap(find.byType(TextActionButton));
      await tester.pump();

      expect(taps, 1);
    });

    testWidgets('does not fire when disabled (onPressed null)', (tester) async {
      await tester.pumpWidget(
        const _Host(TextActionButton(label: 'Disabled', onPressed: null)),
      );

      await tester.tap(find.byType(TextActionButton), warnIfMissed: false);
      await tester.pump();

      expect(find.text('Disabled'), findsOneWidget);
    });

    testWidgets('keeps a 44px-tall hit target', (tester) async {
      await tester.pumpWidget(
        _Host(TextActionButton(label: 'Hi', onPressed: () {})),
      );

      expect(
        tester.getSize(find.byType(TextActionButton)).height,
        greaterThanOrEqualTo(44),
      );
    });
  });
}
