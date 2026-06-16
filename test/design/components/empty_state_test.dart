import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/design/components/empty_state.dart';
import 'package:morkva_crm/design/theme/app_theme.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: child),
      );

  group('EmptyState', () {
    testWidgets('renders title, message, and icon', (tester) async {
      await tester.pumpWidget(
        host(
          const EmptyState(
            icon: Icons.inbox_outlined,
            title: 'No contacts yet',
            message: 'Add your first contact to get started.',
          ),
        ),
      );

      expect(find.text('No contacts yet'), findsOneWidget);
      expect(
        find.text('Add your first contact to get started.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
    });

    testWidgets('fires onAction when the action button is tapped',
        (tester) async {
      var tapped = 0;
      await tester.pumpWidget(
        host(
          EmptyState(
            icon: Icons.inbox_outlined,
            title: 'No contacts yet',
            message: 'Add your first contact to get started.',
            actionLabel: 'Add contact',
            onAction: () => tapped++,
          ),
        ),
      );

      expect(find.text('Add contact'), findsOneWidget);

      await tester.tap(find.text('Add contact'));
      await tester.pump();

      expect(tapped, 1);
    });

    testWidgets('renders no action when none is provided', (tester) async {
      await tester.pumpWidget(
        host(
          const EmptyState(
            icon: Icons.inbox_outlined,
            title: 'No contacts yet',
            message: 'Nothing to show.',
          ),
        ),
      );

      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('Add contact'), findsNothing);
    });
  });
}
