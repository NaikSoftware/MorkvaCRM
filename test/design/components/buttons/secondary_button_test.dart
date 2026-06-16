import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/design/components/buttons/secondary_button.dart';
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
  group('SecondaryButton', () {
    testWidgets('renders its label', (tester) async {
      await tester.pumpWidget(
        _Host(SecondaryButton(label: 'Save draft', onPressed: () {})),
      );

      expect(find.text('Save draft'), findsOneWidget);
    });

    testWidgets('renders a leading icon when provided', (tester) async {
      await tester.pumpWidget(
        _Host(SecondaryButton(label: 'Add', icon: Icons.add, onPressed: () {})),
      );

      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('fires onPressed when tapped', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _Host(SecondaryButton(label: 'Tap me', onPressed: () => taps++)),
      );

      await tester.tap(find.byType(SecondaryButton));
      await tester.pump();

      expect(taps, 1);
    });

    testWidgets('does not fire when disabled (onPressed null)', (tester) async {
      await tester.pumpWidget(
        const _Host(SecondaryButton(label: 'Disabled', onPressed: null)),
      );

      await tester.tap(find.byType(SecondaryButton), warnIfMissed: false);
      await tester.pump();

      // No callback can fire; reaching here without error is the contract.
      expect(find.text('Disabled'), findsOneWidget);
    });

    testWidgets('shows a spinner and hides label while loading', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _Host(
          SecondaryButton(
            label: 'Loading',
            loading: true,
            onPressed: () => taps++,
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading'), findsNothing);

      await tester.tap(find.byType(SecondaryButton), warnIfMissed: false);
      await tester.pump();
      expect(taps, 0);
    });
  });
}
