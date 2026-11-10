import '../../domain/collection.dart';
import '../../domain/field_definition.dart';
import '../../domain/morkva_object.dart';
import '../../domain/types/auto_number_field.dart';
import '../../domain/types/select_option.dart';
import '../../domain/types/text_field.dart';
import '../../domain/view/field_format.dart';
import '../../domain/view/view_definition.dart';
import '../api/envelope.dart';
import '../api/harness_context.dart';
import '../schema/arg_shapes.dart';

/// The workspace as the input layer reads it. The workspace cache implements
/// it over leased snapshots and the planning overlay over pending changes;
/// tests back it with plain lists.
abstract interface class WorkspaceReader {
  /// Every collection the user can access, lookups resolved (so a lookup's
  /// `outputField` is its target's type). Grants are applied by the resolver.
  List<Collection> get collections;

  /// The cards of [collectionId]. Callers lease the collection first.
  List<MorkvaObject> objectsOf(String collectionId);
}

/// A [WorkspaceReader] over fixed lists.
final class StaticWorkspace implements WorkspaceReader {
  StaticWorkspace(this.collections, [this.objects = const {}]);

  @override
  final List<Collection> collections;

  final Map<String, List<MorkvaObject>> objects;

  @override
  List<MorkvaObject> objectsOf(String collectionId) =>
      objects[collectionId] ?? const [];
}

/// The reserved refs that point at what is on screen.
abstract final class ScreenRefs {
  /// The screen's query (collection, filters, search, sort).
  static const String screen = '@screen';

  /// The card open in the editor or sheet.
  static const String card = '@card';

  /// The selected cards.
  static const String selected = '@selected';
}

/// Resolves friendly refs (ids, or names, labels and titles matched
/// case-insensitively) to schema entries and card ids, failing with
/// candidates the caller can retry with.
///
/// Scope: collections outside `ctx.grants` are invisible (`unknown_collection`
/// when named directly); reaching one through a reference field is
/// `not_permitted`. Card title indexes are built once per collection per
/// resolver, so build one resolver per call and reuse it for every row.
final class RefResolver {
  RefResolver(
    this.workspace,
    this.ctx, {
    Map<String, String> cardAliases = const {},
  }) : _aliases = cardAliases;

  final WorkspaceReader workspace;
  final HarnessContext ctx;

  /// Turn-local refs (`@c1` → a card id) a planning overlay has minted.
  final Map<String, String> _aliases;
  final Map<String, _CardIndex> _cardIndexes = {};

  /// The collections this caller may see.
  List<Collection> get visibleCollections => [
    for (final c in workspace.collections)
      if (ctx.grants.allowsCollection(c.id)) c,
  ];

  /// The visible collection [ref] names.
  Collection collection(String ref, {String path = 'collection'}) {
    final visible = visibleCollections;
    final hit = _match(
      ref,
      visible,
      (c) => c.id,
      (c) => c.name,
      path: path,
      kind: 'collection',
    );
    if (hit != null) return hit;
    final names = [for (final c in visible) c.name];
    throw HarnessException.of(
      ErrorCode.unknownCollection,
      'There is no collection "$ref".${_didYouMean(ref, names)}',
      path: path,
      candidates: names.length <= 10 ? names : nearest(ref, names, 5),
      hint: 'Use a collection name or id from workspace.describe.',
    );
  }

  /// The collection with [id], reached through a reference field or a stored
  /// id: `unknown_collection` when it is gone, `not_permitted` when it lies
  /// outside the caller's grants.
  Collection collectionById(String id, {String path = 'collection'}) {
    final found = workspace.collections.where((c) => c.id == id).firstOrNull;
    if (found == null) {
      throw HarnessException.of(
        ErrorCode.unknownCollection,
        'Collection "$id" no longer exists.',
        path: path,
      );
    }
    if (!ctx.grants.allowsCollection(id)) {
      throw HarnessException.of(
        ErrorCode.notPermitted,
        'This client may not touch collection "${found.name}".',
        path: path,
      );
    }
    return found;
  }

  /// The field of [collection] that [ref] names.
  FieldDefinition field(
    Collection collection,
    String ref, {
    String path = 'field',
  }) {
    final hit = _match(
      ref,
      collection.fields,
      (f) => f.id,
      (f) => f.name,
      path: path,
      kind: 'field',
    );
    if (hit != null) return hit;
    final names = [for (final f in collection.fields) f.name];
    throw HarnessException.of(
      ErrorCode.unknownField,
      'No field "$ref" in ${collection.name}.${_didYouMean(ref, names)}',
      path: path,
      candidates: nearest(ref, names, 3),
      hint: 'Use a field name or id from collections.get.',
    );
  }

  /// A field id of [collection], or [kCreatedAtRef] / [kUpdatedAtRef] (the
  /// card's timestamps) when [ref] is one of them.
  String fieldIdOrMeta(
    Collection collection,
    String ref, {
    String path = 'field',
  }) {
    final meta = ref.trim();
    if (meta == kCreatedAtRef || meta == kUpdatedAtRef) return meta;
    return field(collection, ref, path: path).id;
  }

  /// The view of [collection] that [ref] names.
  ViewDefinition view(
    Collection collection,
    String ref, {
    String path = 'view',
  }) {
    final hit = _match(
      ref,
      collection.views,
      (v) => v.id,
      (v) => v.name,
      path: path,
      kind: 'view',
    );
    if (hit != null) return hit;
    throw HarnessException.of(
      ErrorCode.unknownView,
      'No view "$ref" in ${collection.name}.',
      path: path,
      candidates: [for (final v in collection.views) v.name],
    );
  }

  /// The option of [field] (named [fieldName]) that [ref] names, by id or
  /// label.
  SelectOption option(
    String fieldName,
    List<SelectOption> options,
    String ref, {
    String path = 'option',
  }) {
    final hit = _match(
      ref,
      options,
      (o) => o.id,
      (o) => o.label,
      path: path,
      kind: 'option',
    );
    if (hit != null) return hit;
    throw HarnessException.of(
      ErrorCode.unknownOption,
      '$fieldName has no option "$ref". Options: '
      '${options.map((o) => o.label).join(', ')}.',
      path: path,
      candidates: [for (final o in options) o.label],
      hint: 'Add it first with fields.update addOptions.',
    );
  }

  /// The one card of [collection] that [ref] names: an id, a title (the
  /// first text field), an auto-number as shown (`#1042`), [ScreenRefs.card],
  /// a one-card [ScreenRefs.selected] or a turn-local `@` alias.
  ///
  /// A miss fails with [missing] (`unknown_object` by default; value input
  /// uses `invalid_reference`) and the nearest 3 titles.
  String card(
    Collection collection,
    String ref, {
    String path = 'card',
    ErrorCode missing = ErrorCode.unknownObject,
  }) {
    final ids = cards(collection, [ref], path: path, missing: missing);
    if (ids.length != 1) {
      throw HarnessException.of(
        ErrorCode.invalidArgs,
        '"$ref" means ${ids.length} cards here; only one fits.',
        path: path,
        hint: 'Pass the card ids one by one.',
      );
    }
    return ids.single;
  }

  /// The card ids [refs] name in [collection], in order, without repeats;
  /// [ScreenRefs.selected] expands to every selected card. Every ref is
  /// checked; the first miss throws.
  List<String> cards(
    Collection collection,
    Iterable<String> refs, {
    String path = 'ids',
    ErrorCode missing = ErrorCode.unknownObject,
  }) {
    final out = <String>{};
    var i = 0;
    final many = refs.length > 1;
    for (final ref in refs) {
      final at = many ? '$path[$i]' : path;
      out.addAll(_cardIds(collection, ref, at, missing));
      i++;
    }
    return out.toList();
  }

  /// The screen snapshot, which must show a collection; `invalid_args`
  /// otherwise.
  ScreenContext screen({String path = 'from'}) {
    final focus = ctx.focus;
    if (focus == null || focus.collectionId == null) {
      throw HarnessException.of(
        ErrorCode.invalidArgs,
        'Nothing is on screen to refer to.',
        path: path,
        hint:
            'Name the collection and filters instead of ${ScreenRefs.screen}.',
      );
    }
    return focus;
  }

  /// The collection on screen.
  Collection screenCollection({String path = 'from'}) {
    final id = screen(path: path).collectionId!;
    if (!workspace.collections.any((c) => c.id == id)) {
      throw HarnessException.of(
        ErrorCode.invalidArgs,
        'The collection on screen no longer exists.',
        path: path,
      );
    }
    return collectionById(id, path: path);
  }

  List<String> _cardIds(
    Collection collection,
    String ref,
    String path,
    ErrorCode missing,
  ) {
    final trimmed = ref.trim();
    if (trimmed == ScreenRefs.card) {
      final focus = _screenOf(collection, path, ScreenRefs.card);
      final id = focus.openCardId;
      if (id == null) {
        throw HarnessException.of(
          ErrorCode.invalidArgs,
          'No card is open on screen.',
          path: path,
        );
      }
      return [_existing(collection, id, path, ScreenRefs.card)];
    }
    if (trimmed == ScreenRefs.selected) {
      final focus = _screenOf(collection, path, ScreenRefs.selected);
      if (focus.selectedIds.isEmpty) {
        throw HarnessException.of(
          ErrorCode.invalidArgs,
          'Nothing is selected on screen.',
          path: path,
        );
      }
      return [
        for (final id in focus.selectedIds)
          _existing(collection, id, path, ScreenRefs.selected),
      ];
    }
    final index = _index(collection);
    final alias = _aliases[trimmed];
    if (alias != null && index.ids.contains(alias)) return [alias];
    if (index.ids.contains(ref)) return [ref];
    final hits = index.byKey[_norm(ref)] ?? const [];
    if (hits.length == 1) return hits;
    if (hits.length > 1) {
      throw HarnessException.of(
        ErrorCode.ambiguousReference,
        '${hits.length} ${collection.name} cards are called "$ref". '
        'Pass one of their ids.',
        path: path,
        candidates: [
          for (final id in hits.take(10)) {'id': id, 'title': index.titles[id]},
        ],
      );
    }
    final titles = index.titles;
    final near = nearest(ref, titles.values, 3);
    throw HarnessException.of(
      missing,
      'No card "$ref" in ${collection.name}.',
      path: path,
      candidates: [
        for (final title in near)
          {
            'id': titles.entries.firstWhere((e) => e.value == title).key,
            'title': title,
          },
      ],
      hint: 'Use a card id or exact title (cards.find searches by text).',
    );
  }

  ScreenContext _screenOf(Collection collection, String path, String ref) {
    final focus = screen(path: path);
    if (focus.collectionId != collection.id) {
      final onScreen = workspace.collections
          .where((c) => c.id == focus.collectionId)
          .firstOrNull;
      throw HarnessException.of(
        ErrorCode.invalidArgs,
        '$ref is in ${onScreen?.name ?? 'another collection'}, '
        'not in ${collection.name}.',
        path: path,
      );
    }
    return focus;
  }

  String _existing(Collection collection, String id, String path, String ref) {
    if (_index(collection).ids.contains(id)) return id;
    throw HarnessException.of(
      ErrorCode.unknownObject,
      'The card $ref means ($id) no longer exists in ${collection.name}.',
      path: path,
    );
  }

  _CardIndex _index(Collection collection) => _cardIndexes.putIfAbsent(
    collection.id,
    () => _CardIndex(collection, workspace.objectsOf(collection.id)),
  );

  /// The item whose id is [ref], else the one whose name matches it
  /// case-insensitively; null when none does. Several name matches are an
  /// `ambiguous_reference`.
  T? _match<T>(
    String ref,
    Iterable<T> items,
    String Function(T) idOf,
    String Function(T) nameOf, {
    required String path,
    required String kind,
  }) {
    for (final item in items) {
      if (idOf(item) == ref) return item;
    }
    final key = _norm(ref);
    final hits = [
      for (final item in items)
        if (_norm(nameOf(item)) == key) item,
    ];
    if (hits.length <= 1) return hits.firstOrNull;
    throw HarnessException.of(
      ErrorCode.ambiguousReference,
      '${hits.length} ${kind}s are called "$ref". Pass one of their ids.',
      path: path,
      candidates: [
        for (final h in hits) {'id': idOf(h), 'name': nameOf(h)},
      ],
    );
  }
}

/// Lowercased, trimmed, inner whitespace collapsed: how refs are compared.
String _norm(String s) => s.trim().toLowerCase().replaceAll(_spaces, ' ');
final RegExp _spaces = RegExp(r'\s+');

String _didYouMean(String ref, List<String> names) {
  final best = nearest(ref, names, 1);
  return best.isEmpty ? '' : ' Did you mean "${best.single}"?';
}

/// Up to [n] of [names] closest to [query] (prefix and substring hits first,
/// then by edit distance), for "did you mean" candidates. Names further than
/// half their length away are left out.
List<String> nearest(String query, Iterable<String> names, int n) {
  final q = _norm(query);
  final scored = <(int, String)>[];
  for (final name in names.toSet()) {
    final k = _norm(name);
    final score = k.startsWith(q) || q.startsWith(k)
        ? 0
        : k.contains(q) || q.contains(k)
        ? 1
        : 2 + _distance(q, k);
    if (score < 2 || score - 2 <= (k.length / 2).ceil()) {
      scored.add((score, name));
    }
  }
  scored.sort((a, b) => a.$1 != b.$1 ? a.$1 - b.$1 : a.$2.compareTo(b.$2));
  return [for (final s in scored.take(n)) s.$2];
}

/// Levenshtein distance.
int _distance(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  var prev = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final cur = List<int>.filled(b.length + 1, 0)..[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      final best = prev[j] + 1 < cur[j - 1] + 1 ? prev[j] + 1 : cur[j - 1] + 1;
      cur[j] = best < prev[j - 1] + cost ? best : prev[j - 1] + cost;
    }
    prev = cur;
  }
  return prev[b.length];
}

/// The ids, titles and lookup keys of one collection's cards. A card's title
/// is its first text field (the label the app shows); its auto-numbers as
/// shown (`#1042`) are keys too. Blank titles are not keys.
final class _CardIndex {
  _CardIndex(Collection collection, List<MorkvaObject> objects) {
    final titleField = collection.fields
        .whereType<TextFieldDefinition>()
        .firstOrNull;
    final numbers = collection.fields.whereType<AutoNumberFieldDefinition>();
    for (final o in objects) {
      ids.add(o.id);
      final title = switch (o[titleField?.id ?? '']) {
        TextFieldValue(:final text?) when text.trim().isNotEmpty => text.trim(),
        _ => null,
      };
      titles[o.id] = title ?? 'Untitled';
      if (title != null) _key(title, o.id);
      for (final f in numbers) {
        final value = o[f.id];
        if (value != null && value.isNotEmpty) {
          _key(formatFieldValue(f, value), o.id);
        }
      }
    }
  }

  final Set<String> ids = {};
  final Map<String, String> titles = {};
  final Map<String, List<String>> byKey = {};

  void _key(String key, String id) {
    final ids = byKey.putIfAbsent(_norm(key), () => []);
    if (!ids.contains(id)) ids.add(id);
  }
}
