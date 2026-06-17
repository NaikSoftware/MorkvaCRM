import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/design/theme/app_theme.dart';
import 'package:morkva_crm/features/collections/editor/add_field_sheet.dart';
import 'package:morkva_crm/features/collections/field_editors/built_in_field_editors.dart';

void main() {
  final registry = defaultFieldEditorRegistry();

  testWidgets('AddFieldSheet lists every registered type and returns the '
      'picked one', (tester) async {
    // A tall, single-column surface so every type card is laid out (the grid
    // builds lazily; off-screen cards would otherwise not exist in the tree).
    tester.view.physicalSize = const Size(420, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    String? picked;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () async {
                  picked = await AddFieldSheet.show(
                    context,
                    editors: registry.all,
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Every built-in type's label appears in the picker.
    expect(find.text('Text'), findsOneWidget);
    expect(find.text('Number'), findsOneWidget);
    expect(find.text('Reference'), findsOneWidget);

    // Computed types (auto-number, calculated) keep their real description and
    // carry a "Declare only" pill marking them as declare-now/compute-later.
    expect(find.text('Declare only'), findsWidgets);

    // Picking a type pops the sheet with its typeId.
    await tester.tap(find.text('Number'));
    await tester.pumpAndSettle();

    expect(picked, kNumberFieldType);
    expect(find.byType(AddFieldSheet), findsNothing);
  });

  testWidgets('dismissing the sheet resolves to null', (tester) async {
    Object? result = 'sentinel';

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await AddFieldSheet.show(
                    context,
                    editors: registry.all,
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(AddFieldSheet), findsOneWidget);

    // Tap the scrim to dismiss.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(result, isNull);
  });
}
