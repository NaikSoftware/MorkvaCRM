import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/design/components/buttons/icon_action_button.dart';
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
  group('IconActionButton', () {
    testWidgets('renders its icon', (tester) async {
      await tester.pumpWidget(
        _Host(
          IconActionButton(
            icon: Icons.search,
            tooltip: 'Search',
            onPressed: () {},
          ),
        ),
      );

      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('exposes the tooltip as a semantic label', (tester) async {
      await tester.pumpWidget(
        _Host(
          IconActionButton(
            icon: Icons.search,
            tooltip: 'Search',
            onPressed: () {},
          ),
        ),
      );

      expect(find.byTooltip('Search'), findsOneWidget);
    });

    testWidgets('fires onPressed when tapped', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _Host(
          IconActionButton(
            icon: Icons.delete_outline,
            tooltip: 'Delete',
            onPressed: () => taps++,
          ),
        ),
      );

      await tester.tap(find.byType(IconActionButton));
      await tester.pump();

      expect(taps, 1);
    });

    testWidgets('does not fire when disabled (onPressed null)', (tester) async {
      await tester.pumpWidget(
        const _Host(
          IconActionButton(
            icon: Icons.delete_outline,
            tooltip: 'Delete',
            onPressed: null,
          ),
        ),
      );

      await tester.tap(find.byType(IconActionButton), warnIfMissed: false);
      await tester.pump();

      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });

    testWidgets('keeps a 44x44 hit target', (tester) async {
      await tester.pumpWidget(
        _Host(
          IconActionButton(
            icon: Icons.search,
            tooltip: 'Search',
            onPressed: () {},
          ),
        ),
      );

      final size = tester.getSize(find.byType(IconActionButton));
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));
    });

    testWidgets('paints a disc in the filled variant', (tester) async {
      await tester.pumpWidget(
        _Host(
          IconActionButton(
            icon: Icons.search,
            tooltip: 'Search',
            filled: true,
            onPressed: () {},
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(IconActionButton),
          matching: find.byType(Container),
        ),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.shape, BoxShape.circle);
      expect(decoration.color, isNotNull);
    });
  });
}
