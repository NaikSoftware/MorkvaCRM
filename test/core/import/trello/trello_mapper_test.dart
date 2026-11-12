import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/core/domain/ids.dart';
import 'package:morkva_crm/core/import/trello/trello_board.dart';
import 'package:morkva_crm/core/import/trello/trello_mapper.dart';

/// Optional real export to check the invariants against (not committed).
final _realExport = Platform.environment['TRELLO_EXPORT'] ?? '';

void main() {
  final board = TrelloBoard.parse(
    File(
      'test/core/import/trello/fixtures/sample_board.json',
    ).readAsStringSync(),
  );

  List<ImportedCollection> map({
    bool includeArchived = false,
    bool checklists = true,
    bool comments = true,
    TrelloBoard? from,
  }) => mapTrelloBoard(
    from ?? board,
    includeArchived: includeArchived,
    checklists: checklists,
    comments: comments,
    ids: IdGenerator(),
  );

  FieldDefinition field(Collection c, String name) =>
      c.fields.firstWhere((f) => f.name == name);

  Object? value(ImportedCollection ic, MorkvaObject o, String fieldName) =>
      switch (o.values[field(ic.collection, fieldName).id]) {
        TextFieldValue(:final text) => text,
        NumberFieldValue(:final value) => value,
        BooleanFieldValue(:final value) => value,
        DateFieldValue(:final value) => value,
        SingleSelectFieldValue(:final optionId) => _label(
          field(ic.collection, fieldName),
          optionId,
        ),
        MultiSelectFieldValue(:final optionIds) => [
          for (final id in optionIds)
            _label(field(ic.collection, fieldName), id),
        ],
        ReferenceFieldValue(:final objectIds) => objectIds,
        _ => throw StateError('unexpected value'),
      };

  MorkvaObject card(ImportedCollection ic, String name) =>
      ic.objects.firstWhere((o) => value(ic, o, 'Name') == name);

  group('board collection', () {
    test('creates only the fields some card fills, in table order', () {
      final boardCol = map().first;
      expect(boardCol.kind, ImportedKind.board);
      expect(boardCol.boardId, board.id);
      expect(boardCol.collection.name, 'Sales Pipeline');
      expect(boardCol.collection.icon, 'cards');
      expect(boardCol.collection.fields.map((f) => f.name), [
        'Name',
        'Description',
        'List',
        'Labels',
        'Members',
        'Start',
        'Due',
        'Due done',
        'Notes',
        'Deal size',
        'Signed',
        'Paid',
        'Source',
        'due (Trello field)',
        'Attachments',
        'Trello link',
      ]);
      final c = boardCol.collection;
      expect((field(c, 'Description') as TextFieldDefinition).multiline, true);
      expect((field(c, 'Due') as DateFieldDefinition).includeTime, true);
      expect((field(c, 'Start') as DateFieldDefinition).includeTime, false);
      expect(field(c, 'Source'), isA<SingleSelectFieldDefinition>());
      expect(field(c, 'Paid'), isA<BooleanFieldDefinition>());
      expect(field(c, 'Deal size'), isA<NumberFieldDefinition>());
    });

    test('skips archived cards and archived lists by default', () {
      final boardCol = map().first;
      final c = boardCol.collection;
      expect(boardCol.objects.map((o) => value(boardCol, o, 'Name')), [
        'Beta Ltd',
        'Acme Corp',
        'Untitled card',
        'Orphan',
      ]);
      final list = field(c, 'List') as SingleSelectFieldDefinition;
      expect(list.options.map((o) => o.label), [
        'Leads',
        'Untitled list',
        'leads (2)',
      ]);
      expect(value(boardCol, card(boardCol, 'Orphan'), 'List'), isNull);
    });

    test('with archived on, a card in an archived list is archived', () {
      final boardCol = map(includeArchived: true).first;
      final c = boardCol.collection;
      expect(
        (field(c, 'List') as SingleSelectFieldDefinition).options.map(
          (o) => o.label,
        ),
        ['Leads', 'Old', 'Untitled list', 'leads (2)'],
      );
      expect(
        value(boardCol, card(boardCol, 'Gamma (old list)'), 'Archived'),
        true,
      );
      expect(
        value(boardCol, card(boardCol, 'Delta (archived)'), 'Archived'),
        true,
      );
      expect(value(boardCol, card(boardCol, 'Acme Corp'), 'Archived'), false);
      expect(
        value(boardCol, card(boardCol, 'Gamma (old list)'), 'List'),
        'Old',
      );
      expect(c.fields.last.name, 'Archived');
      expect(c.views.first.filters, [
        ViewFilter(fieldId: field(c, 'Archived').id, op: FilterOp.isFalse),
      ]);
    });

    test('maps card values', () {
      final boardCol = map().first;
      final acme = card(boardCol, 'Acme Corp');
      final beta = card(boardCol, 'Beta Ltd');
      expect(value(boardCol, acme, 'Description'), '**Hot** lead');
      expect(value(boardCol, acme, 'List'), 'Leads');
      expect(value(boardCol, acme, 'Labels'), ['Won', 'VIP', 'Won (2)']);
      expect(value(boardCol, beta, 'Labels'), ['Label', 'Sky']);
      expect(value(boardCol, acme, 'Members'), ['Ann Lee']);
      expect(value(boardCol, beta, 'Members'), ['bob']);
      expect(value(boardCol, acme, 'Start'), DateTime.utc(2026, 11, 20));
      expect(value(boardCol, acme, 'Due'), DateTime.utc(2026, 12, 1, 12));
      expect(value(boardCol, beta, 'Due done'), true);
      expect(value(boardCol, acme, 'Notes'), 'Call Tue');
      expect(value(boardCol, acme, 'Deal size'), 12500.5);
      expect(value(boardCol, beta, 'Deal size'), 7);
      expect(value(boardCol, acme, 'Signed'), DateTime.utc(2026, 11, 20, 15));
      expect(value(boardCol, acme, 'Paid'), true);
      expect(value(boardCol, beta, 'Paid'), true);
      expect(value(boardCol, acme, 'Source'), 'Ads');
      expect(value(boardCol, beta, 'Source'), isNull, reason: 'unknown option');
      expect(value(boardCol, acme, 'due (Trello field)'), 'ASAP');
      expect(
        value(boardCol, acme, 'Attachments'),
        'https://acme.com\n'
        'contract.png — https://trello.com/1/cards/x/attachments/y/download/contract.png',
      );
      expect(
        value(boardCol, acme, 'Trello link'),
        'https://trello.com/c/Xy12Ab34',
      );
      // 0x64a1f0c2 seconds since the epoch.
      expect(
        acme.createdAt,
        DateTime.fromMillisecondsSinceEpoch(0x64a1f0c2 * 1000, isUtc: true),
      );
      expect(acme.updatedAt, DateTime.utc(2026, 11, 10, 9, 30));
    });

    test('maps label colours, unnamed labels and list option order', () {
      final c = map().first.collection;
      final labels = field(c, 'Labels') as MultiSelectFieldDefinition;
      expect(labels.options.map((o) => (o.label, o.color)), [
        ('Won', '#4BCE97'),
        ('VIP', '#6E5DC6'),
        ('Label', null),
        ('Sky', '#6CC3E0'),
        ('Won (2)', '#F87168'),
        ('Unused', '#D3F1A7'),
      ]);
      final source = field(c, 'Source') as SingleSelectFieldDefinition;
      expect(source.options.map((o) => (o.label, o.color)), [
        ('Referral', null),
        ('Ads', '#579DFF'),
      ]);
    });

    test('has a Board view then an All table', () {
      final boardCol = map().first;
      final c = boardCol.collection;
      final [boardView, all] = c.views;
      expect(boardView.name, 'Board');
      expect(boardView.mode, ViewModeIds.board);
      expect(boardView.layoutFieldId, field(c, 'List').id);
      expect(boardView.sort, isNull);
      expect(boardView.filters, isEmpty);
      expect(boardView.fieldIds, [
        for (final n in ['Name', 'Labels', 'Due', 'Members']) field(c, n).id,
      ]);
      String nameOf(String id) =>
          value(
                boardCol,
                boardCol.objects.firstWhere((o) => o.id == id),
                'Name',
              )
              as String;
      expect(boardView.manualOrder.map(nameOf), [
        'Beta Ltd',
        'Acme Corp',
        'Untitled card',
        'Orphan',
      ]);
      expect(all.name, 'All');
      expect(all.mode, ViewModeIds.table);
      expect(all.fieldIds.first, field(c, 'Name').id);
      expect(all.manualOrder, isEmpty, reason: 'doc-size guard');
      expect(c.layout.fieldIds.toList(), c.fields.map((f) => f.id).toList());
    });

    test('a board without imported lists gets a "No list" option', () {
      final tiny = TrelloBoard.parse(
        '{"id":"b1","name":"Tiny","lists":[{"id":"l1","name":"Gone",'
        '"closed":true,"pos":1}],"cards":[{"id":"c1","name":"Lonely",'
        '"idList":"l9","pos":1,"dateLastActivity":"2026-01-02T00:00:00Z"}]}',
      );
      final boardCol = map(from: tiny).single;
      final list =
          field(boardCol.collection, 'List') as SingleSelectFieldDefinition;
      expect(list.options.map((o) => o.label), ['No list']);
      expect(value(boardCol, boardCol.objects.single, 'List'), 'No list');
      expect(boardCol.collection.fields.map((f) => f.name), ['Name', 'List']);
      expect(
        boardCol.objects.single.createdAt,
        DateTime.utc(2026, 1, 2),
        reason: 'a non-ObjectId id falls back to dateLastActivity',
      );
    });

    test('a start stored at local midnight keeps its calendar day', () {
      final tiny = TrelloBoard.parse(
        '{"id":"b1","name":"Tiny","lists":[],"cards":['
        '{"id":"c1","name":"Kyiv","start":"2026-11-12T22:00:00.000Z"},'
        '{"id":"c2","name":"New York","start":"2026-11-13T05:00:00.000Z"}]}',
      );
      final boardCol = map(from: tiny).single;
      expect(
        boardCol.objects.map((o) => value(boardCol, o, 'Start')),
        everyElement(DateTime.utc(2026, 11, 13)),
      );
    });

    test('a custom field never takes an absent built-in name', () {
      final tiny = TrelloBoard.parse(
        '{"id":"b1","name":"Tiny","lists":[{"id":"l1","name":"A","pos":1}],'
        '"customFields":[{"id":"cf","name":"Archived","type":"checkbox"}],'
        '"cards":[{"id":"c1","name":"x","idList":"l1","customFieldItems":'
        '[{"idCustomField":"cf","value":{"checked":"true"}}]}]}',
      );
      final c = map(from: tiny).single.collection;
      expect(c.fields.last.name, 'Archived (Trello field)');
      expect(c.views.first.filters, isEmpty);
    });
  });

  group('checklist items', () {
    test('one item per check item of an imported card, in order', () {
      final [boardCol, items, _] = map();
      expect(items.kind, ImportedKind.checklistItems);
      expect(items.collection.name, 'Sales Pipeline · Checklist items');
      expect(items.collection.fields.map((f) => f.name), [
        'Item',
        'Done',
        'Checklist',
        'Due',
        'Card',
      ]);
      final ref = field(items.collection, 'Card') as ReferenceFieldDefinition;
      expect(ref.targetCollectionId, boardCol.collection.id);
      expect(ref.multiple, false);
      final ordered = [
        for (final id in items.collection.views.first.manualOrder)
          items.objects.firstWhere((o) => o.id == id),
      ];
      expect(ordered.map((o) => value(items, o, 'Item')), [
        'Send NDA',
        'Kickoff call',
        'Sign contract',
      ]);
      final kickoff = ordered[1];
      expect(value(items, kickoff, 'Done'), false);
      expect(value(items, ordered[0], 'Done'), true);
      expect(value(items, kickoff, 'Checklist'), 'Onboarding');
      expect(value(items, kickoff, 'Due'), DateTime.utc(2026, 11, 25, 15));
      expect(value(items, kickoff, 'Card'), [card(boardCol, 'Acme Corp').id]);
    });

    test('items of an archived card come only with archived on', () {
      expect(map()[1].objects, hasLength(3));
      expect(map(includeArchived: true)[1].objects, hasLength(4));
    });

    test('are left out when not asked for', () {
      expect(map(checklists: false).map((c) => c.kind), [
        ImportedKind.board,
        ImportedKind.comments,
      ]);
    });
  });

  group('comments', () {
    test('newest first, dropped when the card is not imported', () {
      final [boardCol, _, comments] = map();
      expect(comments.kind, ImportedKind.comments);
      expect(comments.collection.name, 'Sales Pipeline · Comments');
      expect(comments.collection.fields.map((f) => f.name), [
        'Comment',
        'Author',
        'Date',
        'Card',
      ]);
      expect(
        comments.collection.views.first.sort,
        const ViewSort(fieldId: ViewSort.createdAt, ascending: false),
      );
      expect(comments.objects, hasLength(2));
      final bob = comments.objects.firstWhere(
        (o) => value(comments, o, 'Author') == 'bob',
      );
      expect(value(comments, bob, 'Comment'), 'Follow up next week');
      expect(value(comments, bob, 'Date'), DateTime.utc(2026, 11, 4, 8));
      expect(bob.createdAt, DateTime.utc(2026, 11, 4, 8));
      expect(value(comments, bob, 'Card'), [card(boardCol, 'Acme Corp').id]);
      expect(map(includeArchived: true)[2].objects, hasLength(3));
    });

    test('a board without comments gets no comments collection', () {
      final tiny = TrelloBoard.parse(
        '{"id":"b1","name":"Tiny","lists":[],"cards":[]}',
      );
      expect(map(from: tiny).map((c) => c.kind), [ImportedKind.board]);
    });
  });

  group('summary', () {
    test('counts follow the archived toggle and lists real fields', () {
      final off = summarizeTrelloBoard(board, includeArchived: false);
      expect(off.lists, 3);
      expect(off.cards, 4);
      expect(off.archivedCards, 2);
      expect(off.checklistItems, 3);
      expect(off.comments, 2);
      expect(off.fieldNames, map().first.collection.fields.map((f) => f.name));

      final on = summarizeTrelloBoard(board, includeArchived: true);
      expect(on.lists, 4);
      expect(on.cards, 6);
      expect(on.checklistItems, 4);
      expect(on.comments, 3);
      expect(on.fieldNames.last, 'Archived');
    });
  });

  group('invariants', () {
    final sources = <String, TrelloBoard Function()>{
      'fixture': () => board,
      'real export': () =>
          TrelloBoard.parse(File(_realExport).readAsStringSync()),
    };
    for (final MapEntry(key: name, value: load) in sources.entries) {
      for (final archived in [false, true]) {
        test(
          '$name (archived $archived) stays valid',
          skip: name == 'real export' && !File(_realExport).existsSync()
              ? 'set TRELLO_EXPORT to a board export to run'
              : false,
          () => _checkInvariants(
            mapTrelloBoard(
              load(),
              includeArchived: archived,
              checklists: true,
              comments: true,
              ids: IdGenerator(),
            ),
          ),
        );
      }
    }
  });
}

String? _label(FieldDefinition field, String? optionId) {
  if (optionId == null) return null;
  final options = switch (field) {
    SingleSelectFieldDefinition(:final options) => options,
    MultiSelectFieldDefinition(:final options) => options,
    _ => const <SelectOption>[],
  };
  return options.firstWhere((o) => o.id == optionId).label;
}

void _checkInvariants(List<ImportedCollection> output) {
  final registry = defaultFieldTypeRegistry();
  final collectionIds = {for (final c in output) c.collection.id};
  final objectIds = {
    for (final c in output)
      for (final o in c.objects) o.id,
  };
  expect(objectIds.length, output.fold(0, (n, c) => n + c.objects.length));
  for (final ic in output) {
    final c = ic.collection;
    final schema = validateCollectionSchema(
      c,
      strict: true,
      collectionIds: collectionIds,
    );
    expect(schema.blocking.map((i) => i.message), isEmpty, reason: c.name);
    expect(Collection.fromJson(c.toJson(), registry), c, reason: c.name);
    expect(c.views, isNotEmpty);
    final own = {for (final o in ic.objects) o.id};
    for (final view in c.views) {
      expect(own.containsAll(view.manualOrder), isTrue, reason: view.name);
    }
    for (final o in ic.objects) {
      expect(o.collectionId, c.id);
      expect(o.validateAgainst(c).errors, isEmpty, reason: '${c.name} ${o.id}');
      expect(MorkvaObject.fromJson(o.toJson(), c), o);
      for (final f in c.fields) {
        switch ((f, o.values[f.id])) {
          case (ReferenceFieldDefinition r, ReferenceFieldValue v):
            final target = output.firstWhere(
              (t) => t.collection.id == r.targetCollectionId,
            );
            expect(
              target.objects.map((t) => t.id).toSet().containsAll(v.objectIds),
              isTrue,
            );
          case (SingleSelectFieldDefinition s, SingleSelectFieldValue v):
            if (v.optionId != null) {
              expect(s.options.map((x) => x.id), contains(v.optionId));
            }
          case (MultiSelectFieldDefinition s, MultiSelectFieldValue v):
            expect(
              s.options.map((x) => x.id).toSet().containsAll(v.optionIds),
              isTrue,
            );
          default:
        }
      }
    }
  }
}
