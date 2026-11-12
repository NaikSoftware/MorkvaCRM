import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/design/design.dart';
import 'package:morkva_crm/features/automation/bloc/modules_cubit.dart';
import 'package:morkva_crm/features/automation/view/import_sheet.dart';

import 'automation_view_harness.dart';

void main() {
  late AutomationRig rig;

  setUp(() => rig = AutomationRig());
  tearDown(() => rig.dispose());

  Future<List<ImportPreview?>> open(
    WidgetTester tester, {
    Size size = wideWindow,
  }) async {
    setWindow(tester, size);
    final result = <ImportPreview?>[];
    await tester.pumpWidget(
      rig.wrap(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async => result.add(
              await showImportSheet(
                context,
                preview: rig.modules.previewImport,
                pickFile: rig.host.pickModuleFile,
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  PrimaryButton continueButton(WidgetTester tester) => tester
      .widget<PrimaryButton>(find.widgetWithText(PrimaryButton, 'Continue'));

  testWidgets('paste: problems show as "path — message"; Continue waits', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('Choose a .morkva.json file'), findsOneWidget);
    await tester.tap(find.text('Paste'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '{"nope": 1}');
    await tester.pump();
    expect(find.text("This isn't a Morkva module file."), findsOneWidget);
    expect(continueButton(tester).onPressed, isNull);

    final file = jsonDecode(stampBundle().encode()) as Map<String, Object?>;
    final manifest = file['manifest']! as Map<String, Object?>;
    ((manifest['actions']! as List).first as Map)['scope'] = 'everywhere';
    await tester.enterText(find.byType(TextField), jsonEncode(file));
    await tester.pump();
    expect(find.textContaining('actions[0].scope — '), findsOneWidget);
    expect(continueButton(tester).onPressed, isNull);
  });

  testWidgets('paste: a valid file continues with its preview', (tester) async {
    final result = await open(tester);
    await tester.tap(find.text('Paste'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), stampBundle().encode());
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(result.single!.bundle!.manifest.id, stampId);
  });

  testWidgets('file: an installed id shows the replace notice', (tester) async {
    await rig.stores.modules.save(stampModule());
    rig.host.file = (
      name: 'stamp.morkva.json',
      text: stampBundle(version: '1.1.0', code: 'v2()').encode(),
    );
    await open(tester);
    await tester.pump();
    await tester.tap(find.text('Choose file'));
    await tester.pumpAndSettle();
    expect(find.text('stamp.morkva.json'), findsOneWidget);
    expect(
      find.textContaining('A module with this id is installed (v1.0.0).'),
      findsOneWidget,
    );
    expect(find.textContaining('replaces it with v1.1.0'), findsOneWidget);
    expect(continueButton(tester).onPressed, isNotNull);
  });

  testWidgets('phone: no drop zone, only the button', (tester) async {
    await open(tester, size: phoneWindow);
    expect(find.text('Choose a .morkva.json file'), findsNothing);
    expect(find.text('Choose file'), findsOneWidget);
  });
}
