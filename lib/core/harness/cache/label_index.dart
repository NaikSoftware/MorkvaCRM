import '../../domain/domain.dart';

/// Where a [LabelIndex.search] matched: the card and the first field whose
/// text holds the query.
typedef SearchHit = ({String id, String fieldId});

/// Human labels and text search over one snapshot of a collection.
///
/// Built once per snapshot, on first read (see `CollectionSnapshot.labels`):
/// - [labels]: `objectLabels` (the first text field, `Untitled` when blank),
///   the one labelling rule the views and the editor use;
/// - [idsWithLabel]: a case-insensitive label → ids multimap, so a card title
///   resolves to its id and two cards with one title are ambiguous;
/// - [search]: every query term must occur in some searchable value (text,
///   auto-number, select labels), case-insensitively.
final class LabelIndex {
  LabelIndex(this.collection, List<MorkvaObject> objects)
    : labels = objectLabels(collection, objects) {
    final searchable = [
      for (final f in collection.fields)
        if (_isSearchable(f)) f,
    ];
    for (final o in objects) {
      final label = labels[o.id]!;
      (_byLabel[_fold(label)] ??= []).add(o.id);
      _texts.add((
        id: o.id,
        texts: [
          for (final f in searchable)
            if (_textOf(f, o[f.id] ?? f.emptyValue()) case final text?)
              (fieldId: f.id, text: text),
        ],
      ));
    }
  }

  final Collection collection;

  /// Object id → label, in the order of the collection's first view.
  final Map<String, String> labels;

  final Map<String, List<String>> _byLabel = {};
  final List<({String id, List<({String fieldId, String text})> texts})>
  _texts = [];

  /// The label of object [id]; `Untitled` when it is not in this snapshot.
  String labelOf(String id) => labels[id] ?? 'Untitled';

  /// Ids of the objects labelled [label] (trimmed, case-insensitive), in
  /// stored order; empty when none is.
  List<String> idsWithLabel(String label) =>
      List.unmodifiable(_byLabel[_fold(label)] ?? const <String>[]);

  /// The objects matching [query], in stored order, at most [limit]. Each
  /// whitespace-separated term must occur in one of the object's searchable
  /// values; the hit names the first value holding the first term. A blank
  /// query matches nothing.
  List<SearchHit> search(String query, {int? limit}) {
    final terms = _fold(query).split(RegExp(r'\s+'))
      ..removeWhere((t) => t.isEmpty);
    if (terms.isEmpty) return const [];
    final hits = <SearchHit>[];
    for (final entry in _texts) {
      if (!terms.every((t) => entry.texts.any((v) => v.text.contains(t)))) {
        continue;
      }
      final field = entry.texts.firstWhere((v) => v.text.contains(terms[0]));
      hits.add((id: entry.id, fieldId: field.fieldId));
      if (limit != null && hits.length >= limit) break;
    }
    return hits;
  }

  static String _fold(String text) => text.trim().toLowerCase();

  static bool _isSearchable(FieldDefinition f) =>
      f is TextFieldDefinition ||
      f is AutoNumberFieldDefinition ||
      f is SingleSelectFieldDefinition ||
      f is MultiSelectFieldDefinition;

  /// [value] as lowercase searchable text, or null when blank.
  static String? _textOf(FieldDefinition f, FieldValue value) {
    final text = formatFieldValue(f, value).trim();
    return text.isEmpty ? null : text.toLowerCase();
  }
}
