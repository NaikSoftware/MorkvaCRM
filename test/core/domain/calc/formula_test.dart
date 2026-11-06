import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';

const _fields = <FieldDefinition>[
  NumberFieldDefinition(id: 'price', name: 'Price'),
  NumberFieldDefinition(id: 'qty', name: 'Quantity'),
  TextFieldDefinition(id: 'name', name: 'Name'),
  BooleanFieldDefinition(id: 'paid', name: 'Paid'),
  DateFieldDefinition(id: 'due', name: 'Due'),
  DateFieldDefinition(id: 'start', name: 'Start'),
  SingleSelectFieldDefinition(
    id: 'stage',
    name: 'Stage',
    options: [SelectOption(id: 'won', label: 'Won')],
  ),
  ReferenceFieldDefinition(id: 'ref', name: 'Item', targetCollectionId: 'x'),
  CalculatedFieldDefinition(
    id: 'total',
    name: 'Total',
    declaredOutputType: 'number',
  ),
];

Object? _eval(String source, Map<String, Object?> values) {
  final r = compileFormula(source, _fields, selfId: 'self');
  expect(r.error, isNull, reason: r.error?.message);
  return r.formula!.evaluate((id) => values[id], today: DateTime(2026, 3, 10));
}

FormulaError _error(String source) {
  final r = compileFormula(source, _fields, selfId: 'total');
  expect(r.formula, isNull);
  return r.error!;
}

void main() {
  group('evaluate', () {
    test('arithmetic with precedence and brackets', () {
      expect(_eval('{Price} * {Quantity}', {'price': 12.5, 'qty': 4}), 50);
      expect(_eval('1 + 2 * 3', {}), 7);
      expect(_eval('(1 + 2) * 3', {}), 9);
      expect(_eval('-{Price} + 1', {'price': 3}), -2);
      expect(_eval('7 / 2', {}), 3.5);
      expect(_eval('6 / 2', {}), 3);
    });

    test('refs resolve by id or by name, case-insensitive', () {
      expect(_eval('{price} + {QUANTITY}', {'price': 1, 'qty': 2}), 3);
    });

    test('blank fields read as 0, but all-blank is blank', () {
      expect(_eval('{Price} + {Quantity}', {'price': 5}), 5);
      expect(_eval('{Price} * {Quantity}', {}), isNull);
      expect(_eval('2 + 3', {}), 5);
    });

    test('division by zero is blank', () {
      expect(_eval('{Price} / {Quantity}', {'price': 5, 'qty': 0}), isNull);
    });

    test('text join and functions', () {
      expect(
        _eval('{Name} & " #" & {Quantity}', {'name': 'Hoodie', 'qty': 3}),
        'Hoodie #3',
      );
      expect(_eval('UPPER({Name})', {'name': 'ab'}), 'AB');
      expect(_eval('LEN({Name})', {'name': 'abc'}), 3);
      expect(_eval('CONCAT({Stage}, "!")', {'stage': 'Won'}), 'Won!');
    });

    test('IF, comparisons and logic', () {
      expect(_eval('IF({Price} > 10, "big", "small")', {'price': 11}), 'big');
      expect(_eval('IF({Paid}, 1, 0)', {'paid': false, 'price': 1}), 0);
      expect(_eval('AND({Price} >= 1, NOT({Paid}))', {'price': 1}), true);
      expect(_eval('{Name} = "x"', {'name': 'X'}), false);
    });

    test('rounding and min/max', () {
      expect(_eval('ROUND({Price}, 2)', {'price': 1.23456}), 1.23);
      expect(_eval('ROUND({Price})', {'price': 2.5}), 3);
      expect(_eval('MAX({Price}, {Quantity}, 4)', {'price': 1, 'qty': 9}), 9);
      expect(_eval('FLOOR(2.7) + CEIL(2.1) + ABS(-1)', {}), 6);
    });

    test('dates: shift by days, difference in days, parts', () {
      final due = DateTime.utc(2026, 3, 20);
      final start = DateTime.utc(2026, 3, 1);
      expect(_eval('{Due} + 7', {'due': due}), DateTime.utc(2026, 3, 27));
      expect(_eval('{Due} - {Start}', {'due': due, 'start': start}), 19);
      expect(_eval('{Due} - TODAY()', {'due': due}), 10);
      expect(_eval('MONTH({Due})', {'due': due}), 3);
      expect(_eval('{Due} > {Start}', {'due': due, 'start': start}), true);
      expect(_eval('{Due} + 1', {'start': start}), isNull);
    });

    test('ISBLANK sees the raw value', () {
      expect(_eval('ISBLANK({Name})', {'price': 1}), true);
      expect(_eval('ISBLANK({Name})', {'name': 'a'}), false);
    });
  });

  group('errors', () {
    test('unknown field and function', () {
      expect(_error('{Nope} + 1').message, contains('No field named "Nope"'));
      expect(_error('SUMX(1)').message, contains('Unknown function'));
      expect(_error('Price * 2').message, contains('{Price}'));
    });

    test('type errors name the types', () {
      expect(_error('{Name} + 1').message, 'Use & to join text');
      expect(_error('{Paid} * 2').message, contains('Yes / No and Number'));
      expect(_error('IF(1, 2, 3)').message, contains('condition'));
      expect(_error('ROUND()').message, contains('ROUND(number, digits)'));
    });

    test('reference fields point to aggregates', () {
      expect(_error('{Item}').message, contains('Aggregate'));
    });

    test('a field cannot read itself', () {
      expect(_error('{Total} + 1').message, contains('own field'));
    });

    test('syntax errors carry the offset', () {
      final e = _error('(1 + 2');
      expect(e.message, contains(')'));
      expect(_error('1 +').message, contains('ends too early'));
      expect(_error('"open').offset, 0);
      expect(_error('').message, 'Enter a formula');
    });
  });

  test('result types', () {
    FormulaType typeOf(String s) => compileFormula(s, _fields).formula!.type;
    expect(typeOf('{Price} * 2'), FormulaType.number);
    expect(typeOf('{Name} & "x"'), FormulaType.text);
    expect(typeOf('{Price} > 1'), FormulaType.boolean);
    expect(typeOf('{Due} + 1'), FormulaType.date);
    expect(typeOf('{Due} - {Start}'), FormulaType.number);
  });

  test('display and storage forms swap names and ids', () {
    const stored = '{price} * {qty} + {missing}';
    final shown = formulaToDisplay(stored, _fields);
    expect(shown, '{Price} * {Quantity} + {missing}');
    expect(formulaToStorage(shown, _fields), stored);
    expect(formulaFieldIds(stored, _fields), {'price', 'qty'});
  });
}
