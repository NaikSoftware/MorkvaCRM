import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/design/design.dart';
import 'package:morkva_crm/features/views/views.dart';

import 'views_fixtures.dart';

const _tags = MultiSelectFieldDefinition(
  id: 'tags',
  name: 'Tags',
  options: [
    SelectOption(id: 'hot', label: 'Hot', color: '#C0392B'),
    SelectOption(id: 'vip', label: 'VIP'),
  ],
);
const _flag = BooleanFieldDefinition(id: 'flag', name: 'Priority');

final _collection = deals.copyWith(fields: [...deals.fields, _tags, _flag]);

void main() {
  late List<ViewFilter> applied;

  Future<void> pump(
    WidgetTester tester, {
    ViewFilter? initial,
    Map<String, String>? choices = const {},
    ValueChanged<String>? onLoad,
  }) async {
    applied = [];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              height: 600,
              child: FilterBuilder(
                collection: _collection,
                initial: initial,
                referenceChoices: (_) => choices,
                onLoadChoices: onLoad,
                onApply: applied.add,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> pick(WidgetTester tester, String label) async {
    await tester.tap(find.bySemanticsLabel(label).last);
    await tester.pumpAndSettle();
  }

  PrimaryButton applyButton(WidgetTester tester) =>
      tester.widget<PrimaryButton>(find.byType(PrimaryButton));

  testWidgets('steps: field list with search → operators by type', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Filter by'), findsOneWidget);
    for (final f in _collection.fields) {
      expect(find.bySemanticsLabel(f.name), findsOneWidget);
    }
    await tester.enterText(find.byType(TextField), 'mee');
    await tester.pump();
    expect(find.bySemanticsLabel('Meeting'), findsOneWidget);
    expect(find.bySemanticsLabel('Amount'), findsNothing);
    await pick(tester, 'Meeting');
    for (final op in ['is before', 'is after', 'is on', 'is empty']) {
      expect(find.bySemanticsLabel(op), findsOneWidget);
    }
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Filter by'), findsOneWidget);
  });

  testWidgets('text: blank disables Apply; the operand is trimmed', (
    tester,
  ) async {
    await pump(tester);
    await pick(tester, 'Name');
    await pick(tester, 'contains');
    expect(find.text('Name contains'), findsOneWidget);
    expect(applyButton(tester).onPressed, isNull);
    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    expect(applyButton(tester).onPressed, isNull);
    await tester.enterText(find.byType(TextField), ' acme ');
    await tester.pump();
    await tester.tap(find.text('Add filter'));
    expect(applied, [
      const ViewFilter(fieldId: 'name', op: FilterOp.contains, operand: 'acme'),
    ]);
  });

  testWidgets('number: saved as a num; non-numbers disable Apply', (
    tester,
  ) async {
    await pump(tester);
    await pick(tester, 'Amount');
    await pick(tester, '>');
    await tester.enterText(find.byType(TextField), '12a');
    await tester.pump();
    expect(find.text('Enter a number'), findsOneWidget);
    expect(applyButton(tester).onPressed, isNull);
    await tester.enterText(find.byType(TextField), 'Infinity');
    await tester.pump();
    expect(applyButton(tester).onPressed, isNull);
    await tester.enterText(find.byType(TextField), '-1.5');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(applied.single.operand, -1.5);
    expect(applied.single.op, FilterOp.greaterThan);
  });

  testWidgets('date: a bare YYYY-MM-DD day from the calendar', (tester) async {
    await pump(
      tester,
      initial: const ViewFilter(
        fieldId: 'due',
        op: FilterOp.before,
        operand: '2026-03-05',
      ),
    );
    expect(find.text('Due is before'), findsOneWidget);
    expect(find.text('March 2026'), findsOneWidget);
    await tester.tap(find.text('9'));
    await tester.pump();
    await tester.tap(find.text('Update filter'));
    expect(applied.single.operand, '2026-03-09');
  });

  testWidgets('date: nothing picked yet disables Apply', (tester) async {
    await pump(tester);
    await pick(tester, 'Due');
    await pick(tester, 'is on');
    expect(find.byType(CalendarDatePicker), findsOneWidget);
    expect(applyButton(tester).onPressed, isNull);
  });

  testWidgets('single select: option ids, unchecking all disables Apply', (
    tester,
  ) async {
    await pump(tester);
    await pick(tester, 'Stage');
    await pick(tester, 'is any of');
    expect(find.byType(OptionPill), findsNWidgets(3));
    await pick(tester, 'Won');
    await pick(tester, 'Lead');
    await tester.tap(find.text('Add filter'));
    expect(applied.single.operand, ['won', 'lead']);
    await pick(tester, 'Won');
    await pick(tester, 'Lead');
    expect(applyButton(tester).onPressed, isNull);
  });

  testWidgets('multi select: "has none of"', (tester) async {
    await pump(tester);
    await pick(tester, 'Tags');
    await pick(tester, 'has none of');
    await pick(tester, 'VIP');
    await tester.tap(find.text('Add filter'));
    expect(
      applied.single,
      const ViewFilter(fieldId: 'tags', op: FilterOp.noneOf, operand: ['vip']),
    );
  });

  testWidgets('reference: pick target objects by label', (tester) async {
    await pump(tester, choices: const {'k1': 'Zeta Corp', 'k2': 'Alpha Ltd'});
    await pick(tester, 'Company');
    await pick(tester, 'is any of');
    await pick(tester, 'Alpha Ltd');
    await tester.tap(find.text('Add filter'));
    expect(applied.single.operand, ['k2']);
  });

  testWidgets('two toggles within one frame both count', (tester) async {
    await pump(tester);
    await pick(tester, 'Stage');
    await pick(tester, 'is any of');
    await tester.tap(find.bySemanticsLabel('Lead'));
    await tester.tap(find.bySemanticsLabel('Won'));
    await tester.pump();
    await tester.tap(find.text('Add filter'));
    expect(applied.single.operand, ['lead', 'won']);
  });

  testWidgets('checklist rows are one tab stop each', (tester) async {
    await pump(tester);
    await pick(tester, 'Stage');
    await pick(tester, 'is any of');
    for (final box in tester.widgetList<Checkbox>(find.byType(Checkbox))) {
      expect(
        find.ancestor(
          of: find.byWidget(box),
          matching: find.byType(ExcludeFocus),
        ),
        findsOneWidget,
      );
    }
  });

  testWidgets('reference: choices are requested on pick, loading shown', (
    tester,
  ) async {
    final requested = <String>[];
    await pump(tester, choices: null, onLoad: requested.add);
    await pick(tester, 'Company');
    expect(requested, ['company']);
    await tester.tap(find.bySemanticsLabel('is any of'));
    await tester.pump(); // the spinner never settles
    expect(find.text('Loading items…'), findsOneWidget);
    expect(find.text('Nothing to link to yet'), findsNothing);
  });

  testWidgets('reference: editing while loading shows no "Missing item"', (
    tester,
  ) async {
    final requested = <String>[];
    await pump(
      tester,
      choices: null,
      onLoad: requested.add,
      initial: const ViewFilter(
        fieldId: 'company',
        op: FilterOp.anyOf,
        operand: ['k1'],
      ),
    );
    expect(requested, ['company']);
    expect(find.text('Loading items…'), findsOneWidget);
    expect(find.text('Missing item'), findsNothing);
    expect(applyButton(tester).onPressed, isNotNull);
  });

  testWidgets('reference: a vanished pick stays uncheckable', (tester) async {
    await pump(
      tester,
      choices: const {'k1': 'Zeta Corp'},
      initial: const ViewFilter(
        fieldId: 'company',
        op: FilterOp.anyOf,
        operand: ['k9'],
      ),
    );
    expect(find.text('Missing item'), findsOneWidget);
  });

  testWidgets('a list operand with no ids does not count as a value', (
    tester,
  ) async {
    await pump(
      tester,
      initial: const ViewFilter(
        fieldId: 'stage',
        op: FilterOp.anyOf,
        operand: [1, null],
      ),
    );
    expect(applyButton(tester).onPressed, isNull);
  });

  testWidgets('reference: loaded but empty shows a hint', (tester) async {
    await pump(tester);
    await pick(tester, 'Company');
    await pick(tester, 'is any of');
    expect(find.text('Nothing to link to yet'), findsOneWidget);
    expect(applyButton(tester).onPressed, isNull);
  });

  testWidgets('boolean and empties apply from the operator step', (
    tester,
  ) async {
    await pump(tester);
    await pick(tester, 'Priority');
    expect(find.bySemanticsLabel('is empty'), findsNothing);
    await pick(tester, 'is checked');
    expect(
      applied.single,
      const ViewFilter(fieldId: 'flag', op: FilterOp.isTrue),
    );
    expect(find.byType(PrimaryButton), findsNothing);
  });

  testWidgets('editing a select filter opens at the value step, prefilled', (
    tester,
  ) async {
    await pump(
      tester,
      initial: const ViewFilter(
        fieldId: 'stage',
        op: FilterOp.anyOf,
        operand: ['lost'],
      ),
    );
    expect(find.text('Stage is any of'), findsOneWidget);
    final lost = tester.widget<Checkbox>(
      find.descendant(
        of: find.bySemanticsLabel('Lost'),
        matching: find.byType(Checkbox),
      ),
    );
    expect(lost.value, isTrue);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Stage'), findsOneWidget);
  });

  testWidgets('a filter on a deleted field starts at the field step', (
    tester,
  ) async {
    await pump(
      tester,
      initial: const ViewFilter(fieldId: 'gone', op: FilterOp.isEmpty),
    );
    expect(find.text('Filter by'), findsOneWidget);
  });

  test('dateOperand pads to YYYY-MM-DD', () {
    expect(dateOperand(DateTime(987, 3, 4, 23, 30)), '0987-03-04');
  });
}
