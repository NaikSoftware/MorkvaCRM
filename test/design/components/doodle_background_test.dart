import 'dart:ui' as ui;

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

  test('repaints only when the colour or pixel ratio changes', () {
    final a = DoodlePainter(MorkvaPalette.doodleLight);
    expect(a.shouldRepaint(DoodlePainter(MorkvaPalette.doodleLight)), isFalse);
    expect(a.shouldRepaint(DoodlePainter(MorkvaPalette.doodleDark)), isTrue);
    expect(
      a.shouldRepaint(DoodlePainter(MorkvaPalette.doodleLight, pixelRatio: 2)),
      isTrue,
    );
  });

  testWidgets('draws the tile and repeats it every tile width', (
    tester,
  ) async {
    const opaque = Color(0xFF000000);
    const w = DoodlePainter.tile * 2;
    const h = DoodlePainter.tile;
    final bytes = await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      DoodlePainter(opaque).paint(Canvas(recorder), const Size(w, h));
      final image = recorder.endRecording().toImageSync(w.toInt(), h.toInt());
      return (await image.toByteData())!;
    });
    int alpha(int x, int y) => bytes!.getUint8((y * w.toInt() + x) * 4 + 3);

    var inked = 0;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < DoodlePainter.tile; x++) {
        final a = alpha(x, y);
        if (a > 0) inked++;
        // The second tile is a pixel copy of the first.
        expect(alpha(x + DoodlePainter.tile.toInt(), y), a);
      }
    }
    expect(inked, greaterThan(500));
  });
}
