import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/automation/automation.dart';
import 'package:morkva_crm/design/design.dart';
import 'package:morkva_crm/features/automation/widgets/reason_copy.dart';
import 'package:morkva_crm/features/automation/widgets/status_chip.dart';

void main() {
  Widget host(Widget child, {ThemeData? theme}) => MaterialApp(
    theme: theme ?? AppTheme.light,
    home: Scaffold(body: Center(child: child)),
  );

  Color fillOf(WidgetTester tester) {
    final box = tester.widget<Container>(
      find.descendant(
        of: find.byType(StatusChip),
        matching: find.byType(Container),
      ),
    );
    return (box.decoration! as BoxDecoration).color!;
  }

  testWidgets('shows the words, tinted by tone', (tester) async {
    await tester.pumpWidget(
      host(StatusChip.of(moduleChip(ModuleStatus.needsConsent))),
    );
    expect(find.text('Needs consent'), findsOneWidget);
    expect(
      fillOf(tester),
      AppTheme.light.extension<MorkvaSemanticColors>()!.warningContainer,
    );

    await tester.pumpWidget(host(StatusChip.of(moduleChip(ModuleStatus.ok))));
    expect(find.text('Installed'), findsOneWidget);
    expect(fillOf(tester), CollectionTints.light[1].background);
  });

  testWidgets('dark theme uses the dark containers', (tester) async {
    await tester.pumpWidget(
      host(
        StatusChip.of(moduleChip(ModuleStatus.broken)),
        theme: AppTheme.dark,
      ),
    );
    expect(fillOf(tester), AppTheme.dark.colorScheme.errorContainer);
  });

  testWidgets('a tappable chip has a 44 px hit area and fires', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      host(
        StatusChip(label: 'Broken', tone: CopyTone.error, onTap: () => taps++),
      ),
    );
    expect(tester.getSize(find.byType(StatusChip)).height, 44);
    await tester.tap(find.text('Broken'));
    await tester.pumpAndSettle();
    expect(taps, 1);
  });

  testWidgets('a static chip is 24 px', (tester) async {
    await tester.pumpWidget(
      host(const StatusChip(label: 'Paused', tone: CopyTone.neutral)),
    );
    expect(tester.getSize(find.byType(StatusChip)).height, 24);
  });
}
