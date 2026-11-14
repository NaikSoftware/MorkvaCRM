import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/design/design.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(body: child),
  );

  group('SearchField', () {
    testWidgets('dense is a 44 px field with 16 px icons', (tester) async {
      await tester.pumpWidget(wrap(const SearchField(dense: true)));

      expect(tester.getSize(find.byType(TextField)).height, 44);
      expect(tester.widget<Icon>(find.byIcon(MorkvaIcons.search)).size, 16);
    });

    testWidgets('shows the default "Search" hint and search icon', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(const SearchField()));

      expect(find.text('Search'), findsOneWidget);
      expect(find.byIcon(MorkvaIcons.search), findsOneWidget);
    });

    testWidgets('clear button appears only when there is text and clears it', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      var cleared = false;
      await tester.pumpWidget(
        wrap(
          SearchField(controller: controller, onCleared: () => cleared = true),
        ),
      );

      // No clear button while empty.
      expect(find.byIcon(MorkvaIcons.close), findsNothing);

      await tester.enterText(find.byType(TextField), 'carrots');
      await tester.pump();
      expect(find.byIcon(MorkvaIcons.close), findsOneWidget);

      await tester.tap(find.byIcon(MorkvaIcons.close));
      await tester.pump();

      expect(controller.text, isEmpty);
      expect(cleared, isTrue);
      expect(find.byIcon(MorkvaIcons.close), findsNothing);
    });

    testWidgets('fires onChanged as the user types', (tester) async {
      String? changed;
      await tester.pumpWidget(
        wrap(SearchField(onChanged: (value) => changed = value)),
      );

      await tester.enterText(find.byType(TextField), 'abc');

      expect(changed, 'abc');
    });
  });
}
