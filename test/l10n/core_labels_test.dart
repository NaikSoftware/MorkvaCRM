import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/automation/automation.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/core/domain/ids.dart';
import 'package:morkva_crm/core/import/trello/trello_board.dart';
import 'package:morkva_crm/core/import/trello/trello_mapper.dart';
import 'package:morkva_crm/l10n/l10n.dart';

/// The feature-layer words for core's structured values: English matches
/// core's own English text exactly, Ukrainian is filled in.
void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final uk = lookupAppLocalizations(const Locale('uk'));

  const fields = <FieldDefinition>[
    NumberFieldDefinition(id: 'price', name: 'Price'),
    TextFieldDefinition(id: 'name', name: 'Name'),
    BooleanFieldDefinition(id: 'paid', name: 'Paid'),
    DateFieldDefinition(id: 'due', name: 'Due'),
    ReferenceFieldDefinition(id: 'ref', name: 'Item', targetCollectionId: 'x'),
  ];
  // One source per error code.
  const broken = [
    '',
    '1.2.3',
    '"abc',
    '{Price',
    '1 @ 2',
    '{Nope}',
    '{Self}',
    '{Item}',
    'Price + 1',
    'FOO(1)',
    'ROUND(1, 2, 3)',
    'ROUND(1',
    'ROUND("a")',
    'AND(1)',
    'LEN(1)',
    'YEAR(1)',
    'IF(1, 2, 3)',
    'IF(TRUE, 1, "a")',
    '(1',
    '1 +',
    '-"a"',
    '"a" + "b"',
    '{Due} * 2',
  ];
  final errors = [
    for (final source in broken)
      compileFormula(source, [
        ...fields,
        const CalculatedFieldDefinition(
          id: 'self',
          name: 'Self',
          declaredOutputType: 'number',
        ),
      ], selfId: 'self').error!,
  ];

  test('every formula error code is covered', () {
    expect({for (final e in errors) e.code}, FormulaErrorCode.values.toSet());
  });

  test('formula errors word like core in English', () {
    for (final e in errors) {
      expect(en.formulaErrorMessage(e), e.message, reason: '${e.code}');
      expect(uk.formulaErrorMessage(e), isNot(e.message), reason: '${e.code}');
    }
    final usage = errors.firstWhere(
      (e) => e.code == FormulaErrorCode.wrongArguments,
    );
    expect(uk.formulaErrorMessage(usage), 'Пишіть так: ROUND(число, знаки)');
  });

  test('formula functions, types and aggregate ops word like core', () {
    for (final f in formulaFunctions.values) {
      expect(en.formulaUsage(f), f.usage);
      expect(en.formulaSummary(f), f.summary);
      expect(uk.formulaSummary(f), isNot(f.summary));
    }
    for (final t in FormulaType.values) {
      expect(en.formulaTypeLabel(t), t.label);
    }
    for (final op in AggregateOp.values) {
      expect(en.aggregateOpLabel(op), op.label);
    }
    expect(uk.aggregateOpLabel(AggregateOp.sum), 'Сума');
  });

  test('capability copy matches kCapabilityCopy in English', () {
    for (final MapEntry(key: cap, value: copy) in kCapabilityCopy.entries) {
      expect(en.capabilityTitle(cap), copy.title);
      expect(en.capabilityExplanation(cap), copy.explanation);
      expect(uk.capabilityTitle(cap), isNot(copy.title));
    }
    expect(en.capabilityTitle('x:y'), 'x:y');
  });

  test('blocking schema issues word like core in English', () {
    Collection draft(List<FieldDefinition> fields, {String name = 'Orders'}) =>
        Collection(id: 'c', name: name, fields: fields);
    final saved = draft(const [TextFieldDefinition(id: 'a', name: 'Title')]);
    final issues = [
      ...validateCollectionSchema(draft(const [], name: ' ')).blocking,
      ...validateCollectionSchema(
        draft(const [TextFieldDefinition(id: 'a', name: '')]),
      ).blocking,
      ...validateCollectionSchema(
        draft(const [
          TextFieldDefinition(id: 'a', name: 'Title'),
          TextFieldDefinition(id: 'b', name: 'title'),
        ]),
      ).blocking,
      ...validateCollectionSchema(
        draft(const [NumberFieldDefinition(id: 'a', name: 'Title')]),
        saved: saved,
      ).blocking,
    ];
    expect(
      {for (final i in issues) i.code},
      {
        SchemaIssueCode.emptyCollectionName,
        SchemaIssueCode.emptyFieldName,
        SchemaIssueCode.duplicateFieldName,
        SchemaIssueCode.typeLocked,
      },
    );
    for (final i in issues) {
      expect(en.schemaIssueMessage(i), i.message);
    }
    expect(
      uk.schemaIssueMessage(issues.last),
      'Тип поля «Title» не можна змінити після збереження — додайте нове поле',
    );
  });

  test('broken field rules word like core in English', () {
    final rules = <(FieldDefinition, FieldValue)>[
      (
        const TextFieldDefinition(id: 'a', name: 'Title', isRequired: true),
        const TextFieldValue(null),
      ),
      (
        const TextFieldDefinition(id: 'a', name: 'Title', maxLength: 3),
        const TextFieldValue('long'),
      ),
      (
        const NumberFieldDefinition(id: 'a', name: 'Qty', min: 1),
        const NumberFieldValue(0),
      ),
      (
        const NumberFieldDefinition(id: 'a', name: 'Qty', max: 2.5),
        const NumberFieldValue(3),
      ),
      (
        DateFieldDefinition(id: 'a', name: 'Due', min: DateTime.utc(2026)),
        DateFieldValue(DateTime.utc(2025)),
      ),
      (
        DateFieldDefinition(id: 'a', name: 'Due', max: DateTime.utc(2026)),
        DateFieldValue(DateTime.utc(2027)),
      ),
      (
        const FileFieldDefinition(
          id: 'a',
          name: 'Scan',
          allowedExtensions: ['pdf'],
        ),
        const FileFieldValue([FileAttachment(id: 'f', name: 'a.exe')]),
      ),
      (
        const FileFieldDefinition(id: 'a', name: 'Scan'),
        const FileFieldValue([
          FileAttachment(id: 'f', name: 'a.pdf'),
          FileAttachment(id: 'g', name: 'b.pdf'),
        ]),
      ),
      (
        const SingleSelectFieldDefinition(id: 'a', name: 'Stage'),
        const SingleSelectFieldValue('x'),
      ),
      (
        const MultiSelectFieldDefinition(id: 'a', name: 'Tags'),
        const MultiSelectFieldValue(['x']),
      ),
      (
        const ReferenceFieldDefinition(
          id: 'a',
          name: 'Client',
          targetCollectionId: 'c',
        ),
        const ReferenceFieldValue(['']),
      ),
      (
        const ReferenceFieldDefinition(
          id: 'a',
          name: 'Client',
          targetCollectionId: 'c',
        ),
        const ReferenceFieldValue(['x', 'y']),
      ),
    ];
    for (final (field, value) in rules) {
      final errors = field.validate(value);
      expect(errors, isNotEmpty, reason: field.name);
      for (final e in errors) {
        expect(en.validationMessage(field, e), e.message);
        expect(uk.validationMessage(field, e), isNot(e.message));
      }
    }
    final (long, text) = rules[1];
    expect(
      uk.validationMessage(long, long.validate(text).single),
      '«Title»: щонайбільше 3 символи',
    );
  });

  test('core words in English are core defaults', () {
    final words = en.coreWords;
    const defaults = CoreWords();
    expect(words.untitled, defaults.untitled);
    expect((words.yes, words.no), (defaults.yes, defaults.no));
    expect(words.linkedCount(3), defaults.linkedCount(3));
    expect(words.noValueGroup('Status'), defaults.noValueGroup('Status'));
    expect(words.weekOf('Nov 9, 2026'), defaults.weekOf('Nov 9, 2026'));
    expect(words.defaultViewName, defaults.defaultViewName);
  });

  group('Trello names', () {
    final board = TrelloBoard.parse(
      File(
        'test/core/import/trello/fixtures/sample_board.json',
      ).readAsStringSync(),
    );
    List<ImportedCollection> map(TrelloNames names) => mapTrelloBoard(
      board,
      includeArchived: true,
      checklists: true,
      comments: true,
      ids: IdGenerator(),
      names: names,
    );
    String shape(List<ImportedCollection> mapped) => jsonEncode([
      for (final c in mapped)
        [
          c.collection.name,
          for (final f in c.collection.fields) f.name,
          for (final v in c.collection.views) v.name,
        ],
    ]);

    test('English ones are the mapper defaults', () {
      final names = en.trelloNames;
      const defaults = TrelloNames();
      expect(shape(map(names)), shape(map(defaults)));
      for (final (base, shade) in [
        ('purple', 'dark'),
        ('sky', null),
        ('lime', 'light'),
        ('teal', null),
      ]) {
        expect(names.color(base, shade), defaults.color(base, shade));
      }
      expect(names.trelloField('Due', 2), defaults.trelloField('Due', 2));
      expect(names.trelloField('Due', 3), defaults.trelloField('Due', 3));
      expect(names.checklistItems('B'), defaults.checklistItems('B'));
      expect(names.comments('B'), defaults.comments('B'));
    });

    test('Ukrainian ones name the board and keep its views working', () {
      final mapped = map(uk.trelloNames);
      final boardCollection = mapped.first.collection;
      final names = [for (final f in boardCollection.fields) f.name];
      expect(names, containsAll(['Назва', 'Список']));
      final view = boardCollection.views.first;
      expect(view.name, 'Дошка');
      // Found by its translated name, not by "List".
      expect(boardCollection.fieldById(view.layoutFieldId!)!.name, 'Список');
      expect(boardCollection.views.last.name, 'Усі');
      expect(uk.trelloNames.color('purple', 'dark'), 'Фіолетовий (темний)');
    });
  });
}
