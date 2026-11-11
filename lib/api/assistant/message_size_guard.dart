import 'dart:convert';

import 'thread_repository.dart';

/// Byte budget for one turn doc (Firestore rejects docs over 1 MiB).
const int kMessageDocBudgetBytes = 700 * 1024;

/// A turn record after [fitMessageToBudget].
final class FittedMessage {
  const FittedMessage({
    required this.record,
    required this.bytes,
    required this.elidedRounds,
    required this.journalDropped,
    required this.fits,
  });

  /// The record to write (the input itself when nothing had to change).
  final AssistantRecord record;

  /// Its stored size per [firestoreDocSize].
  final int bytes;

  /// How many contents' function responses were cut to `{elided, summary}`.
  final int elidedRounds;

  /// The journal mirror was removed: undo then lasts only for this session
  /// ("Undo available until you close Morkva").
  final bool journalDropped;

  /// Whether [bytes] is within the budget even after shrinking.
  final bool fits;
}

/// Shrinks a turn record until it fits [budget]: first the oldest rounds'
/// function responses inside `llm` become `{elided: true, summary}`, one round
/// at a time, then the `journal` mirror is dropped.
FittedMessage fitMessageToBudget(
  AssistantRecord record, {
  int budget = kMessageDocBudgetBytes,
}) {
  var current = record;
  var bytes = firestoreDocSize(current);
  var elided = 0;
  final contents = bytes > budget ? _decodeLlm(record['llm']) : null;
  if (contents != null) {
    for (final content in contents) {
      if (bytes <= budget) break;
      if (!_elideResponses(content)) continue;
      elided++;
      current = {...current, 'llm': jsonEncode(contents)};
      bytes = firestoreDocSize(current);
    }
  }
  var journalDropped = false;
  if (bytes > budget && current.containsKey('journal')) {
    current = {...current}..remove('journal');
    journalDropped = true;
    bytes = firestoreDocSize(current);
  }
  return FittedMessage(
    record: current,
    bytes: bytes,
    elidedRounds: elided,
    journalDropped: journalDropped,
    fits: bytes <= budget,
  );
}

/// The stored size of a doc with [data], per Firestore's size rules (strings
/// count UTF-8 bytes + 1, numbers and timestamps 8, bools and null 1, map keys
/// like strings, plus 32 per doc). The doc name (~150 bytes here) is left to
/// the budget's headroom.
int firestoreDocSize(AssistantRecord data) => 32 + _mapSize(data);

int _mapSize(Map<Object?, Object?> map) {
  var size = 0;
  map.forEach((key, value) {
    size += utf8.encode('$key').length + 1 + _valueSize(value);
  });
  return size;
}

int _valueSize(Object? value) => switch (value) {
  null || bool() => 1,
  String() => utf8.encode(value).length + 1,
  Map() => _mapSize(value),
  List() => value.fold(0, (sum, item) => sum + _valueSize(item)),
  _ => 8, // num, Timestamp, DateTime
};

List<Object?>? _decodeLlm(Object? llm) {
  if (llm is! String) return null;
  try {
    final decoded = jsonDecode(llm);
    return decoded is List ? decoded : null;
  } on FormatException {
    return null;
  }
}

/// Cuts every not yet elided `functionResponse.response` of one content
/// (`{role, parts: [{functionResponse: {name, response, id?}}]}`); returns
/// whether anything changed.
bool _elideResponses(Object? content) {
  if (content is! Map || content['parts'] is! List) return false;
  var changed = false;
  for (final part in content['parts'] as List) {
    if (part is! Map) continue;
    final call = part['functionResponse'];
    if (call is! Map) continue;
    final response = call['response'];
    if (response is Map && response['elided'] == true) continue;
    call['response'] = {
      'elided': true,
      if (response is Map && response['summary'] is String)
        'summary': response['summary'],
    };
    changed = true;
  }
  return changed;
}
