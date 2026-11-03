import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/design/design.dart';

void main() {
  Future<void> pump(WidgetTester tester, ThemeData theme, Widget child) =>
      tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(body: DoodleBackground(child: child)),
        ),
      );

  DoodlePainter painter(WidgetTester tester) => tester
      .widgetList<CustomPaint>(
        find.descendant(
          of: find.byType(DoodleBackground),
          matching: find.byType(CustomPaint),
        ),
      )
      .map((p) => p.painter)
      .whereType<DoodlePainter>()
      .single;

  testWidgets('paints under its child, ignores pointers and semantics', (
    tester,
  ) async {
    var taps = 0;
    await pump(
      tester,
      AppTheme.light,
      Center(
        child: TextButton(onPressed: () => taps++, child: const Text('Go')),
      ),
    );

    final stack = tester.widget<Stack>(
      find
          .descendant(
            of: find.byType(DoodleBackground),
            matching: find.byType(Stack),
          )
          .first,
    );
    // Decor first (underneath), the child on top.
    expect(stack.children.first, isA<Positioned>());
    expect(
      find.descendant(
        of: find.byWidget(stack.children.first),
        matching: find.byType(IgnorePointer),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byWidget(stack.children.first),
        matching: find.byType(ExcludeSemantics),
      ),
      findsOneWidget,
    );
    expect(painter(tester).color, MorkvaPalette.doodleLight);

    await tester.tap(find.text('Go'));
    expect(taps, 1);
    // Taps on the bare decor reach nothing but the scaffold.
    await tester.tapAt(const Offset(5, 5));
    expect(taps, 1);
    expect(find.bySemanticsLabel('Go'), findsOneWidget);
  });

  testWidgets('dark theme uses the dark doodle colour', (tester) async {
    await pump(tester, AppTheme.dark, const SizedBox.expand());
    expect(painter(tester).color, MorkvaPalette.doodleDark);
    expect(tester.takeException(), isNull);
  });

  test('repaints only when the colour changes', () {
    final a = DoodlePainter(MorkvaPalette.doodleLight);
    expect(a.shouldRepaint(DoodlePainter(MorkvaPalette.doodleLight)), isFalse);
    expect(a.shouldRepaint(DoodlePainter(MorkvaPalette.doodleDark)), isTrue);
  });
}
