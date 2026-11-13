import '../../domain/domain.dart';
import '../../domain/ids.dart';
import 'trello_board.dart';

/// Which Trello part an [ImportedCollection] holds.
enum ImportedKind { board, checklistItems, comments }

/// One collection to create from a Trello board, with its cards. Every id
/// (collection, fields, options, views, objects) is freshly minted, and
/// references between the board's collections point at those ids.
class ImportedCollection {
  const ImportedCollection({
    required this.kind,
    required this.boardId,
    required this.collection,
    required this.objects,
  });

  final ImportedKind kind;

  /// The Trello board id it came from.
  final String boardId;
  final Collection collection;
  final List<MorkvaObject> objects;
}

/// What importing a board would create, for the "Choose what to import" step.
/// Counts follow the `includeArchived` toggle it was made with, except
/// [archivedCards].
class TrelloBoardSummary {
  const TrelloBoardSummary({
    required this.lists,
    required this.cards,
    required this.archivedCards,
    required this.checklistItems,
    required this.comments,
    required this.fieldNames,
  });

  /// Imported lists.
  final int lists;

  /// Imported cards.
  final int cards;

  /// Archived cards on the board (closed, or in a closed list).
  final int archivedCards;

  /// Checklist items on imported cards.
  final int checklistItems;

  /// Comments on imported cards (an export keeps only the newest ones).
  final int comments;

  /// The board collection's field names, in order.
  final List<String> fieldNames;
}

/// Summarizes [board] by mapping it, so the field names are the real ones.
TrelloBoardSummary summarizeTrelloBoard(
  TrelloBoard board, {
  required bool includeArchived,
}) {
  final mapped = mapTrelloBoard(
    board,
    includeArchived: includeArchived,
    checklists: true,
    comments: true,
    ids: IdGenerator(),
  );
  int count(ImportedKind kind) => mapped
      .where((c) => c.kind == kind)
      .fold(0, (n, c) => n + c.objects.length);
  final closedLists = {
    for (final l in board.lists)
      if (l.closed) l.id,
  };
  return TrelloBoardSummary(
    lists: board.lists.where((l) => includeArchived || !l.closed).length,
    cards: count(ImportedKind.board),
    archivedCards: board.cards
        .where((c) => c.closed || closedLists.contains(c.idList))
        .length,
    checklistItems: count(ImportedKind.checklistItems),
    comments: count(ImportedKind.comments),
    fieldNames: [for (final f in mapped.first.collection.fields) f.name],
  );
}

/// Maps a Trello [board] to Morkva collections: the board itself first, then
/// its checklist items and comments when asked for and present.
///
/// Archived cards (closed, or in a closed list) and closed lists are imported
/// only with [includeArchived]. A board field is created only when some
/// imported card has a value for it, except Name and List. Mapping the same
/// board twice creates two independent copies; de-duplicating boards is the
/// caller's job.
List<ImportedCollection> mapTrelloBoard(
  TrelloBoard board, {
  required bool includeArchived,
  required bool checklists,
  required bool comments,
  required IdGenerator ids,
}) {
  final closedLists = {
    for (final l in board.lists)
      if (l.closed) l.id,
  };
  bool archived(TrelloCard c) => c.closed || closedLists.contains(c.idList);

  final lists = _sorted(
    board.lists.where((l) => includeArchived || !l.closed),
    (l) => [l.pos],
  );
  final listRank = {for (final (i, l) in lists.indexed) l.id: i};
  final cards = _sorted(
    board.cards.where((c) => includeArchived || !archived(c)),
    (c) => [listRank[c.idList] ?? lists.length, c.pos],
  );
  final boardName = board.name.trim().isEmpty
      ? 'Trello board'
      : board.name.trim();
  final boardTime = _idTime(board.id) ?? DateTime.utc(1970);
  final objectIds = {for (final c in cards) c.id: ids.objectId()};
  final created = {
    for (final c in cards)
      c.id: _idTime(c.id) ?? c.dateLastActivity ?? boardTime,
  };

  // --- Board fields: each a column of per-card values (null = empty).
  final columns = <_Column>[];
  void column(
    String name,
    FieldDefinition Function(String id, String name) make,
    FieldValue? Function(TrelloCard c) valueOf, {
    bool always = false,
    bool custom = false,
  }) {
    final values = [for (final c in cards) valueOf(c)];
    if (always || values.any((v) => v != null)) {
      columns.add(_Column(name, make, values, custom: custom));
    }
  }

  column(
    'Name',
    (id, name) => TextFieldDefinition(id: id, name: name),
    (c) => TextFieldValue(c.name.trim().isEmpty ? 'Untitled card' : c.name),
    always: true,
  );
  column(
    'Description',
    (id, name) => TextFieldDefinition(id: id, name: name, multiline: true),
    (c) => c.desc.trim().isEmpty ? null : TextFieldValue(c.desc),
  );

  final listOptions = lists.isEmpty
      ? [SelectOption(id: ids.optionId(), label: 'No list')]
      : _options(ids, [
          for (final l in lists)
            (l.name.trim().isEmpty ? 'Untitled list' : l.name.trim(), null),
        ]);
  final listOption = {
    for (final (i, l) in lists.indexed) l.id: listOptions[i].id,
  };
  column(
    'List',
    (id, name) =>
        SingleSelectFieldDefinition(id: id, name: name, options: listOptions),
    (c) => SingleSelectFieldValue(
      lists.isEmpty ? listOptions.single.id : listOption[c.idList],
    ),
    always: true,
  );

  final labelOptions = _options(ids, [
    for (final l in board.labels)
      (
        l.name.trim().isNotEmpty
            ? l.name.trim()
            : l.color == null
            ? 'Label'
            : _colorName(l.color!),
        _hex(l.color),
      ),
  ]);
  final labelOption = {
    for (final (i, l) in board.labels.indexed) l.id: labelOptions[i].id,
  };
  column(
    'Labels',
    (id, name) =>
        MultiSelectFieldDefinition(id: id, name: name, options: labelOptions),
    (c) => _multi(c.idLabels, labelOption),
  );

  final memberOptions = _options(ids, [
    for (final m in board.members)
      (m.fullName.isEmpty ? 'Member' : m.fullName, null),
  ]);
  final memberOption = {
    for (final (i, m) in board.members.indexed) m.id: memberOptions[i].id,
  };
  column(
    'Members',
    (id, name) =>
        MultiSelectFieldDefinition(id: id, name: name, options: memberOptions),
    (c) => _multi(c.idMembers, memberOption),
  );

  column(
    'Start',
    (id, name) => DateFieldDefinition(id: id, name: name),
    (c) => c.start == null ? null : DateFieldValue(_day(c.start!)),
  );
  column(
    'Due',
    (id, name) => DateFieldDefinition(id: id, name: name, includeTime: true),
    (c) => c.due == null ? null : DateFieldValue(c.due),
  );
  column(
    'Due done',
    (id, name) => BooleanFieldDefinition(id: id, name: name),
    (c) => c.due != null || c.dueComplete
        ? BooleanFieldValue(c.dueComplete)
        : null,
  );

  for (final f in _sorted(board.customFields, (f) => [f.pos])) {
    final name = f.name.trim().isEmpty ? 'Untitled field' : f.name.trim();
    switch (f.type) {
      case 'text':
        column(
          name,
          (id, name) => TextFieldDefinition(id: id, name: name),
          (c) => switch (c.customValues[f.id]) {
            final String text => TextFieldValue(text),
            _ => null,
          },
          custom: true,
        );
      case 'number':
        column(
          name,
          (id, name) => NumberFieldDefinition(id: id, name: name),
          (c) => switch (c.customValues[f.id]) {
            final num n => NumberFieldValue(n),
            _ => null,
          },
          custom: true,
        );
      case 'date':
        column(
          name,
          (id, name) =>
              DateFieldDefinition(id: id, name: name, includeTime: true),
          (c) => switch (c.customValues[f.id]) {
            final DateTime d => DateFieldValue(d),
            _ => null,
          },
          custom: true,
        );
      case 'checkbox':
        column(
          name,
          (id, name) => BooleanFieldDefinition(id: id, name: name),
          (c) => switch (c.customValues[f.id]) {
            final bool b => BooleanFieldValue(b),
            _ => null,
          },
          custom: true,
        );
      case 'list':
        final sorted = _sorted(f.options, (o) => [o.pos]);
        final options = _options(ids, [
          for (final o in sorted)
            (
              o.text.trim().isEmpty ? 'Untitled option' : o.text.trim(),
              _hex(o.color),
            ),
        ]);
        final optionOf = {
          for (final (i, o) in sorted.indexed) o.id: options[i].id,
        };
        column(
          name,
          (id, name) =>
              SingleSelectFieldDefinition(id: id, name: name, options: options),
          (c) => switch (optionOf[c.customValues[f.id]]) {
            final String option => SingleSelectFieldValue(option),
            _ => null,
          },
          custom: true,
        );
    }
  }

  column(
    'Attachments',
    (id, name) => TextFieldDefinition(id: id, name: name, multiline: true),
    (c) => c.attachments.isEmpty
        ? null
        : TextFieldValue(
            c.attachments
                .map(
                  (a) => a.name.trim().isEmpty || a.name == a.url
                      ? a.url
                      : '${a.name.trim()} — ${a.url}',
                )
                .join('\n'),
          ),
  );
  column(
    'Trello link',
    (id, name) => TextFieldDefinition(id: id, name: name),
    (c) => c.shortUrl == null ? null : TextFieldValue(c.shortUrl),
  );
  if (cards.any(archived)) {
    column(
      'Archived',
      (id, name) => BooleanFieldDefinition(id: id, name: name),
      (c) => BooleanFieldValue(archived(c)),
    );
  }

  // Built-in names win even when that field is absent (views find built-ins
  // by name); a clashing custom field gets "(Trello field)".
  final taken = {for (final n in _builtInNames) n.toLowerCase()};
  final fields = [
    for (final col in columns)
      col.make(
        ids.fieldId(),
        col.custom
            ? _unique(
                col.name,
                taken,
                (n) => n == 2
                    ? '${col.name} (Trello field)'
                    : '${col.name} (Trello field ${n - 1})',
              )
            : col.name,
      ),
  ];
  FieldDefinition? named(String name) =>
      fields.where((f) => f.name == name).firstOrNull;
  final objects = [
    for (final (i, c) in cards.indexed)
      MorkvaObject(
        id: objectIds[c.id]!,
        collectionId: '',
        values: {
          for (final (j, col) in columns.indexed) fields[j].id: ?col.values[i],
        },
        createdAt: created[c.id]!,
        updatedAt: c.dateLastActivity ?? created[c.id]!,
      ),
  ];
  final order = [for (final o in objects) o.id];
  final archivedField = named('Archived');
  final boardCollection = Collection(
    id: ids.collectionId(),
    name: boardName,
    description: board.desc.trim().isEmpty ? null : board.desc.trim(),
    icon: 'cards',
    fields: fields,
    layout: CardLayout.synthesize([for (final f in fields) f.id]),
    views: [
      ViewDefinition(
        id: ids.viewId(),
        name: 'Board',
        mode: ViewModeIds.board,
        layoutFieldId: named('List')!.id,
        fieldIds: [
          fields.first.id,
          for (final f in [named('Labels'), named('Due'), named('Members')])
            ?f?.id,
        ],
        filters: [
          if (archivedField != null)
            ViewFilter(fieldId: archivedField.id, op: FilterOp.isFalse),
        ],
        manualOrder: order,
      ),
      ViewDefinition(
        id: ids.viewId(),
        name: 'All',
        fieldIds: [for (final f in fields) f.id],
        // No manualOrder: a second copy of every card id would double the
        // collection doc's size for big boards.
      ),
    ],
  );

  final result = [
    ImportedCollection(
      kind: ImportedKind.board,
      boardId: board.id,
      collection: boardCollection,
      objects: _create(boardCollection, objects),
    ),
  ];

  // --- Checklist items of imported cards.
  final cardRank = {for (final (i, c) in cards.indexed) c.id: i};
  final items = _sorted([
    for (final list in board.checklists)
      if (cardRank[list.idCard] != null)
        for (final item in list.items) (list, item),
  ], (e) => [cardRank[e.$1.idCard]!, e.$1.pos, e.$2.pos]);
  if (checklists && items.isNotEmpty) {
    final hasDue = items.any((e) => e.$2.due != null);
    final fields = <FieldDefinition>[
      TextFieldDefinition(id: ids.fieldId(), name: 'Item'),
      BooleanFieldDefinition(id: ids.fieldId(), name: 'Done'),
      TextFieldDefinition(id: ids.fieldId(), name: 'Checklist'),
      if (hasDue)
        DateFieldDefinition(id: ids.fieldId(), name: 'Due', includeTime: true),
      ReferenceFieldDefinition(
        id: ids.fieldId(),
        name: 'Card',
        targetCollectionId: boardCollection.id,
      ),
    ];
    final objects = [
      for (final (list, item) in items)
        _object(ids, fields, [
          TextFieldValue(
            item.name.trim().isEmpty ? 'Untitled item' : item.name,
          ),
          BooleanFieldValue(item.complete),
          TextFieldValue(list.name.trim().isEmpty ? null : list.name.trim()),
          if (hasDue) DateFieldValue(item.due),
          ReferenceFieldValue([objectIds[list.idCard]!]),
        ], _idTime(item.id) ?? _idTime(list.id) ?? created[list.idCard]!),
    ];
    final collection = _child(
      ids,
      '$boardName · Checklist items',
      'task',
      fields,
      manualOrder: [for (final o in objects) o.id],
    );
    result.add(
      ImportedCollection(
        kind: ImportedKind.checklistItems,
        boardId: board.id,
        collection: collection,
        objects: _create(collection, objects),
      ),
    );
  }

  // --- Comments on imported cards.
  final notes = [
    for (final c in board.comments)
      if (objectIds.containsKey(c.cardId)) c,
  ];
  if (comments && notes.isNotEmpty) {
    final fields = <FieldDefinition>[
      TextFieldDefinition(id: ids.fieldId(), name: 'Comment', multiline: true),
      TextFieldDefinition(id: ids.fieldId(), name: 'Author'),
      DateFieldDefinition(id: ids.fieldId(), name: 'Date', includeTime: true),
      ReferenceFieldDefinition(
        id: ids.fieldId(),
        name: 'Card',
        targetCollectionId: boardCollection.id,
      ),
    ];
    DateTime dateOf(TrelloComment c) =>
        c.date ?? _idTime(c.id) ?? created[c.cardId]!;
    final objects = [
      for (final c in notes)
        _object(ids, fields, [
          TextFieldValue(c.text.trim().isEmpty ? null : c.text),
          TextFieldValue(c.author.isEmpty ? null : c.author),
          DateFieldValue(dateOf(c)),
          ReferenceFieldValue([objectIds[c.cardId]!]),
        ], dateOf(c)),
    ];
    final collection = _child(
      ids,
      '$boardName · Comments',
      'note',
      fields,
      sort: const ViewSort(fieldId: ViewSort.createdAt, ascending: false),
    );
    result.add(
      ImportedCollection(
        kind: ImportedKind.comments,
        boardId: board.id,
        collection: collection,
        objects: _create(collection, objects),
      ),
    );
  }
  return result;
}

const _builtInNames = [
  'Name',
  'Description',
  'List',
  'Labels',
  'Members',
  'Start',
  'Due',
  'Due done',
  'Attachments',
  'Trello link',
  'Archived',
];

/// A board field before its id and final name are known.
class _Column {
  _Column(this.name, this.make, this.values, {required this.custom});

  final String name;
  final FieldDefinition Function(String id, String name) make;
  final List<FieldValue?> values;

  /// A Trello custom field (renamed when it clashes with a built-in one).
  final bool custom;
}

/// [items] sorted by [key] (compared part by part), ties kept in input order.
List<T> _sorted<T>(Iterable<T> items, List<num> Function(T) key) {
  final keyed = [for (final (i, item) in items.indexed) (key(item), i, item)];
  keyed.sort((a, b) {
    for (var k = 0; k < a.$1.length; k++) {
      final c = a.$1[k].compareTo(b.$1[k]);
      if (c != 0) return c;
    }
    return a.$2.compareTo(b.$2);
  });
  return [for (final (_, _, item) in keyed) item];
}

/// Select options for [labels], de-duplicated as "X (2)", "X (3)"….
List<SelectOption> _options(
  IdGenerator ids,
  List<(String label, String? color)> labels,
) {
  final taken = <String>{};
  return [
    for (final (label, color) in labels)
      SelectOption(
        id: ids.optionId(),
        label: _unique(label, taken, (n) => '$label ($n)'),
        color: color,
      ),
  ];
}

/// [base], or the first free [variant] (n = 2, 3…), compared
/// case-insensitively; the result is added to [taken].
String _unique(String base, Set<String> taken, String Function(int n) variant) {
  var name = base;
  for (var n = 2; !taken.add(name.toLowerCase()); n++) {
    name = variant(n);
  }
  return name;
}

MultiSelectFieldValue? _multi(List<String> ids, Map<String, String> options) {
  final picked = {for (final id in ids) ?options[id]};
  return picked.isEmpty ? null : MultiSelectFieldValue(picked.toList());
}

MorkvaObject _object(
  IdGenerator ids,
  List<FieldDefinition> fields,
  List<FieldValue> values,
  DateTime createdAt,
) => MorkvaObject(
  id: ids.objectId(),
  collectionId: '',
  values: {for (final (i, f) in fields.indexed) f.id: values[i]},
  createdAt: createdAt,
  updatedAt: createdAt,
);

/// Normalizes [drafts] against [collection] (one value per field, UTC).
List<MorkvaObject> _create(Collection collection, List<MorkvaObject> drafts) =>
    [
      for (final o in drafts)
        MorkvaObject.create(
          id: o.id,
          collection: collection,
          values: o.values,
          createdAt: o.createdAt,
          updatedAt: o.updatedAt,
        ),
    ];

Collection _child(
  IdGenerator ids,
  String name,
  String icon,
  List<FieldDefinition> fields, {
  List<String> manualOrder = const [],
  ViewSort? sort,
}) => Collection(
  id: ids.collectionId(),
  name: name,
  icon: icon,
  fields: fields,
  layout: CardLayout.synthesize([for (final f in fields) f.id]),
  views: [
    ViewDefinition(
      id: ids.viewId(),
      name: 'All',
      fieldIds: [for (final f in fields) f.id],
      sort: sort,
      manualOrder: manualOrder,
    ),
  ],
);

/// The creation time in a Trello (Mongo ObjectId) id: its first 8 hex digits
/// are Unix seconds.
DateTime? _idTime(String id) {
  if (id.length < 24) return null;
  final seconds = int.tryParse(id.substring(0, 8), radix: 16);
  return seconds == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
}

/// The calendar day of a date-only Trello value, as Trello shows it to the
/// importer: the day in this device's zone. Real starts are any time of day
/// (Butler sets "now"), so rounding in UTC moved afternoon starts a day on.
/// shortcut: assumes the importer shares the board's zone; a board imported
/// from far away can be a day out — pass the zone in if that ever matters.
DateTime _day(DateTime d) {
  final local = d.toLocal();
  return DateTime.utc(local.year, local.month, local.day);
}

/// Trello label colours (light, base, dark) in Atlassian's palette.
const _palette = {
  'green': ['#BAF3DB', '#4BCE97', '#1F845A'],
  'yellow': ['#F8E6A0', '#F5CD47', '#946F00'],
  'orange': ['#FEDEC8', '#FEA362', '#C25100'],
  'red': ['#FFD5D2', '#F87168', '#C9372C'],
  'purple': ['#DFD8FD', '#9F8FEF', '#6E5DC6'],
  'blue': ['#CCE0FF', '#579DFF', '#0C66E4'],
  'sky': ['#C6EDFB', '#6CC3E0', '#227D9B'],
  'lime': ['#D3F1A7', '#94C748', '#5B7F24'],
  'pink': ['#FDD0EC', '#E774BB', '#AE4787'],
  'black': ['#DCDFE4', '#8590A2', '#626F86'],
};

/// The hex of a Trello colour name (`green`, `sky_dark` …), or null.
String? _hex(String? color) {
  final [base, ...shade] = (color ?? '').split('_');
  final tones = _palette[base];
  if (tones == null) return null;
  return switch (shade) {
    [] => tones[1],
    ['light'] => tones[0],
    ['dark'] => tones[2],
    _ => null,
  };
}

/// "purple_dark" → "Purple dark".
String _colorName(String color) {
  final words = color.split('_').where((w) => w.isNotEmpty).join(' ');
  return words.isEmpty ? 'Label' : words[0].toUpperCase() + words.substring(1);
}
