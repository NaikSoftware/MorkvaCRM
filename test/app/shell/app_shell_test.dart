import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/app/shell/app_shell.dart';
import 'package:morkva_crm/design/design.dart';

void main() {
  /// Sets the logical surface size to [size] and resets it after the test.
  void useSurface(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget buildShell() {
    return MaterialApp(
      theme: AppTheme.light,
      home: AppShell(
        sidebarBuilder: (_, extended) => Text('sidebar:$extended'),
        bottomBar: const Text('bottom bar'),
        title: 'MorkvaCRM',
        child: const Center(child: Text('body')),
      ),
    );
  }

  group('AppShell', () {
    testWidgets('wide: the full sidebar beside the content, no bottom bar', (
      tester,
    ) async {
      useSurface(tester, const Size(1300, 800));
      await tester.pumpWidget(buildShell());

      expect(find.text('sidebar:true'), findsOneWidget);
      expect(find.text('bottom bar'), findsNothing);
      expect(find.text('MorkvaCRM'), findsOneWidget);
      // Doodles sit behind the main panel only, not the sidebar.
      final doodles = find.byType(DoodleBackground);
      expect(
        find.descendant(of: doodles, matching: find.text('body')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: doodles, matching: find.text('sidebar:true')),
        findsNothing,
      );
    });

    testWidgets('medium: the slim rail', (tester) async {
      useSurface(tester, const Size(1000, 800));
      await tester.pumpWidget(buildShell());

      expect(find.text('sidebar:false'), findsOneWidget);
    });

    testWidgets('narrow: header and bottom bar, no sidebar', (tester) async {
      useSurface(tester, const Size(400, 800));
      await tester.pumpWidget(buildShell());

      expect(find.textContaining('sidebar'), findsNothing);
      expect(find.text('bottom bar'), findsOneWidget);
      expect(find.text('MorkvaCRM'), findsOneWidget);
      // Phone: behind the body only, not the header.
      final doodles = find.byType(DoodleBackground);
      expect(
        find.descendant(of: doodles, matching: find.text('body')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: doodles, matching: find.text('MorkvaCRM')),
        findsNothing,
      );
    });
  });
}
