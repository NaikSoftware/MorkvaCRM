import 'package:morkva_crm/api/inbox/inbox_repository.dart';
import 'package:morkva_crm/core/domain/inbox/inbox.dart';
import 'package:rxdart/rxdart.dart';

/// What a denied Firestore listener or write reports.
final Exception kInboxDenied = Exception(
  '[cloud_firestore/permission-denied] Missing or insufficient permissions.',
);

/// In-memory [InboxRepository]. Docs are kept as `toJson()` maps and read
/// back through `fromJson`, like the Firestore one; writes complete at once
/// (unlike Firestore's server ack) unless [failWrites] is set.
final class FakeInboxRepository implements InboxRepository {
  FakeInboxRepository({DateTime Function()? now})
    : _now = now ?? (() => DateTime.utc(2026, 11, 14, 12));

  final DateTime Function() _now;
  final docs = <String, Map<String, Object?>>{};
  final _subject = BehaviorSubject<List<InboxItem>>.seeded(const []);
  var _ids = 0;
  String? uid;

  /// Every write call, e.g. `('update', 'i1', {'done': true, ...})`.
  final writes = <(String, String, Map<String, Object?>)>[];

  /// When set, every write fails with it (nothing is stored).
  Object? failWrites;

  List<InboxItem> get items => [
    for (final MapEntry(:key, :value) in docs.entries) ?_read(key, value),
  ];

  InboxItem? _read(String id, Map<String, Object?> json) {
    try {
      return InboxItem.fromJson(id, json);
    } on FormatException {
      return null;
    }
  }

  /// Seeds docs without a write record.
  void seed(Iterable<InboxItem> items) {
    for (final i in items) {
      docs[i.id] = i.toJson();
    }
    _subject.add(this.items);
  }

  /// The watch reports [error] (replayed to new listeners until [recover]).
  void failWatch([Object? error]) => _subject.addError(error ?? kInboxDenied);

  /// Emits the current items again, clearing a [failWatch].
  void recover() => _subject.add(items);

  @override
  void initialize({required String workspaceId, required String uid}) =>
      this.uid = uid;

  @override
  Stream<List<InboxItem>> watch() => _subject.stream;

  @override
  String newId() => 'new_${++_ids}';

  @override
  Future<void> create(InboxItem item) =>
      _write('create', item.id, item.toJson());

  @override
  Future<void> update(String id, Map<String, Object?> fields) => _write(
    'update',
    id,
    {...fields, 'updatedAt': _now().toUtc()},
    merge: true,
  );

  @override
  Future<void> delete(String id) => _write('delete', id, const {});

  Future<void> _write(
    String op,
    String id,
    Map<String, Object?> json, {
    bool merge = false,
  }) async {
    writes.add((op, id, json));
    if (failWrites case final error?) throw error;
    if (op == 'delete') {
      docs.remove(id);
    } else {
      final existing = docs[id];
      if (!merge) {
        docs[id] = json;
      } else if (existing == null) {
        throw StateError('not-found: $id');
      } else {
        docs[id] = {...existing, ...json};
      }
    }
    _subject.add(items);
  }

  Future<void> dispose() => _subject.close();
}
