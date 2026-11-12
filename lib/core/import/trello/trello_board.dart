import 'dart:convert';

/// A Trello board export ("Export as JSON") that could not be read.
class TrelloFormatException implements Exception {
  const TrelloFormatException(this.message);

  /// A message for the user.
  final String message;

  @override
  String toString() => 'TrelloFormatException: $message';
}

/// The parts of a Trello board export the importer uses, read tolerantly:
/// entries without an id are skipped and malformed values read as empty.
class TrelloBoard {
  const TrelloBoard({
    required this.id,
    required this.name,
    this.desc = '',
    this.lists = const [],
    this.cards = const [],
    this.labels = const [],
    this.members = const [],
    this.checklists = const [],
    this.customFields = const [],
    this.comments = const [],
  });

  final String id;
  final String name;
  final String desc;
  final List<TrelloList> lists;
  final List<TrelloCard> cards;
  final List<TrelloLabel> labels;
  final List<TrelloMember> members;
  final List<TrelloChecklist> checklists;
  final List<TrelloCustomField> customFields;

  /// The `commentCard` actions (an export keeps only the newest 1000 actions).
  final List<TrelloComment> comments;

  static const _notABoard = TrelloFormatException(
    "This isn't a Trello board export. Use Export as JSON on the board.",
  );

  /// Parses a board export; throws [TrelloFormatException] when [jsonText] is
  /// not JSON or lacks the board's id, name, lists or cards.
  static TrelloBoard parse(String jsonText) {
    final Object? json;
    try {
      json = jsonDecode(jsonText);
    } on FormatException {
      throw _notABoard;
    }
    if (json is! Map<String, dynamic>) throw _notABoard;
    final id = _str(json['id']);
    final name = json['name'];
    if (id == null || name is! String) throw _notABoard;
    if (json['lists'] is! List || json['cards'] is! List) throw _notABoard;

    final labels = _withId(json['labels']).map(TrelloLabel._fromJson).toList();
    final cards = _withId(json['cards']).map(TrelloCard._fromJson).toList();
    // Cards inline their labels; keep any the board list lacks.
    final knownLabels = {for (final l in labels) l.id};
    for (final card in _withId(json['cards'])) {
      for (final label in _withId(card['labels'])) {
        if (knownLabels.add(_str(label['id'])!)) {
          labels.add(TrelloLabel._fromJson(label));
        }
      }
    }
    return TrelloBoard(
      id: id,
      name: name,
      desc: _str(json['desc']) ?? '',
      lists: _withId(json['lists']).map(TrelloList._fromJson).toList(),
      cards: cards,
      labels: labels,
      members: _withId(json['members']).map(TrelloMember._fromJson).toList(),
      checklists: _withId(
        json['checklists'],
      ).map(TrelloChecklist._fromJson).toList(),
      customFields: _withId(
        json['customFields'],
      ).map(TrelloCustomField._fromJson).toList(),
      comments: [
        for (final action in _maps(json['actions']))
          if (action['type'] == 'commentCard') ?TrelloComment._fromJson(action),
      ],
    );
  }
}

class TrelloList {
  const TrelloList({
    required this.id,
    required this.name,
    this.closed = false,
    this.pos = 0,
  });

  final String id;
  final String name;
  final bool closed;
  final num pos;

  factory TrelloList._fromJson(Map<String, dynamic> json) => TrelloList(
    id: _str(json['id'])!,
    name: _str(json['name']) ?? '',
    closed: json['closed'] == true,
    pos: _num(json['pos']) ?? 0,
  );
}

class TrelloLabel {
  const TrelloLabel({required this.id, required this.name, this.color});

  final String id;
  final String name;

  /// A Trello colour name (`green`, `sky_dark` …) or null for no colour.
  final String? color;

  factory TrelloLabel._fromJson(Map<String, dynamic> json) => TrelloLabel(
    id: _str(json['id'])!,
    name: _str(json['name']) ?? '',
    color: _str(json['color']),
  );
}

class TrelloMember {
  const TrelloMember({required this.id, required this.fullName});

  final String id;

  /// The full name, or the username when the name is blank.
  final String fullName;

  factory TrelloMember._fromJson(Map<String, dynamic> json) =>
      TrelloMember(id: _str(json['id'])!, fullName: _personName(json));
}

class TrelloAttachment {
  const TrelloAttachment({required this.name, required this.url});

  final String name;
  final String url;
}

class TrelloCard {
  const TrelloCard({
    required this.id,
    required this.name,
    this.desc = '',
    this.idList,
    this.closed = false,
    this.pos = 0,
    this.start,
    this.due,
    this.dueComplete = false,
    this.idLabels = const [],
    this.idMembers = const [],
    this.attachments = const [],
    this.shortUrl,
    this.dateLastActivity,
    this.customValues = const {},
  });

  final String id;
  final String name;
  final String desc;
  final String? idList;
  final bool closed;
  final num pos;
  final DateTime? start;
  final DateTime? due;
  final bool dueComplete;
  final List<String> idLabels;
  final List<String> idMembers;
  final List<TrelloAttachment> attachments;
  final String? shortUrl;
  final DateTime? dateLastActivity;

  /// Custom-field id → value: a `String` (text, or the option id of a list
  /// field), `num`, `DateTime` or `bool`. A field without a value is absent.
  final Map<String, Object> customValues;

  factory TrelloCard._fromJson(Map<String, dynamic> json) => TrelloCard(
    id: _str(json['id'])!,
    name: _str(json['name']) ?? '',
    desc: _str(json['desc']) ?? '',
    idList: _str(json['idList']),
    closed: json['closed'] == true,
    pos: _num(json['pos']) ?? 0,
    start: _date(json['start']),
    due: _date(json['due']),
    dueComplete: json['dueComplete'] == true,
    idLabels: _strings(json['idLabels']),
    idMembers: _strings(json['idMembers']),
    attachments: [
      for (final a in _maps(json['attachments']))
        if (_str(a['url']) case final url?)
          TrelloAttachment(name: _str(a['name']) ?? '', url: url),
    ],
    shortUrl: _str(json['shortUrl']),
    dateLastActivity: _date(json['dateLastActivity']),
    customValues: {
      for (final item in _maps(json['customFieldItems']))
        if ((_str(item['idCustomField']), _customValue(item)) case (
          final field?,
          final value?,
        ))
          field: value,
    },
  );
}

class TrelloCheckItem {
  const TrelloCheckItem({
    required this.id,
    required this.name,
    this.pos = 0,
    this.complete = false,
    this.due,
  });

  final String id;
  final String name;
  final num pos;
  final bool complete;
  final DateTime? due;
}

class TrelloChecklist {
  const TrelloChecklist({
    required this.id,
    required this.name,
    this.idCard,
    this.pos = 0,
    this.items = const [],
  });

  final String id;
  final String name;
  final String? idCard;
  final num pos;
  final List<TrelloCheckItem> items;

  factory TrelloChecklist._fromJson(Map<String, dynamic> json) =>
      TrelloChecklist(
        id: _str(json['id'])!,
        name: _str(json['name']) ?? '',
        idCard: _str(json['idCard']),
        pos: _num(json['pos']) ?? 0,
        items: [
          for (final item in _withId(json['checkItems']))
            TrelloCheckItem(
              id: _str(item['id'])!,
              name: _str(item['name']) ?? '',
              pos: _num(item['pos']) ?? 0,
              complete: item['state'] == 'complete',
              due: _date(item['due']),
            ),
        ],
      );
}

class TrelloCustomFieldOption {
  const TrelloCustomFieldOption({
    required this.id,
    required this.text,
    this.color,
    this.pos = 0,
  });

  final String id;
  final String text;

  /// A Trello colour name, or null for `none`.
  final String? color;
  final num pos;
}

class TrelloCustomField {
  const TrelloCustomField({
    required this.id,
    required this.name,
    required this.type,
    this.pos = 0,
    this.options = const [],
  });

  final String id;
  final String name;

  /// `text`, `number`, `date`, `checkbox` or `list`.
  final String type;
  final num pos;

  /// The choices of a `list` field.
  final List<TrelloCustomFieldOption> options;

  factory TrelloCustomField._fromJson(Map<String, dynamic> json) =>
      TrelloCustomField(
        id: _str(json['id'])!,
        name: _str(json['name']) ?? '',
        type: _str(json['type']) ?? '',
        pos: _num(json['pos']) ?? 0,
        options: [
          for (final o in _withId(json['options']))
            TrelloCustomFieldOption(
              id: _str(o['id'])!,
              text: switch (o['value']) {
                {'text': final String text} => text,
                _ => '',
              },
              color: switch (_str(o['color'])) {
                'none' => null,
                final color => color,
              },
              pos: _num(o['pos']) ?? 0,
            ),
        ],
      );
}

class TrelloComment {
  const TrelloComment({
    required this.id,
    required this.cardId,
    required this.text,
    required this.author,
    this.date,
  });

  final String id;
  final String cardId;
  final String text;
  final String author;
  final DateTime? date;

  static TrelloComment? _fromJson(Map<String, dynamic> json) {
    final id = _str(json['id']);
    if (id == null) return null;
    final (cardId, text) = switch (json['data']) {
      {'card': {'id': final String cardId}, 'text': final String text} => (
        cardId,
        text,
      ),
      {'card': {'id': final String cardId}} => (cardId, ''),
      _ => (null, ''),
    };
    if (cardId == null) return null;
    final creator = json['memberCreator'];
    return TrelloComment(
      id: id,
      cardId: cardId,
      text: text,
      author: creator is Map<String, dynamic> ? _personName(creator) : '',
      date: _date(json['date']),
    );
  }
}

/// The JSON objects in [raw] when it is a list.
Iterable<Map<String, dynamic>> _maps(Object? raw) =>
    raw is List ? raw.whereType<Map<String, dynamic>>() : const [];

/// The JSON objects in [raw] that carry an id; the others are skipped.
Iterable<Map<String, dynamic>> _withId(Object? raw) =>
    _maps(raw).where((m) => _str(m['id']) != null);

String? _str(Object? raw) => raw is String && raw.isNotEmpty ? raw : null;

List<String> _strings(Object? raw) =>
    raw is List ? raw.whereType<String>().toList() : const [];

num? _num(Object? raw) {
  final n = raw is num
      ? raw
      : (raw is String ? num.tryParse(raw.trim()) : null);
  return n != null && n.isFinite ? n : null;
}

DateTime? _date(Object? raw) =>
    raw is String ? DateTime.tryParse(raw)?.toUtc() : null;

String _personName(Map<String, dynamic> json) =>
    _str(_trimmed(json['fullName'])) ?? _str(json['username']) ?? '';

String? _trimmed(Object? raw) => raw is String ? raw.trim() : null;

/// A custom-field item's value, or null when it is empty or unreadable.
/// Trello stores every value as a string; booleans and numbers are accepted
/// too.
Object? _customValue(Map<String, dynamic> item) {
  if (_str(item['idValue']) case final option?) return option;
  return switch (item['value']) {
    {'text': final String text} when text.trim().isNotEmpty => text,
    {'number': final raw} => _num(raw),
    {'date': final raw} => _date(raw),
    {'checked': final raw} => switch (raw) {
      true || 'true' => true,
      false || 'false' => false,
      _ => null,
    },
    _ => null,
  };
}
