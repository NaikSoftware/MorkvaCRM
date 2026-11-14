import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/features/objects/value_editors/field_value_editor.dart';
import 'package:morkva_crm/features/objects/widgets/reference_picker.dart';

import 'editor_harness.dart';
import 'package:morkva_crm/design/morkva_icons.dart';

const _stage = SingleSelectFieldDefinition(
  id: 'stage',
  name: 'Stage',
  options: [
    SelectOption(id: 'lead', label: 'Lead', color: '#3A7CA5'),
    SelectOption(id: 'won', label: 'Won', color: '#2E8B57'),
  ],
);

const _tags = MultiSelectFieldDefinition(
  id: 'tags',
  name: 'Tags',
  options: [
    SelectOption(id: 'ent', label: 'Enterprise', color: '#3A7CA5'),
    SelectOption(id: 'up', label: 'Upsell'),
    SelectOption(id: 'new', label: 'New'),
  ],
);

const _contacts = Collection(
  id: 'contacts',
  name: 'Contacts',
  fields: [
    TextFieldDefinition(id: 'name', name: 'Name'),
    TextFieldDefinition(id: 'role', name: 'Role'),
  ],
  views: [
    ViewDefinition(id: 'all', name: 'All', fieldIds: ['name', 'role']),
  ],
);

const _company = ReferenceFieldDefinition(
  id: 'company',
  name: 'Company',
  targetCollectionId: 'contacts',
);
const _people = ReferenceFieldDefinition(
  id: 'people',
  name: 'People',
  targetCollectionId: 'contacts',
  multiple: true,
);

MorkvaObject _contact(String id, String name, String role, int day) =>
    MorkvaObject.create(
      id: id,
      collection: _contacts,
      values: {'name': TextFieldValue(name), 'role': TextFieldValue(role)},
      createdAt: DateTime.utc(2026, 1, day),
      updatedAt: DateTime.utc(2026, 1, day),
    );

final _choices = ReferenceChoices.fromObjects(
  targets: [_contacts],
  objects: {
    'contacts': [
      _contact('ann', 'Ann Lee', 'CEO', 1),
      _contact('bob', 'Bob Stone', 'CTO', 2),
      _contact('dan', 'Dana Ray', 'Sales', 3),
    ],
  },
);

void main() {
  group('single select', () {
    testWidgets('picks an option and clears it', (tester) async {
      final h = EditorHarness(_stage, null);
      await h.pump(tester);
      expect(find.text('Choose…'), findsOneWidget);

      await tester.tap(find.byType(InputDecorator).first);
      await tester.pumpAndSettle();
      expect(find.text('Clear'), findsNothing);
      await tester.tap(find.text('Won'));
      await tester.pumpAndSettle();
      expect(h.value, const SingleSelectFieldValue('won'));
      expect(find.text('Won'), findsOneWidget);

      await tester.tap(find.byType(InputDecorator).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();
      expect(h.value, const SingleSelectFieldValue(null));
    });

    testWidgets('disabled does not open the menu', (tester) async {
      final h = EditorHarness(_stage, null);
      await h.pump(tester, enabled: false);
      await tester.tap(find.byType(InputDecorator).first);
      await tester.pumpAndSettle();
      expect(find.text('Lead'), findsNothing);
    });
  });

  group('multi select', () {
    testWidgets('adds from the checklist (menu stays open) and removes', (
      tester,
    ) async {
      final h = EditorHarness(_tags, const MultiSelectFieldValue(['up']));
      await h.pump(tester);
      expect(find.text('Upsell'), findsOneWidget);

      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CheckboxMenuButton, 'Enterprise'));
      await tester.pumpAndSettle();
      // Schema order, and the menu is still open.
      expect(h.value, const MultiSelectFieldValue(['ent', 'up']));
      expect(find.byType(CheckboxMenuButton), findsNWidgets(3));
      await tester.tap(find.widgetWithText(CheckboxMenuButton, 'Upsell'));
      await tester.pumpAndSettle();
      expect(h.value, const MultiSelectFieldValue(['ent']));

      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Remove Enterprise'));
      await tester.pumpAndSettle();
      expect(h.value, const MultiSelectFieldValue());
    });

    // The menu used to ride along with "+ Add" as chips were added before it.
    for (final width in [800.0, 260.0]) {
      testWidgets('menu stays put while adding tags (width $width)', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final h = EditorHarness(_tags, const MultiSelectFieldValue(['up']));
        await h.pump(tester);

        // A second tap on Add closes the menu (not close-then-reopen).
        await tester.tap(find.text('Add'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Add'));
        await tester.pumpAndSettle();
        expect(find.byType(CheckboxMenuButton), findsNothing);

        await tester.tap(find.text('Add'));
        await tester.pumpAndSettle();
        Rect item() =>
            tester.getRect(find.widgetWithText(CheckboxMenuButton, 'New'));
        final opened = item();
        // Opens right under the Add button, as before.
        final add = tester.getRect(find.widgetWithText(TextButton, 'Add'));
        // "New" is the third 48 px row of a menu hanging from Add's bottom.
        expect(opened.topLeft - add.bottomLeft, const Offset(0, 104));

        await tester.tap(find.widgetWithText(CheckboxMenuButton, 'Enterprise'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(CheckboxMenuButton, 'New'));
        await tester.pumpAndSettle();
        expect(h.value, const MultiSelectFieldValue(['ent', 'up', 'new']));
        expect(item(), opened);

        // Tapping beside the chips still dismisses the menu.
        await tester.tapAt(Offset(width - 10, 30));
        await tester.pumpAndSettle();
        expect(find.byType(CheckboxMenuButton), findsNothing);
      });
    }
  });

  group('reference', () {
    testWidgets('chips show labels; ✕ unlinks', (tester) async {
      final h = EditorHarness(
        _people,
        const ReferenceFieldValue(['ann', 'bob']),
      );
      await h.pump(tester, references: _choices);
      expect(find.text('Ann Lee'), findsOneWidget);
      expect(find.text('Link contact'), findsOneWidget);

      await tester.tap(find.byTooltip('Unlink Ann Lee'));
      await tester.pump();
      expect(h.value, const ReferenceFieldValue(['bob']));
    });

    testWidgets('loading labels show stub chips and no link action', (
      tester,
    ) async {
      final h = EditorHarness(_people, const ReferenceFieldValue(['ann']));
      await h.pump(
        tester,
        references: const ReferenceChoices(targets: {'contacts': _contacts}),
      );
      expect(find.text('Ann Lee'), findsNothing);
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Link contact'))
            .onPressed,
        isNull,
      );
    });

    testWidgets('single: tap links and closes, Unlink clears', (tester) async {
      final h = EditorHarness(_company, null);
      await h.pump(tester, references: _choices);
      await tester.tap(find.text('Link contact'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget); // 800 px: phone sheet
      expect(find.text('CTO'), findsOneWidget); // secondary line
      await tester.tap(find.text('Bob Stone'));
      await tester.pumpAndSettle();
      expect(find.byType(ReferencePicker), findsNothing);
      expect(h.value, const ReferenceFieldValue(['bob']));
      // A single link shows only its chip; tapping it reopens the picker.
      expect(find.text('Link contact'), findsNothing);

      await tester.tap(find.text('Bob Stone'));
      await tester.pumpAndSettle();
      expect(find.byIcon(MorkvaIcons.check), findsOneWidget);
      await tester.tap(find.text('Unlink'));
      await tester.pumpAndSettle();
      expect(h.value, const ReferenceFieldValue());
    });
  });

  group('picker', () {
    Future<Future<List<String>?> Function()> open(
      WidgetTester tester, {
      required ReferenceFieldDefinition field,
      ReferenceChoices? choices,
      List<String> selected = const [],
      Size size = const Size(1200, 800),
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      Future<List<String>?>? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => result = ReferencePicker.show(
                context,
                field: field,
                choices: choices ?? _choices,
                selected: selected,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      return () => result!;
    }

    testWidgets('wide: a dialog; search filters case-insensitively', (
      tester,
    ) async {
      await open(tester, field: _people);
      await tester.pump();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('Link contacts'), findsOneWidget);
      expect(find.text('from Contacts'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'AN');
      await tester.pump();
      expect(find.text('Ann Lee'), findsOneWidget);
      expect(find.text('Dana Ray'), findsOneWidget);
      expect(find.text('Bob Stone'), findsNothing);
      expect(find.text('2 of 3'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'zz');
      await tester.pump();
      expect(find.text('No contacts match “zz”'), findsOneWidget);
      expect(find.text('Try another name'), findsOneWidget);
    });

    testWidgets('multiple: checkboxes, count, Done returns the set', (
      tester,
    ) async {
      final result = await open(tester, field: _people, selected: ['dan']);
      await tester.pump();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('1 linked'), findsOneWidget);
      await tester.tap(find.text('Ann Lee'));
      await tester.pump();
      expect(find.text('2 linked'), findsOneWidget);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(await result(), ['ann', 'dan']);
    });

    testWidgets('Cancel returns null', (tester) async {
      final result = await open(tester, field: _people, selected: ['dan']);
      await tester.pump();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ann Lee'));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await result(), isNull);
    });

    testWidgets('empty target says so', (tester) async {
      await open(
        tester,
        field: _company,
        choices: ReferenceChoices.fromObjects(
          targets: [_contacts],
          objects: {'contacts': []},
        ),
        size: const Size(390, 844),
      );
      await tester.pump();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('Link contact'), findsOneWidget);
      expect(find.text('Contacts has no items yet'), findsOneWidget);
      expect(find.text('Unlink'), findsNothing);
    });
  });

  test('fromObjects: labels in view order, secondary from other view '
      'fields, missing target objects = loading', () {
    expect(_choices.labelsFor(_people), {
      'ann': 'Ann Lee',
      'bob': 'Bob Stone',
      'dan': 'Dana Ray',
    });
    expect(_choices.secondaryOf('ann'), 'CEO');
    expect(_choices.targetOf(_people), _contacts);
    final loading = ReferenceChoices.fromObjects(
      targets: [_contacts],
      objects: const {},
    );
    expect(loading.labelsFor(_people), isNull);
  });
}
