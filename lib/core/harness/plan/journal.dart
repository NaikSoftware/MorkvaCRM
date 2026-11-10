import 'dart:math';

import '../../domain/domain.dart';
import '../api/capability.dart';
import '../api/envelope.dart';
import 'journal_entry.dart';
import 'plan.dart';

/// The session's undo journal: one [JournalEntry] per commit, in memory for
/// [ttl] (10 minutes) from the commit. `journal.undo` reverts one through
/// `PlanCommitter.undo`; after a reload the host puts a mirrored entry back
/// with [restore], which re-validates every item first (the mirror lives on
/// a member-writable chat message).
final class Journal {
  Journal({this.ttl = const Duration(minutes: 10), Random? random})
    : _random = random ?? Random.secure();

  /// How long a commit can be undone.
  final Duration ttl;
  final Random _random;
  final Map<String, JournalEntry> _entries = {};

  /// Stores a new entry for [planId]'s commit by [actor] at [now].
  JournalEntry record({
    required String planId,
    required Actor actor,
    required DateTime now,
    required List<JournalItem> items,
  }) {
    _prune(now);
    String id;
    do {
      id =
          'j_${[for (var i = 0; i < 8; i++) _random.nextInt(256).toRadixString(16).padLeft(2, '0')].join()}';
    } while (_entries.containsKey(id));
    final entry = JournalEntry(
      journalId: id,
      planId: planId,
      actor: actor.wire,
      createdAt: now,
      expiresAt: now.add(ttl),
      items: items,
    );
    return _entries[id] = entry;
  }

  /// The entry [journalId], expired or not; null when unknown.
  JournalEntry? get(String journalId) => _entries[journalId];

  /// Replaces (or adds) [entry] under its id.
  void put(JournalEntry entry) => _entries[entry.journalId] = entry;

  void remove(String journalId) => _entries.remove(journalId);

  /// Forgets everything (sign-out, a workspace switch).
  void reset() => _entries.clear();

  /// Re-validates the mirrored [json] and puts it back with its original
  /// expiry. [collections] is the live schema. Throws `invalid_args` for an
  /// unreadable entry, `plan_expired` past its `expiresAt` and
  /// `not_permitted` when [actor] did not commit it.
  ///
  /// An item survives only if it can still apply as written: its collection
  /// (and every field it names) exists, each value decodes losslessly to its
  /// field's type and passes the field's own rules, and card items name
  /// writable fields only. Anything else is dropped, item by item.
  RestoreResult restore(
    Map<String, Object?> json, {
    required Actor actor,
    required DateTime now,
    required List<Collection> collections,
    required FieldTypeRegistry registry,
  }) {
    final ({JournalEntry entry, List<DroppedItem> dropped}) parsed;
    try {
      parsed = JournalEntry.parse(json);
    } on FormatException catch (e) {
      throw HarnessException.of(
        ErrorCode.invalidArgs,
        'The journal entry cannot be read: ${e.message}.',
        path: 'entry',
      );
    }
    final entry = parsed.entry;
    if (entry.isExpired(now)) {
      throw HarnessException.of(
        ErrorCode.planExpired,
        'Undo for this change ended at '
        '${entry.expiresAt.toUtc().toIso8601String()}.',
        path: 'entry.expiresAt',
      );
    }
    if (entry.actor != actor.wire) {
      throw HarnessException.of(
        ErrorCode.notPermitted,
        'This change was made by ${entry.actor}, not $actor.',
        path: 'entry.actor',
      );
    }
    final existing = _entries[entry.journalId];
    if (existing != null) {
      // Already in memory (a second restore of the same message).
      return RestoreResult(existing, parsed.dropped);
    }

    final live = {for (final c in collections) c.id: c};
    // Cards of a collection this entry deleted are checked against the
    // deleted schema.
    final deleted = <String, Collection>{};
    for (final item in entry.items.whereType<JournalCollectionDelete>()) {
      try {
        deleted[item.collectionId] = Collection.fromJson(item.before, registry);
      } on Object {
        // Dropped below as invalid.
      }
    }
    final kept = <JournalItem>[];
    final dropped = [...parsed.dropped];
    for (final item in entry.items) {
      final reason = _check(item, live, deleted, registry);
      if (reason == null) {
        kept.add(item);
      } else {
        dropped.add((id: item.targetId, reason: reason));
      }
    }
    final restored = entry.withItems(kept);
    if (kept.isNotEmpty) _entries[restored.journalId] = restored;
    return RestoreResult(restored, dropped);
  }

  void _prune(DateTime now) => _entries.removeWhere((_, e) => e.isExpired(now));

  /// Why [item] cannot be restored, or null.
  static String? _check(
    JournalItem item,
    Map<String, Collection> live,
    Map<String, Collection> deleted,
    FieldTypeRegistry registry,
  ) {
    final schema = live[item.collectionId];
    switch (item) {
      case JournalCollectionDelete():
        if (schema != null) return _schemaChanged;
        return deleted.containsKey(item.collectionId) ? null : _invalid;
      case JournalCardDelete():
        final s = schema ?? deleted[item.collectionId];
        if (s == null) return _schemaChanged;
        for (final e in item.values.entries) {
          final f = s.fieldById(e.key);
          if (f == null) return _schemaChanged;
          if (f is CalculatedFieldDefinition) return _invalid;
          if (!_valid(f, e.value)) return _invalid;
        }
        return null;
      case _ when schema == null:
        return _schemaChanged;
      case JournalCardUpdate(:final keys):
        for (final e in keys.entries) {
          final f = schema.fieldById(e.key);
          if (f == null) return _schemaChanged;
          if (!_writable(f) ||
              !_valid(f, e.value.before) ||
              !_valid(f, e.value.after)) {
            return _invalid;
          }
        }
        return null;
      case JournalCardCreate(:final after):
        for (final e in after.entries) {
          final f = schema.fieldById(e.key);
          if (f == null) return _schemaChanged;
          if (!_writable(f) || !_valid(f, e.value)) return _invalid;
        }
        return null;
      case JournalFieldEntry(:final fieldId, :final before, :final after):
        if (after != null && schema.fieldById(fieldId) == null) {
          return _schemaChanged;
        }
        for (final image in [?before, ?after]) {
          try {
            registry.definitionFromJson(image);
          } on Object {
            return _invalid;
          }
        }
        return null;
      case JournalViewEntry(:final before, :final after):
        for (final image in [?before, ?after]) {
          try {
            ViewDefinition.fromJson(image);
          } on Object {
            return _invalid;
          }
        }
        return null;
      case JournalLayoutEntry() ||
          JournalCollectionMeta() ||
          JournalCollectionCreate():
        return null;
    }
  }

  static const String _schemaChanged = 'schema_changed';
  static const String _invalid = 'invalid';

  /// Calculated and auto-number values are never written by an undo of an
  /// update or create.
  static bool _writable(FieldDefinition f) =>
      f is! CalculatedFieldDefinition && f is! AutoNumberFieldDefinition;

  /// Whether stored [json] decodes to a value of [f] without loss (a wrong
  /// type decodes to empty, so it does not round-trip) and passes [f]'s own
  /// rules. Empty values skip the rules: an undo may put an empty required
  /// field back the way it was.
  static bool _valid(FieldDefinition f, Object? json) {
    final value = f.valueFromJson(json);
    if (!jsonEquals(value.toJson(), json)) return false;
    return value.isEmpty || f.validateValue(value).isEmpty;
  }
}

/// What [Journal.restore] put back and what it dropped.
final class RestoreResult {
  const RestoreResult(this.entry, this.dropped);

  /// The entry as restored (only the kept items).
  final JournalEntry entry;
  final List<DroppedItem> dropped;

  Map<String, Object?> toJson() => {
    'journalId': entry.journalId,
    'expiresAt': entry.expiresAt.toUtc().toIso8601String(),
    'dropped': [
      for (final d in dropped) {'id': d.id, 'reason': d.reason},
    ],
  };
}
