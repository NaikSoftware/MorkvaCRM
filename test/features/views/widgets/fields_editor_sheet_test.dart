import 'dart:ui' show CheckedState;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/design/design.dart';
import 'package:morkva_crm/features/views/widgets/fields_editor_sheet.dart';

import 'package:morkva_crm/core/domain/domain.dart';

import '../views_fixtures.dart';

void main() {
  List<String>? saved;

  Future<void> pump(
    WidgetTester tester, {
    String title = 'Setup card',
    bool board = true,
    bool withObject = true,
  }) async {
    saved = null;
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: FieldsEditorSheet(
            title: title,
            collection: deals,
            view: board ? boardView : tableView,
            object: withObject ? deal('d1', 0, name: 'Acme', amount: 5) : null,
            onSave: (ids) => saved = ids,
          ),
        ),
      ),
    );
  }

  testWidgets('lists fields except title and layout field, with a note', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Card title'), findsOneWidget);
    expect(find.text('Amount'), findsOneWidget);
    expect(find.text('Company'), findsOneWidget);
    expect(find.text('Stage is shown as the columns'), findsOneWidget);
    expect(find.text('Stage'), findsNothing);
  });

  testWidgets('Save is disabled until something changes', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Save'));
    expect(saved, isNull);
  });

  testWidgets('toggling a row shows it and saves title-first order', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('Company'));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(saved, ['name', 'amount', 'company']);
  });

  testWidgets('hiding every row leaves only the title', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Amount'));
    await tester.pump();
    await tester.tap(find.text('Save'));
    expect(saved, ['name']);
  });

  testWidgets('Move down menu reorders', (tester) async {
    await pump(tester);
    await tester.tap(find.byTooltip('Move Amount'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move down'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Company'));
    await tester.pump();
    await tester.tap(find.text('Save'));
    expect(saved, ['name', 'company', 'amount']);
  });

  testWidgets('dragging a handle reorders', (tester) async {
    await pump(tester);
    final handle = find.byIcon(Icons.drag_indicator).first;
    await tester.drag(handle, const Offset(0, 130));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Company'));
    await tester.pump();
    await tester.tap(find.text('Save'));
    expect(saved, ['name', 'company', 'amount']);
  });

  testWidgets('changing the card title swaps it with the old one', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('Card title'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Company').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    expect(saved, ['company', 'name', 'amount']);
  });

  testWidgets('preview shows field names when the view has no objects', (
    tester,
  ) async {
    await pump(tester, withObject: false);
    expect(find.text('Name'), findsWidgets);
    await tester.tap(find.text('Company'));
    await tester.pump();
    expect(find.text('Company'), findsNWidgets(2));
  });

  testWidgets('Columns variant previews a table row', (tester) async {
    await pump(tester, title: 'Columns', board: false);
    expect(find.text('Title column'), findsOneWidget);
    expect(find.text('Acme'), findsOneWidget);
    await tester.tap(find.text('Company').last);
    await tester.pump();
    await tester.tap(find.text('Save'));
    expect(saved, ['name', 'amount', 'stage']);
  });

  testWidgets('rows expose a named checked state and a reorder handle', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pump(tester);
    expect(find.bySemanticsLabel(RegExp(r'Reorder\s+Amount')), findsOneWidget);
    final box = tester.getSemantics(find.byType(Checkbox).first);
    expect(box.label, contains('Amount'));
    expect(box.flagsCollection.isChecked, CheckedState.isTrue);
    handle.dispose();
  });

  testWidgets(
    'an unknown title id falls back and a field-less collection is a no-op',
    (tester) async {
      await pump(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => FieldsEditorSheet.show(
                context,
                title: 'Columns',
                collection: const Collection(id: 'x', name: 'X'),
                view: tableView,
                onSave: (_) {},
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('PREVIEW'), findsNothing);
    },
  );
}
