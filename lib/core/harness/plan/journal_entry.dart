/// The undo journal's persisted form: a versioned [JournalEntry] (schema 1)
/// of inverse items, one per written key set. The same JSON is the in-memory
/// entry and the mirror on the chat message, so there is one shape.
///
/// Values are stored domain JSON (`FieldValue.toJson`). Card items list only
/// the keys the commit touched; schema items are entries (a field, a view, a
/// field's layout cell, collection keys), never a whole old collection,
/// except the before-image of a deleted collection.
///
/// Parsing is strict: an item with an unknown kind, a missing or extra key
/// or a wrong-typed value is a [FormatException], so a tampered mirror is
/// dropped item by item ([JournalEntry.parse]).
library;

import 'dart:convert';

import '../../domain/domain.dart';

/// The persisted journal schema version.
const int kJournalSchema = 1;

/// The largest mirror (UTF-8 JSON) kept on a chat message. Above it the
/// mirror is omitted and undo lasts only as long as the session.
const int kJournalMirrorMaxBytes = 400 * 1024;

/// One key's value before and after the commit (stored domain JSON).
typedef ValueChange = ({Object? before, Object? after});

/// One inverse item of a [JournalEntry].
sealed class JournalItem {
  const JournalItem(this.collectionId);

  /// Parses one item. Throws [FormatException] on any deviation.
  factory JournalItem.fromJson(Map<String, Object?> json) {
    final kind = json['kind'];
    return switch (kind) {
      JournalCardUpdate.kindName => JournalCardUpdate._fromJson(json),
      JournalCardCreate.kindName => JournalCardCreate._fromJson(json),
      JournalCardDelete.kindName => JournalCardDelete._fromJson(json),
      JournalFieldEntry.kindName => JournalFieldEntry._fromJson(json),
      JournalViewEntry.kindName => JournalViewEntry._fromJson(json),
      JournalLayoutEntry.kindName => JournalLayoutEntry._fromJson(json),
      JournalCollectionMeta.kindName => JournalCollectionMeta._fromJson(json),
      JournalCollectionCreate.kindName => JournalCollectionCreate._fromJson(
        json,
      ),
      JournalCollectionDelete.kindName => JournalCollectionDelete._fromJson(
        json,
      ),
      _ => throw FormatException('Unknown journal item kind "$kind"'),
    };
  }

  final String collectionId;

  /// The card, field, view or collection the item is about (what undo and
  /// restore report).
  String get targetId;

  String get kind;

  Map<String, Object?> toJson();
}

/// Touched keys of one card: undo writes `before` back where the card still
/// holds `after`.
final class JournalCardUpdate extends JournalItem {
  const JournalCardUpdate({
    required String collectionId,
    required this.id,
    required this.keys,
  }) : super(collectionId);

  factory JournalCardUpdate._fromJson(Map<String, Object?> json) {
    _keys(json, const {'kind', 'collectionId', 'id', 'keys'});
    final keys = _map(json, 'keys');
    if (keys.isEmpty) throw const FormatException('"keys" is empty');
    return JournalCardUpdate(
      collectionId: _str(json, 'collectionId'),
      id: _str(json, 'id'),
      keys: {
        for (final e in keys.entries) e.key: _change(e.value, 'keys.${e.key}'),
      },
    );
  }

  static const String kindName = 'card.update';

  final String id;

  /// Field id → stored JSON before and after.
  final Map<String, ValueChange> keys;

  @override
  String get targetId => id;

  @override
  String get kind => kindName;

  @override
  Map<String, Object?> toJson() => {
    'kind': kind,
    'collectionId': collectionId,
    'id': id,
    'keys': {
      for (final e in keys.entries)
        e.key: {'before': e.value.before, 'after': e.value.after},
    },
  };
}

/// A created card: undo deletes it while it still holds [after].
final class JournalCardCreate extends JournalItem {
  const JournalCardCreate({
    required String collectionId,
    required this.id,
    required this.after,
  }) : super(collectionId);

  factory JournalCardCreate._fromJson(Map<String, Object?> json) {
    _keys(json, const {'kind', 'collectionId', 'id', 'after'});
    return JournalCardCreate(
      collectionId: _str(json, 'collectionId'),
      id: _str(json, 'id'),
      after: _map(json, 'after'),
    );
  }

  static const String kindName = 'card.create';

  final String id;

  /// Field id → stored JSON of the values written (non-empty, writable
  /// fields only).
  final Map<String, Object?> after;

  @override
  String get targetId => id;

  @override
  String get kind => kindName;

  @override
  Map<String, Object?> toJson() => {
    'kind': kind,
    'collectionId': collectionId,
    'id': id,
    'after': after,
  };
}

/// A deleted card: undo re-creates it with the same id and auto-number.
final class JournalCardDelete extends JournalItem {
  const JournalCardDelete({
    required String collectionId,
    required this.id,
    required this.before,
  }) : super(collectionId);

  /// [object] of [schema] as its delete before-image (calculated values are
  /// never stored, so they are left out).
  factory JournalCardDelete.of(MorkvaObject object, Collection schema) =>
      JournalCardDelete(
        collectionId: object.collectionId,
        id: object.id,
        before: {
          'createdAt': object.createdAt.toUtc().toIso8601String(),
          'updatedAt': object.updatedAt.toUtc().toIso8601String(),
          'values': {
            for (final e in object.values.entries)
              if (schema.fieldById(e.key) is! CalculatedFieldDefinition?)
                e.key: e.value.toJson(),
          },
        },
      );

  factory JournalCardDelete._fromJson(Map<String, Object?> json) {
    _keys(json, const {'kind', 'collectionId', 'id', 'before'});
    final before = _map(json, 'before');
    _keys(before, const {'createdAt', 'updatedAt', 'values'}, at: 'before');
    _date(before, 'createdAt');
    _date(before, 'updatedAt');
    _map(before, 'values');
    return JournalCardDelete(
      collectionId: _str(json, 'collectionId'),
      id: _str(json, 'id'),
      before: before,
    );
  }

  static const String kindName = 'card.delete';

  final String id;

  /// `{createdAt, updatedAt, values}` as `MorkvaObject.toJson` writes them.
  final Map<String, Object?> before;

  /// The stored values of the before-image.
  Map<String, Object?> get values => (before['values']! as Map).cast();

  /// The card as it was, decoded against [schema].
  MorkvaObject object(Collection schema) => MorkvaObject.fromJson({
    ...before,
    'id': id,
    'collectionId': collectionId,
  }, schema);

  @override
  String get targetId => id;

  @override
  String get kind => kindName;

  @override
  Map<String, Object?> toJson() => {
    'kind': kind,
    'collectionId': collectionId,
    'id': id,
    'before': before,
  };
}

/// One field definition before and after: null [before] means the commit
/// added it, null [after] that it removed it.
final class JournalFieldEntry extends JournalItem {
  const JournalFieldEntry({
    required String collectionId,
    required this.fieldId,
    required this.index,
    this.before,
    this.after,
  }) : super(collectionId);

  factory JournalFieldEntry._fromJson(Map<String, Object?> json) {
    _keys(json, const {
      'kind',
      'collectionId',
      'fieldId',
      'index',
      'before',
      'after',
    });
    final entry = JournalFieldEntry(
      collectionId: _str(json, 'collectionId'),
      fieldId: _str(json, 'fieldId'),
      index: _int(json, 'index'),
      before: _mapOrNull(json, 'before'),
      after: _mapOrNull(json, 'after'),
    );
    _checkImages(entry.before, entry.after, entry.fieldId);
    return entry;
  }

  static const String kindName = 'field.entry';

  final String fieldId;

  /// The field's position before the commit (after it, for an add).
  final int index;

  /// `FieldDefinition.toJson` images.
  final Map<String, Object?>? before;
  final Map<String, Object?>? after;

  @override
  String get targetId => fieldId;

  @override
  String get kind => kindName;

  @override
  Map<String, Object?> toJson() => {
    'kind': kind,
    'collectionId': collectionId,
    'fieldId': fieldId,
    'index': index,
    'before': before,
    'after': after,
  };
}

/// One view before and after (null: added / removed by the commit).
final class JournalViewEntry extends JournalItem {
  const JournalViewEntry({
    required String collectionId,
    required this.viewId,
    required this.index,
    this.before,
    this.after,
  }) : super(collectionId);

  factory JournalViewEntry._fromJson(Map<String, Object?> json) {
    _keys(json, const {
      'kind',
      'collectionId',
      'viewId',
      'index',
      'before',
      'after',
    });
    final entry = JournalViewEntry(
      collectionId: _str(json, 'collectionId'),
      viewId: _str(json, 'viewId'),
      index: _int(json, 'index'),
      before: _mapOrNull(json, 'before'),
      after: _mapOrNull(json, 'after'),
    );
    _checkImages(entry.before, entry.after, entry.viewId);
    return entry;
  }

  static const String kindName = 'view.entry';

  final String viewId;

  /// The view's position in the list before the commit (after, for an add).
  final int index;

  /// `ViewDefinition.toJson` images.
  final Map<String, Object?>? before;
  final Map<String, Object?>? after;

  @override
  String get targetId => viewId;

  @override
  String get kind => kindName;

  @override
  Map<String, Object?> toJson() => {
    'kind': kind,
    'collectionId': collectionId,
    'viewId': viewId,
    'index': index,
    'before': before,
    'after': after,
  };
}

/// Where one field's cell sits in a card layout.
final class CellPlacement {
  const CellPlacement({
    required this.sectionId,
    required this.rowId,
    required this.rowIndex,
    required this.cellIndex,
    required this.span,
  });

  factory CellPlacement.fromJson(Map<String, Object?> json) {
    _keys(json, const {'sectionId', 'rowId', 'rowIndex', 'cellIndex', 'span'});
    return CellPlacement(
      sectionId: _str(json, 'sectionId'),
      rowId: _str(json, 'rowId'),
      rowIndex: _int(json, 'rowIndex'),
      cellIndex: _int(json, 'cellIndex'),
      span: _int(json, 'span'),
    );
  }

  /// Where [fieldId] sits in [layout], or null when it has no cell.
  static CellPlacement? of(CardLayout layout, String fieldId) {
    for (final s in layout.sections) {
      for (final (r, row) in s.rows.indexed) {
        for (final (c, cell) in row.cells.indexed) {
          if (cell.fieldId != fieldId) continue;
          return CellPlacement(
            sectionId: s.id,
            rowId: row.id,
            rowIndex: r,
            cellIndex: c,
            span: cell.span,
          );
        }
      }
    }
    return null;
  }

  final String sectionId;
  final String rowId;

  /// Position hints for putting the cell back; other cells moving shifts
  /// them, so [sameSpot] ignores them.
  final int rowIndex;
  final int cellIndex;
  final int span;

  /// Whether [other] is the same row and span (the indexes are hints).
  bool sameSpot(CellPlacement? other) =>
      other != null &&
      other.sectionId == sectionId &&
      other.rowId == rowId &&
      other.span == span;

  Map<String, Object?> toJson() => {
    'sectionId': sectionId,
    'rowId': rowId,
    'rowIndex': rowIndex,
    'cellIndex': cellIndex,
    'span': span,
  };
}

/// One field's layout cell before and after (null: no cell).
final class JournalLayoutEntry extends JournalItem {
  const JournalLayoutEntry({
    required String collectionId,
    required this.fieldId,
    this.before,
    this.after,
  }) : super(collectionId);

  factory JournalLayoutEntry._fromJson(Map<String, Object?> json) {
    _keys(json, const {'kind', 'collectionId', 'fieldId', 'before', 'after'});
    CellPlacement? cell(String key) => switch (_mapOrNull(json, key)) {
      null => null,
      final m => CellPlacement.fromJson(m),
    };
    final before = cell('before');
    final after = cell('after');
    if (before == null && after == null) {
      throw const FormatException('A layout entry needs before or after');
    }
    return JournalLayoutEntry(
      collectionId: _str(json, 'collectionId'),
      fieldId: _str(json, 'fieldId'),
      before: before,
      after: after,
    );
  }

  static const String kindName = 'layout.entry';

  final String fieldId;
  final CellPlacement? before;
  final CellPlacement? after;

  @override
  String get targetId => fieldId;

  @override
  String get kind => kindName;

  @override
  Map<String, Object?> toJson() => {
    'kind': kind,
    'collectionId': collectionId,
    'fieldId': fieldId,
    'before': before?.toJson(),
    'after': after?.toJson(),
  };
}

/// A collection's name, description or icon before and after.
final class JournalCollectionMeta extends JournalItem {
  const JournalCollectionMeta({
    required String collectionId,
    required this.keys,
  }) : super(collectionId);

  factory JournalCollectionMeta._fromJson(Map<String, Object?> json) {
    _keys(json, const {'kind', 'collectionId', 'keys'});
    final raw = _map(json, 'keys');
    if (raw.isEmpty) throw const FormatException('"keys" is empty');
    final keys = <String, ValueChange>{};
    for (final e in raw.entries) {
      if (!metaKeys.contains(e.key)) {
        throw FormatException('"${e.key}" is not a collection key');
      }
      final change = _change(e.value, 'keys.${e.key}');
      if (change.before is! String? || change.after is! String?) {
        throw FormatException('"keys.${e.key}" must hold strings');
      }
      if (e.key == 'name' && (change.before == null || change.after == null)) {
        throw const FormatException('A collection name cannot be empty');
      }
      keys[e.key] = change;
    }
    return JournalCollectionMeta(
      collectionId: _str(json, 'collectionId'),
      keys: keys,
    );
  }

  static const String kindName = 'collection.meta';

  /// The collection keys a meta item may carry.
  static const Set<String> metaKeys = {'name', 'description', 'icon'};

  final Map<String, ValueChange> keys;

  /// [key] of [collection] (`name`, `description`, `icon`).
  static String? valueOf(Collection collection, String key) => switch (key) {
    'name' => collection.name,
    'description' => collection.description,
    'icon' => collection.icon,
    _ => throw ArgumentError.value(key, 'key'),
  };

  /// [collection] with [key] set to [value].
  static Collection withValue(Collection collection, String key, Object? v) =>
      switch (key) {
        'name' => collection.copyWith(name: v! as String),
        'description' => collection.copyWith(description: v as String?),
        'icon' => collection.copyWith(icon: v as String?),
        _ => throw ArgumentError.value(key, 'key'),
      };

  @override
  String get targetId => collectionId;

  @override
  String get kind => kindName;

  @override
  Map<String, Object?> toJson() => {
    'kind': kind,
    'collectionId': collectionId,
    'keys': {
      for (final e in keys.entries)
        e.key: {'before': e.value.before, 'after': e.value.after},
    },
  };
}

/// A created collection: undo deletes the cards it was created with, then
/// the collection unless someone added cards since.
final class JournalCollectionCreate extends JournalItem {
  const JournalCollectionCreate({
    required String collectionId,
    this.createdCardIds = const [],
  }) : super(collectionId);

  factory JournalCollectionCreate._fromJson(Map<String, Object?> json) {
    _keys(json, const {'kind', 'collectionId', 'createdCardIds'});
    final ids = json['createdCardIds'];
    if (ids is! List || ids.any((id) => id is! String)) {
      throw const FormatException('"createdCardIds" must be a list of ids');
    }
    return JournalCollectionCreate(
      collectionId: _str(json, 'collectionId'),
      createdCardIds: ids.cast<String>(),
    );
  }

  static const String kindName = 'collection.create';

  final List<String> createdCardIds;

  @override
  String get targetId => collectionId;

  @override
  String get kind => kindName;

  @override
  Map<String, Object?> toJson() => {
    'kind': kind,
    'collectionId': collectionId,
    'createdCardIds': createdCardIds,
  };
}

/// A deleted collection's schema (its cards are [JournalCardDelete]s of the
/// same entry): undo re-creates it, then the cards.
final class JournalCollectionDelete extends JournalItem {
  const JournalCollectionDelete({
    required String collectionId,
    required this.before,
  }) : super(collectionId);

  factory JournalCollectionDelete._fromJson(Map<String, Object?> json) {
    _keys(json, const {'kind', 'collectionId', 'before'});
    final entry = JournalCollectionDelete(
      collectionId: _str(json, 'collectionId'),
      before: _map(json, 'before'),
    );
    if (entry.before['id'] != entry.collectionId) {
      throw const FormatException('"before" is another collection');
    }
    return entry;
  }

  static const String kindName = 'collection.delete';

  /// `Collection.toJson` of the server copy.
  final Map<String, Object?> before;

  @override
  String get targetId => collectionId;

  @override
  String get kind => kindName;

  @override
  Map<String, Object?> toJson() => {
    'kind': kind,
    'collectionId': collectionId,
    'before': before,
  };
}

/// One journal item that could not be read or no longer applies, with why
/// (`invalid`, `schema_changed`, …).
typedef DroppedItem = ({String id, String reason});

/// One commit's inverse items, restorable after a reload until [expiresAt].
final class JournalEntry {
  JournalEntry({
    required this.journalId,
    required this.planId,
    required this.actor,
    required this.createdAt,
    required this.expiresAt,
    required List<JournalItem> items,
  }) : items = List.unmodifiable(items);

  /// Reads the head strictly (a bad head is a [FormatException]) and each
  /// item on its own, so one tampered item drops only itself.
  static ({JournalEntry entry, List<DroppedItem> dropped}) parse(
    Map<String, Object?> json,
  ) {
    _keys(json, const {
      'schema',
      'journalId',
      'planId',
      'actor',
      'createdAt',
      'expiresAt',
      'items',
    });
    if (json['schema'] != kJournalSchema) {
      throw FormatException('Unsupported journal schema ${json['schema']}');
    }
    final raw = json['items'];
    if (raw is! List) throw const FormatException('"items" must be a list');
    final items = <JournalItem>[];
    final dropped = <DroppedItem>[];
    for (final (i, item) in raw.indexed) {
      try {
        if (item is! Map) throw const FormatException('not an object');
        items.add(JournalItem.fromJson(item.cast<String, Object?>()));
      } on FormatException {
        final id = item is Map ? _anyId(item) : null;
        dropped.add((id: id ?? 'items[$i]', reason: 'invalid'));
      }
    }
    return (
      entry: JournalEntry(
        journalId: _str(json, 'journalId'),
        planId: _str(json, 'planId'),
        actor: _str(json, 'actor'),
        createdAt: _date(json, 'createdAt'),
        expiresAt: _date(json, 'expiresAt'),
        items: items,
      ),
      dropped: dropped,
    );
  }

  final String journalId;
  final String planId;

  /// `user:<uid>` of the user who committed.
  final String actor;
  final DateTime createdAt;

  /// Undo is refused from this instant on.
  final DateTime expiresAt;
  final List<JournalItem> items;

  bool isExpired(DateTime now) => !now.isBefore(expiresAt);

  /// The same entry with [items] instead.
  JournalEntry withItems(List<JournalItem> items) => JournalEntry(
    journalId: journalId,
    planId: planId,
    actor: actor,
    createdAt: createdAt,
    expiresAt: expiresAt,
    items: items,
  );

  Map<String, Object?> toJson() => {
    'schema': kJournalSchema,
    'journalId': journalId,
    'planId': planId,
    'actor': actor,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'expiresAt': expiresAt.toUtc().toIso8601String(),
    'items': [for (final i in items) i.toJson()],
  };

  /// [toJson] when it fits in [maxBytes] of UTF-8 JSON, else null (the
  /// mirror is omitted; undo lasts until the session ends).
  Map<String, Object?>? mirror({int maxBytes = kJournalMirrorMaxBytes}) {
    final json = toJson();
    return utf8.encode(jsonEncode(json)).length > maxBytes ? null : json;
  }
}

// ---------------------------------------------------------------------------
// Strict readers.

/// An entry image must be an object of the entry's own id; at least one
/// side must be present.
void _checkImages(
  Map<String, Object?>? before,
  Map<String, Object?>? after,
  String id,
) {
  if (before == null && after == null) {
    throw const FormatException('An entry needs before or after');
  }
  for (final image in [?before, ?after]) {
    if (image['id'] != id) {
      throw const FormatException('An image names another id');
    }
  }
}

void _keys(Map<String, Object?> json, Set<String> allowed, {String? at}) {
  for (final key in json.keys) {
    if (!allowed.contains(key)) {
      throw FormatException('Unexpected key "${at == null ? '' : '$at.'}$key"');
    }
  }
}

String _str(Map<String, Object?> json, String key) => switch (json[key]) {
  final String s when s.isNotEmpty => s,
  _ => throw FormatException('"$key" must be a non-empty string'),
};

int _int(Map<String, Object?> json, String key) => switch (json[key]) {
  final int i when i >= 0 => i,
  _ => throw FormatException('"$key" must be a non-negative integer'),
};

DateTime _date(Map<String, Object?> json, String key) {
  final raw = _str(json, key);
  return DateTime.tryParse(raw)?.toUtc() ??
      (throw FormatException('"$key" is not an ISO date'));
}

Map<String, Object?> _map(Map<String, Object?> json, String key) =>
    switch (json[key]) {
      final Map m => m.cast<String, Object?>(),
      _ => throw FormatException('"$key" must be an object'),
    };

Map<String, Object?>? _mapOrNull(Map<String, Object?> json, String key) {
  if (!json.containsKey(key)) throw FormatException('"$key" is missing');
  return json[key] == null ? null : _map(json, key);
}

ValueChange _change(Object? raw, String path) {
  if (raw is! Map) throw FormatException('"$path" must be an object');
  final m = raw.cast<String, Object?>();
  _keys(m, const {'before', 'after'}, at: path);
  if (!m.containsKey('before') || !m.containsKey('after')) {
    throw FormatException('"$path" needs before and after');
  }
  return (before: m['before'], after: m['after']);
}

/// The best id to report for an unreadable item.
String? _anyId(Map<Object?, Object?> item) {
  for (final key in const ['id', 'fieldId', 'viewId', 'collectionId']) {
    if (item[key] case final String id) return id;
  }
  return null;
}
