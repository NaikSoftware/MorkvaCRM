import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/app/navigation/navigation_cubit.dart';
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

  Widget buildShell({
    required int selectedIndex,
    required ValueChanged<int> onDestinationSelected,
  }) {
    return MaterialApp(
      theme: AppTheme.light,
      home: AppShell(
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected,
        destinations: kAppSections,
        title: 'MorkvaCRM',
        child: const Center(child: Text('body')),
      ),
    );
  }

  group('AppShell', () {
    testWidgets('wide surface shows a NavigationRail (no NavigationBar)',
        (tester) async {
      useSurface(tester, const Size(1200, 800));

      await tester.pumpWidget(
        buildShell(selectedIndex: 0, onDestinationSelected: (_) {}),
      );

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.text('MorkvaCRM'), findsOneWidget);
      expect(find.text('body'), findsOneWidget);
    });

    testWidgets('narrow surface shows a NavigationBar (no NavigationRail)',
        (tester) async {
      useSurface(tester, const Size(400, 800));

      await tester.pumpWidget(
        buildShell(selectedIndex: 0, onDestinationSelected: (_) {}),
      );

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.text('MorkvaCRM'), findsOneWidget);
      expect(find.text('body'), findsOneWidget);
    });

    testWidgets('reflects the selected destination on the rail',
        (tester) async {
      useSurface(tester, const Size(1200, 800));

      await tester.pumpWidget(
        buildShell(selectedIndex: 1, onDestinationSelected: (_) {}),
      );

      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.selectedIndex, 1);
    });

    testWidgets('tapping a rail destination reports its index',
        (tester) async {
      useSurface(tester, const Size(1200, 800));

      int? tapped;
      await tester.pumpWidget(
        buildShell(selectedIndex: 0, onDestinationSelected: (i) => tapped = i),
      );

      await tester.tap(find.text(AppSection.settings.label));
      expect(tapped, kAppSections.indexOf(AppSection.settings));
    });

    testWidgets('tapping a bar destination reports its index',
        (tester) async {
      useSurface(tester, const Size(400, 800));

      int? tapped;
      await tester.pumpWidget(
        buildShell(selectedIndex: 0, onDestinationSelected: (i) => tapped = i),
      );

      await tester.tap(find.text(AppSection.settings.label));
      expect(tapped, kAppSections.indexOf(AppSection.settings));
    });
  });
}
