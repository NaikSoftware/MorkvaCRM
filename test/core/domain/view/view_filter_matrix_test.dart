import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';

void main() {
  bool m(FieldDefinition f, FilterOp op, Object? operand, FieldValue v) =>
      matchesFilter(ViewFilter(fieldId: f.id, op: op, operand: operand), f, v);

  const textField = TextFieldDefinition(id: 'text_1', name: 'Text Field');
  const numberField = NumberFieldDefinition(id: 'num_1', name: 'Number Field');
  const autoNumberField = AutoNumberFieldDefinition(
    id: 'auto_1',
    name: 'Auto Number Field',
  );
  const dateField = DateFieldDefinition(
    id: 'date_1',
    name: 'Date Field',
    includeTime: false,
  );
  const dateTimeField = DateFieldDefinition(
    id: 'date_2',
    name: 'Date Time Field',
    includeTime: true,
  );
  const singleSelectField = SingleSelectFieldDefinition(
    id: 'single_1',
    name: 'Single Select Field',
    options: [
      SelectOption(id: 'o1', label: 'Option 1'),
      SelectOption(id: 'o2', label: 'Option 2'),
      SelectOption(id: 'o3', label: 'Option 3'),
    ],
  );
  const multiSelectField = MultiSelectFieldDefinition(
    id: 'multi_1',
    name: 'Multi Select Field',
    options: [
      SelectOption(id: 'o1', label: 'Option 1'),
      SelectOption(id: 'o2', label: 'Option 2'),
      SelectOption(id: 'o3', label: 'Option 3'),
    ],
  );
  const booleanField = BooleanFieldDefinition(
    id: 'bool_1',
    name: 'Boolean Field',
  );
  const referenceField = ReferenceFieldDefinition(
    id: 'ref_1',
    name: 'Reference Field',
    targetCollectionId: 'c2',
    multiple: false,
  );
  const fileField = FileFieldDefinition(id: 'file_1', name: 'File Field');
  const calculatedField = CalculatedFieldDefinition(
    id: 'calc_1',
    name: 'Calculated Field',
    declaredOutputType: 'number',
  );

  group('operatorsFor', () {
    test('text: [contains, notContains, equals, isEmpty, isNotEmpty]', () {
      expect(operatorsFor(textField), [
        FilterOp.contains,
        FilterOp.notContains,
        FilterOp.equals,
        FilterOp.isEmpty,
        FilterOp.isNotEmpty,
      ]);
    });

    test(
      'number and auto_number: [equals, notEquals, greaterThan, lessThan, isEmpty, isNotEmpty]',
      () {
        const expected = [
          FilterOp.equals,
          FilterOp.notEquals,
          FilterOp.greaterThan,
          FilterOp.lessThan,
          FilterOp.isEmpty,
          FilterOp.isNotEmpty,
        ];
        expect(operatorsFor(numberField), expected);
        expect(operatorsFor(autoNumberField), expected);
      },
    );

    test('date: [before, after, onDay, isEmpty, isNotEmpty]', () {
      const expected = [
        FilterOp.before,
        FilterOp.after,
        FilterOp.onDay,
        FilterOp.isEmpty,
        FilterOp.isNotEmpty,
      ];
      expect(operatorsFor(dateField), expected);
      expect(operatorsFor(dateTimeField), expected);
    });

    test(
      'single_select and multi_select: [anyOf, noneOf, isEmpty, isNotEmpty]',
      () {
        const expected = [
          FilterOp.anyOf,
          FilterOp.noneOf,
          FilterOp.isEmpty,
          FilterOp.isNotEmpty,
        ];
        expect(operatorsFor(singleSelectField), expected);
        expect(operatorsFor(multiSelectField), expected);
      },
    );

    test('boolean: [isTrue, isFalse]', () {
      expect(operatorsFor(booleanField), [FilterOp.isTrue, FilterOp.isFalse]);
    });

    test('reference: [anyOf, isEmpty, isNotEmpty]', () {
      expect(operatorsFor(referenceField), [
        FilterOp.anyOf,
        FilterOp.isEmpty,
        FilterOp.isNotEmpty,
      ]);
    });

    test('file: [isEmpty, isNotEmpty]', () {
      expect(operatorsFor(fileField), [FilterOp.isEmpty, FilterOp.isNotEmpty]);
    });

    test('calculated: the operators of its output type', () {
      expect(
        operatorsFor(calculatedField),
        operatorsFor(const NumberFieldDefinition(id: 'n', name: 'N')),
      );
    });
  });

  group('TextFieldDefinition matches', () {
    const matchingNonEmpty = TextFieldValue('Hello World');
    const nonMatchingNonEmpty = TextFieldValue('Hello Universe');
    const emptyText = TextFieldValue('');
    const nullText = TextFieldValue(null);

    test('contains operator', () {
      expect(
        m(textField, FilterOp.contains, 'world', matchingNonEmpty),
        isTrue,
      );
      expect(
        m(textField, FilterOp.contains, 'world', nonMatchingNonEmpty),
        isFalse,
      );
      expect(m(textField, FilterOp.contains, 'world', emptyText), isFalse);
      expect(m(textField, FilterOp.contains, 'world', nullText), isFalse);
    });

    test('notContains operator', () {
      expect(
        m(textField, FilterOp.notContains, 'world', nonMatchingNonEmpty),
        isTrue,
      );
      expect(
        m(textField, FilterOp.notContains, 'world', matchingNonEmpty),
        isFalse,
      );
      expect(m(textField, FilterOp.notContains, 'world', emptyText), isTrue);
      expect(m(textField, FilterOp.notContains, 'world', nullText), isTrue);
    });

    test('equals operator (case-insensitive)', () {
      expect(
        m(textField, FilterOp.equals, 'hello world', matchingNonEmpty),
        isTrue,
      );
      expect(
        m(textField, FilterOp.equals, 'hello', nonMatchingNonEmpty),
        isFalse,
      );
      expect(m(textField, FilterOp.equals, 'hello', emptyText), isFalse);
      expect(m(textField, FilterOp.equals, 'hello', nullText), isFalse);
    });

    test('isEmpty operator', () {
      expect(m(textField, FilterOp.isEmpty, null, emptyText), isTrue);
      expect(m(textField, FilterOp.isEmpty, null, nullText), isTrue);
      expect(m(textField, FilterOp.isEmpty, null, matchingNonEmpty), isFalse);
    });

    test('isNotEmpty operator', () {
      expect(m(textField, FilterOp.isNotEmpty, null, matchingNonEmpty), isTrue);
      expect(m(textField, FilterOp.isNotEmpty, null, emptyText), isFalse);
      expect(m(textField, FilterOp.isNotEmpty, null, nullText), isFalse);
    });

    test(
      'inapplicable operators are ignored for empty and non-empty values',
      () {
        final applicable = operatorsFor(textField).toSet();
        for (final op in FilterOp.values.where(
          (o) => !applicable.contains(o),
        )) {
          expect(
            m(textField, op, 'operand', matchingNonEmpty),
            isTrue,
            reason: '$op should pass for non-empty text',
          );
          expect(
            m(textField, op, 'operand', emptyText),
            isTrue,
            reason: '$op should pass for empty text',
          );
          expect(
            m(textField, op, 'operand', nullText),
            isTrue,
            reason: '$op should pass for null text',
          );
        }
      },
    );
  });

  group('NumberFieldDefinition matches', () {
    const matchingNonEmpty = NumberFieldValue(5);
    const nonMatchingNonEmpty = NumberFieldValue(10);
    const emptyValue = NumberFieldValue(null);

    test('equals operator (num equality, 5 == 5.0)', () {
      expect(m(numberField, FilterOp.equals, 5, matchingNonEmpty), isTrue);
      expect(m(numberField, FilterOp.equals, 5.0, matchingNonEmpty), isTrue);
      expect(m(numberField, FilterOp.equals, 5, nonMatchingNonEmpty), isFalse);
      expect(m(numberField, FilterOp.equals, 5, emptyValue), isFalse);
    });

    test('notEquals operator', () {
      expect(
        m(numberField, FilterOp.notEquals, 5, nonMatchingNonEmpty),
        isTrue,
      );
      expect(m(numberField, FilterOp.notEquals, 5, matchingNonEmpty), isFalse);
      expect(m(numberField, FilterOp.notEquals, 5, emptyValue), isTrue);
    });

    test('greaterThan operator (strict)', () {
      expect(
        m(numberField, FilterOp.greaterThan, 5, const NumberFieldValue(6)),
        isTrue,
      );
      expect(
        m(numberField, FilterOp.greaterThan, 5, matchingNonEmpty),
        isFalse,
      );
      expect(
        m(numberField, FilterOp.greaterThan, 5, const NumberFieldValue(4)),
        isFalse,
      );
      expect(m(numberField, FilterOp.greaterThan, 5, emptyValue), isFalse);
    });

    test('lessThan operator (strict)', () {
      expect(
        m(numberField, FilterOp.lessThan, 5, const NumberFieldValue(4)),
        isTrue,
      );
      expect(m(numberField, FilterOp.lessThan, 5, matchingNonEmpty), isFalse);
      expect(
        m(numberField, FilterOp.lessThan, 5, const NumberFieldValue(6)),
        isFalse,
      );
      expect(m(numberField, FilterOp.lessThan, 5, emptyValue), isFalse);
    });

    test('isEmpty operator', () {
      expect(m(numberField, FilterOp.isEmpty, null, emptyValue), isTrue);
      expect(m(numberField, FilterOp.isEmpty, null, matchingNonEmpty), isFalse);
      expect(
        m(numberField, FilterOp.isEmpty, null, const NumberFieldValue(0)),
        isFalse,
      );
    });

    test('isNotEmpty operator', () {
      expect(
        m(numberField, FilterOp.isNotEmpty, null, matchingNonEmpty),
        isTrue,
      );
      expect(
        m(numberField, FilterOp.isNotEmpty, null, const NumberFieldValue(0)),
        isTrue,
      );
      expect(m(numberField, FilterOp.isNotEmpty, null, emptyValue), isFalse);
    });

    test(
      'inapplicable operators are ignored for empty and non-empty values',
      () {
        final applicable = operatorsFor(numberField).toSet();
        for (final op in FilterOp.values.where(
          (o) => !applicable.contains(o),
        )) {
          expect(
            m(numberField, op, 5, matchingNonEmpty),
            isTrue,
            reason: '$op should pass for non-empty number',
          );
          expect(
            m(numberField, op, 5, emptyValue),
            isTrue,
            reason: '$op should pass for empty number',
          );
        }
      },
    );
  });

  group('AutoNumberFieldDefinition matches', () {
    const matchingNonEmpty = AutoNumberFieldValue(5);
    const nonMatchingNonEmpty = AutoNumberFieldValue(10);
    const emptyValue = AutoNumberFieldValue(null);

    test('equals operator', () {
      expect(m(autoNumberField, FilterOp.equals, 5, matchingNonEmpty), isTrue);
      expect(
        m(autoNumberField, FilterOp.equals, 5, nonMatchingNonEmpty),
        isFalse,
      );
      expect(m(autoNumberField, FilterOp.equals, 5, emptyValue), isFalse);
    });

    test('notEquals operator', () {
      expect(
        m(autoNumberField, FilterOp.notEquals, 5, nonMatchingNonEmpty),
        isTrue,
      );
      expect(
        m(autoNumberField, FilterOp.notEquals, 5, matchingNonEmpty),
        isFalse,
      );
      expect(m(autoNumberField, FilterOp.notEquals, 5, emptyValue), isTrue);
    });

    test('greaterThan operator (strict)', () {
      expect(
        m(
          autoNumberField,
          FilterOp.greaterThan,
          5,
          const AutoNumberFieldValue(6),
        ),
        isTrue,
      );
      expect(
        m(autoNumberField, FilterOp.greaterThan, 5, matchingNonEmpty),
        isFalse,
      );
      expect(
        m(
          autoNumberField,
          FilterOp.greaterThan,
          5,
          const AutoNumberFieldValue(4),
        ),
        isFalse,
      );
      expect(m(autoNumberField, FilterOp.greaterThan, 5, emptyValue), isFalse);
    });

    test('lessThan operator (strict)', () {
      expect(
        m(autoNumberField, FilterOp.lessThan, 5, const AutoNumberFieldValue(4)),
        isTrue,
      );
      expect(
        m(autoNumberField, FilterOp.lessThan, 5, matchingNonEmpty),
        isFalse,
      );
      expect(
        m(autoNumberField, FilterOp.lessThan, 5, const AutoNumberFieldValue(6)),
        isFalse,
      );
      expect(m(autoNumberField, FilterOp.lessThan, 5, emptyValue), isFalse);
    });

    test('isEmpty operator', () {
      expect(m(autoNumberField, FilterOp.isEmpty, null, emptyValue), isTrue);
      expect(
        m(autoNumberField, FilterOp.isEmpty, null, matchingNonEmpty),
        isFalse,
      );
    });

    test('isNotEmpty operator', () {
      expect(
        m(autoNumberField, FilterOp.isNotEmpty, null, matchingNonEmpty),
        isTrue,
      );
      expect(
        m(autoNumberField, FilterOp.isNotEmpty, null, emptyValue),
        isFalse,
      );
    });

    test(
      'inapplicable operators are ignored for empty and non-empty values',
      () {
        final applicable = operatorsFor(autoNumberField).toSet();
        for (final op in FilterOp.values.where(
          (o) => !applicable.contains(o),
        )) {
          expect(
            m(autoNumberField, op, 5, matchingNonEmpty),
            isTrue,
            reason: '$op should pass for non-empty auto_number',
          );
          expect(
            m(autoNumberField, op, 5, emptyValue),
            isTrue,
            reason: '$op should pass for empty auto_number',
          );
        }
      },
    );
  });

  group('DateFieldDefinition matches', () {
    const emptyValue = DateFieldValue(null);

    group('includeTime: false (stored UTC, UTC day)', () {
      final matchingValue = DateFieldValue(DateTime.utc(2026, 3, 10));
      final otherDayValue = DateFieldValue(DateTime.utc(2026, 3, 11));

      test('onDay operator', () {
        expect(
          m(dateField, FilterOp.onDay, '2026-03-10', matchingValue),
          isTrue,
        );
        expect(
          m(dateField, FilterOp.onDay, '2026-03-10', otherDayValue),
          isFalse,
        );
        expect(m(dateField, FilterOp.onDay, '2026-03-10', emptyValue), isFalse);
      });

      test('before operator', () {
        expect(
          m(dateField, FilterOp.before, '2026-03-11', matchingValue),
          isTrue,
        );
        expect(
          m(dateField, FilterOp.before, '2026-03-10', matchingValue),
          isFalse,
        );
        expect(
          m(dateField, FilterOp.before, '2026-03-11', emptyValue),
          isFalse,
        );
      });

      test('after operator', () {
        expect(
          m(dateField, FilterOp.after, '2026-03-09', matchingValue),
          isTrue,
        );
        expect(
          m(dateField, FilterOp.after, '2026-03-10', matchingValue),
          isFalse,
        );
        expect(m(dateField, FilterOp.after, '2026-03-09', emptyValue), isFalse);
      });

      test('isEmpty operator', () {
        expect(m(dateField, FilterOp.isEmpty, null, emptyValue), isTrue);
        expect(m(dateField, FilterOp.isEmpty, null, matchingValue), isFalse);
      });

      test('isNotEmpty operator', () {
        expect(m(dateField, FilterOp.isNotEmpty, null, matchingValue), isTrue);
        expect(m(dateField, FilterOp.isNotEmpty, null, emptyValue), isFalse);
      });
    });

    group('includeTime: true (local time -> UTC, timezone-agnostic)', () {
      final matchingValue = DateFieldValue(
        DateTime(2026, 3, 10, 23, 30).toUtc(),
      );
      final otherDayValue = DateFieldValue(DateTime(2026, 3, 11, 8, 0).toUtc());

      test('onDay operator', () {
        expect(
          m(dateTimeField, FilterOp.onDay, '2026-03-10', matchingValue),
          isTrue,
        );
        expect(
          m(dateTimeField, FilterOp.onDay, '2026-03-10', otherDayValue),
          isFalse,
        );
        expect(
          m(dateTimeField, FilterOp.onDay, '2026-03-10', emptyValue),
          isFalse,
        );
      });

      test('before operator', () {
        expect(
          m(dateTimeField, FilterOp.before, '2026-03-11', matchingValue),
          isTrue,
        );
        expect(
          m(dateTimeField, FilterOp.before, '2026-03-10', matchingValue),
          isFalse,
        );
        expect(
          m(dateTimeField, FilterOp.before, '2026-03-11', emptyValue),
          isFalse,
        );
      });

      test('after operator', () {
        expect(
          m(dateTimeField, FilterOp.after, '2026-03-09', matchingValue),
          isTrue,
        );
        expect(
          m(dateTimeField, FilterOp.after, '2026-03-10', matchingValue),
          isFalse,
        );
        expect(
          m(dateTimeField, FilterOp.after, '2026-03-09', emptyValue),
          isFalse,
        );
      });

      test('isEmpty operator', () {
        expect(m(dateTimeField, FilterOp.isEmpty, null, emptyValue), isTrue);
        expect(
          m(dateTimeField, FilterOp.isEmpty, null, matchingValue),
          isFalse,
        );
      });

      test('isNotEmpty operator', () {
        expect(
          m(dateTimeField, FilterOp.isNotEmpty, null, matchingValue),
          isTrue,
        );
        expect(
          m(dateTimeField, FilterOp.isNotEmpty, null, emptyValue),
          isFalse,
        );
      });
    });

    test(
      'inapplicable operators are ignored for empty and non-empty values',
      () {
        final applicable = operatorsFor(dateField).toSet();
        final nonNullVal = DateFieldValue(DateTime.utc(2026, 3, 10));
        for (final op in FilterOp.values.where(
          (o) => !applicable.contains(o),
        )) {
          expect(
            m(dateField, op, '2026-03-10', nonNullVal),
            isTrue,
            reason: '$op should pass for non-empty date',
          );
          expect(
            m(dateField, op, '2026-03-10', emptyValue),
            isTrue,
            reason: '$op should pass for empty date',
          );
        }
      },
    );
  });

  group('SingleSelectFieldDefinition matches', () {
    const matchingNonEmpty = SingleSelectFieldValue('o1');
    const nonMatchingNonEmpty = SingleSelectFieldValue('o3');
    const nullSelect = SingleSelectFieldValue(null);
    const emptySelect = SingleSelectFieldValue('');

    test('anyOf operator', () {
      const operand = ['o1', 'o2'];
      expect(
        m(singleSelectField, FilterOp.anyOf, operand, matchingNonEmpty),
        isTrue,
      );
      expect(
        m(singleSelectField, FilterOp.anyOf, operand, nonMatchingNonEmpty),
        isFalse,
      );
      expect(
        m(singleSelectField, FilterOp.anyOf, operand, nullSelect),
        isFalse,
      );
      expect(
        m(singleSelectField, FilterOp.anyOf, operand, emptySelect),
        isFalse,
      );
    });

    test('noneOf operator', () {
      const operand = ['o1', 'o2'];
      expect(
        m(singleSelectField, FilterOp.noneOf, operand, nonMatchingNonEmpty),
        isTrue,
      );
      expect(
        m(singleSelectField, FilterOp.noneOf, operand, matchingNonEmpty),
        isFalse,
      );
      expect(
        m(singleSelectField, FilterOp.noneOf, operand, nullSelect),
        isTrue,
      );
      expect(
        m(singleSelectField, FilterOp.noneOf, operand, emptySelect),
        isTrue,
      );
    });

    test('isEmpty operator', () {
      expect(m(singleSelectField, FilterOp.isEmpty, null, nullSelect), isTrue);
      expect(m(singleSelectField, FilterOp.isEmpty, null, emptySelect), isTrue);
      expect(
        m(singleSelectField, FilterOp.isEmpty, null, matchingNonEmpty),
        isFalse,
      );
    });

    test('isNotEmpty operator', () {
      expect(
        m(singleSelectField, FilterOp.isNotEmpty, null, matchingNonEmpty),
        isTrue,
      );
      expect(
        m(singleSelectField, FilterOp.isNotEmpty, null, nullSelect),
        isFalse,
      );
      expect(
        m(singleSelectField, FilterOp.isNotEmpty, null, emptySelect),
        isFalse,
      );
    });

    test(
      'inapplicable operators are ignored for empty and non-empty values',
      () {
        final applicable = operatorsFor(singleSelectField).toSet();
        for (final op in FilterOp.values.where(
          (o) => !applicable.contains(o),
        )) {
          expect(
            m(singleSelectField, op, const ['o1'], matchingNonEmpty),
            isTrue,
            reason: '$op should pass for non-empty single_select',
          );
          expect(
            m(singleSelectField, op, const ['o1'], nullSelect),
            isTrue,
            reason: '$op should pass for null single_select',
          );
          expect(
            m(singleSelectField, op, const ['o1'], emptySelect),
            isTrue,
            reason: '$op should pass for empty-string single_select',
          );
        }
      },
    );
  });

  group('MultiSelectFieldDefinition matches', () {
    const matchingNonEmpty = MultiSelectFieldValue(['o1']);
    const partiallyMatchingNonEmpty = MultiSelectFieldValue(['o1', 'o3']);
    const nonMatchingNonEmpty = MultiSelectFieldValue(['o3']);
    const emptyValue = MultiSelectFieldValue([]);

    test('anyOf operator', () {
      const operand = ['o1', 'o2'];
      expect(
        m(multiSelectField, FilterOp.anyOf, operand, matchingNonEmpty),
        isTrue,
      );
      expect(
        m(multiSelectField, FilterOp.anyOf, operand, partiallyMatchingNonEmpty),
        isTrue,
      );
      expect(
        m(multiSelectField, FilterOp.anyOf, operand, nonMatchingNonEmpty),
        isFalse,
      );
      expect(m(multiSelectField, FilterOp.anyOf, operand, emptyValue), isFalse);
    });

    test('noneOf operator', () {
      const operand = ['o1', 'o2'];
      expect(
        m(multiSelectField, FilterOp.noneOf, operand, nonMatchingNonEmpty),
        isTrue,
      );
      expect(
        m(
          multiSelectField,
          FilterOp.noneOf,
          operand,
          partiallyMatchingNonEmpty,
        ),
        isFalse,
      );
      expect(
        m(multiSelectField, FilterOp.noneOf, operand, matchingNonEmpty),
        isFalse,
      );
      expect(m(multiSelectField, FilterOp.noneOf, operand, emptyValue), isTrue);
    });

    test('isEmpty operator', () {
      expect(m(multiSelectField, FilterOp.isEmpty, null, emptyValue), isTrue);
      expect(
        m(multiSelectField, FilterOp.isEmpty, null, matchingNonEmpty),
        isFalse,
      );
    });

    test('isNotEmpty operator', () {
      expect(
        m(multiSelectField, FilterOp.isNotEmpty, null, matchingNonEmpty),
        isTrue,
      );
      expect(
        m(multiSelectField, FilterOp.isNotEmpty, null, emptyValue),
        isFalse,
      );
    });

    test(
      'inapplicable operators are ignored for empty and non-empty values',
      () {
        final applicable = operatorsFor(multiSelectField).toSet();
        for (final op in FilterOp.values.where(
          (o) => !applicable.contains(o),
        )) {
          expect(
            m(multiSelectField, op, const ['o1'], matchingNonEmpty),
            isTrue,
            reason: '$op should pass for non-empty multi_select',
          );
          expect(
            m(multiSelectField, op, const ['o1'], emptyValue),
            isTrue,
            reason: '$op should pass for empty multi_select',
          );
        }
      },
    );
  });

  group('BooleanFieldDefinition matches', () {
    const trueValue = BooleanFieldValue(true);
    const falseValue = BooleanFieldValue(false);
    const nullValue = BooleanFieldValue(null);

    test('isTrue operator', () {
      expect(m(booleanField, FilterOp.isTrue, null, trueValue), isTrue);
      expect(m(booleanField, FilterOp.isTrue, null, falseValue), isFalse);
      expect(m(booleanField, FilterOp.isTrue, null, nullValue), isFalse);
    });

    test('isFalse operator (null isFalse = true)', () {
      expect(m(booleanField, FilterOp.isFalse, null, falseValue), isTrue);
      expect(m(booleanField, FilterOp.isFalse, null, trueValue), isFalse);
      expect(m(booleanField, FilterOp.isFalse, null, nullValue), isTrue);
    });

    test(
      'inapplicable operators are ignored for empty and non-empty values',
      () {
        final applicable = operatorsFor(booleanField).toSet();
        for (final op in FilterOp.values.where(
          (o) => !applicable.contains(o),
        )) {
          expect(
            m(booleanField, op, null, trueValue),
            isTrue,
            reason: '$op should pass for true boolean',
          );
          expect(
            m(booleanField, op, null, falseValue),
            isTrue,
            reason: '$op should pass for false boolean',
          );
          expect(
            m(booleanField, op, null, nullValue),
            isTrue,
            reason: '$op should pass for null boolean',
          );
        }
      },
    );
  });

  group('ReferenceFieldDefinition matches', () {
    const matchingNonEmpty = ReferenceFieldValue(['c2_1']);
    const nonMatchingNonEmpty = ReferenceFieldValue(['c2_3']);
    const emptyValue = ReferenceFieldValue([]);

    test('anyOf operator', () {
      const operand = ['c2_1', 'c2_2'];
      expect(
        m(referenceField, FilterOp.anyOf, operand, matchingNonEmpty),
        isTrue,
      );
      expect(
        m(referenceField, FilterOp.anyOf, operand, nonMatchingNonEmpty),
        isFalse,
      );
      expect(m(referenceField, FilterOp.anyOf, operand, emptyValue), isFalse);
    });

    test('isEmpty operator', () {
      expect(m(referenceField, FilterOp.isEmpty, null, emptyValue), isTrue);
      expect(
        m(referenceField, FilterOp.isEmpty, null, matchingNonEmpty),
        isFalse,
      );
    });

    test('isNotEmpty operator', () {
      expect(
        m(referenceField, FilterOp.isNotEmpty, null, matchingNonEmpty),
        isTrue,
      );
      expect(m(referenceField, FilterOp.isNotEmpty, null, emptyValue), isFalse);
    });

    test(
      'inapplicable operators are ignored for empty and non-empty values',
      () {
        final applicable = operatorsFor(referenceField).toSet();
        for (final op in FilterOp.values.where(
          (o) => !applicable.contains(o),
        )) {
          expect(
            m(referenceField, op, const ['c2_1'], matchingNonEmpty),
            isTrue,
            reason: '$op should pass for non-empty reference',
          );
          expect(
            m(referenceField, op, const ['c2_1'], emptyValue),
            isTrue,
            reason: '$op should pass for empty reference',
          );
        }
      },
    );
  });

  group('FileFieldDefinition matches', () {
    const matchingNonEmpty = FileFieldValue([
      FileAttachment(id: 'a1', name: 'x.pdf'),
    ]);
    const emptyValue = FileFieldValue([]);

    test('isEmpty operator', () {
      expect(m(fileField, FilterOp.isEmpty, null, emptyValue), isTrue);
      expect(m(fileField, FilterOp.isEmpty, null, matchingNonEmpty), isFalse);
    });

    test('isNotEmpty operator', () {
      expect(m(fileField, FilterOp.isNotEmpty, null, matchingNonEmpty), isTrue);
      expect(m(fileField, FilterOp.isNotEmpty, null, emptyValue), isFalse);
    });

    test(
      'inapplicable operators are ignored for empty and non-empty values',
      () {
        final applicable = operatorsFor(fileField).toSet();
        for (final op in FilterOp.values.where(
          (o) => !applicable.contains(o),
        )) {
          expect(
            m(fileField, op, null, matchingNonEmpty),
            isTrue,
            reason: '$op should pass for non-empty file',
          );
          expect(
            m(fileField, op, null, emptyValue),
            isTrue,
            reason: '$op should pass for empty file',
          );
        }
      },
    );
  });

  group('CalculatedFieldDefinition matches', () {
    const matchingNonEmpty = CalculatedFieldValue(3);
    const emptyValue = CalculatedFieldValue(null);

    test('isEmpty operator', () {
      expect(m(calculatedField, FilterOp.isEmpty, null, emptyValue), isTrue);
      expect(
        m(calculatedField, FilterOp.isEmpty, null, matchingNonEmpty),
        isFalse,
      );
    });

    test('isNotEmpty operator', () {
      expect(
        m(calculatedField, FilterOp.isNotEmpty, null, matchingNonEmpty),
        isTrue,
      );
      expect(
        m(calculatedField, FilterOp.isNotEmpty, null, emptyValue),
        isFalse,
      );
    });

    test(
      'inapplicable operators are ignored for empty and non-empty values',
      () {
        final applicable = operatorsFor(calculatedField).toSet();
        for (final op in FilterOp.values.where(
          (o) => !applicable.contains(o),
        )) {
          expect(
            m(calculatedField, op, null, matchingNonEmpty),
            isTrue,
            reason: '$op should pass for non-empty calculated',
          );
          expect(
            m(calculatedField, op, null, emptyValue),
            isTrue,
            reason: '$op should pass for empty calculated',
          );
        }
      },
    );
  });

  group('Malformed operands & dynamic lists', () {
    test('text contains with operand 42 -> true', () {
      expect(
        m(
          textField,
          FilterOp.contains,
          42,
          const TextFieldValue('Hello World'),
        ),
        isTrue,
      );
      expect(
        m(textField, FilterOp.contains, 42, const TextFieldValue('')),
        isTrue,
      );
      expect(
        m(textField, FilterOp.contains, 42, const TextFieldValue(null)),
        isTrue,
      );
    });

    test('number equals with operand "x" -> true', () {
      expect(
        m(numberField, FilterOp.equals, 'x', const NumberFieldValue(5)),
        isTrue,
      );
      expect(
        m(numberField, FilterOp.equals, 'x', const NumberFieldValue(null)),
        isTrue,
      );
    });

    test('number greaterThan with operand null -> true', () {
      expect(
        m(numberField, FilterOp.greaterThan, null, const NumberFieldValue(5)),
        isTrue,
      );
      expect(
        m(
          numberField,
          FilterOp.greaterThan,
          null,
          const NumberFieldValue(null),
        ),
        isTrue,
      );
    });

    test('date onDay with operand "not a date" -> true', () {
      expect(
        m(
          dateField,
          FilterOp.onDay,
          'not a date',
          DateFieldValue(DateTime.utc(2026, 3, 10)),
        ),
        isTrue,
      );
      expect(
        m(dateField, FilterOp.onDay, 'not a date', const DateFieldValue(null)),
        isTrue,
      );
    });

    test('single_select anyOf with operand "o1" (String not List) -> true', () {
      expect(
        m(
          singleSelectField,
          FilterOp.anyOf,
          'o1',
          const SingleSelectFieldValue('o1'),
        ),
        isTrue,
      );
      expect(
        m(
          singleSelectField,
          FilterOp.anyOf,
          'o1',
          const SingleSelectFieldValue(null),
        ),
        isTrue,
      );
    });

    test('anyOf with operand as List<dynamic> works like List<String>', () {
      final dynamicList = <dynamic>['o1', 'o2'];

      // single_select
      expect(
        m(
          singleSelectField,
          FilterOp.anyOf,
          dynamicList,
          const SingleSelectFieldValue('o1'),
        ),
        isTrue,
      );
      expect(
        m(
          singleSelectField,
          FilterOp.anyOf,
          dynamicList,
          const SingleSelectFieldValue('o3'),
        ),
        isFalse,
      );
      expect(
        m(
          singleSelectField,
          FilterOp.anyOf,
          dynamicList,
          const SingleSelectFieldValue(null),
        ),
        isFalse,
      );

      // multi_select
      expect(
        m(
          multiSelectField,
          FilterOp.anyOf,
          dynamicList,
          const MultiSelectFieldValue(['o1']),
        ),
        isTrue,
      );
      expect(
        m(
          multiSelectField,
          FilterOp.anyOf,
          dynamicList,
          const MultiSelectFieldValue(['o3']),
        ),
        isFalse,
      );
      expect(
        m(
          multiSelectField,
          FilterOp.anyOf,
          dynamicList,
          const MultiSelectFieldValue([]),
        ),
        isFalse,
      );

      // reference
      final refDynamicList = <dynamic>['c2_1'];
      expect(
        m(
          referenceField,
          FilterOp.anyOf,
          refDynamicList,
          const ReferenceFieldValue(['c2_1']),
        ),
        isTrue,
      );
      expect(
        m(
          referenceField,
          FilterOp.anyOf,
          refDynamicList,
          const ReferenceFieldValue(['c2_2']),
        ),
        isFalse,
      );
      expect(
        m(
          referenceField,
          FilterOp.anyOf,
          refDynamicList,
          const ReferenceFieldValue([]),
        ),
        isFalse,
      );
    });
  });
}
