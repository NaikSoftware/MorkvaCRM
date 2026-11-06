import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/features/objects/value_editors/built_in_value_editors.dart';
import 'package:morkva_crm/features/objects/value_editors/field_value_editor.dart';
import 'package:morkva_crm/features/objects/value_editors/number_value_editor.dart';

import 'editor_harness.dart';

Finder get _input => find.byType(TextField).first;

void main() {
  group('registry', () {
    test('every built-in type has an editor', () {
      final registry = defaultValueEditorRegistry();
      for (final type in [
        kTextFieldType,
        kNumberFieldType,
        kBooleanFieldType,
        kDateFieldType,
        kAutoNumberFieldType,
        kCalculatedFieldType,
        kFileFieldType,
      ]) {
        expect(registry.forType(type)?.typeId, type);
      }
      expect(registry.forType('nope'), isNull);
      expect(registry.editorFor(kAutoNumberFieldType).isReadOnly, isTrue);
      expect(registry.editorFor(kBooleanFieldType).rendersOwnLabel, isTrue);
      expect(registry.editorFor(kTextFieldType).rendersOwnLabel, isFalse);
    });

    testWidgets('an unregistered type falls back to a read-only line', (
      tester,
    ) async {
      final registry = FieldValueEditorRegistry();
      expect(registry.editorFor(kFileFieldType).isReadOnly, isTrue);
      final h = EditorHarness(
        const FileFieldDefinition(id: 'f', name: 'Contract'),
        null,
      );
      await h.pump(tester, registry: registry);
      expect(find.text("Can't edit File here"), findsOneWidget);
      final unknown = EditorHarness(const _MysteryField(), null);
      await unknown.pump(tester, registry: FieldValueEditorRegistry());
      expect(find.text("Can't edit mystery here"), findsOneWidget);
    });
  });

  group('text', () {
    testWidgets('round-trips, empty emits null', (tester) async {
      final h = EditorHarness(
        const TextFieldDefinition(id: 'name', name: 'Name'),
        const TextFieldValue('Ann'),
      );
      await h.pump(tester);
      expect(find.text('Ann'), findsOneWidget);

      await tester.enterText(_input, 'Bob');
      expect(h.value, const TextFieldValue('Bob'));
      await tester.enterText(_input, '');
      expect(h.value, const TextFieldValue(null));
    });

    testWidgets('multiline grows 3–8 lines; counter shows n / max', (
      tester,
    ) async {
      final h = EditorHarness(
        const TextFieldDefinition(
          id: 's',
          name: 'Summary',
          multiline: true,
          maxLength: 5,
        ),
        const TextFieldValue('abc'),
      );
      await h.pump(tester);
      final field = tester.widget<TextField>(_input);
      expect((field.minLines, field.maxLines), (3, 8));
      expect(find.text('3 / 5'), findsOneWidget);

      // Not enforced: validation reports the overflow, the counter turns red.
      await tester.enterText(_input, 'abcdefg');
      await tester.pump();
      expect(h.value, const TextFieldValue('abcdefg'));
      final counter = tester.widget<Text>(find.text('7 / 5'));
      final context = tester.element(find.text('7 / 5'));
      expect(counter.style?.color, Theme.of(context).colorScheme.error);
    });

    testWidgets('follows outside changes only while not focused', (
      tester,
    ) async {
      final h = EditorHarness(
        const TextFieldDefinition(id: 'name', name: 'Name'),
        const TextFieldValue('Ann'),
      );
      await h.pump(tester);
      h.value = const TextFieldValue('Remote');
      await h.pump(tester);
      expect(find.text('Remote'), findsOneWidget);
    });

    testWidgets('error shows as a red border without text; disabled is inert', (
      tester,
    ) async {
      final h = EditorHarness(
        const TextFieldDefinition(id: 'name', name: 'Name'),
        null,
      );
      await h.pump(tester, error: 'Name is required', enabled: false);
      final decoration = tester.widget<TextField>(_input).decoration;
      expect(decoration?.error, isNotNull);
      expect(find.text('Name is required'), findsNothing);
      expect(tester.widget<TextField>(_input).enabled, isFalse);
    });
  });

  group('number', () {
    const amount = NumberFieldDefinition(
      id: 'amount',
      name: 'Amount',
      unitLabel: 'USD',
      decimalPlaces: 2,
    );

    test('parses either decimal separator; rejects junk', () {
      expect(parseNumberInput('12,5'), (12.5, true));
      expect(parseNumberInput(' 12.5 '), (12.5, true));
      expect(parseNumberInput('1,234.5'), (1234.5, true));
      expect(parseNumberInput('-7'), (-7, true));
      expect(parseNumberInput(''), (null, true));
      expect(parseNumberInput('12,3a'), (null, false));
      expect(parseNumberInput('NaN'), (null, false));
      expect(parseNumberInput('Infinity'), (null, false));
      expect(parseNumberInput('42').$1, isA<int>());
    });

    testWidgets('shows the stored value and the unit suffix', (tester) async {
      final h = EditorHarness(amount, const NumberFieldValue(52000));
      await h.pump(tester);
      expect(find.text('52000.00'), findsOneWidget);
      expect(find.text('USD'), findsOneWidget);
    });

    testWidgets('typing emits the parsed value and clears the input error', (
      tester,
    ) async {
      final h = EditorHarness(amount, null);
      await h.pump(tester);
      await tester.enterText(_input, '12,3');
      expect(h.value, const NumberFieldValue(12.3));
      expect(h.inputError, isNull);
      expect(h.inputErrors, isNotEmpty);

      await tester.enterText(_input, '');
      expect(h.value, const NumberFieldValue(null));
    });

    testWidgets('junk reports "Enter a number" and keeps the raw text', (
      tester,
    ) async {
      final h = EditorHarness(amount, const NumberFieldValue(5));
      await h.pump(tester);
      await tester.enterText(_input, '12,3a');
      expect(h.inputError, 'Enter a number');
      expect(h.value, const NumberFieldValue(5));
      await blur(tester);
      expect(find.text('12,3a'), findsOneWidget);

      await tester.enterText(_input, '7');
      expect(h.inputError, isNull);
      expect(h.value, const NumberFieldValue(7));
    });

    testWidgets('blur rounds to decimalPlaces and reformats', (tester) async {
      final h = EditorHarness(amount, null);
      await h.pump(tester);
      await tester.enterText(_input, '12.345');
      expect(h.value, const NumberFieldValue(12.345));
      await blur(tester);
      expect(h.value, const NumberFieldValue(12.35));
      expect(find.text('12.35'), findsOneWidget);

      await tester.enterText(_input, '3');
      await blur(tester);
      expect(find.text('3.00'), findsOneWidget);
    });
  });

  group('boolean', () {
    testWidgets('renders its own label and toggles', (tester) async {
      final h = EditorHarness(
        const BooleanFieldDefinition(id: 'paid', name: 'Paid'),
        null,
      );
      await h.pump(tester);
      expect(find.text('Paid'), findsOneWidget);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);

      await tester.tap(find.byType(Switch));
      await tester.pump();
      expect(h.value, const BooleanFieldValue(true));

      await tester.tap(find.text('Paid'));
      await tester.pump();
      expect(h.value, const BooleanFieldValue(false));
    });

    testWidgets('disabled is inert', (tester) async {
      final h = EditorHarness(
        const BooleanFieldDefinition(id: 'paid', name: 'Paid'),
        null,
      );
      await h.pump(tester, enabled: false);
      await tester.tap(find.byType(Switch));
      await tester.tap(find.text('Paid'));
      await tester.pump();
      expect(h.changes, isEmpty);
    });
  });

  group('date', () {
    testWidgets('picks a day as UTC midnight', (tester) async {
      final h = EditorHarness(
        const DateFieldDefinition(id: 'due', name: 'Due'),
        DateFieldValue(DateTime.utc(2026, 11, 14)),
      );
      await h.pump(tester);
      expect(find.text('Nov 14, 2026'), findsOneWidget);

      await tester.tap(find.text('Nov 14, 2026'));
      await tester.pumpAndSettle();
      // Monday-first grid.
      expect(find.text('M').first, findsOneWidget);
      await tester.tap(find.text('20'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(h.value, DateFieldValue(DateTime.utc(2026, 11, 20)));
      expect(find.text('Nov 20, 2026'), findsOneWidget);
    });

    testWidgets('clear button empties the value', (tester) async {
      final h = EditorHarness(
        const DateFieldDefinition(id: 'due', name: 'Due'),
        DateFieldValue(DateTime.utc(2026, 11, 14)),
      );
      await h.pump(tester);
      await tester.tap(find.byTooltip('Clear Due'));
      await tester.pump();
      expect(h.value, const DateFieldValue(null));
      expect(find.byTooltip('Clear Due'), findsNothing);
      expect(find.text('Pick a date'), findsOneWidget);
    });

    testWidgets('min/max bound the picker even when today is outside', (
      tester,
    ) async {
      final h = EditorHarness(
        DateFieldDefinition(
          id: 'due',
          name: 'Due',
          min: DateTime.utc(2030, 3, 10),
          max: DateTime.utc(2030, 3, 20),
        ),
        null,
      );
      await h.pump(tester);
      await tester.tap(find.byType(InputDecorator).first);
      await tester.pumpAndSettle();
      final picker = tester.widget<DatePickerDialog>(
        find.byType(DatePickerDialog),
      );
      expect(picker.firstDate, DateTime(2030, 3, 10));
      expect(picker.lastDate, DateTime(2030, 3, 20));
      expect(picker.initialDate, DateTime(2030, 3, 10));
      await tester.tap(find.text('15'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(h.value, DateFieldValue(DateTime.utc(2030, 3, 15)));
    });

    testWidgets('includeTime asks for a time and stores the instant in UTC', (
      tester,
    ) async {
      final h = EditorHarness(
        const DateFieldDefinition(id: 'at', name: 'At', includeTime: true),
        DateFieldValue(DateTime(2026, 11, 14, 9, 30).toUtc()),
      );
      await h.pump(tester);
      await tester.tap(find.byType(InputDecorator).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.byType(TimePickerDialog), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(h.value, DateFieldValue(DateTime(2026, 11, 14, 9, 30).toUtc()));
      expect(h.changes, hasLength(1));
    });

    testWidgets('disabled does not open the picker', (tester) async {
      final h = EditorHarness(
        const DateFieldDefinition(id: 'due', name: 'Due'),
        null,
      );
      await h.pump(tester, enabled: false);
      await tester.tap(find.byType(InputDecorator).first);
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsNothing);
    });
  });

  group('read-only', () {
    testWidgets('auto_number shows the formatted value or a placeholder', (
      tester,
    ) async {
      const field = AutoNumberFieldDefinition(
        id: 'no',
        name: 'Deal #',
        prefix: 'D-',
        padding: 4,
      );
      final h = EditorHarness(field, const AutoNumberFieldValue(42));
      await h.pump(tester);
      expect(find.text('D-0042'), findsOneWidget);
      expect(find.text('Set automatically'), findsOneWidget);
      expect(find.byType(EditableText), findsOneWidget); // only 'elsewhere'

      final empty = EditorHarness(field, null);
      await empty.pump(tester);
      expect(find.text('Assigned on save'), findsOneWidget);
      await tester.tap(find.text('Assigned on save'));
      await tester.pump();
      expect(empty.changes, isEmpty);
    });

    testWidgets('calculated shows the derived value or a placeholder', (
      tester,
    ) async {
      const field = CalculatedFieldDefinition(
        id: 'total',
        name: 'Total',
        declaredOutputType: kNumberFieldType,
      );
      await EditorHarness(field, const CalculatedFieldValue(7)).pump(tester);
      expect(find.text('7'), findsOneWidget);
      expect(find.text('Calculated'), findsOneWidget);

      await EditorHarness(field, null).pump(tester);
      expect(find.text('Nothing to calculate yet'), findsOneWidget);
    });
  });
}

class _MysteryField extends FieldDefinition {
  const _MysteryField() : super(id: 'm', name: 'Mystery');

  @override
  String get type => 'mystery';

  @override
  Map<String, dynamic> configToJson() => const {};

  @override
  List<Object?> get configProps => const [];

  @override
  FieldValue emptyValue() => const TextFieldValue(null);

  @override
  FieldValue valueFromJson(Object? json) => emptyValue();

  @override
  List<ValidationError> validateValue(FieldValue value) => const [];
}
