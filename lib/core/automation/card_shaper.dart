// The cards a module is handed (`ctx.card`, `trigger.before/after`) go
// through the same projection `cards.get` uses under the run's effective
// grants (design spec, Action context; critique S4).
import '../domain/domain.dart';
import '../harness/api/capability.dart';
import '../harness/cache/workspace_cache.dart';
import '../harness/query/query_engine.dart' show readsUngranted;
import '../harness/query/result_shaper.dart';

/// Shapes cards for the action context: `Card` is `{id, collectionId, title,
/// values: {fieldId: display value}, fields: {fieldId: name}}`, values in
/// the `cards.get` display form. Calculated fields that read an ungranted
/// collection are left out, reference titles outside the grants are
/// withheld. Without `data:read` a module gets a `CardRef` `{id,
/// collectionId}` for `ctx.card` and nothing for the trigger images.
final class CardShaper {
  CardShaper(this.cache, {this.shaper = const ResultShaper()});

  final WorkspaceCache cache;
  final ResultShaper shaper;

  /// `ctx.card` for card [cardId] of [collectionId] as stored now, derived
  /// for [today]; null when the card or the collection is gone, or the
  /// collection is outside [grants].
  Future<Map<String, Object?>?> current(
    String collectionId,
    String cardId,
    Grants grants, {
    required DateTime today,
  }) async {
    if (!grants.allowsCollection(collectionId)) return null;
    if (!grants.allows(Capability.dataRead)) {
      return _ref(collectionId, cardId);
    }
    try {
      final derived = await cache.derive(collectionId, today: today);
      final stored = derived.base[cardId];
      return stored == null
          ? null
          : _card(derived.schema, derived.deriveWith(stored)!, grants);
    } on MissingCollectionException {
      return null;
    }
  }

  /// `ctx.card` from an event image [object] of [collection] whose
  /// calculated values are already filled (`DerivedSnapshot.deriveWith`):
  /// a `CardRef` without `data:read`.
  Map<String, Object?>? card(
    Collection collection,
    MorkvaObject? object,
    Grants grants,
  ) {
    if (object == null || !grants.allowsCollection(collection.id)) {
      return null;
    }
    return grants.allows(Capability.dataRead)
        ? _card(collection, object, grants)
        : _ref(collection.id, object.id);
  }

  /// `trigger.before` / `trigger.after`: like [card], but null without
  /// `data:read`.
  Map<String, Object?>? image(
    Collection collection,
    MorkvaObject? object,
    Grants grants,
  ) => grants.allows(Capability.dataRead)
      ? card(collection, object, grants)
      : null;

  Map<String, Object?> _card(
    Collection collection,
    MorkvaObject object,
    Grants grants,
  ) {
    final readable = [
      for (final f in collection.fields)
        if (!readsUngranted(collection, f, grants, cache.collections)) f,
    ];
    final values = <String, Object?>{};
    for (final f in readable) {
      final shown = shaper.value(
        f,
        object[f.id] ?? f.emptyValue(),
        referenceTitle: (cid, id) => _title(grants, cid, id),
      );
      if (shown != null) values[f.id] = shown;
    }
    return {
      'id': object.id,
      'collectionId': collection.id,
      'title': shaper.title(collection, object),
      'values': values,
      'fields': {for (final f in readable) f.id: shaper.name(f.name)},
    };
  }

  String? _title(Grants grants, String collectionId, String id) {
    if (!grants.allowsCollection(collectionId)) return null;
    final target = cache.collection(collectionId);
    final object = cache.current(collectionId)?[id];
    return target == null || object == null ? null : cardTitle(target, object);
  }

  static Map<String, Object?> _ref(String collectionId, String id) => {
    'id': id,
    'collectionId': collectionId,
  };
}
