import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/design/components/loading_indicator.dart';
import 'package:morkva_crm/design/theme/app_theme.dart';

void main() {
  Widget host(Widget child, {bool reduceMotion = false}) => MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(disableAnimations: reduceMotion),
            child: Center(child: child),
          ),
        ),
      );

  group('LoadingIndicator', () {
    testWidgets('shows the spinner', (tester) async {
      await tester.pumpWidget(host(const LoadingIndicator()));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows the message when provided', (tester) async {
      await tester.pumpWidget(
        host(const LoadingIndicator(message: 'Loading your workspace')),
      );

      expect(find.text('Loading your workspace'), findsOneWidget);
    });
  });

  group('SkeletonBox', () {
    testWidgets('renders at the given size', (tester) async {
      await tester.pumpWidget(
        host(const SkeletonBox(width: 120, height: 24)),
      );

      final size = tester.getSize(find.byType(SkeletonBox));
      expect(size, const Size(120, 24));
    });

    testWidgets('animates (pulses) when motion is enabled', (tester) async {
      await tester.pumpWidget(
        host(const SkeletonBox(width: 120, height: 24)),
      );

      expect(
        find.descendant(
          of: find.byType(SkeletonBox),
          matching: find.byType(FadeTransition),
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders static under reduced motion', (tester) async {
      await tester.pumpWidget(
        host(
          const SkeletonBox(width: 120, height: 24),
          reduceMotion: true,
        ),
      );

      // No opacity animation wrapper when reduced motion is requested.
      expect(
        find.descendant(
          of: find.byType(SkeletonBox),
          matching: find.byType(FadeTransition),
        ),
        findsNothing,
      );
      expect(find.byType(SkeletonBox), findsOneWidget);
    });
  });
}
