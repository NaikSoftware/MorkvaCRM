import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/design/design.dart';
import 'package:morkva_crm/features/views/widgets/views_skeleton.dart';

void main() {
  testWidgets('shows a toolbar row: a chip stub left, two stubs right', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: ViewsSkeleton()),
      ),
    );
    expect(find.bySemanticsLabel('Loading'), findsNothing);
    await tester.pump(ViewsSkeleton.delay);
    expect(find.bySemanticsLabel('Loading'), findsOneWidget);

    Iterable<Rect> stubs(Size size) => find
        .byWidgetPredicate(
          (w) => w is Container && w.constraints?.isTight == true,
        )
        .evaluate()
        .map((e) => tester.getRect(find.byWidget(e.widget)))
        .where((r) => r.size == size);
    final chip = stubs(const Size(96, 32)).single;
    final right = stubs(const Size(32, 32)).toList();
    expect(right, hasLength(2));
    for (final r in right) {
      expect(r.top, chip.top);
      expect(r.left, greaterThan(chip.right + 400));
    }
  });
}
