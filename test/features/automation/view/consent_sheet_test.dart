import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/design/design.dart';
import 'package:morkva_crm/features/automation/bloc/modules_cubit.dart';
import 'package:morkva_crm/features/automation/view/consent_sheet.dart';

import 'automation_view_harness.dart';

void main() {
  late AutomationRig rig;

  setUp(() => rig = AutomationRig());
  tearDown(() => rig.dispose());

  /// Opens the sheet; the result lands in the returned holder.
  Future<List<ConsentScope?>> open(
    WidgetTester tester, {
    required ConsentView view,
    ConsentScope initial = const ConsentScope.only({}),
    ConsentMode mode = ConsentMode.install,
    Size size = wideWindow,
    ThemeData? theme,
  }) async {
    setWindow(tester, size);
    final result = <ConsentScope?>[];
    await tester.pumpWidget(
      rig.wrap(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async => result.add(
              await showConsentSheet(
                context,
                view: view,
                collections: rig.collections,
                initial: initial,
                mode: mode,
                source: 'Imported',
              ),
            ),
            child: const Text('open'),
          ),
        ),
        theme: theme,
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  PrimaryButton primary(WidgetTester tester, String label) =>
      tester.widget<PrimaryButton>(find.widgetWithText(PrimaryButton, label));

  testWidgets('import: caps, actions, nothing preselected until a choice', (
    tester,
  ) async {
    final result = await open(
      tester,
      view: consentViewOf(stampBundle(), null),
      initial: ConsentScope.forImport(),
    );
    expect(find.text('Allow "Stamp shipped date"?'), findsOneWidget);
    expect(find.textContaining('v1.0.0 · Imported'), findsOneWidget);
    expect(find.text('Read cards'), findsOneWidget);
    expect(find.text('Create and change cards'), findsOneWidget);
    expect(find.text('On a card'), findsOneWidget);
    expect(find.text('Choose where it can work'), findsOneWidget);
    expect(primary(tester, 'Allow and install').onPressed, isNull);

    await tester.tap(find.text('Orders'));
    await tester.pump();
    expect(primary(tester, 'Allow and install').onPressed, isNotNull);
    await tester.tap(find.text('Orders'));
    await tester.pump();
    expect(primary(tester, 'Allow and install').onPressed, isNull);

    await tester.tap(find.text('All collections'));
    await tester.pump();
    await tester.tap(find.text('Allow and install'));
    await tester.pumpAndSettle();
    expect(result.single, const ConsentScope.all());
  });

  testWidgets('import from a collection: only that one is checked', (
    tester,
  ) async {
    final result = await open(
      tester,
      view: consentViewOf(stampBundle(), null),
      initial: ConsentScope.forImport(fromCollection: 'c_orders'),
    );
    await tester.tap(find.text('Allow and install'));
    await tester.pumpAndSettle();
    expect(result.single, const ConsentScope.only({'c_orders'}));
  });

  testWidgets('re-consent: New and Removed rows, code and auto-apply lines', (
    tester,
  ) async {
    final old = stampModule();
    final previous = consentTo(old, autoApply: true);
    final next = stampBundle(
      code: 'v2()',
      version: '1.1.0',
      caps: ['data:read', 'data:write', 'ui:navigate'],
    );
    await open(
      tester,
      view: consentViewOf(next, previous),
      initial: ConsentScope.of(previous),
      mode: ConsentMode.allow,
    );
    expect(find.text('New'), findsOneWidget);
    expect(find.text('Removed'), findsOneWidget);
    expect(
      find.textContaining('Code changed: v1.0.0 → v1.1.0'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Auto-apply turns off for the new version'),
      findsOneWidget,
    );
    expect(primary(tester, 'Allow').onPressed, isNotNull);
  });

  testWidgets('edit: only Where, Save returns the new scope', (tester) async {
    final module = stampModule();
    final result = await open(
      tester,
      view: consentViewOf(module.bundle!, consentTo(module)),
      initial: ConsentScope.of(consentTo(module)),
      mode: ConsentMode.edit,
    );
    expect(find.text('Change access for "Stamp shipped date"'), findsOneWidget);
    expect(find.text('It can:'), findsNothing);
    await tester.tap(find.text('Clients'));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(result.single, const ConsentScope.only({'c_orders', 'c_clients'}));
  });

  testWidgets('View code opens the viewer over the bundle', (tester) async {
    await open(tester, view: consentViewOf(stampBundle(), null));
    await tester.tap(find.text('View code'));
    await tester.pumpAndSettle();
    expect(find.text('module.js'), findsOneWidget);
    expect(find.text('morkva.action("stamp", () => {});'), findsOneWidget);
  });

  testWidgets('phone: a bottom sheet; dark renders', (tester) async {
    await open(
      tester,
      view: consentViewOf(stampBundle(), null),
      size: phoneWindow,
      theme: AppTheme.dark,
    );
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
